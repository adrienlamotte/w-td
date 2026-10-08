class_name SimWorld
extends RefCounted
## Root of the headless simulation. Nothing in sim/ may touch Node or scenes
## (02_TECH_ARCHITECTURE.md section 3). Deterministic for a given seed.

const TICK_RATE: int = 30  # D-038
const SIM_DT: float = 1.0 / TICK_RATE

var tick: int = 0
var catalog: EnemyCatalog
var enemies: SimEnemies = SimEnemies.new()
# One RNG per concern, each seeded from the run seed (3a). Others add theirs the same way.
var _spawn_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(run_seed: int, p_catalog: EnemyCatalog = null) -> void:
	catalog = p_catalog if p_catalog else EnemyCatalog.load_dir()
	_spawn_rng.seed = hash([run_seed, "spawns"])


## Spawns count enemies of type_id on a ring of ring_radius around the Guardian,
## at angles drawn from the spawn RNG. Test/benchmark API; the real spawn curve is M2.
func spawn_ring(p_type_id: int, count: int, ring_radius: float) -> void:
	var type_hp := catalog.hp[p_type_id]
	for n in count:
		var angle := _spawn_rng.randf() * TAU
		enemies.add(p_type_id, cos(angle) * ring_radius, sin(angle) * ring_radius, type_hp)


## Advances the simulation by exactly one tick of SIM_DT.
func step() -> void:
	enemies.chase_guardian(catalog.speed, catalog.radius, SIM_DT)
	tick += 1


## Fingerprint of the whole sim state, used by determinism tests.
## Extend it with every entity array as they are added.
func state_hash() -> int:
	return hash([tick, _spawn_rng.state, enemies.pos_x, enemies.pos_z, enemies.hp,
		enemies.type_id, enemies.state, enemies.anim_frame])
