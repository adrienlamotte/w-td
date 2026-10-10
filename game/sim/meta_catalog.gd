class_name MetaCatalog
extends RefCounted
## Meta-tree nodes (data/meta) and the waifu data the profile needs (D-152). Load time only.

## Node ids, sorted: the order StartRun applies them in (D-152 rule 8).
var ids: PackedStringArray = PackedStringArray()
## Per node id: cost in hearts, `requires` ids, effect objects (10_M3_CONTENT.md 2.5).
var cost: Dictionary = {}
var requires: Dictionary = {}
var effects: Dictionary = {}
## Per node id: tree branch and the name / description string keys (for the hub, task 039).
var branch: Dictionary = {}
var name_key: Dictionary = {}
var desc_key: Dictionary = {}
## `guardian`-status waifu ids sorted by `offer_order` (07_ROSTER.md 3).
var offer_order: PackedStringArray = PackedStringArray()
## Waifu id -> her guardian id (guardian-status waifus only).
var guardian_of: Dictionary = {}
var waifu_ids: PackedStringArray = PackedStringArray()
## Waifu id -> name string key.
var waifu_name_key: Dictionary = {}
## `starter`-status waifu ids, id order.
var starters: PackedStringArray = PackedStringArray()


static func load_dir(path := "res://data/meta", waifu_path := "res://data/waifus") -> MetaCatalog:
	var cat := MetaCatalog.new()
	for d in DataFiles.read_dir(path):
		cat.ids.append(d.id)
		cat.cost[d.id] = int(d.cost)
		cat.requires[d.id] = PackedStringArray(d.requires)
		cat.effects[d.id] = d.effects
		cat.branch[d.id] = String(d.branch)
		cat.name_key[d.id] = String(d.name_key)
		cat.desc_key[d.id] = String(d.desc_key)
	var guardians: Array[Dictionary] = []
	for w in DataFiles.read_dir(waifu_path):
		cat.waifu_ids.append(w.id)
		cat.waifu_name_key[w.id] = String(w.name_key)
		if w.status == "starter":
			cat.starters.append(w.id)
		if w.status == "guardian":
			guardians.append(w)
			cat.guardian_of[w.id] = String(w.guardian)
	guardians.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.offer_order < b.offer_order)
	for w in guardians:
		cat.offer_order.append(w.id)
	return cat


## The waifu whose Guardian is `guardian_id`, "" if none (a placeholder Guardian).
func waifu_of(guardian_id: String) -> String:
	for w: String in guardian_of:
		if guardian_of[w] == guardian_id:
			return w
	return ""
