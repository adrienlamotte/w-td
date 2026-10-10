class_name BenchScenario
extends RefCounted
## Sets up one benchmark scenario (task 008, D-088) through the sim's test/benchmark
## APIs only (spawn_ring, towers.add, recycle_radius, TowerBuilding.add_built, a run's
## overrides as in test_walled_in.gd). No rules, no Node.

const GOLDEN_ANGLE: float = 2.39996


## cfg: the bench JSON (data/bench); sc: one of its scenarios.
static func apply(world: SimWorld, cfg: Dictionary, sc: Dictionary) -> void:
	if sc.get("combat", false):
		_start_combat(world, cfg)
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
		if sc.get("combat", false):  # real towers that fire; taken cells skipped
			var types := world.run.tower_types
			TowerBuilding.add_built(world, types[t % types.size()], cos(angle) * rad, sin(angle) * rad)
		else:
			world.towers.add(cos(angle) * rad, sin(angle) * rad, cfg.tower_range)
	if sc.get("maze", false):
		_maze(world, cfg)
	if sc.get("walled", false):
		_walled(world, cfg)
	if sc.get("combat", false):
		world.field = null  # full computation on the next step, as for a fresh build grid


## Combat scenarios: tops the horde back up after deaths, on the outer spawn ring.
## Harness only, like spawn_ring (the grid safety net rebuilds outside the phase timers).
## Also takes the first card of a draft at once, so the horde never freezes (D-147).
static func refill(world: SimWorld, cfg: Dictionary, sc: Dictionary) -> void:
	if world.draft.drafting:
		world.queue(SimCommand.pick_card(world.tick, 0))
	var missing := int(sc.enemies) - world.enemies.count()
	if missing > 0:
		world.spawn_ring(world.catalog.type_of(cfg.enemy_type), missing, float(cfg.spawn_ring_max))


# A RUNNING run of combat_run (towers fire only while RUNNING), with the overrides of
# test_walled_in.gd: no wave spawns, no bosses, a Guardian that never falls.
static func _start_combat(world: SimWorld, cfg: Dictionary) -> void:
	world.queue(SimCommand.start_run(0, int(cfg.seed), cfg.combat_run))
	world.step()
	world.run.first_wave_tick = 1 << 30
	world.run.final_boss_tick = -1
	world.run.boss_ticks = PackedInt32Array()
	world.guardian_hp = 1e12


# The 026 worst case: one full ring at walled_ring (towers every 0.25 units of arc, as
# test_walled_in.gd), no gap, towers that never fall, so the horde stays walled in and attacks.
static func _walled(world: SimWorld, cfg: Dictionary) -> void:
	var type := world.tower_catalog.type_of(cfg.maze_tower)
	var radius := float(cfg.walled_ring)
	var count := ceili(TAU * radius / 0.25)
	for k in count:
		var angle := k * TAU / count
		TowerBuilding.add_built(world, type, cos(angle) * radius, sin(angle) * radius)
	world.towers.hp.fill(1e6)


# Concentric rings of built towers (D-115), towers every 0.5 units of arc (taken cells
# skipped), one gap of maze_gap units per ring, alternating at angle 0 and PI.
static func _maze(world: SimWorld, cfg: Dictionary) -> void:
	if world.build == null:  # combat: the run's grid (same radius and step, tested)
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
