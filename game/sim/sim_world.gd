class_name SimWorld
extends RefCounted
## Root of the headless simulation. Nothing in sim/ may touch Node or scenes
## (02_TECH_ARCHITECTURE.md section 3). Deterministic for a given seed.

const TICK_RATE: int = 30  # D-038
const SIM_DT: float = 1.0 / TICK_RATE

## Phases of step(), in tick order (D-083).
enum Phase { SEPARATE, MOVE, GRID, TARGETING }

var tick: int = 0
var catalog: EnemyCatalog
var enemies: SimEnemies = SimEnemies.new()
## Derived each tick from enemy positions; not part of state_hash().
var grid: SpatialGrid
var separation: EnemySeparation = EnemySeparation.new()
var towers: SimTowers = SimTowers.new()
## Wall-clock usec of each phase of the last step(), indexed by Phase.
## Diagnostics only: never read by rules, not in state_hash(). A missing phase reads 0.
var phase_usec: PackedInt64Array = PackedInt64Array([0, 0, 0, 0])
## Test/benchmark/demo setting: when > 0, every AT_GUARDIAN enemy is moved back to a
## ring of this radius each tick (MOVING again), so a demo horde never empties.
## 0 = off. The real spawn curve is M2.
var recycle_radius: float = 0.0
var _grid_count: int = -1
var _t: int = 0
# One RNG per concern, each seeded from the run seed (3a). Others add theirs the same way.
var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(run_seed: int, p_catalog: EnemyCatalog = null) -> void:
	catalog = p_catalog if p_catalog else EnemyCatalog.load_dir()
	_spawn_rng.seed = hash([run_seed, "spawns"])
	# Cell size = largest enemy collision diameter x 2 (3a).
	grid = SpatialGrid.new(4.0 * catalog.max_radius)


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
	tick += 1


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
	_t = now


## Fingerprint of the whole sim state, used by determinism tests.
## Extend it with every entity array as they are added.
func state_hash() -> int:
	return hash([tick, _spawn_rng.state, enemies.pos_x, enemies.pos_z, enemies.hp,
		enemies.type_id, enemies.state, enemies.anim_frame,
		towers.pos_x, towers.pos_z, towers.attack_range, towers.target])
