class_name SimTowers
extends RefCounted
## Tower SoA arrays (02_TECH_ARCHITECTURE.md 3a, D-085, D-109). Arrays grow, no cap (D-040, D-042).
## Built towers are placed, sold and rebuilt by SimWorld commands; add() alone gives a bare
## tower off the build grid (M1 demo, bench, tests): type -1, uid -1, hp 1.

var pos_x: PackedFloat32Array = PackedFloat32Array()
var pos_z: PackedFloat32Array = PackedFloat32Array()
var attack_range: PackedFloat32Array = PackedFloat32Array()
## Nearest enemy index in range, -1 if none (always -1 on a husk). Valid within this tick only (D-081).
var target: PackedInt32Array = PackedInt32Array()
## Stable id from placement, never reused; -1 for a bare tower. Find a tower with uid.find().
var uid: PackedInt32Array = PackedInt32Array()
## TowerCatalog index, -1 for a bare tower.
var type_id: PackedInt32Array = PackedInt32Array()
## Gold paid at placement (base of the sell refund and the rebuild price, D-113).
var paid: PackedInt32Array = PackedInt32Array()
## First build-grid cell and cells per side of the footprint (BuildGrid).
var cell_i: PackedInt32Array = PackedInt32Array()
var cell_j: PackedInt32Array = PackedInt32Array()
var footprint: PackedInt32Array = PackedInt32Array()
var hp: PackedFloat32Array = PackedFloat32Array()
## 1 = dead tower left as a walkable husk (D-104).
var husk: PackedByteArray = PackedByteArray()


func count() -> int:
	return pos_x.size()


## Appends a tower with defaults and returns its index; SimWorld fills the build fields.
func add(x: float, z: float, p_range: float) -> int:
	pos_x.append(x)
	pos_z.append(z)
	attack_range.append(p_range)
	target.append(-1)
	uid.append(-1)
	type_id.append(-1)
	paid.append(0)
	cell_i.append(0)
	cell_j.append(0)
	footprint.append(0)
	hp.append(1.0)
	husk.append(0)
	return pos_x.size() - 1


## O(1) removal: the last tower moves into slot t (uids stay stable). Every per-tower array goes here.
func remove(t: int) -> void:
	var last := pos_x.size() - 1
	pos_x[t] = pos_x[last]
	pos_z[t] = pos_z[last]
	attack_range[t] = attack_range[last]
	target[t] = target[last]
	uid[t] = uid[last]
	type_id[t] = type_id[last]
	paid[t] = paid[last]
	cell_i[t] = cell_i[last]
	cell_j[t] = cell_j[last]
	footprint[t] = footprint[last]
	hp[t] = hp[last]
	husk[t] = husk[last]
	pos_x.resize(last)
	pos_z.resize(last)
	attack_range.resize(last)
	target.resize(last)
	uid.resize(last)
	type_id.resize(last)
	paid.resize(last)
	cell_i.resize(last)
	cell_j.resize(last)
	footprint.resize(last)
	hp.resize(last)
	husk.resize(last)


## Towers of this catalog type on the field, husks included (D-113).
func copies(p_type: int) -> int:
	return type_id.count(p_type)


## Sets every tower's target to its nearest enemy in range, in tower index order. Husks never target.
func retarget(grid: SpatialGrid, xs: PackedFloat32Array, zs: PackedFloat32Array) -> void:
	for t in pos_x.size():
		target[t] = -1 if husk[t] else grid.nearest(pos_x[t], pos_z[t], attack_range[t], xs, zs)
