class_name BuildGrid
extends RefCounted
## Fine build grid around the Guardian (D-040, D-042, D-109). Square of `size` cells
## per side centred on (0, 0); cell (i, j) covers x in [(i - size/2) * step, (i - size/2 + 1) * step),
## same for z with j; flat index j * size + i. Derived from the tower arrays: not in state_hash().

var step: float = 0.5
var size: int = 0
## Tower uid per cell, -1 = free. A husk keeps its cells (D-104).
var owner: PackedInt32Array = PackedInt32Array()
## 1 = live tower (solid for pathing), 0 = free or husk (walkable, D-104).
var solid: PackedByteArray = PackedByteArray()
## Bumped on every change of `solid`, so pathing (task 024) recomputes only then.
var version: int = 0


func _init(build_radius: float, p_step: float) -> void:
	step = p_step
	size = 2 * ceili(build_radius / step)
	owner.resize(size * size)
	owner.fill(-1)
	solid.resize(size * size)


## Cells per side of a tower of this radius (at least 1).
static func footprint(radius: float, p_step: float) -> int:
	return maxi(1, ceili(2.0 * radius / p_step - 1e-4))


## First cell (i or j) of an n-cell footprint centred as close as possible to world coordinate v.
func first_cell(v: float, n: int) -> int:
	return roundi(v / step + size / 2.0 - n / 2.0)


## World coordinate of the centre of an n-cell footprint starting at cell i0.
func cell_centre(i0: int, n: int) -> float:
	return (i0 + n / 2.0 - size / 2.0) * step


## True if every cell of the footprint is inside the grid and has no owner.
func is_free(i0: int, j0: int, n: int) -> bool:
	if i0 < 0 or j0 < 0 or i0 + n > size or j0 + n > size:
		return false
	for j in range(j0, j0 + n):
		for i in range(i0, i0 + n):
			if owner[j * size + i] != -1:
				return false
	return true


## Sets owner and solid on every cell of the footprint; bumps version if solid changed.
func fill(i0: int, j0: int, n: int, uid: int, p_solid: int) -> void:
	var changed := false
	for j in range(j0, j0 + n):
		for i in range(i0, i0 + n):
			var c := j * size + i
			owner[c] = uid
			if solid[c] != p_solid:
				solid[c] = p_solid
				changed = true
	if changed:
		version += 1
