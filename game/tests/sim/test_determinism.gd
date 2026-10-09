extends GutTest
## Same seed + same commands = same state (02_TECH_ARCHITECTURE.md section 6).
## No commands here; test_replay.gd covers same seed + same commands.

const SWARMER := "enemy_swarmer_01"  # catalog sorted by id: type 0 is not the swarmer
const TICKS: int = 30 * 60  # one simulated minute
const ENEMIES: int = 1000
const TOWERS: int = 50

var _hash_a: int
var _hash_a2: int
var _hash_b: int


func _run(run_seed: int) -> int:
	var world := SimWorld.new(run_seed)
	world.recycle_radius = 30.0  # the minute is long enough for arrivals: covers the recycle path
	world.spawn_ring(world.catalog.type_of(SWARMER), ENEMIES, 30.0)
	for t in TOWERS:  # same towers for every run, on a spiral inside the build radius
		var angle := t * 2.4
		var r := 20.0 * sqrt((t + 0.5) / TOWERS)
		world.towers.add(cos(angle) * r, sin(angle) * r, 8.0)
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


func _run_m2(run_seed: int) -> int:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	for i in 2400:  # wave 0, its break, the start of wave 1
		world.step()
	assert_gt(world.enemies.count(), 0)
	return world.state_hash()


func test_run_spawns_deterministic() -> void:
	var h := _run_m2(7)
	assert_eq(_run_m2(7), h)
	assert_ne(_run_m2(8), h)


# Maze routing (D-115): a wall placed, one tower killed into a husk, one sold, mid-run.
func _run_maze(run_seed: int) -> int:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	world.step()
	world.gold = 1 << 30
	for z in range(-6, 7):
		world.queue(SimCommand.place_tower(world.tick, "tower_single_01", 8.0, z))
		world.queue(SimCommand.place_tower(world.tick, "tower_single_01", -8.0, z))
	for i in 600:
		world.step()
	world.damage_tower(3, 1e9)
	world.queue(SimCommand.sell_tower(world.tick, world.towers.uid[20]))
	for i in 900:
		world.step()
	assert_gt(world.field.recomputes, 2)
	assert_gt(world.enemies.count(), 0)
	return world.state_hash()


func test_maze_deterministic() -> void:
	var h := _run_maze(7)
	assert_eq(_run_maze(7), h)
	assert_ne(_run_maze(8), h)
