class_name SimWorld
extends RefCounted
## Root of the headless simulation. Nothing in sim/ may touch Node or scenes
## (02_TECH_ARCHITECTURE.md section 3). Deterministic for a given seed.

const TICK_RATE: int = 30  # D-038
const SIM_DT: float = 1.0 / TICK_RATE

## Phases of step(), in tick order (D-083).
enum Phase { COMMANDS, SEPARATE, MOVE, GRID, TARGETING }
## IDLE: no run started; still simulates (M1 demo, bench, tests). D-100.
enum RunState { IDLE, RUNNING, WON, LOST }

## Command clock: advances on every step(), paused or not, so replays address the same ticks.
var tick: int = 0
## Run clock: advances only while RUNNING and not paused (D-100).
var clock: int = 0
var run_state: RunState = RunState.IDLE
var paused: bool = false
## Loaded by StartRun; null before.
var run: RunData = null
var catalog: EnemyCatalog
var tower_catalog: TowerCatalog
## Events of the last step(), cleared at its start.
var events: SimEvents = SimEvents.new()
var enemies: SimEnemies = SimEnemies.new()
## Derived each tick from enemy positions; not part of state_hash().
var grid: SpatialGrid
var separation: EnemySeparation = EnemySeparation.new()
var towers: SimTowers = SimTowers.new()
## Wall-clock usec of each phase of the last step(), indexed by Phase.
## Diagnostics only: never read by rules, not in state_hash(). A missing phase reads 0.
var phase_usec: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0])
## Running sum of phase_usec over every step() (benchmark, task 008). Diagnostics only,
## not in state_hash(); the caller resets it.
var phase_usec_sum: PackedInt64Array = PackedInt64Array([0, 0, 0, 0, 0])
## Test/benchmark/demo setting: when > 0, every AT_GUARDIAN enemy is moved back to a
## ring of this radius each tick (MOVING again), so a demo horde never empties.
## 0 = off. The real spawn curve is M2.
var recycle_radius: float = 0.0
var _grid_count: int = -1
var _t: int = 0
# One RNG per concern, each seeded from the run seed (3a). Others add theirs the same way.
var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Sorted by tick, then enqueue order.
var _queue: Array[SimCommand] = []


func _init(run_seed: int, p_catalog: EnemyCatalog = null) -> void:
	catalog = p_catalog if p_catalog else EnemyCatalog.load_dir()
	tower_catalog = TowerCatalog.load_dir()
	_seed_rngs(run_seed)
	# Cell size = largest enemy collision diameter x 2 (3a).
	grid = SpatialGrid.new(4.0 * catalog.max_radius)


func _seed_rngs(run_seed: int) -> void:
	_spawn_rng.seed = hash([run_seed, "spawns"])


## Queues a command. A late command (tick already passed) is stamped to the current
## tick, and that stamped tick is what a replay must record (D-100).
func queue(cmd: SimCommand) -> void:
	cmd.tick = maxi(cmd.tick, tick)
	var i := _queue.size()
	while i > 0 and _queue[i - 1].tick > cmd.tick:
		i -= 1
	_queue.insert(i, cmd)


## Spawns count enemies of type_id on a ring of ring_radius around the Guardian,
## at angles drawn from the spawn RNG. Test/benchmark API; the real spawn curve is M2.
func spawn_ring(p_type_id: int, count: int, ring_radius: float) -> void:
	var type_hp := catalog.hp[p_type_id]
	for n in count:
		var angle := _spawn_rng.randf() * TAU
		enemies.add(p_type_id, cos(angle) * ring_radius, sin(angle) * ring_radius, type_hp)


## Advances the simulation by exactly one tick of SIM_DT.
## Phase order and the grid invariant: 02_TECH_ARCHITECTURE.md 3a (D-083).
func step() -> void:
	events.clear()
	_t = Time.get_ticks_usec()
	while not _queue.is_empty() and _queue[0].tick <= tick:
		_apply(_queue.pop_front())
	_lap(Phase.COMMANDS)
	if paused or run_state == RunState.WON or run_state == RunState.LOST:
		tick += 1
		return
	if _grid_count != enemies.count():  # safety net: enemies added/removed outside step()
		_rebuild_grid()
		_t = Time.get_ticks_usec()
	separation.apply(enemies, grid, catalog)
	_lap(Phase.SEPARATE)
	enemies.chase_guardian(catalog.speed, catalog.radius, SIM_DT)
	if recycle_radius > 0.0:
		_recycle()
	_lap(Phase.MOVE)
	_rebuild_grid()
	_lap(Phase.GRID)
	towers.retarget(grid, enemies.pos_x, enemies.pos_z)
	_lap(Phase.TARGETING)
	if run_state == RunState.RUNNING:
		clock += 1
	tick += 1


func _apply(cmd: SimCommand) -> void:
	match cmd.type:
		SimCommand.Type.START_RUN:
			if run_state != RunState.IDLE:
				return
			_seed_rngs(cmd.run_seed)
			run = RunData.load_id(cmd.run_id, catalog, tower_catalog)
			clock = 0
			run_state = RunState.RUNNING
		SimCommand.Type.PAUSE:
			paused = cmd.paused
		SimCommand.Type.PLACE_TOWER, SimCommand.Type.SELL_TOWER:
			if paused:  # no building while paused (D-105)
				return
			# task 015
		SimCommand.Type.USE_SKILL:
			pass  # task 017


# In index order, no swap-remove: indices and count stay stable.
func _recycle() -> void:
	var st := enemies.state
	for i in st.size():
		if st[i] != SimEnemies.State.AT_GUARDIAN:
			continue
		var angle := _spawn_rng.randf() * TAU
		enemies.pos_x[i] = cos(angle) * recycle_radius
		enemies.pos_z[i] = sin(angle) * recycle_radius
		enemies.state[i] = SimEnemies.State.MOVING


func _rebuild_grid() -> void:
	grid.rebuild(enemies.pos_x, enemies.pos_z)
	_grid_count = enemies.count()


func _lap(phase: Phase) -> void:
	var now := Time.get_ticks_usec()
	phase_usec[phase] = now - _t
	phase_usec_sum[phase] += now - _t
	_t = now


## Fingerprint of the whole sim state, used by determinism tests.
## Extend it with every entity array as they are added.
func state_hash() -> int:
	return hash([tick, clock, run_state, paused, run.id if run else "", _spawn_rng.state, enemies.pos_x, enemies.pos_z, enemies.hp,
		enemies.type_id, enemies.state, enemies.anim_frame,
		towers.pos_x, towers.pos_z, towers.attack_range, towers.target])
