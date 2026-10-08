class_name EnemyCatalog
extends RefCounted
## Enemy types loaded from data. type_id = index in this catalog, sorted by id
## so the order is deterministic (02_TECH_ARCHITECTURE.md 3a, D-081).

var ids: PackedStringArray = PackedStringArray()
var speed: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var separation_strength: PackedFloat32Array = PackedFloat32Array()
## Largest radius over all types, computed at load.
var max_radius: float = 0.0


static func load_dir(path: String = "res://data/enemies") -> EnemyCatalog:
	var files: Array[Dictionary] = []
	for file_name in DirAccess.get_files_at(path):
		if not file_name.ends_with(".json"):
			continue
		var full := path.path_join(file_name)
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(full))
		if not data is Dictionary:
			push_error("EnemyCatalog: cannot read %s" % full)
			assert(false, "EnemyCatalog: cannot read %s" % full)
			continue
		files.append(data)
	files.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.id < b.id)
	var catalog := EnemyCatalog.new()
	for data in files:
		catalog.ids.append(data.id)
		catalog.speed.append(data.speed)
		catalog.radius.append(data.radius)
		catalog.hp.append(data.hp)
		catalog.separation_strength.append(data.separation_strength)
		catalog.max_radius = maxf(catalog.max_radius, data.radius)
	return catalog


## type_id of an enemy id, or -1 if unknown.
func type_of(id: String) -> int:
	return Array(ids).find(id)
