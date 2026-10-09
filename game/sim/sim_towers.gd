class_name SimTowers
extends RefCounted
## Tower SoA arrays (02_TECH_ARCHITECTURE.md 3a, D-085, D-109). Arrays grow, no cap (D-040, D-042).
## Built towers are placed, sold and rebuilt by SimWorld commands; add() alone gives a bare
## tower off the build grid (M1 demo, bench, tests): type -1, uid -1, hp 1.

var pos_x: PackedFloat32Array = PackedFloat32Array()
var pos_z: PackedFloat32Array = PackedFloat32Array()
## Derived (D-144, TowerStats), like damage..slow_ticks below; set at add() for a bare tower.
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
## Attack cooldown in ticks, 0 = ready; 0 at placement and rebuild (D-114).
var cooldown: PackedInt32Array = PackedInt32Array()
## Tower index by uid, -1 = none (sold or never placed). Refreshed by SimWorld in the PATH
## phase; valid until the end of that tick (indices only move on sell, in COMMANDS; D-116).
var uid_index: PackedInt32Array = PackedInt32Array()
## Upgrade level, 1 at placement (D-144).
var level: PackedInt32Array = PackedInt32Array()
## Derived stats (D-144, TowerStats). `reload` = cooldown in ticks after a shot.
var damage: PackedFloat32Array = PackedFloat32Array()
var reload: PackedInt32Array = PackedInt32Array()
var max_hp: PackedFloat32Array = PackedFloat32Array()
var splash_radius: PackedFloat32Array = PackedFloat32Array()
var slow_factor: PackedFloat32Array = PackedFloat32Array()
var slow_ticks: PackedInt32Array = PackedInt32Array()
## Set by every layout, level or modifier change; TowerStats.recompute clears it in the PATH phase.
var stats_dirty: bool = false


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
	cooldown.append(0)
	level.append(1)
	damage.append(0.0)
	reload.append(0)
	max_hp.append(1.0)
	splash_radius.append(0.0)
	slow_factor.append(1.0)
	slow_ticks.append(0)
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
	cooldown[t] = cooldown[last]
	level[t] = level[last]
	damage[t] = damage[last]
	reload[t] = reload[last]
	max_hp[t] = max_hp[last]
	splash_radius[t] = splash_radius[last]
	slow_factor[t] = slow_factor[last]
	slow_ticks[t] = slow_ticks[last]
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
	cooldown.resize(last)
	level.resize(last)
	damage.resize(last)
	reload.resize(last)
	max_hp.resize(last)
	splash_radius.resize(last)
	slow_factor.resize(last)
	slow_ticks.resize(last)


## Towers of this catalog type on the field, husks included (D-113).
func copies(p_type: int) -> int:
	return type_id.count(p_type)


## Sets every tower's target to its nearest enemy in range, in tower index order. Husks never target.
func retarget(grid: SpatialGrid, xs: PackedFloat32Array, zs: PackedFloat32Array) -> void:
	for t in pos_x.size():
		target[t] = -1 if husk[t] else grid.nearest(pos_x[t], pos_z[t], attack_range[t], xs, zs)


## Rebuilds uid_index for uids 0..next_uid-1.
func refresh_uid_index(next_uid: int) -> void:
	uid_index.resize(next_uid)
	uid_index.fill(-1)
	for t in uid.size():
		if uid[t] >= 0:
			uid_index[uid[t]] = t
