extends GutTest

var world: SimWorld
var driver: SimDriver


func before_each() -> void:
	world = SimWorld.new(1)
	driver = SimDriver.new(world)


func test_one_and_a_half_ticks() -> void:
	assert_eq(driver.advance(0.05), 1)
	assert_almost_eq(driver.alpha(), 0.5, 1e-4)


func test_several_ticks_in_one_frame() -> void:
	assert_eq(driver.advance(0.11), 3)
	assert_eq(world.tick, 3)


func test_hitch_is_capped() -> void:
	assert_eq(driver.advance(10.0), SimDriver.MAX_STEPS_PER_FRAME)
	assert_lt(driver.alpha(), 1.0)
	assert_eq(driver.advance(0.0), 0)


func test_interpolates_between_ticks() -> void:
	world.enemies.add(0, 10.0, 0.0, 1.0)
	driver.advance(SimWorld.SIM_DT * 1.0001)
	var prev := driver.prev_x[0]
	var cur := world.enemies.pos_x[0]
	assert_ne(prev, cur, "the enemy moves toward the Guardian")
	assert_almost_eq(driver.interp_x(0), prev, 1e-3)
	driver.advance(SimWorld.SIM_DT * 0.5)
	assert_almost_eq(driver.interp_x(0), (prev + cur) * 0.5, 1e-3)
	assert_almost_eq(driver.interp_z(0), 0.0, 1e-3)


func test_new_enemy_uses_current_position() -> void:
	driver.advance(0.05)
	world.enemies.add(0, 7.0, 3.0, 1.0)
	assert_eq(driver.interp_x(0), 7.0)
	assert_eq(driver.interp_z(0), 3.0)
