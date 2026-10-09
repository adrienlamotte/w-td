class_name SimModifiers
extends RefCounted
## Modifier store (D-144): flat effect entries `{stat, op, value, target}` exactly as the
## 10_M3_CONTENT.md 2.5 effect object, pushed unfiltered by cards (033) and meta (035).
## Add through SimWorld.add_modifier so the tower stats get recomputed. Hashed.

enum Op { ADD, MULT }

var stat: PackedStringArray = PackedStringArray()
var op: PackedInt32Array = PackedInt32Array()
var value: PackedFloat64Array = PackedFloat64Array()
var target: PackedStringArray = PackedStringArray()


func add(p_stat: String, p_op: Op, p_value: float, p_target: String) -> void:
	stat.append(p_stat)
	op.append(p_op)
	value.append(p_value)
	target.append(p_target)


## (sum of add, sum of mult) of `p_stat` over the entries targeting this tower type.
func sums(p_stat: String, tower_id: String) -> Vector2:
	var out := Vector2.ZERO
	for e in stat.size():
		if stat[e] == p_stat and _hits(e, tower_id):
			if op[e] == Op.ADD:
				out.x += value[e]
			else:
				out.y += value[e]
	return out


## Highest `unlock_level` value targeting this tower type, 0 if none (D-144 rule 4).
func unlocked_level(tower_id: String) -> int:
	var best := 0
	for e in stat.size():
		if stat[e] == "unlock_level" and _hits(e, tower_id):
			best = maxi(best, int(value[e]))
	return best


func hash_parts() -> Array:
	return [stat, op, value, target]


func _hits(e: int, tower_id: String) -> bool:
	return target[e] == "all_towers" or target[e] == "tower:" + tower_id
