extends GutTest
## Flow field (D-115): dist, dir, hit, escape, slicing, recompute only on change.

const C: int = 44  # first cell east/south of the Guardian on the 88-cell grid of run_m2

var b: BuildGrid
var f: FlowField


func before_each() -> void:
	b = BuildGrid.new(20.0, 0.5)
	f = FlowField.new(b, 0.0)  # goal radius = step: the 4 centre cells


func _c(i: int, j: int) -> int:
	return j * b.size + i


func _solid(i: int, j: int) -> void:
	b.fill(i, j, 1, 1, 1)


func test_empty_grid() -> void:
	f.update(FlowField.FULL)
	assert_eq(f.recomputes, 1)
	assert_eq(f.hit.count(-1), b.size * b.size, "every line clear")
	for c in [_c(C, C), _c(C - 1, C), _c(C, C - 1), _c(C - 1, C - 1)]:
		assert_eq(f.dist[c], 0)
	assert_eq(f.dist[_c(C + 4, C)], 8, "4 east")
	assert_eq(f.dir[_c(C + 4, C)], 1, "steps west")
	assert_eq(f.dist[_c(C + 3, C - 4)], 9, "3 east 3 north of the goal")
	assert_eq(f.escape[_c(3, 7)], _c(3, 7), "a free cell escapes to itself")


func test_wall_routes_around_toward_the_nearer_end() -> void:
	for j in range(34, 54):  # x in [3, 4), z in [-5, 5)
		b.fill(50, j, 2, 1, 1)
	f.update(FlowField.FULL)
	var c := _c(56, 46)
	var h := f.hit[c]
	assert_true(h >= 0 and b.solid[h] == 1, "line blocked by the wall")
	assert_lt(f.dist[c], FlowField.INF)
	assert_gt(f.dist[c], 24, "longer than the straight 12 steps")
	assert_gt(FlowField.DIR_Z[f.dir[c]], 0.0, "toward the nearer (south, +z) end")


func _square_ring(lo: int, hi: int) -> void:
	for k in range(lo, hi + 1, 2):
		b.fill(k, lo, 2, 1, 1)
		b.fill(k, hi, 2, 1, 1)
		b.fill(lo, k, 2, 1, 1)
		b.fill(hi, k, 2, 1, 1)


func test_closed_ring_then_husk() -> void:
	_square_ring(36, 50)
	f.update(FlowField.FULL)
	assert_eq(f.dist[_c(60, 44)], FlowField.INF, "outside: no path")
	assert_ne(f.hit[_c(60, 44)], -1)
	assert_lt(f.dist[_c(40, 44)], FlowField.INF, "inside")
	b.fill(50, 44, 2, 1, 0)  # one tower becomes a husk: walkable
	f.update(FlowField.FULL)
	assert_lt(f.dist[_c(60, 44)], FlowField.INF, "through the husk")


func test_corner_touching_diamond_blocks_path_and_line() -> void:
	for j in b.size:
		for i in b.size:
			if absi(i - C) + absi(j - C) == 9:
				_solid(i, j)
	f.update(FlowField.FULL)
	assert_eq(f.dist[_c(C + 12, C)], FlowField.INF, "no corner cutting")
	assert_lt(f.dist[_c(C + 3, C)], FlowField.INF)
	# (5, 5) -> (4, 4) is diagonal between the solid (4, 5) and (5, 4): the line is blocked.
	assert_eq(f.hit[_c(C + 5, C + 5)], _c(C + 4, C + 5))
	assert_eq(f.hit[_c(C + 6, C + 6)], _c(C + 4, C + 5))


func test_escape() -> void:
	b.fill(60, 60, 2, 1, 1)
	b.fill(62, 60, 2, 2, 1)
	b.fill(60, 62, 2, 3, 1)
	b.fill(62, 62, 2, 4, 1)  # a 4 x 4 block
	b.fill(20, 20, 2, 5, 1)
	f.update(FlowField.FULL)
	var e := f.escape[_c(20, 20)]
	assert_eq(b.solid[e], 0)
	assert_eq(absi(e % b.size - 20) + absi(e / b.size - 20), 1, "a free neighbour")
	e = f.escape[_c(61, 61)]
	assert_eq(b.solid[e], 0)
	assert_eq(absi(e % b.size - 61) + absi(e / b.size - 61), 2, "nearest border cell")


func _maze() -> void:
	_square_ring(30, 56)
	_square_ring(38, 48)
	b.fill(56, 44, 2, 1, 0)  # gaps on opposite sides
	b.fill(38, 42, 2, 1, 0)


func test_slicing_equals_full() -> void:
	_maze()
	var g := FlowField.new(b, 0.0)
	g.update(FlowField.FULL)
	var n := 0
	while f.recomputes == 0 and n < 10000:
		f.update(100)
		n += 1
	assert_gt(n, 50, "really sliced")
	assert_eq(f.dist, g.dist)
	assert_eq(f.dir, g.dir)
	assert_eq(f.hit, g.hit)
	assert_eq(f.escape, g.escape)


func test_change_mid_computation_waits_for_the_next() -> void:
	f.update(FlowField.FULL)
	var before := f.dist.duplicate()
	_maze()
	f.update(100)
	assert_true(f.busy())
	b.fill(70, 44, 2, 9, 1)  # a change while the first one runs
	f.update(100)
	assert_eq(f.dist, before, "published arrays kept until the swap")
	var n := 0
	while f.busy() and n < 10000:
		f.update(100)
		n += 1
	assert_eq(f.recomputes, 2)
	assert_lt(f.dist[_c(70, 44)], FlowField.INF, "not yet solid: the snapshot predates the change")
	while (f.busy() or f.recomputes < 3) and n < 20000:
		f.update(100)
		n += 1
	assert_eq(f.recomputes, 3, "exactly 2 more")
	var g := FlowField.new(b, 0.0)
	g.update(FlowField.FULL)
	assert_eq(f.dist, g.dist, "final layout")
	assert_eq(f.dist[_c(70, 44)], FlowField.INF)
	f.update(100)
	assert_eq(f.recomputes, 3, "nothing changed: no new computation")


func test_world_recomputes_only_on_change() -> void:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.run.first_wave_tick = 1 << 30
	assert_eq(world.field.recomputes, 1, "full first computation at StartRun")
	for i in 100:
		world.step()
	assert_eq(world.field.recomputes, 1)
	world.queue(SimCommand.place_tower(world.tick, "tower_single_01", 5.0, 0.0))
	for i in 100:
		world.step()
	assert_eq(world.field.recomputes, 2)
