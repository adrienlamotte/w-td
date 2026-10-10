class_name SimSnapshot
extends RefCounted
## Suspend-save snapshot of a SimWorld (D-167, 10_M3_CONTENT.md 7): plain data, no file access.
## The state objects are saved field by field from their script variables, so a field added
## later is saved without touching this file. Derived state (build grid, flow field, spatial
## grid, uid index, tower stats and links) is rebuilt on restore, then state_hash() is checked.
## Capture only when the flow field is settled (FlowField.settled): a field rebuilt in full
## equals the live one only then. Reads SimWorld's RNGs and _queue (their snapshot friend).

const SCHEMA_VERSION: int = 1
## SimWorld fields saved explicitly (the rest of SimWorld is content, scratch or derived).
const SCALARS: PackedStringArray = ["tick", "paused", "run_state", "guardian_syn_mask", "tower_types",
	"unlocked", "xp_mult", "kill_gold_mult", "max_build_radius", "build_radius", "rebuild_mult",
	"detour_mult", "next_tower_uid", "guardian_hp", "guardian_max_hp", "gold"]
## SimWorld state objects saved from their script variables (CardDraft without its rng).
const OBJECTS: PackedStringArray = ["enemies", "towers", "modifiers", "skills", "draft"]


## The whole run state as a JSON-ready Dictionary. Write it with full float precision
## (JSON.stringify(d, "\t", false, true)); RNG states and the hash go as strings (above 2^53).
static func capture(w: SimWorld) -> Dictionary:
	var state := {}
	for name in SCALARS:
		state[name] = _plain(w.get(name))
	for name in OBJECTS:
		state[name] = _capture_obj(w.get(name))
	var queue: Array = []
	for cmd in w._queue:
		queue.append(_capture_obj(cmd))
	state["queue"] = queue
	state["rng_spawn"] = str(w._spawn_rng.state)
	state["rng_loot"] = str(w._loot_rng.state)
	state["rng_cards"] = str(w.draft.rng.state)
	return {"schema_version": SCHEMA_VERSION, "run_id": w.run.id, "guardian_id": w.run.guardian_id,
		"run_seed": w.run_seed, "clock": w.clock, "state": state, "state_hash": str(w.state_hash())}


## Restores `d` into a fresh SimWorld. Returns "" when the restored state hashes as saved,
## else the reason. `w.run` and `w.clock` are set as soon as the header is valid, so a
## later failure can still be recorded as an abandon at the saved clock.
static func restore(w: SimWorld, d: Variant) -> String:
	if not d is Dictionary:
		return "not an object"
	if not (d.get("schema_version") is float or d.get("schema_version") is int) \
			or int(d.schema_version) != SCHEMA_VERSION:
		return "unsupported schema_version"
	var err := check_header(d)
	if err != "":
		return err
	w.run = RunData.load_id(d.run_id, w.catalog, w.tower_catalog, d.guardian_id)
	w.clock = int(d.clock)
	w.run_seed = int(d.run_seed)
	w.movement.set_stop(w.catalog, w.run.guardian_contact_radius)
	var s: Variant = d.get("state")
	if not s is Dictionary:
		return "no state"
	for name in SCALARS:
		err = _put(w, name, typeof(w.get(name)), s.get(name))
		if err != "":
			return err
	for name in OBJECTS:
		err = _restore_obj(w.get(name), s.get(name))
		if err != "":
			return "%s: %s" % [name, err]
	if not s.get("queue") is Array:
		return "queue: not an array"
	w._queue.clear()
	for c: Variant in s.queue:
		var cmd := SimCommand.new()
		err = _restore_obj(cmd, c)
		if err != "":
			return "queue: " + err
		w._queue.append(cmd)
	for pair: Array in [[w._spawn_rng, "rng_spawn"], [w._loot_rng, "rng_loot"], [w.draft.rng, "rng_cards"]]:
		var v: Variant = s.get(pair[1])
		if not v is String or not v.is_valid_int():
			return pair[1] + ": not an integer string"
		(pair[0] as RandomNumberGenerator).state = v.to_int()  # state only: never seed after it
	_rebuild_derived(w)
	if str(w.state_hash()) != str(d.get("state_hash")):
		return "state_hash mismatch"
	return ""


## "" when the header (run and Guardian ids, seed, clock) is usable; ids must exist in data.
static func check_header(d: Dictionary) -> String:
	for key in ["run_id", "guardian_id"]:
		if not d.get(key) is String or not FileAccess.file_exists(
				"%s/%s/%s.json" % [RunData.DIR, "runs" if key == "run_id" else "guardians", d[key]]):
			return "unknown " + key
	for key in ["run_seed", "clock"]:
		if not (d.get(key) is float or d.get(key) is int):
			return key + ": not a number"
	return ""


static func _rebuild_derived(w: SimWorld) -> void:
	w.build = BuildGrid.new(w.max_build_radius, w.run.grid_step)
	var t := w.towers
	for k in t.count():
		if t.uid[k] >= 0:
			w.build.fill(t.cell_i[k], t.cell_j[k], t.footprint[k], t.uid[k], 0 if t.husk[k] else 1)
	w.field = FlowField.new(w.build, w.run.guardian_contact_radius)
	w.field.update(FlowField.FULL)
	w._rebuild_grid()
	t.refresh_uid_index(w.next_tower_uid)
	if not t.stats_dirty:  # else the next PATH phase recomputes, as in the live run
		TowerStats.recompute(w)


static func _capture_obj(o: Object) -> Dictionary:
	var out := {}
	for p in o.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.type != TYPE_OBJECT:
			out[p.name] = _plain(o.get(p.name))
	return out


# Packed arrays as plain Arrays: JSON writes a PackedByteArray as a base64 string, not numbers.
static func _plain(v: Variant) -> Variant:
	return Array(v) if typeof(v) >= TYPE_PACKED_BYTE_ARRAY else v


static func _restore_obj(o: Object, d: Variant) -> String:
	if not d is Dictionary:
		return "not an object"
	for p in o.get_property_list():
		if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.type != TYPE_OBJECT:
			var err := _put(o, p.name, p.type, d.get(p.name))
			if err != "":
				return err
	return ""


# Checks the JSON type of `v` against the field's type, then sets the converted value.
static func _put(o: Object, name: String, type: int, v: Variant) -> String:
	var ok := false
	match type:
		TYPE_INT, TYPE_FLOAT:
			ok = v is int or v is float
		TYPE_BOOL:
			ok = v is bool
		TYPE_STRING:
			ok = v is String
		_:
			ok = type >= TYPE_ARRAY and (v is Array or typeof(v) == type)
	if not ok:
		return "%s: wrong type" % name
	o.set(name, type_convert(v, type))
	return ""
