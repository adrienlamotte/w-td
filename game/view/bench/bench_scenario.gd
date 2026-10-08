class_name BenchScenario
extends RefCounted
## Sets up one benchmark scenario (task 008, D-088) through the sim's test/benchmark
## APIs only (spawn_ring, towers.add, recycle_radius). No rules, no Node.

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
