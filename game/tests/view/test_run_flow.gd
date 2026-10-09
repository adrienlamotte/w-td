extends GutTest
## RunFlow (D-125): slow-time factor and determinism of a scaled driver delta.

const SINGLE := "tower_single_01"
const END_TICK := 150


func test_time_scale_truth_table() -> void:
	assert_eq(RunFlow.time_scale(false, true, true, 0.5), 1.0, "option off")
	assert_eq(RunFlow.time_scale(true, true, true, 0.5), 0.5, "placing")
	assert_eq(RunFlow.time_scale(true, false, true, 0.5), 1.0, "not placing")
	assert_eq(RunFlow.time_scale(true, true, false, 0.5), 1.0, "paused or not running")


func test_slow_time_scale_in_data() -> void:
	var s := float(PlacementGhost.load_config().slow_time_scale)
	assert_gt(s, 0.0)
	assert_lte(s, 1.0)


# Same seed, same commands at the same ticks; only the frame deltas differ.
func _run(scaled: bool) -> SimWorld:
	var w := SimWorld.new(1)
	var d := SimDriver.new(w)
	w.queue(SimCommand.start_run(0, 42, "run_m2"))
	var sent := {}
	var frame := 0
	while w.tick < END_TICK:
		if w.tick >= 30 and not sent.has("place"):
			sent["place"] = true
			w.queue(SimCommand.place_tower(w.tick, SINGLE, 3.0, 4.0))
		if w.tick >= 60 and not sent.has("skill"):
			sent["skill"] = true
			w.queue(SimCommand.use_skill(w.tick, w.run.skill_ids[0]))
		var scale := 0.5 if scaled and frame % 3 != 0 else 1.0
		d.advance(SimWorld.SIM_DT * 0.5 * scale)  # at most one tick per frame: no overshoot
		frame += 1
	return w


func test_scaled_delta_is_deterministic() -> void:
	var a := _run(false)
	var b := _run(true)
	assert_eq(a.tick, END_TICK)
	assert_eq(b.tick, END_TICK)
	assert_gt(a.towers.uid.size(), 0, "the tower was placed")
	assert_eq(a.state_hash(), b.state_hash())
