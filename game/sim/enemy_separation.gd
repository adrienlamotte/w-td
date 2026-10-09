class_name EnemySeparation
extends RefCounted
## Soft separation (D-079, D-084): each overlapping pair pushes both enemies apart,
## each by 0.5 * overlap * separation_strength of its own type. Jacobi style:
## pushes are computed from the positions at the start of the phase, then applied
## in one pass. Every pair is visited once (j > i) in fixed grid order, so the
## result is deterministic. The horde loop skips bosses: their radius is outside
## the horde scan reach (D-099), so a boss pass handles every pair with a boss (D-106).

const COINCIDENT_EPS: float = 1e-6

var _push_x: PackedFloat32Array = PackedFloat32Array()
var _push_z: PackedFloat32Array = PackedFloat32Array()
## Boss indices of the current apply(), ascending.
var _bosses: PackedInt32Array = PackedInt32Array()


## grid must match the enemy positions (02_TECH_ARCHITECTURE.md 3a, tick order).
## Iterates grid.cell_start / cell_items directly: query_radius per enemy cost
## about 73 ms per tick at 3000 piled enemies (task 004).
func apply(enemies: SimEnemies, grid: SpatialGrid, catalog: EnemyCatalog) -> void:
	var xs := enemies.pos_x
	var zs := enemies.pos_z
	var types := enemies.type_id
	var radius := catalog.radius
	var strength := catalog.separation_strength
	var is_boss := catalog.is_boss
	var cell_start := grid.cell_start
	var cell_items := grid.cell_items
	var dim := grid.dim
	var n := xs.size()
	_push_x.resize(n)
	_push_z.resize(n)
	_push_x.fill(0.0)
	_push_z.fill(0.0)
	_bosses.clear()
	for i in n:
		var ti := types[i]
		if is_boss[ti]:
			_bosses.append(i)
			continue
		var ri := radius[ti]
		var ki := 0.5 * strength[ti]
		var x := xs[i]
		var z := zs[i]
		var reach := ri + catalog.max_radius
		var x0 := grid.cell_coord(x - reach)
		var x1 := grid.cell_coord(x + reach)
		for gz in range(grid.cell_coord(z - reach), grid.cell_coord(z + reach) + 1):
			var row := gz * dim
			for k in range(cell_start[row + x0], cell_start[row + x1 + 1]):
				var j := cell_items[k]
				if j <= i:
					continue
				var dx := x - xs[j]
				var dz := z - zs[j]
				var tj := types[j]
				var rr := ri + radius[tj]
				var d2 := dx * dx + dz * dz
				if d2 >= rr * rr or is_boss[tj]:  # boss pairs: _apply_bosses
					continue
				var d := sqrt(d2)
				var ux := -1.0  # coincident: i (lower index) goes -x, j goes +x
				var uz := 0.0
				if d >= COINCIDENT_EPS:
					ux = dx / d
					uz = dz / d
				var overlap := rr - d
				var pi := ki * overlap
				var pj := 0.5 * strength[tj] * overlap
				_push_x[i] += pi * ux
				_push_z[i] += pi * uz
				_push_x[j] -= pj * ux
				_push_z[j] -= pj * uz
	_apply_bosses(xs, zs, types, grid, catalog)
	for i in n:
		var px := _push_x[i]
		var pz := _push_z[i]
		# ponytail: total push per tick capped at the enemy's own radius so a dense
		# pile stays stable; revisit if fast enemies or big radii need more.
		var r := radius[types[i]]
		var len := sqrt(px * px + pz * pz)
		if len > r:
			px *= r / len
			pz *= r / len
		xs[i] += px
		zs[i] += pz


# Every boss-horde pair from the grid, then every boss-boss pair directly (bosses are few).
func _apply_bosses(xs: PackedFloat32Array, zs: PackedFloat32Array, types: PackedInt32Array,
		grid: SpatialGrid, catalog: EnemyCatalog) -> void:
	for b in _bosses.size():
		var i := _bosses[b]
		var x := xs[i]
		var z := zs[i]
		var reach := catalog.radius[types[i]] + catalog.max_radius
		var x0 := grid.cell_coord(x - reach)
		var x1 := grid.cell_coord(x + reach)
		for gz in range(grid.cell_coord(z - reach), grid.cell_coord(z + reach) + 1):
			var row := gz * grid.dim
			for k in range(grid.cell_start[row + x0], grid.cell_start[row + x1 + 1]):
				var j := grid.cell_items[k]
				if not catalog.is_boss[types[j]]:
					_push_pair(mini(i, j), maxi(i, j), xs, zs, types, catalog)
		for c in range(b + 1, _bosses.size()):
			_push_pair(i, _bosses[c], xs, zs, types, catalog)


# Same pair rule as the horde loop; i < j (coincident: i goes -x).
func _push_pair(i: int, j: int, xs: PackedFloat32Array, zs: PackedFloat32Array,
		types: PackedInt32Array, catalog: EnemyCatalog) -> void:
	var dx := xs[i] - xs[j]
	var dz := zs[i] - zs[j]
	var rr := catalog.radius[types[i]] + catalog.radius[types[j]]
	var d2 := dx * dx + dz * dz
	if d2 >= rr * rr:
		return
	var d := sqrt(d2)
	var ux := -1.0
	var uz := 0.0
	if d >= COINCIDENT_EPS:
		ux = dx / d
		uz = dz / d
	var overlap := rr - d
	var pi := 0.5 * catalog.separation_strength[types[i]] * overlap
	var pj := 0.5 * catalog.separation_strength[types[j]] * overlap
	_push_x[i] += pi * ux
	_push_z[i] += pi * uz
	_push_x[j] -= pj * ux
	_push_z[j] -= pj * uz
