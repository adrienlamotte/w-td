class_name SpatialGrid
extends RefCounted
## Bounded uniform grid over the enemy positions, rebuilt every tick with a
## counting sort (02_TECH_ARCHITECTURE.md 3a, D-082). Covers the square
## [-half_extent, half_extent] on x and z; positions outside are clamped into the
## edge cells, so query results stay exact anywhere (only slower far outside).
## The grid never keeps the position arrays: callers pass them to every call.

var cell_size: float
var half_extent: float
var dim: int  # cells per side
## Enemies of cell c are cell_items[cell_start[c] .. cell_start[c + 1] - 1], ascending index.
var cell_start: PackedInt32Array = PackedInt32Array()
var cell_items: PackedInt32Array = PackedInt32Array()
var _enemy_cell: PackedInt32Array = PackedInt32Array()


func _init(p_cell_size: float, p_half_extent: float = 64.0) -> void:
	cell_size = p_cell_size
	half_extent = p_half_extent
	dim = maxi(1, ceili(2.0 * half_extent / cell_size))
	cell_start.resize(dim * dim + 1)


## Cell coordinate of a world coordinate, clamped to the grid.
func cell_coord(v: float) -> int:
	return clampi(floori((v + half_extent) / cell_size), 0, dim - 1)


## Rebuilds the grid from the position arrays. No allocation once count has peaked.
func rebuild(xs: PackedFloat32Array, zs: PackedFloat32Array) -> void:
	var count := xs.size()
	var n_cells := dim * dim
	cell_items.resize(count)
	_enemy_cell.resize(count)
	cell_start.fill(0)
	for i in count:
		var c := cell_coord(zs[i]) * dim + cell_coord(xs[i])
		_enemy_cell[i] = c
		cell_start[c] += 1
	# Inclusive prefix sum: cell_start[c] = end of cell c.
	for c in range(1, n_cells):
		cell_start[c] += cell_start[c - 1]
	cell_start[n_cells] = count
	# Scatter in reverse index order, moving each end back to the start,
	# so every cell slice is in ascending index order.
	for i in range(count - 1, -1, -1):
		var c := _enemy_cell[i]
		cell_start[c] -= 1
		cell_items[cell_start[c]] = i


## Writes into out every enemy index with distance <= r from (x, z), ascending.
## ponytail: clear + append allocates; if 004 calls this per enemy per tick and it
## shows in the profile, add an index-range iteration API over cell_start/cell_items.
func query_radius(x: float, z: float, r: float, xs: PackedFloat32Array,
		zs: PackedFloat32Array, out: PackedInt32Array) -> void:
	out.clear()
	var r2 := r * r
	var x0 := cell_coord(x - r)
	var x1 := cell_coord(x + r)
	for gz in range(cell_coord(z - r), cell_coord(z + r) + 1):
		var row := gz * dim
		for c in range(row + x0, row + x1 + 1):
			for k in range(cell_start[c], cell_start[c + 1]):
				var i := cell_items[k]
				var dx := xs[i] - x
				var dz := zs[i] - z
				if dx * dx + dz * dz <= r2:
					out.append(i)
	out.sort()


## Index of the nearest enemy within max_range of (x, z), lowest index on ties, -1 if none.
## Searches square rings of cells around the point's cell and stops once a ring
## cannot hold anything closer than the best found.
func nearest(x: float, z: float, max_range: float, xs: PackedFloat32Array,
		zs: PackedFloat32Array) -> int:
	var best := -1
	var best_d2 := max_range * max_range
	var cx := cell_coord(x)
	var cz := cell_coord(z)
	var k_max := mini(int(max_range / cell_size) + 1, dim)
	for k in k_max + 1:
		# Any enemy in ring k is at least (k - 1) * cell_size away (clamping keeps this true).
		var gap := (k - 1) * cell_size
		if k > 1 and gap * gap > best_d2:
			break
		for gz in range(maxi(cz - k, 0), mini(cz + k, dim - 1) + 1):
			var edge_row := absi(gz - cz) == k
			var step := 1 if edge_row else 2 * k
			var gx := cx - k
			while gx <= cx + k:
				if gx >= 0 and gx < dim:
					var c := gz * dim + gx
					for n in range(cell_start[c], cell_start[c + 1]):
						var i := cell_items[n]
						var dx := xs[i] - x
						var dz := zs[i] - z
						var d2 := dx * dx + dz * dz
						if d2 < best_d2 or (d2 == best_d2 and (best == -1 or i < best)):
							best = i
							best_d2 = d2
				gx += step
	return best
