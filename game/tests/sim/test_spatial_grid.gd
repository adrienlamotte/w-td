extends GutTest

const CELL: float = 1.4

var rng: RandomNumberGenerator
var xs: PackedFloat32Array
var zs: PackedFloat32Array
var grid: SpatialGrid


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 12345
	xs = PackedFloat32Array()
	zs = PackedFloat32Array()
	grid = SpatialGrid.new(CELL)


func _random_layout(n: int) -> void:
	xs.clear()
	zs.clear()
	for i in n:
		xs.append(rng.randf_range(-40.0, 40.0))
		zs.append(rng.randf_range(-40.0, 40.0))
	# Far outside the grid, to cover clamping.
	for p: Vector2 in [Vector2(100, -90), Vector2(-200, 5), Vector2(70, 70), Vector2(-64, 64)]:
		xs.append(p.x)
		zs.append(p.y)


func _brute_radius(x: float, z: float, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in xs.size():
		var dx := xs[i] - x
		var dz := zs[i] - z
		if dx * dx + dz * dz <= r * r:
			out.append(i)
	return out


func _brute_nearest(x: float, z: float, max_range: float) -> int:
	var best := -1
	var best_d2 := max_range * max_range
	for i in xs.size():
		var dx := xs[i] - x
		var dz := zs[i] - z
		var d2 := dx * dx + dz * dz
		if d2 < best_d2 or (d2 == best_d2 and best == -1):
			best = i
			best_d2 = d2
	return best


## Runs seeded queries against brute force; returns the number of mismatches.
func _mismatches(queries: int) -> int:
	var bad := 0
	var out := PackedInt32Array()
	for q in queries:
		var x := rng.randf_range(-60.0, 60.0)
		var z := rng.randf_range(-60.0, 60.0)
		var r := rng.randf_range(0.0, 12.0)
		grid.query_radius(x, z, r, xs, zs, out)
		if out != _brute_radius(x, z, r):
			bad += 1
		var max_range := rng.randf_range(0.0, 20.0)
		if grid.nearest(x, z, max_range, xs, zs) != _brute_nearest(x, z, max_range):
			bad += 1
	# Points far outside the grid.
	for p: Vector2 in [Vector2(150, -150), Vector2(-300, 0), Vector2(99, -88)]:
		grid.query_radius(p.x, p.y, 20.0, xs, zs, out)
		if out != _brute_radius(p.x, p.y, 20.0):
			bad += 1
		if grid.nearest(p.x, p.y, 30.0, xs, zs) != _brute_nearest(p.x, p.y, 30.0):
			bad += 1
	return bad


func test_matches_brute_force() -> void:
	_random_layout(2000)
	grid.rebuild(xs, zs)
	assert_eq(_mismatches(200), 0)


func test_nearest_far_from_everything_is_minus_one() -> void:
	_random_layout(2000)
	grid.rebuild(xs, zs)
	assert_eq(grid.nearest(0.0, 500.0, 8.0, xs, zs), -1)


func test_query_writes_into_callers_array() -> void:
	xs.append(1.0)
	zs.append(1.0)
	grid.rebuild(xs, zs)
	var out := PackedInt32Array([7, 7, 7])
	grid.query_radius(0.0, 0.0, 2.0, xs, zs, out)
	assert_eq(out, PackedInt32Array([0]))


func test_tie_goes_to_lowest_index() -> void:
	for p: Vector2 in [Vector2(5, 0), Vector2(0, 3), Vector2(-3, 0), Vector2(0, -3)]:
		xs.append(p.x)
		zs.append(p.y)
	grid.rebuild(xs, zs)
	assert_eq(grid.nearest(0.0, 0.0, 10.0, xs, zs), 1)


func test_rebuild_after_movement_and_count_changes() -> void:
	_random_layout(2000)
	grid.rebuild(xs, zs)
	for i in xs.size():
		xs[i] += rng.randf_range(-3.0, 3.0)
		zs[i] += rng.randf_range(-3.0, 3.0)
	grid.rebuild(xs, zs)
	assert_eq(_mismatches(100), 0, "moved")
	xs.resize(500)
	zs.resize(500)
	grid.rebuild(xs, zs)
	assert_eq(_mismatches(100), 0, "fewer")
	_random_layout(3000)
	grid.rebuild(xs, zs)
	assert_eq(_mismatches(100), 0, "more")


func test_empty_grid() -> void:
	grid.rebuild(xs, zs)
	var out := PackedInt32Array([1])
	grid.query_radius(0.0, 0.0, 5.0, xs, zs, out)
	assert_eq(out.size(), 0)
	assert_eq(grid.nearest(0.0, 0.0, 5.0, xs, zs), -1)


func test_sim_world_grid_matches_enemies() -> void:
	var world := SimWorld.new(7)
	assert_almost_eq(world.grid.cell_size, 4.0 * world.catalog.radius[0], 1e-6)
	world.spawn_ring(0, 500, 30.0)
	for t in 60:
		world.step()
	xs = world.enemies.pos_x
	zs = world.enemies.pos_z
	grid = world.grid
	assert_eq(_mismatches(100), 0)


## Timing for the PR (no assertion): 100 rebuilds of 3000, 300 nearest calls.
func test_print_timings() -> void:
	_random_layout(3000)
	var t0 := Time.get_ticks_usec()
	for n in 100:
		grid.rebuild(xs, zs)
	var t1 := Time.get_ticks_usec()
	var found := 0
	for n in 300:
		if grid.nearest(rng.randf_range(-40.0, 40.0), rng.randf_range(-40.0, 40.0), 8.0, xs, zs) >= 0:
			found += 1
	var t2 := Time.get_ticks_usec()
	gut.p("SpatialGrid: 100 rebuilds of %d = %.1f ms; 300 nearest(8) = %.2f ms (%d found)"
		% [xs.size(), (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, found])
	assert_gt(found, 0)
