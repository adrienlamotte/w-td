class_name EnemySeparation
extends RefCounted
## Soft separation (D-079, D-084): each overlapping pair pushes both enemies apart,
## each by 0.5 * overlap * separation_strength of its own type. Jacobi style:
## pushes are computed from the positions at the start of the phase, then applied
## in one pass. Every pair is visited once (j > i) in fixed grid order, so the
## result is deterministic.

const COINCIDENT_EPS: float = 1e-6

var _push_x: PackedFloat32Array = PackedFloat32Array()
var _push_z: PackedFloat32Array = PackedFloat32Array()


## grid must match the enemy positions (02_TECH_ARCHITECTURE.md 3a, tick order).
## Iterates grid.cell_start / cell_items directly: query_radius per enemy cost
## about 73 ms per tick at 3000 piled enemies (task 004).
func apply(enemies: SimEnemies, grid: SpatialGrid, catalog: EnemyCatalog) -> void:
	var xs := enemies.pos_x
	var zs := enemies.pos_z
	var types := enemies.type_id
	var radius := catalog.radius
	var strength := catalog.separation_strength
	var cell_start := grid.cell_start
	var cell_items := grid.cell_items
	var dim := grid.dim
	var n := xs.size()
	_push_x.resize(n)
	_push_z.resize(n)
	_push_x.fill(0.0)
	_push_z.fill(0.0)
	for i in n:
		var ti := types[i]
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
				if d2 >= rr * rr:
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
