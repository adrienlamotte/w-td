extends GutTest

const SWARMER := "enemy_swarmer_01"  # catalog sorted by id: type 0 is not the swarmer


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
	world.spawn_ring(world.catalog.type_of(SWARMER), 10, 5.0)
	world.step()
	assert_eq(world.phase_usec.size(), SimWorld.Phase.size())


func test_phase_usec_sum_accumulates() -> void:
	var world := SimWorld.new(1)
	world.spawn_ring(world.catalog.type_of(SWARMER), 10, 5.0)
	for i in 3:
		world.step()
	assert_eq(world.phase_usec_sum.size(), SimWorld.Phase.size())
	for p in SimWorld.Phase.size():
		assert_true(world.phase_usec_sum[p] >= world.phase_usec[p])


func test_recycle_moves_arrived_enemy_back_to_ring() -> void:
	var world := SimWorld.new(1)
	world.recycle_radius = 10.0
	world.enemies.add(world.catalog.type_of(SWARMER), 0.4, 0.0, 1.0)  # within one tick of contact (radius 0.35)
	world.step()
	assert_eq(world.enemies.count(), 1)
	assert_eq(world.enemies.state[0], SimEnemies.State.MOVING)
	assert_almost_eq(Vector2(world.enemies.pos_x[0], world.enemies.pos_z[0]).length(), 10.0, 1e-3)


func test_recycle_off_by_default() -> void:
	var world := SimWorld.new(1)
	world.enemies.add(world.catalog.type_of(SWARMER), 0.4, 0.0, 1.0)  # within one tick of contact (radius 0.35)
	world.step()
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING)


func test_start_run_starts_wave_zero_and_spawns() -> void:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	assert_eq(world.events.count, 1)
	assert_eq(world.events.kind[0], SimEvents.Kind.WAVE_STARTED)
	assert_eq(world.events.a[0], 0)
	# Even spread: the first spawn of a wave of n is at offset wave_ticks / n - 1.
	var first := world.run.wave_ticks / world.run.wave_count[0]
	for i in first - 2:
		world.step()
	assert_eq(world.enemies.count(), 0)
	world.step()
	assert_eq(world.enemies.count(), 1)


func test_idle_spawns_nothing() -> void:
	var world := SimWorld.new(1)
	for i in 300:
		world.step()
	assert_eq(world.enemies.count(), 0)
	assert_eq(world.events.count, 0)
