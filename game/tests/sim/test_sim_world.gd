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


func test_phase_usec_sum_accumulates() -> void:
	var world := SimWorld.new(1)
	world.spawn_ring(0, 10, 5.0)
	for i in 3:
		world.step()
	assert_eq(world.phase_usec_sum.size(), 4)
	for p in 4:
		assert_true(world.phase_usec_sum[p] >= world.phase_usec[p])


func test_recycle_moves_arrived_enemy_back_to_ring() -> void:
	var world := SimWorld.new(1)
	world.recycle_radius = 10.0
	world.enemies.add(0, 0.4, 0.0, 1.0)  # within one tick of contact (radius 0.35)
	world.step()
	assert_eq(world.enemies.count(), 1)
	assert_eq(world.enemies.state[0], SimEnemies.State.MOVING)
	assert_almost_eq(Vector2(world.enemies.pos_x[0], world.enemies.pos_z[0]).length(), 10.0, 1e-3)


func test_recycle_off_by_default() -> void:
	var world := SimWorld.new(1)
	world.enemies.add(0, 0.4, 0.0, 1.0)  # within one tick of contact (radius 0.35)
	world.step()
	assert_eq(world.enemies.state[0], SimEnemies.State.AT_GUARDIAN)
