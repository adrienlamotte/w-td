extends GutTest
## Same seed + same commands = same state (02_TECH_ARCHITECTURE.md section 6).
## No commands exist yet; feed the same command list to both worlds once they do.

const TICKS: int = 30 * 60  # one simulated minute
const ENEMIES: int = 1000

var _hash_a: int
var _hash_a2: int
var _hash_b: int


func _run(run_seed: int) -> int:
	var world := SimWorld.new(run_seed)
	world.spawn_ring(0, ENEMIES, 30.0)
	var start := Time.get_ticks_msec()
	for i in TICKS:
		world.step()
	gut.p("seed %d: %d ticks x %d enemies in %d ms" % [run_seed, TICKS, ENEMIES, Time.get_ticks_msec() - start])
	return world.state_hash()


func before_all() -> void:
	_hash_a = _run(12345)
	_hash_a2 = _run(12345)
	_hash_b = _run(54321)


func test_same_seed_same_state() -> void:
	assert_eq(_hash_a, _hash_a2)


func test_different_seed_different_state() -> void:
	assert_ne(_hash_a, _hash_b)
