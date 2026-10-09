class_name SimWorld
extends RefCounted
## Root of the headless simulation. Nothing in sim/ may touch Node or scenes
## (02_TECH_ARCHITECTURE.md section 3). Deterministic for a given seed.

const TICK_RATE: int = 30  # D-038
const SIM_DT: float = 1.0 / TICK_RATE

## Phases of step(), in tick order (D-083).
enum Phase { COMMANDS, SEPARATE, MOVE, DEATHS, SPAWN, GRID, TARGETING, ATTACKS }
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
## Created at StartRun from the run's build radius and grid step; null before (D-109).
var build: BuildGrid = null
## Uid of the next placed tower: starts at 0, never reused (D-109).
var next_tower_uid: int = 0
var movement: EnemyMovement = EnemyMovement.new()
var tower_attacks: TowerAttacks = TowerAttacks.new()
## Set from the run at StartRun (D-107); 0 before.
var guardian_hp: float = 0.0
var gold: int = 0
## Wall-clock usec of each phase of the last step(), indexed by Phase.
## Diagnostics only: never read by rules, not in state_hash(). A missing phase reads 0.
var phase_usec: PackedInt64Array = PackedInt64Array()
## Running sum of phase_usec over every step() (benchmark, task 008). Diagnostics only,
## not in state_hash(); the caller resets it.
var phase_usec_sum: PackedInt64Array = PackedInt64Array()
## Test/benchmark/demo setting: when > 0, every stopped enemy (ATTACKING or QUEUED) is moved back to a
## ring of this radius each tick (MOVING again), so a demo horde never empties.
## 0 = off. Runs spawn from their timeline instead (WaveSpawner).
var recycle_radius: float = 0.0
var _grid_count: int = -1
var _t: int = 0
# One RNG per concern, each seeded from the run seed (3a). Others add theirs the same way.
var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Sorted by tick, then enqueue order.
var _queue: Array[SimCommand] = []


func _init(run_seed: int, p_catalog: EnemyCatalog = null) -> void:
	catalog = p_catalog if p_catalog else EnemyCatalog.load_dir()
	tower_catalog = TowerCatalog.load_dir()
	phase_usec.resize(Phase.size())
	phase_usec_sum.resize(Phase.size())
	_seed_rngs(run_seed)
	movement.set_stop(catalog, 0.0)  # IDLE: no Guardian body, stop at own radius (M1)
	# Cell size = largest horde collision diameter (3a, D-108).
	grid = SpatialGrid.new(2.0 * catalog.max_radius)


func _seed_rngs(run_seed: int) -> void:
	_spawn_rng.seed = hash([run_seed, "spawns"])
	_loot_rng.seed = hash([run_seed, "loot"])


## Queues a command. A late command (tick already passed) is stamped to the current
## tick, and that stamped tick is what a replay must record (D-100).
func queue(cmd: SimCommand) -> void:
	cmd.tick = maxi(cmd.tick, tick)
	var i := _queue.size()
	while i > 0 and _queue[i - 1].tick > cmd.tick:
		i -= 1
	_queue.insert(i, cmd)


## Spawns count enemies of type_id on a ring of ring_radius around the Guardian,
## at angles drawn from the spawn RNG. Test/benchmark API; runs spawn through WaveSpawner.
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
	movement.steer(enemies)
	movement.advance(enemies, catalog.speed, SIM_DT, separation.blocked)
	if recycle_radius > 0.0:
		_recycle()
	_lap(Phase.MOVE)
	_deaths()
	_lap(Phase.DEATHS)
	if run_state == RunState.RUNNING:
		WaveSpawner.step(clock, run, catalog, enemies, _spawn_rng, events)
	_lap(Phase.SPAWN)
	_rebuild_grid()
	_lap(Phase.GRID)
	towers.retarget(grid, enemies.pos_x, enemies.pos_z)
	_lap(Phase.TARGETING)
	if run_state == RunState.RUNNING:
		tower_attacks.fire(self)  # towers first: an enemy killed this tick does not attack (D-114)
		_enemy_attacks()
	_lap(Phase.ATTACKS)
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
			movement.set_stop(catalog, run.guardian_contact_radius)
			guardian_hp = run.guardian_hp
			gold = run.starting_gold
			build = BuildGrid.new(run.build_radius, run.grid_step)
			clock = 0
			run_state = RunState.RUNNING
		SimCommand.Type.PAUSE:
			paused = cmd.paused
		SimCommand.Type.PLACE_TOWER, SimCommand.Type.SELL_TOWER, SimCommand.Type.REBUILD_TOWER:
			if run_state != RunState.RUNNING or paused:  # no building while paused (D-105)
				return
			if cmd.type == SimCommand.Type.PLACE_TOWER:
				TowerBuilding.place(self, cmd)
			elif cmd.type == SimCommand.Type.SELL_TOWER:
				TowerBuilding.sell(self, cmd.tower_uid)
			else:
				TowerBuilding.rebuild(self, cmd.tower_uid)
		SimCommand.Type.USE_SKILL:
			pass  # task 017


