class_name SuspendStore
extends RefCounted
## Reads and writes the suspend save `suspend.json` (D-167, 10_M3_CONTENT.md 7). File I/O
## only: the snapshot is SimSnapshot's. `dir` lets tests use a scratch folder.

const FILE := "suspend.json"
const BAD := "suspend.bad.json"

## Why the last load failed ("" = it did not); for the start-screen notice.
static var last_error: String = ""


static func exists(dir := "user://") -> bool:
	return FileAccess.file_exists(dir.path_join(FILE))


## Atomic write of the world's snapshot, full float precision.
static func save(world: SimWorld, dir := "user://") -> Error:
	var text := JSON.stringify(SimSnapshot.capture(world), "", false, true)
	return ProfileStore.write_atomic(dir.path_join(FILE), text)


## Restores the suspend save into a fresh world. On failure the file is kept as
## suspend.bad.json and `last_error` is set; world.run is set if the header was readable.
static func load_into(world: SimWorld, dir := "user://") -> bool:
	last_error = ""
	var path := dir.path_join(FILE)
	var reason := SimSnapshot.restore(world, _read(path))
	if reason == "":
		return true
	last_error = "%s: %s" % [path, reason]
	push_warning("SuspendStore: %s; kept as %s" % [last_error, BAD])
	var bad := dir.path_join(BAD)
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(bad)
	DirAccess.rename_absolute(path, bad)
	return false


## Start-screen Abandon run (D-167 rule 4): restores the save into a scratch world and records
## it as a loss at the saved clock, which deletes the file. A failed restore follows rule 6:
## recorded only if the header was readable.
static func abandon(dir := "user://") -> void:
	var w := SimWorld.new(0)
	load_into(w, dir)
	if w.run != null:
		ProfileStore.record_run_end(w, dir)


static func delete(dir := "user://") -> void:
	if exists(dir):
		DirAccess.remove_absolute(dir.path_join(FILE))


## The run_id, guardian_id, run_seed and clock of the save, or {} if unreadable.
static func header(dir := "user://") -> Dictionary:
	var d: Variant = _read(dir.path_join(FILE))
	return d if d is Dictionary and SimSnapshot.check_header(d) == "" else {}


static func _read(path: String) -> Variant:
	var json := JSON.new()
	return json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
