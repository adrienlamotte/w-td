extends GutTest
## Build grid: footprint, snap, free cells, solid/version (D-109).


func test_footprint() -> void:
	assert_eq(BuildGrid.footprint(0.5, 0.5), 2)
	assert_eq(BuildGrid.footprint(0.2, 0.5), 1)
	assert_eq(BuildGrid.footprint(0.7, 0.5), 3)


func test_snap_even_and_odd() -> void:
	var b := BuildGrid.new(20.0, 0.5)
	assert_eq(b.size, 88)
	assert_almost_eq(b.cell_centre(b.first_cell(1.3, 2), 2), 1.5, 1e-6)
	assert_almost_eq(b.cell_centre(b.first_cell(1.3, 1), 1), 1.25, 1e-6)
	assert_almost_eq(b.cell_centre(b.first_cell(-1.3, 2), 2), -1.5, 1e-6)


func test_is_free_and_fill() -> void:
	var b := BuildGrid.new(20.0, 0.5)
	assert_true(b.is_free(0, 0, 2))
	assert_false(b.is_free(-1, 0, 2), "out of the grid")
	assert_false(b.is_free(87, 0, 2), "out of the grid")
	b.fill(10, 10, 2, 7, 1)
	assert_eq(b.version, 1)
	assert_eq(b.owner[11 * 88 + 11], 7)
	assert_eq(b.solid[10 * 88 + 10], 1)
	assert_false(b.is_free(11, 11, 2), "owned cell")
	assert_true(b.is_free(12, 10, 2))
	b.fill(10, 10, 2, 7, 1)
	assert_eq(b.version, 1, "solid unchanged: no bump")
	b.fill(10, 10, 2, 7, 0)
	assert_eq(b.version, 2)
	assert_false(b.is_free(10, 10, 2), "husk keeps its cells")
	b.fill(10, 10, 2, -1, 0)
	assert_eq(b.version, 2)
	assert_true(b.is_free(10, 10, 2))


func test_run_m2_grid_size() -> void:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	# 112, not 88: sized for the reachable radius 20 + perk_expand 2 x 3 (D-148)
	assert_eq(world.build.size, 112)


func test_cell_of() -> void:
	var b := BuildGrid.new(20.0, 0.5)
	assert_eq(b.cell_of(0.1, 0.1), 44 * 88 + 44)
	assert_eq(b.cell_of(-0.1, 0.1), 44 * 88 + 43)
	assert_eq(b.cell_of(-22.0, -22.0), 0)
	assert_eq(b.cell_of(22.0, 0.0), -1, "outside")
	assert_eq(b.cell_of(0.0, -22.01), -1, "outside")
