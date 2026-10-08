class_name SimTowers
extends RefCounted
## Tower SoA arrays (02_TECH_ARCHITECTURE.md 3a, D-085). Arrays grow, no cap (D-040, D-042).
## M1 set only: hp, waifu_id, level, cooldown are added when M2 uses them.

var pos_x: PackedFloat32Array = PackedFloat32Array()
var pos_z: PackedFloat32Array = PackedFloat32Array()
## Range is passed to add() until waifu data exists (M2).
var attack_range: PackedFloat32Array = PackedFloat32Array()
## Nearest enemy index in range, -1 if none. Valid within this tick only (D-081).
var target: PackedInt32Array = PackedInt32Array()


func count() -> int:
	return pos_x.size()


## Appends a tower and returns its index. Removal (sell) is M2.
func add(x: float, z: float, p_range: float) -> int:
	pos_x.append(x)
	pos_z.append(z)
	attack_range.append(p_range)
	target.append(-1)
	return pos_x.size() - 1


## Sets every tower's target to its nearest enemy in range, in tower index order.
func retarget(grid: SpatialGrid, xs: PackedFloat32Array, zs: PackedFloat32Array) -> void:
	for t in pos_x.size():
		target[t] = grid.nearest(pos_x[t], pos_z[t], attack_range[t], xs, zs)
