class_name CardCatalog
extends RefCounted
## Level-up draft cards (10_M3_CONTENT.md 2, D-147), loaded from data/cards sorted by id:
## card index = position here. Waifu references are resolved to tower types. Load time only.

## Card types; the first four are the draw order of rule 3 (D-147) and of `card_type_weights`.
enum Type { NEW_TOWER, SIGNATURE, SKILL, PERK, FILLER }
const TYPE_NAMES: PackedStringArray = ["new_tower", "signature", "skill", "perk", "filler"]

var ids: PackedStringArray = PackedStringArray()
var type: PackedInt32Array = PackedInt32Array()
var max_picks: PackedInt32Array = PackedInt32Array()
## Localisation keys of the card text (view only).
var name_key: PackedStringArray = PackedStringArray()
var desc_key: PackedStringArray = PackedStringArray()
## Waifu id that must be rescued (StartRun `unlocked`); "" = none.
var req_unlocked: PackedStringArray = PackedStringArray()
## Tower type that must be buildable this run; -1 = none.
var req_buildable_type: PackedInt32Array = PackedInt32Array()
## Tower type an `unlock_tower` effect adds; -1 = none.
var unlock_type: PackedInt32Array = PackedInt32Array()
## Per card: its effect objects (10_M3_CONTENT.md 2.5), as in data.
var effects: Array[Array] = []
## The first filler card by id; -1 if none.
var filler: int = -1
## Largest `build_radius` gain reachable from cards: max_picks x value of every add (D-148 rule 1).
var max_build_radius_bonus: float = 0.0


static func load_dir(towers: TowerCatalog, path := "res://data/cards", waifu_path := "res://data/waifus") -> CardCatalog:
	var waifu_tower := {}
	for w in DataFiles.read_dir(waifu_path):
		waifu_tower[w.id] = towers.type_of(w.tower)
	var cat := CardCatalog.new()
	for d in DataFiles.read_dir(path):
		var req: Dictionary = d.requires
		var unlock := -1
		for e: Dictionary in d.effects:
			if e.stat == "unlock_tower":
				unlock = towers.type_of(String(e.target).trim_prefix("tower:"))
			elif e.stat == "build_radius" and e.op == "add":
				cat.max_build_radius_bonus += int(d.max_picks) * float(e.value)
		cat.ids.append(d.id)
		cat.type.append(TYPE_NAMES.find(d.type))
		cat.max_picks.append(int(d.max_picks))
		cat.name_key.append(d.name_key)
		cat.desc_key.append(d.desc_key)
		cat.req_unlocked.append(req.get("unlocked", ""))
		cat.req_buildable_type.append(waifu_tower.get(req.get("buildable", ""), -1))
		cat.unlock_type.append(unlock)
		cat.effects.append(d.effects)
		if cat.filler < 0 and cat.type[-1] == Type.FILLER:
			cat.filler = cat.ids.size() - 1
	return cat


func index_of(id: String) -> int:
	return Array(ids).find(id)
