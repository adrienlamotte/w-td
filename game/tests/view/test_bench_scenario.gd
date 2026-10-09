extends GutTest

var cfg: Dictionary


func before_each() -> void:
	cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/bench/bench_m1.json"))


func _scenario(enemies: int, towers: int, piled: bool) -> Dictionary:
	var sc: Dictionary = cfg.scenarios[0].duplicate()
	sc.enemies = enemies
	sc.towers = towers
	sc.piled = piled
	return sc


func test_counts_and_layout() -> void:
	var world := SimWorld.new(1)
	BenchScenario.apply(world, cfg, _scenario(101, 17, false))
	assert_eq(world.enemies.count(), 101)
	assert_eq(world.towers.count(), 17)
	for t in 17:
		var r := Vector2(world.towers.pos_x[t], world.towers.pos_z[t]).length()
		assert_true(r <= float(cfg.build_radius) + 1e-3, "tower %d at %f" % [t, r])
	assert_eq(world.recycle_radius, float(cfg.recycle_radius))


func test_piled_has_no_recycle() -> void:
	var world := SimWorld.new(1)
	BenchScenario.apply(world, cfg, _scenario(12, 0, true))
	assert_eq(world.recycle_radius, 0.0)


func test_crowd_crosses_the_tower_field() -> void:
	var world := SimWorld.new(1)
	BenchScenario.apply(world, cfg, _scenario(300, 20, false))
	for i in 300:
		world.step()
	assert_eq(world.enemies.count(), 300)
	assert_true(Array(world.towers.target).any(func(t: int) -> bool: return t >= 0))
	var inside := 0
	for i in 300:
		if Vector2(world.enemies.pos_x[i], world.enemies.pos_z[i]).length() < float(cfg.build_radius):
			inside += 1
	assert_gt(inside, 0)


func test_maze_layout_and_field_cost() -> void:
	var world := SimWorld.new(1)
	var sc: Dictionary = cfg.scenarios.filter(func(x: Dictionary) -> bool: return x.get("maze", false))[0]
	BenchScenario.apply(world, cfg, sc)
	assert_gt(world.towers.count(), 100)
	world.field = FlowField.new(world.build, 0.0)
	var start := Time.get_ticks_usec()
	world.field.update(FlowField.FULL)
	var full := Time.get_ticks_usec() - start
	world.build.version += 1
	var ticks := 0
	while ticks == 0 or world.field.busy():
		world.field.update(FlowField.CELLS_PER_TICK)
		ticks += 1
	gut.p("maze %d towers: full field %.2f ms (headless debug), %d ticks at %d units per tick" % [
		world.towers.count(), full / 1000.0, ticks, FlowField.CELLS_PER_TICK])
	# A real maze: from outside, the path is much longer than the straight line (22 units).
	var c := world.build.cell_of(21.5, 0.25)
	assert_gt(world.field.dist[c], 2 * 2 * 22, "at least twice the straight cost")
	assert_lt(world.field.dist[c], FlowField.INF)
