extends GutTest
## D-123: the cell-order half-box separation loop visits the same pairs with the same rule
## as a brute-force O(n^2) loop over every pair i < j.

const IDS: Array[String] = ["enemy_swarmer_01", "enemy_brute_01", "enemy_ranged_01"]

var _catalog: EnemyCatalog


func before_each() -> void:
	_catalog = EnemyCatalog.load_dir()


func _crowd() -> SimEnemies:
	var rng := RandomNumberGenerator.new()
	rng.seed = 123
	var e := SimEnemies.new()
	for k in 500:
		e.add(_catalog.type_of(IDS[k % IDS.size()]), rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0), 1.0)
	for k in 40:  # outside the grid square (half_extent 64): clamped into the edge cells
		e.add(_catalog.type_of(IDS[k % 2]), rng.randf_range(64.5, 66.0), rng.randf_range(-1.0, 1.0), 1.0)
	for k in 10:  # coincident pairs
		var x := rng.randf_range(-6.0, 6.0)
		var z := rng.randf_range(-6.0, 6.0)
		e.add(_catalog.type_of(IDS[0]), x, z, 1.0)
		e.add(_catalog.type_of(IDS[1]), x, z, 1.0)
	for k in 5:  # mirrored pairs: equal queue keys
		e.add(_catalog.type_of(IDS[0]), 0.1, 2.0 + k, 1.0)
		e.add(_catalog.type_of(IDS[0]), -0.1, 2.0 + k, 1.0)
	e.add(_catalog.type_of("enemy_boss_01"), 1.0, 1.0, 1.0)
	e.add(_catalog.type_of("enemy_miniboss_01"), -2.0, 0.5, 1.0)
	for i in e.count():
		e.state[i] = rng.randi_range(0, 2)
	return e


# Every pair i < j with the rule of EnemySeparation._push_pair, keys without a field.
func _reference(e: SimEnemies) -> PackedByteArray:
	var n := e.count()
	var px := PackedFloat64Array()
	var pz := PackedFloat64Array()
	px.resize(n)
	pz.resize(n)
	var blocked := PackedByteArray()
	blocked.resize(n)
	var xs := e.pos_x
	var zs := e.pos_z
	for i in n:
		for j in range(i + 1, n):
			var dx := xs[i] - xs[j]
			var dz := zs[i] - zs[j]
			var rr := _catalog.radius[e.type_id[i]] + _catalog.radius[e.type_id[j]]
			var d2 := dx * dx + dz * dz
			if d2 >= rr * rr:
				continue
			if xs[j] * xs[j] + zs[j] * zs[j] > xs[i] * xs[i] + zs[i] * zs[i]:
				if e.state[i] != SimEnemies.State.MOVING:
					blocked[j] = 1
			elif e.state[j] != SimEnemies.State.MOVING:
				blocked[i] = 1
			var d := sqrt(d2)
			var ux := -1.0
			var uz := 0.0
			if d >= EnemySeparation.COINCIDENT_EPS:
				ux = dx / d
				uz = dz / d
			var overlap := rr - d
			var pi := 0.5 * _catalog.separation_strength[e.type_id[i]] * overlap
			var pj := 0.5 * _catalog.separation_strength[e.type_id[j]] * overlap
			px[i] += pi * ux
			pz[i] += pi * uz
			px[j] -= pj * ux
			pz[j] -= pj * uz
	for i in n:
		var r := _catalog.radius[e.type_id[i]]
		var len := sqrt(px[i] * px[i] + pz[i] * pz[i])
		if len > r:
			px[i] *= r / len
			pz[i] *= r / len
		xs[i] += px[i]
		zs[i] += pz[i]
	return blocked


func test_matches_brute_force_reference() -> void:
	var e := _crowd()
	var ref := _crowd()
	var grid := SpatialGrid.new(2.0 * _catalog.max_radius)  # as SimWorld (D-108)
	var sep := EnemySeparation.new()
	for t in 3:
		grid.rebuild(e.pos_x, e.pos_z)
		sep.apply(e, grid, _catalog)
		var ref_blocked := _reference(ref)
		assert_eq(sep.blocked, ref_blocked, "tick %d: blocked flags" % t)
		var worst := 0.0
		for i in e.count():
			worst = maxf(worst, maxf(absf(e.pos_x[i] - ref.pos_x[i]), absf(e.pos_z[i] - ref.pos_z[i])))
		assert_lt(worst, 1e-5, "tick %d: positions" % t)


func test_coincident_pair_sends_lower_index_to_minus_x() -> void:
	var e := SimEnemies.new()
	var t := _catalog.type_of(IDS[0])
	e.add(t, 3.0, 3.0, 1.0)
	e.add(t, 3.0, 3.0, 1.0)
	var grid := SpatialGrid.new(2.0 * _catalog.max_radius)
	grid.rebuild(e.pos_x, e.pos_z)
	EnemySeparation.new().apply(e, grid, _catalog)
	assert_lt(e.pos_x[0], 3.0)
	assert_gt(e.pos_x[1], 3.0)
