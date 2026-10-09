extends GutTest
## Command queue and run state (D-100, 02_TECH_ARCHITECTURE.md 3a).

const SWARMER := "enemy_swarmer_01"
const RUN := "run_m2"


func _steps(world: SimWorld, n: int) -> void:
	for i in n:
		world.step()


func test_command_applies_at_its_tick_not_before() -> void:
	var world := SimWorld.new(1)
	world.queue(SimCommand.pause(5, true))
	_steps(world, 5)
	assert_false(world.paused)
	world.step()  # the 6th step runs with tick == 5
	assert_true(world.paused)


func test_late_command_is_stamped_to_current_tick() -> void:
	var world := SimWorld.new(1)
	_steps(world, 10)
	var cmd := SimCommand.pause(2, true)
	world.queue(cmd)
	assert_eq(cmd.tick, 10)
	world.step()
	assert_true(world.paused)


func test_same_tick_commands_apply_in_enqueue_order() -> void:
	var world := SimWorld.new(1)
	world.queue(SimCommand.pause(3, true))
	world.queue(SimCommand.pause(3, false))
	_steps(world, 4)
	assert_false(world.paused)
	var world2 := SimWorld.new(1)
	world2.queue(SimCommand.pause(3, false))
	world2.queue(SimCommand.pause(3, true))
	_steps(world2, 4)
	assert_true(world2.paused)


func test_start_run_loads_run_and_runs() -> void:
	var world := SimWorld.new(1)
	assert_eq(world.run_state, SimWorld.RunState.IDLE)
	world.queue(SimCommand.start_run(0, 7, RUN))
	world.step()
	assert_eq(world.run_state, SimWorld.RunState.RUNNING)
	assert_eq(world.run.id, RUN)
	assert_gt(world.run.wave_ticks, 0)


func test_second_start_run_is_ignored() -> void:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, RUN))
	_steps(world, 10)
	var h := world.state_hash()
	var b := SimWorld.new(1)
	b.queue(SimCommand.start_run(0, 7, RUN))
	b.queue(SimCommand.start_run(5, 99, RUN))
	_steps(b, 10)
	assert_eq(b.clock, 10)
	assert_eq(b.state_hash(), h)


func test_clock_runs_only_while_running_and_not_paused() -> void:
	var world := SimWorld.new(1)
	_steps(world, 3)  # IDLE
	assert_eq(world.clock, 0)
	world.queue(SimCommand.start_run(3, 7, RUN))
	world.queue(SimCommand.pause(8, true))
	world.queue(SimCommand.pause(12, false))
	_steps(world, 17)  # ticks 3..19: running at 3..7 and 12..19
	assert_eq(world.tick, 20)
	assert_eq(world.clock, 13)


func test_paused_world_does_not_move() -> void:
	var world := SimWorld.new(1)
	world.spawn_ring(world.catalog.type_of(SWARMER), 20, 10.0)
	world.queue(SimCommand.pause(0, true))
	var xs := world.enemies.pos_x.duplicate()
	var zs := world.enemies.pos_z.duplicate()
	_steps(world, 5)
	assert_eq(world.enemies.pos_x, xs)
	assert_eq(world.enemies.pos_z, zs)
	assert_eq(world.tick, 5)


func test_stub_commands_do_not_crash() -> void:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, RUN))
	world.queue(SimCommand.place_tower(1, "tower_single_01", 3.0, 4.0))
	world.queue(SimCommand.sell_tower(2, 0))
	world.queue(SimCommand.use_skill(3, "skill_area_blast"))
	world.queue(SimCommand.pause(4, true))
	world.queue(SimCommand.place_tower(5, "tower_single_01", 3.0, 4.0))  # ignored while paused (D-105)
	_steps(world, 6)
	assert_eq(world.tick, 6)
