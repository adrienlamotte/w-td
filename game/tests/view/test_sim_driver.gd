extends GutTest

const SWARMER := "enemy_swarmer_01"  # catalog sorted by id: type 0 is not the swarmer

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
	world.enemies.add(world.catalog.type_of(SWARMER), 10.0, 0.0, 1.0)
	driver.advance(SimWorld.SIM_DT * 1.0001)
	var prev := world.enemies.prev_x[0]
	var cur := world.enemies.pos_x[0]
	assert_ne(prev, cur, "the enemy moves toward the Guardian")
	assert_almost_eq(driver.interp_x(0), prev, 1e-3)
	driver.advance(SimWorld.SIM_DT * 0.5)
	assert_almost_eq(driver.interp_x(0), (prev + cur) * 0.5, 1e-3)
	assert_almost_eq(driver.interp_z(0), 0.0, 1e-3)


func test_new_enemy_uses_current_position() -> void:
	driver.advance(0.05)
	world.enemies.add(world.catalog.type_of(SWARMER), 7.0, 3.0, 1.0)
	assert_eq(driver.interp_x(0), 7.0)
	assert_eq(driver.interp_z(0), 3.0)


func test_survivor_interpolates_from_its_own_position_after_a_death() -> void:
	var sw := world.catalog.type_of(SWARMER)
	world.enemies.add(sw, 10.0, 0.0, 1.0)
	world.enemies.add(sw, 10.0, 1.0, 1.0)  # closer than the snap distance
	world.step()
	var own_prev_z := world.enemies.pos_z[1]
	world.enemies.hp[0] = 0.0  # dies in the next DEATHS: enemy 1 moves into slot 0
	driver.advance(SimWorld.SIM_DT * 1.0001)
	assert_eq(world.enemies.count(), 1)
	assert_eq(world.enemies.prev_z[0], own_prev_z, "slot 0 keeps the survivor's previous position")
	assert_almost_eq(driver.interp_z(0), own_prev_z, 1e-3)


func test_on_step_once_per_step() -> void:
	var calls := [0]
	driver.on_step = func() -> void: calls[0] += 1
	assert_eq(driver.advance(0.11), 3)
	assert_eq(calls[0], 3)