# In index order, no swap-remove: indices and count stay stable.
func _recycle() -> void:
	var st := enemies.state
	for i in st.size():
		if st[i] == SimEnemies.State.MOVING:
			continue
		var angle := _spawn_rng.randf() * TAU
		enemies.pos_x[i] = cos(angle) * recycle_radius
		enemies.pos_z[i] = sin(angle) * recycle_radius
		enemies.state[i] = SimEnemies.State.MOVING


## Single entry point for every damage source (towers, skills; D-107).
## A corpse (hp <= 0) ignores it; it is removed in the next DEATHS phase.
func damage_enemy(i: int, amount: float) -> void:
	if enemies.hp[i] <= 0.0:
		return
	enemies.hp[i] -= amount
	events.push(SimEvents.Kind.ENEMY_HIT, enemies.type_id[i], enemies.pos_x[i], enemies.pos_z[i], amount)


## Single entry point for damage to towers (task 024 calls it). A lethal hit leaves a husk (D-104, D-109).
func damage_tower(t: int, amount: float) -> void:
	TowerBuilding.damage(self, t, amount)


# Highest index first, so a swap-remove never moves an unvisited enemy (D-081).
func _deaths() -> void:
	var hp := enemies.hp
	for i in range(enemies.count() - 1, -1, -1):
		if hp[i] > 0.0:
			continue
		var t := enemies.type_id[i]
		var x := enemies.pos_x[i]
		var z := enemies.pos_z[i]
		var chance := catalog.gold_chance[t]
		var gained := 0
		if chance >= 1.0 or _loot_rng.randf() < chance:
			gained = catalog.gold[t]
		gold += gained
		enemies.remove(i)
		events.push(SimEvents.Kind.ENEMY_DIED, t, x, z, gained)
		if run and run_state == RunState.RUNNING and t == run.final_boss_type:
			run_state = RunState.WON
			events.push(SimEvents.Kind.RUN_ENDED, 1, 0.0, 0.0, 0.0)


# Instant hits (D-098): the first on arrival, then one every attack_cooldown ticks.
func _enemy_attacks() -> void:
	var hp := enemies.hp
	var st := enemies.state
	var cd := enemies.cooldown
	for i in enemies.count():
		if hp[i] <= 0.0:
			continue
		if cd[i] > 0:
			cd[i] -= 1
		if cd[i] == 0 and st[i] == SimEnemies.State.ATTACKING:
			var t := enemies.type_id[i]
			cd[i] = catalog.attack_cooldown[t]
			_hit_guardian(t, enemies.pos_x[i], enemies.pos_z[i], catalog.damage[t])
			if run_state == RunState.LOST:
				return


# Task 017 inserts the Shield here.
func _hit_guardian(type_id: int, x: float, z: float, dmg: float) -> void:
	guardian_hp -= dmg
	events.push(SimEvents.Kind.GUARDIAN_HIT, type_id, x, z, dmg)
	if guardian_hp <= 0.0:
		run_state = RunState.LOST
		events.push(SimEvents.Kind.RUN_ENDED, 0, 0.0, 0.0, 0.0)


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
	return hash([tick, clock, run_state, paused, run.id if run else "", _spawn_rng.state, _loot_rng.state,
		guardian_hp, gold, enemies.pos_x, enemies.pos_z, enemies.hp,
		enemies.type_id, enemies.state, enemies.anim_frame, enemies.cooldown, enemies.slow_factor, enemies.slow_ticks,
		towers.pos_x, towers.pos_z, towers.attack_range, towers.target, next_tower_uid,
		towers.uid, towers.type_id, towers.hp, towers.husk, towers.paid, towers.cell_i, towers.cell_j,
		towers.cooldown])
