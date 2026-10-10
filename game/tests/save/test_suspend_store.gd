extends GutTest
## Suspend save file I/O and the boundary saver (D-167 rules 1-3, 6) in a scratch folder.

const DIR := "user://test_suspend/"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func after_each() -> void:
	SuspendStore.last_error = ""
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)


# A run_m3 world after its first step (START_RUN applied, wave 0 started, field settled).
func _world() -> SimWorld:
	var w := SimWorld.new(3)
	w.queue(SimCommand.start_run(0, 77, "run_m3", "guardian_cinder"))
	w.step()
	return w


func test_round_trip_through_the_file() -> void:
	var w := _world()
	w.spawn_ring(0, 2000, 30.0)
	w.step()
	var t := Time.get_ticks_usec()
	assert_eq(SuspendStore.save(w, DIR), OK)
	gut.p("save of %d enemies: %.1f ms, %d KB" % [w.enemies.count(), (Time.get_ticks_usec() - t) / 1000.0,
		FileAccess.get_file_as_bytes(DIR + SuspendStore.FILE).size() / 1024])
	assert_false(FileAccess.file_exists(DIR + SuspendStore.FILE + ".tmp"))
	assert_eq(SuspendStore.header(DIR).run_id, "run_m3")
	var r := SimWorld.new(1)
	t = Time.get_ticks_usec()
	assert_true(SuspendStore.load_into(r, DIR))
	gut.p("load: %.1f ms" % ((Time.get_ticks_usec() - t) / 1000.0))
	assert_eq(r.state_hash(), w.state_hash())
	assert_eq(SuspendStore.last_error, "")


func test_garbage_file_is_kept_aside() -> void:
	var f := FileAccess.open(DIR + SuspendStore.FILE, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	assert_eq(SuspendStore.header(DIR), {})
	var w := SimWorld.new(1)
	assert_false(SuspendStore.load_into(w, DIR))
	assert_ne(SuspendStore.last_error, "")
	assert_null(w.run, "no header: nothing to record")
	assert_true(FileAccess.file_exists(DIR + SuspendStore.BAD))
	assert_false(SuspendStore.exists(DIR))


func test_run_end_deletes_the_save() -> void:
	var w := _world()
	SuspendStore.save(w, DIR)
	ProfileStore.record_run_end(w, DIR)
	assert_false(SuspendStore.exists(DIR))


func test_saver_writes_at_boundaries_only() -> void:
	var w := SimWorld.new(3)
	var saver := SuspendSaver.new(DIR)
	w.queue(SimCommand.start_run(0, 77, "run_m3", "guardian_cinder"))
	w.step()
	saver.on_step(w)
	assert_true(SuspendStore.exists(DIR), "wave 0 started at the first step")
	SuspendStore.delete(DIR)
	for i in 10:
		w.step()
		saver.on_step(w)
	assert_false(SuspendStore.exists(DIR), "mid-wave: no write")


func test_saver_waits_for_a_settled_field() -> void:
	var w := _world()
	var saver := SuspendSaver.new(DIR)
	w.queue(SimCommand.place_tower(w.tick, "tower_pip", 4, 0))
	w.step()
	assert_false(w.field.settled())
	w.events.push(SimEvents.Kind.WAVE_STARTED, 1, 0.0, 0.0, 0.0)
	saver.on_step(w)
	assert_false(SuspendStore.exists(DIR), "deferred")
	for i in 100:
		w.step()
		saver.on_step(w)
		if SuspendStore.exists(DIR):
			break
	assert_true(SuspendStore.exists(DIR))
	assert_true(w.field.settled())
	var r := SimWorld.new(1)
	assert_true(SuspendStore.load_into(r, DIR))


func test_saver_never_writes_an_ended_run() -> void:
	var w := _world()
	var saver := SuspendSaver.new(DIR)
	for s: SimWorld.RunState in [SimWorld.RunState.WON, SimWorld.RunState.LOST]:
		w.run_state = s
		w.events.push(SimEvents.Kind.WAVE_STARTED, 1, 0.0, 0.0, 0.0)
		saver.on_step(w)
	assert_false(SuspendStore.exists(DIR))
