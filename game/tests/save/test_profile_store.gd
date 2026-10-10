extends GutTest
## Profile file I/O (D-152 rule 10) in a scratch folder.

const DIR := "user://test_profile/"

var cat: MetaCatalog = MetaCatalog.load_dir()


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func after_each() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)


func _write(file: String, text: String) -> void:
	var f := FileAccess.open(DIR + file, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_round_trip_and_overwrite() -> void:
	var p := MetaProfile.fresh(cat)
	p.hearts = 42
	p.unlocked = PackedStringArray(["waifu_cinder"])
	p.best_sec = {"guardian_cinder": 120}
	assert_eq(ProfileStore.save_profile(p, DIR), OK)
	assert_eq(ProfileStore.load_profile(cat, DIR).to_dict(), p.to_dict())
	p.hearts = 7
	assert_eq(ProfileStore.save_profile(p, DIR), OK, "rename over an existing file")
	assert_eq(ProfileStore.load_profile(cat, DIR).hearts, 7)
	assert_false(FileAccess.file_exists(DIR + ProfileStore.TMP))
	assert_eq(ProfileStore.last_error, "")


func test_missing_file_loads_tmp() -> void:
	assert_eq(ProfileStore.load_profile(cat, DIR).to_dict(), MetaProfile.fresh(cat).to_dict(), "nothing: fresh")
	_write(ProfileStore.TMP, '{"schema_version": 1, "hearts": 9, "unlocked": [], "meta_nodes": [], "bond": {},'
		+ ' "stats": {"runs": 1, "wins": 0, "losses": 1, "best_sec": {}}}')
	assert_eq(ProfileStore.load_profile(cat, DIR).hearts, 9)


func test_corrupt_files() -> void:
	for text: String in ['{"hearts": ', '[1, 2]']:
		_write(ProfileStore.FILE, text)
		var p := ProfileStore.load_profile(cat, DIR)
		assert_eq(p.to_dict(), MetaProfile.fresh(cat).to_dict(), "fresh profile")
		assert_ne(ProfileStore.last_error, "")
		assert_false(FileAccess.file_exists(DIR + ProfileStore.FILE))
		assert_eq(FileAccess.get_file_as_string(DIR + ProfileStore.BAD), text, "original bytes kept")


func test_record_run_end_win() -> void:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, 7, "run_m3", "guardian_cinder"))
	w.step()
	w.run_state = SimWorld.RunState.WON
	w.clock = 27000
	assert_eq(ProfileStore.record_run_end(w, DIR), 100)
	var p := ProfileStore.load_profile(cat, DIR)
	assert_eq(p.hearts, 100)
	assert_eq(p.unlocked, PackedStringArray(["waifu_cinder"]))
	assert_eq([p.runs, p.wins], [1, 1])
