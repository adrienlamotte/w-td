class_name ProfileStore
extends RefCounted
## Reads and writes the meta profile file (10_M3_CONTENT.md 7, D-152 rule 10). File I/O only:
## the rules are MetaProfile's. `dir` lets tests use a scratch folder.

const FILE := "profile.json"
const TMP := "profile.json.tmp"
const BAD := "profile.bad.json"

## Why the last load started a fresh profile ("" = it did not); for the hub notice (Q-73, task 039).
static var last_error: String = ""


## The saved profile; a missing file gives a fresh one, an unreadable one is kept as
## profile.bad.json and a fresh one is used.
static func load_profile(cat: MetaCatalog, dir := "user://") -> MetaProfile:
	last_error = ""
	var path := dir.path_join(FILE)
	if not FileAccess.file_exists(path):
		path = dir.path_join(TMP)  # a crash between the write and the rename
		if not FileAccess.file_exists(path):
			return MetaProfile.fresh(cat)
	var json := JSON.new()
	var p: MetaProfile = null
	if json.parse(FileAccess.get_file_as_string(path)) == OK:
		p = MetaProfile.from_dict(json.data, cat)
		if p == null:
			last_error = "%s: unsupported version or wrong field types" % path
	else:
		last_error = "%s: line %d: %s" % [path, json.get_error_line(), json.get_error_message()]
	if p != null:
		return p
	push_warning("ProfileStore: %s; kept as %s, starting fresh" % [last_error, BAD])
	var bad := dir.path_join(BAD)
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(bad)
	DirAccess.rename_absolute(path, bad)
	return MetaProfile.fresh(cat)


## Atomic save: write the temp file, then rename it over the profile.
static func save_profile(p: MetaProfile, dir := "user://") -> Error:
	var tmp := dir.path_join(TMP)
	var path := dir.path_join(FILE)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(p.to_dict(), "\t") + "\n")
	f.close()
	if DirAccess.rename_absolute(tmp, path) == OK:
		return OK
	DirAccess.remove_absolute(path)  # some platforms refuse to rename over a file
	return DirAccess.rename_absolute(tmp, path)


## Run end (D-152 rule 5): load, record, save once. Returns the hearts earned.
static func record_run_end(world: SimWorld, dir := "user://") -> int:
	var cat := world.meta if world.meta else MetaCatalog.load_dir()
	var p := load_profile(cat, dir)
	var earned := p.record_run(cat, world.run, world.run_state == SimWorld.RunState.WON, world.clock)
	save_profile(p, dir)
	return earned
