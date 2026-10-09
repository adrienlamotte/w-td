class_name BenchScenario
extends RefCounted
## Sets up one benchmark scenario (task 008, D-088) through the sim's test/benchmark
## APIs only (spawn_ring, towers.add, recycle_radius, TowerBuilding.add_built). No rules, no Node.

const GOLDEN_ANGLE: float = 2.39996


## cfg: the bench JSON (data/bench); sc: one of its scenarios.
static func apply(world: SimWorld, cfg: Dictionary, sc: Dictionary) -> void:
	var type := world.catalog.type_of(cfg.enemy_type)
	var rings := int(cfg.spawn_rings)
	var enemies := int(sc.enemies)
	var per_ring := enemies / rings
	for r in rings:
		var radius := lerpf(cfg.spawn_ring_min, cfg.spawn_ring_max, float(r) / (rings - 1))
		var count := per_ring if r < rings - 1 else enemies - per_ring * (rings - 1)
		world.spawn_ring(type, count, radius)
	world.recycle_radius = 0.0 if sc.piled else float(cfg.recycle_radius)
	# Sunflower spiral: towers spread evenly over the build radius.
	var towers := int(sc.towers)
	for t in towers:
		var rad := float(cfg.build_radius) * sqrt((t + 0.5) / towers)
		var angle := t * GOLDEN_ANGLE
		world.towers.add(cos(angle) * rad, sin(angle) * rad, cfg.tower_range)
	if sc.get("maze", false):
		_maze(world, cfg)


# Concentric rings of built towers (D-115), towers every 0.5 units of arc (taken cells
# skipped), one gap of maze_gap units per ring, alternating at angle 0 and PI.
static func _maze(world: SimWorld, cfg: Dictionary) -> void:
	world.build = BuildGrid.new(float(cfg.build_radius), float(cfg.grid_step))
	var type := world.tower_catalog.type_of(cfg.maze_tower)
	var rings: Array = cfg.maze_rings
	for r in rings.size():
		var radius := float(rings[r])
		var gap_angle := 0.0 if r % 2 == 0 else PI
		var count := ceili(TAU * radius / 0.5)
		for k in count:
			var angle := k * TAU / count
			if absf(angle_difference(angle, gap_angle)) * radius < float(cfg.maze_gap) / 2.0:
				continue
			TowerBuilding.add_built(world, type, cos(angle) * radius, sin(angle) * radius)
