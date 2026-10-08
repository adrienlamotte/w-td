extends GutTest


func test_tick_rate_is_30hz() -> void:
	assert_almost_eq(SimWorld.SIM_DT, 1.0 / 30.0, 1e-9)


func test_step_advances_one_tick() -> void:
	var world := SimWorld.new(1)
	world.step()
	assert_eq(world.tick, 1)


func test_thirty_steps_is_one_second() -> void:
	var world := SimWorld.new(1)
	for i in 30:
		world.step()
	assert_almost_eq(world.tick * SimWorld.SIM_DT, 1.0, 1e-6)


func test_step_records_phase_times() -> void:
	var world := SimWorld.new(1)
	world.spawn_ring(0, 10, 5.0)
	world.step()
	assert_eq(world.phase_usec.size(), 4)
