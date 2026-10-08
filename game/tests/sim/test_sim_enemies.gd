extends GutTest

var world: SimWorld
var speed: float
var radius: float


func before_each() -> void:
	world = SimWorld.new(1)
	speed = world.catalog.speed[0]
	radius = world.catalog.radius[0]


func test_moves_speed_times_dt_toward_origin() -> void:
	world.enemies.add(0, 10.0, 0.0, 1.0)
	world.step()
	assert_almost_eq(world.enemies.pos_x[0], 10.0 - speed * SimWorld.SIM_DT, 1e-4)
	assert_almost_eq(world.enemies.pos_z[0], 0.0, 1e-6)


func test_moves_along_diagonal() -> void:
	world.enemies.add(0, 6.0, -8.0, 1.0)  # distance 10
	world.step()
	var f := (10.0 - speed * SimWorld.SIM_DT) / 10.0
	assert_almost_eq(world.enemies.pos_x[0], 6.0 * f, 1e-4)
	assert_almost_eq(world.enemies.pos_z[0], -8.0 * f, 1e-4)


func test_stops_at_guardian() -> void:
	world.enemies.add(0, radius + speed * SimWorld.SIM_DT * 0.5, 0.0, 1.0)
	world.step()
	assert_almost_eq(world.enemies.pos_x[0], radius, 1e-5)
	assert_eq(world.enemies.state[0], SimEnemies.State.AT_GUARDIAN)
	for i in 10:
		world.step()
	assert_almost_eq(world.enemies.pos_x[0], radius, 1e-5)
	assert_eq(world.enemies.state[0], SimEnemies.State.AT_GUARDIAN)


func test_spawn_ring_count_and_distance() -> void:
	world.spawn_ring(0, 1000, 30.0)
	assert_eq(world.enemies.count(), 1000)
	for i in 1000:
		var x := world.enemies.pos_x[i]
		var z := world.enemies.pos_z[i]
		assert_almost_eq(sqrt(x * x + z * z), 30.0, 1e-3)


func test_remove_middle_swaps_last_in() -> void:
	var e := world.enemies
	for i in 3:
		e.add(i, float(i), float(i) + 10.0, float(i) + 20.0)
	e.state[2] = SimEnemies.State.AT_GUARDIAN
	e.anim_frame[2] = 7
	e.remove(1)
	assert_eq(e.count(), 2)
	assert_eq(e.pos_x[1], 2.0)
	assert_eq(e.pos_z[1], 12.0)
	assert_eq(e.hp[1], 22.0)
	assert_eq(e.type_id[1], 2)
	assert_eq(e.state[1], SimEnemies.State.AT_GUARDIAN)
	assert_eq(e.anim_frame[1], 7)
	for arr in [e.pos_x, e.pos_z, e.hp, e.type_id, e.state, e.anim_frame]:
		assert_eq(arr.size(), 2)


func test_remove_last() -> void:
	var e := world.enemies
	e.add(0, 1.0, 1.0, 1.0)
	e.add(0, 2.0, 2.0, 2.0)
	e.remove(1)
	assert_eq(e.count(), 1)
	assert_eq(e.pos_x[0], 1.0)
