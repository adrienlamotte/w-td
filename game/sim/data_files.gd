class_name DataFiles
extends RefCounted
## Reads content JSON from game/data (02_TECH_ARCHITECTURE.md 3b). Load time only.


## Every .json in path, parsed, sorted by id so catalog order is deterministic (D-081).
static func read_dir(path: String) -> Array[Dictionary]:
	var docs: Array[Dictionary] = []
	for file_name in DirAccess.get_files_at(path):
		if file_name.ends_with(".json"):
			docs.append(read_file(path.path_join(file_name)))
	docs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.get("id", "") < b.get("id", ""))
	return docs


## The document <path>/<id>.json.
static func read_id(path: String, id: String) -> Dictionary:
	return read_file(path.path_join(id + ".json"))


static func read_file(full: String) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(full))
	if not data is Dictionary:
		push_error("DataFiles: cannot read %s" % full)
		assert(false, "DataFiles: cannot read %s" % full)
		return {}
	return data


## Seconds from data to whole sim ticks, so the sim never accumulates float time.
static func ticks(sec: float) -> int:
	return roundi(sec * SimWorld.TICK_RATE)
