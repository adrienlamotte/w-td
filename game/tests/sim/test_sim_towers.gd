extends GutTest
## Tower arrays and per-tick nearest targeting (D-085).

const SWARMER := "enemy_swarmer_01"  # catalog sorted by id: type 0 is not the swarmer
const BUILD_RADIUS: float = 20.0
const RANGE: float = 8.0

var _rng: RandomNumberGenerator


func before_each() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 777


func _add_spread_towers(world: SimWorld, n: int) -> void:
	for t in n:
		var angle := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * BUILD_RADIUS
		world.towers.add(cos(angle) * r, sin(angle) * r, RANGE)


func _brute_nearest(world: SimWorld, t: int) -> int:
	var best := -1
	var best_d2 := INF
	var r := world.towers.attack_range[t]
	for i in world.enemies.count():
		var dx := world.enemies.pos_x[i] - world.towers.pos_x[t]
		var dz := world.enemies.pos_z[i] - world.towers.pos_z[t]
		var d2 := dx * dx + dz * dz
		if d2 <= r * r and d2 < best_d2:  # strict: lowest index wins ties
			best = i
			best_d2 = d2
	return best


func test_target_is_nearest_enemy_in_range() -> void:
	var world := SimWorld.new(42)
	world.spawn_ring(world.catalog.type_of(SWARMER), 200, 24.0)
	_add_spread_towers(world, 20)
	var with_target := 0
	for s in 40:
		world.step()
		for t in world.towers.count():
			assert_eq(world.towers.target[t], _brute_nearest(world, t), "tick %d tower %d" % [world.tick, t])
			if world.towers.target[t] != -1:
				with_target += 1
	assert_gt(with_target, 0, "some towers must have had a target")


func test_out_of_range_then_picked_up() -> void:
	var world := SimWorld.new(1)
	world.enemies.add(world.catalog.type_of(SWARMER), 12.0, 0.0, 1.0)
	world.towers.add(10.0, 0.0, 1.0)
	world.step()
	assert_eq(world.towers.target[0], -1)
	for s in 30:
		world.step()
		var d := Vector2(world.enemies.pos_x[0] - 10.0, world.enemies.pos_z[0]).length()
		assert_eq(world.towers.target[0], 0 if d <= 1.0 else -1, "tick %d" % world.tick)
		if world.towers.target[0] == 0:
			break
	assert_eq(world.towers.target[0], 0, "enemy walking into range is targeted")


func _targeting_usec(ring: float) -> int:
	var world := SimWorld.new(9)
	world.spawn_ring(world.catalog.type_of(SWARMER), 3000, ring)
	_add_spread_towers(world, 300)
	world.step()
	world.step()
	return world.phase_usec[SimWorld.Phase.TARGETING]


func test_300_towers_with_3000_enemies() -> void:
	var world := SimWorld.new(3)
	_add_spread_towers(world, 300)
	assert_eq(world.towers.count(), 300)
	for a: PackedFloat32Array in [world.towers.pos_x, world.towers.pos_z, world.towers.attack_range]:
		assert_eq(a.size(), 300)
	assert_eq(world.towers.target.size(), 300)
	# Ring 30: no enemy within any tower's range (worst case, every ring scanned).
	gut.p("TARGETING 300 towers / 3000 enemies, none in range: %d usec" % _targeting_usec(30.0))
	# Ring 12: enemies among the towers.
	gut.p("TARGETING 300 towers / 3000 enemies, among towers: %d usec" % _targeting_usec(12.0))
	pass_test("ran")
