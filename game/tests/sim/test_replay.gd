extends GutTest
## Acceptance test of task 012: same seed + same commands = same state hash (D-100).

const SWARMER := "enemy_swarmer_01"
const TICKS: int = 600


func _commands(run_seed: int, unpause_tick: int) -> Array[SimCommand]:
	return [
		SimCommand.start_run(0, run_seed, "run_m2"),
		SimCommand.place_tower(30, "tower_single_01", 3.0, 4.0),
		SimCommand.pause(100, true),
		SimCommand.pause(unpause_tick, false),
		SimCommand.use_skill(200, "skill_area_blast"),
		SimCommand.use_skill(220, "skill_shield"),
		SimCommand.sell_tower(210, 0),
	]


func _run(cmds: Array[SimCommand]) -> int:
	var world := SimWorld.new(12345)
	world.recycle_radius = 30.0
	world.spawn_ring(world.catalog.type_of(SWARMER), 300, 30.0)
	for t in 20:
		var angle := t * 2.4
		var r := 20.0 * sqrt((t + 0.5) / 20)
		world.towers.add(cos(angle) * r, sin(angle) * r, 8.0)
	for c in cmds:
		world.queue(c)
	for i in TICKS:
		world.step()
	return world.state_hash()


func test_replay() -> void:
	var h := _run(_commands(7, 160))
	assert_eq(_run(_commands(7, 160)), h, "same commands")
	var shuffled := _commands(7, 160)
	shuffled.reverse()
	var tmp := shuffled[1]
	shuffled[1] = shuffled[3]
	shuffled[3] = tmp
	assert_eq(_run(shuffled), h, "same commands queued in another order")
	assert_ne(_run(_commands(7, 190)), h, "later unpause")
	assert_ne(_run(_commands(8, 160)), h, "other run seed")
