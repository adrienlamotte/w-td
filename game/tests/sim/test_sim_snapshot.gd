extends GutTest
## Suspend-save snapshot (D-167): a restored run continues exactly like the uninterrupted one,
## and a bad snapshot is refused with a reason.

const AFTER: int = 600


# Picks slot 0 of every draft that opens (the same in both worlds), so the run keeps going.
func _steps(w: SimWorld, n: int) -> void:
	for i in n:
		if w.draft.drafting:
			w.queue(SimCommand.pick_card(w.tick, 0))
		w.step()


func _settle(w: SimWorld) -> void:
	for i in 100:
		if w.field.settled():
			return
		w.step()


# A run_m3 world with Cinder's Guardian, towers (one upgraded, one a husk) and a skill used.
func _world() -> SimWorld:
	var w := SimWorld.new(42)
	w.queue(SimCommand.start_run(0, 4242, "run_m3", "guardian_cinder"))
	_steps(w, 30)
	w.gold = 2000
	for p: Vector2 in [Vector2(4, 0), Vector2(-4, 1), Vector2(0, 5), Vector2(3, -4)]:
		w.queue(SimCommand.place_tower(w.tick, "tower_pip" if p.x >= 0 else "tower_mallow", p.x, p.y))
	_steps(w, 5)
	w.queue(SimCommand.upgrade_tower(w.tick, 0))
	w.queue(SimCommand.use_skill(w.tick, "skill_shield"))
	_steps(w, 300)
	w.damage_tower(w.towers.uid_index[3], 1e6)  # a husk
	_steps(w, 1)
	_settle(w)
	return w


func _json(d: Dictionary) -> Variant:
	return JSON.parse_string(JSON.stringify(d, "\t", false, true))


# Restores a JSON round trip of `w` into a world with another seed; checks hash and field.
func _restored(w: SimWorld) -> SimWorld:
	assert_true(w.field.settled(), "captured with a settled field")
	var r := SimWorld.new(999)  # another seed: the RNG states must come from the file
	assert_eq(SimSnapshot.restore(r, _json(SimSnapshot.capture(w))), "")
	assert_eq(r.state_hash(), w.state_hash())
	assert_eq(r.field.dist, w.field.dist, "rebuilt field = live field")
	assert_eq(r.field.dir, w.field.dir)
	return r


func test_draft_round_trip() -> void:
	var w := _world()
	w.queue(SimCommand.place_tower(w.tick, "tower_pip", -3, -5))  # a layout change shortly before
	_steps(w, 1)
	_settle(w)
	w.draft.xp = w.draft.xp_next
	_steps(w, 1)
	assert_true(w.draft.drafting)
	var r := _restored(w)
	for x: SimWorld in [w, r]:
		x.queue(SimCommand.pick_card(x.tick, 1))
		_steps(x, AFTER)
	assert_gt(w.enemies.count(), 0)
	assert_eq(r.state_hash(), w.state_hash())


func test_wave_start_round_trip() -> void:
	var w := _world()
	var wave_at := w.run.first_wave_tick + w.run.wave_ticks + w.run.break_ticks
	_steps(w, wave_at - w.clock - 20)
	w.queue(SimCommand.place_tower(w.tick, "tower_mallow", -6, -2))
	w.spawn_ring(w.catalog.type_of("enemy_swarmer_01"), 50, 30.0)  # wave 1 is cleared by now
	var seen := false
	for i in 100:
		_steps(w, 1)
		for e in w.events.count:
			seen = seen or w.events.kind[e] == SimEvents.Kind.WAVE_STARTED
		if seen:
			break
	assert_true(seen, "wave 2 started (clock %d, state %d)" % [w.clock, w.run_state])
	assert_gt(w.towers.husk.count(1), 0)
	assert_gt(w.enemies.count(), 0)
	var r := _restored(w)
	_steps(w, AFTER)
	_steps(r, AFTER)
	assert_eq(r.state_hash(), w.state_hash())


func test_queued_command_survives() -> void:
	var w := _world()
	w.queue(SimCommand.place_tower(w.tick + 50, "tower_pip", 6, 6))
	var r := _restored(w)
	var before := r.towers.count()
	_steps(w, 100)
	_steps(r, 100)
	assert_eq(r.towers.count(), before + 1)
	assert_eq(r.state_hash(), w.state_hash())


func test_bad_snapshots_are_refused() -> void:
	var good: Dictionary = _json(SimSnapshot.capture(_world()))
	var cases := {
		"schema": func(d: Dictionary) -> void: d.schema_version = 2,
		"run": func(d: Dictionary) -> void: d.run_id = "run_nope",
		"packed": func(d: Dictionary) -> void: d.state.enemies.pos_x = "oops",
		"gold": func(d: Dictionary) -> void: d.state.gold += 1,
	}
	for k: String in cases:
		var d := good.duplicate(true)
		cases[k].call(d)
		var reason := SimSnapshot.restore(SimWorld.new(1), d)
		assert_ne(reason, "", k)
		gut.p("%s: %s" % [k, reason])
	assert_eq(SimSnapshot.restore(SimWorld.new(1), "garbage"), "not an object")
