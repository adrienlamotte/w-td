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
