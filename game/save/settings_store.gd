class_name SettingsStore
extends RefCounted
## The player's settings file (D-157, D-154 rule 9): toggles only, no gameplay data.
## Plain write: a torn file loads as the defaults (one toggle lost, nothing of value).

const FILE := "settings.json"
const CURRENT_VERSION := 1


## Reads the file into RunFlow. Missing, unreadable, newer or mistyped = the defaults (off).
static func load_into_run_flow(dir := "user://") -> void:
	RunFlow.slow_time_placing = false
	var path := dir.path_join(FILE)
	if not FileAccess.file_exists(path):
		return
	var json := JSON.new()
	var d: Variant = json.data if json.parse(FileAccess.get_file_as_string(path)) == OK else null
	var v: Variant = d.get("schema_version") if d is Dictionary else null
	if not (v is float or v is int) or int(v) < 1 or int(v) > CURRENT_VERSION:
		push_warning("SettingsStore: %s unreadable, using the defaults" % path)
		return
	var slow: Variant = d.get("slow_time_placing", false)
	if slow is bool:
		RunFlow.slow_time_placing = slow
	else:
		push_warning("SettingsStore: %s: slow_time_placing is not a bool" % path)


static func save(dir := "user://") -> Error:
	var f := FileAccess.open(dir.path_join(FILE), FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({"schema_version": CURRENT_VERSION,
		"slow_time_placing": RunFlow.slow_time_placing}, "\t") + "\n")
	f.close()
	return OK
