class_name SynergyCatalog
extends RefCounted
## Relationship rules (10_M3_CONTENT.md 5, D-150) from data/synergies, with the waifus of each
## tower type and Guardian from data/waifus. Rules sorted by id: rule index = bit in syn_mask.
## A rule naming a waifu without a file (the M5 rivals) is skipped at load.

## Per tower type, its waifu index; -1 = none (the M2 towers).
var waifu_of_tower: PackedInt32Array = PackedInt32Array()
## Per waifu, the largest max_distance of her rules; 0 = no rule.
var waifu_reach: PackedFloat32Array = PackedFloat32Array()
var rule_ids: PackedStringArray = PackedStringArray()
var min_d: PackedFloat32Array = PackedFloat32Array()
var max_d: PackedFloat32Array = PackedFloat32Array()
## Per rule, side 0 and 1: waifu index, TowerStats.MODDED index, op (SimModifiers.Op), value.
var side_waifu: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var side_stat: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var side_op: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
var side_value: Array[PackedFloat32Array] = [PackedFloat32Array(), PackedFloat32Array()]
## Guardian side of each rule, written to the modifier store as `guardian` entries.
var guardian_stat: PackedStringArray = PackedStringArray()
var guardian_op: PackedInt32Array = PackedInt32Array()
var guardian_value: PackedFloat32Array = PackedFloat32Array()
var _waifu_ids: PackedStringArray = PackedStringArray()
var _guardian_waifu: Dictionary = {}
## Rule indices per (waifu a, waifu b), a * waifu count + b, in both orders.
var _pairs: Array[PackedInt32Array] = []


static func load_dir(towers: TowerCatalog, path := "res://data") -> SynergyCatalog:
	var c := SynergyCatalog.new()
	c.waifu_of_tower.resize(towers.ids.size())
	c.waifu_of_tower.fill(-1)
	for d in DataFiles.read_dir(path + "/waifus"):
		var k := c._waifu_ids.size()
		c._waifu_ids.append(d.id)
		var type := towers.type_of(d.tower)
		if type >= 0:
			c.waifu_of_tower[type] = k
		if d.has("guardian"):
			c._guardian_waifu[d.guardian] = k
	var n := c._waifu_ids.size()
	c.waifu_reach.resize(n)
	c._pairs.resize(n * n)
	for p in n * n:
		c._pairs[p] = PackedInt32Array()
	for d in DataFiles.read_dir(path + "/synergies"):
		c._add_rule(d)
	assert(c.rule_ids.size() <= 31, "SynergyCatalog: more than 31 rules do not fit syn_mask")
	return c


## Waifu index of a Guardian id, -1 if none (guardian_placeholder_01).
func waifu_of_guardian(guardian_id: String) -> int:
	return _guardian_waifu.get(guardian_id, -1)


## Rules with waifu a on one side and b on the other.
func rules_for(a: int, b: int) -> PackedInt32Array:
	return _pairs[a * _waifu_ids.size() + b]


## Side of rule r that belongs to waifu a.
func side_of(r: int, a: int) -> int:
	return 0 if side_waifu[0][r] == a else 1


func _add_rule(d: Dictionary) -> void:
	var w: Array[int] = []
	for b: Dictionary in d.bonuses:
		w.append(Array(_waifu_ids).find(b.waifu))
	if w.size() != 2 or w.has(-1):  # a waifu without a file: M5 rows
		return
	var r := rule_ids.size()
	rule_ids.append(d.id)
	min_d.append(d.min_distance)
	max_d.append(d.max_distance)
	for s in 2:
		var b: Dictionary = d.bonuses[s]
		var stat := TowerStats.MODDED.find(b.stat)
		assert(stat >= 0, "SynergyCatalog: %s: stat %s is not a tower stat" % [d.id, b.stat])
		side_waifu[s].append(w[s])
		side_stat[s].append(stat)
		side_op[s].append(SimModifiers.Op.MULT if b.op == "mult" else SimModifiers.Op.ADD)
		side_value[s].append(b.value)
		waifu_reach[w[s]] = maxf(waifu_reach[w[s]], d.max_distance)
	var g: Dictionary = d.guardian_bonus
	guardian_stat.append(g.stat)
	guardian_op.append(SimModifiers.Op.MULT if g.op == "mult" else SimModifiers.Op.ADD)
	guardian_value.append(g.value)
	var n := _waifu_ids.size()
	_pairs[w[0] * n + w[1]].append(r)
	if w[0] != w[1]:
		_pairs[w[1] * n + w[0]].append(r)
