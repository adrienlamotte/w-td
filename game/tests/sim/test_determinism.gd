extends GutTest
## Same seed + same commands = same state (02_TECH_ARCHITECTURE.md section 6).
## No commands here; test_replay.gd covers same seed + same commands.

const SWARMER := "enemy_swarmer_01"  # catalog sorted by id: type 0 is not the swarmer
const TICKS: int = 30 * 60  # one simulated minute
const ENEMIES: int = 1000
const TOWERS: int = 50

var _hash_a: int
var _hash_a2: int
var _hash_b: int


func _run(run_seed: int) -> int:
	var world := SimWorld.new(run_seed)
	world.recycle_radius = 30.0  # the minute is long enough for arrivals: covers the recycle path
	world.spawn_ring(world.catalog.type_of(SWARMER), ENEMIES, 30.0)
	for t in TOWERS:  # same towers for every run, on a spiral inside the build radius
		var angle := t * 2.4
		var r := 20.0 * sqrt((t + 0.5) / TOWERS)
		world.towers.add(cos(angle) * r, sin(angle) * r, 8.0)
	var start := Time.get_ticks_msec()
	for i in TICKS:
		world.step()
	gut.p("seed %d: %d ticks x %d enemies in %d ms" % [run_seed, TICKS, ENEMIES, Time.get_ticks_msec() - start])
	return world.state_hash()


func before_all() -> void:
	_hash_a = _run(12345)
	_hash_a2 = _run(12345)
	_hash_b = _run(54321)


func test_same_seed_same_state() -> void:
	assert_eq(_hash_a, _hash_a2)


func test_different_seed_different_state() -> void:
	assert_ne(_hash_a, _hash_b)


func _run_m2(run_seed: int) -> int:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	for i in 2400:  # wave 0, its break, the start of wave 1
		world.step()
	assert_gt(world.enemies.count(), 0)
	return world.state_hash()


func test_run_spawns_deterministic() -> void:
	var h := _run_m2(7)
	assert_eq(_run_m2(7), h)
	assert_ne(_run_m2(8), h)


# Maze routing (D-115): a wall placed, one tower killed into a husk, one sold, mid-run.
func _run_maze(run_seed: int) -> int:
	var world := SimWorld.new(1)
	world.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	world.step()
	world.gold = 1 << 30
	for z in range(-6, 7):
		world.queue(SimCommand.place_tower(world.tick, "tower_single_01", 8.0, z))
		world.queue(SimCommand.place_tower(world.tick, "tower_single_01", -8.0, z))
	for i in 600:
		world.step()
	world.damage_tower(3, 1e9)
	world.queue(SimCommand.sell_tower(world.tick, world.towers.uid[20]))
	for i in 900:
		world.step()
	assert_gt(world.field.recomputes, 2)
	assert_gt(world.enemies.count(), 0)
	return world.state_hash()


func test_maze_deterministic() -> void:
	var h := _run_maze(7)
	assert_eq(_run_maze(7), h)
	assert_ne(_run_maze(8), h)


# Place, upgrade and sell commands (D-144).
func test_upgrade_replay_deterministic() -> void:
	assert_eq(_replay_upgrades(), _replay_upgrades())


func _replay_upgrades() -> int:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, 3, "run_m2"))
	w.step()
	w.gold = 1000
	var u := TowerBuilding.add_built(w, w.tower_catalog.type_of("tower_pip"), 6.0, 0.0)
	w.queue(SimCommand.place_tower(w.tick + 5, "tower_single_01", -6.0, 0.0))
	w.queue(SimCommand.upgrade_tower(w.tick + 10, u))
	w.queue(SimCommand.upgrade_tower(w.tick + 20, u))
	w.queue(SimCommand.sell_tower(w.tick + 30, u))
	for i in 900:
		w.step()
	return w.state_hash()


# M3 kinds (D-145): a walled-in ring of Bastia, Clover and Tansy on run_m2.
func test_tower_kinds_deterministic() -> void:
	var h := _run_kinds(7)
	assert_eq(_run_kinds(7), h)
	assert_ne(_run_kinds(8), h)


func _run_kinds(run_seed: int) -> int:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	w.step()
	var ids := ["tower_bastia", "tower_clover", "tower_tansy"]
	var count := ceili(TAU * 6.0 / 0.25)
	for k in count:
		var a := k * TAU / count
		TowerBuilding.add_built(w, w.tower_catalog.type_of(ids[k % 3]), cos(a) * 6.0, sin(a) * 6.0)
	var hits := 0
	for i in 2400:
		w.step()
		for e in w.events.count:
			if w.events.kind[e] == SimEvents.Kind.TOWER_HIT:
				hits += 1
	assert_gt(hits, 0, "the horde hit the wall")
	return w.state_hash()


# A non-placeholder Guardian casting her signature and the Shield (D-146).
func _guardian_hash(gid: String) -> int:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, 7, "run_m2", gid))
	for t in [100, 600, 1300, 2000]:
		w.queue(SimCommand.use_skill(t, "skill_stand_firm"))
	for t in [300, 1200]:
		w.queue(SimCommand.use_skill(t, "skill_shield"))
	for t in 2400:
		w.step()
	return w.state_hash()


func test_guardian_skills_deterministic() -> void:
	var h := _guardian_hash("guardian_bastia")
	assert_eq(_guardian_hash("guardian_bastia"), h)


# Run-scope card effects (D-148): perk_expand and perk_maze picked through the draft on run_m3.
func test_run_effects_deterministic() -> void:
	var h := _run_effects(7)
	assert_eq(_run_effects(7), h)


func _run_effects(run_seed: int) -> int:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, run_seed, "run_m3"))
	w.step()
	w.gold = 1 << 20
	for id in ["perk_expand", "perk_maze"]:
		var c := w.cards.index_of(id)
		w.draft.draft = PackedInt32Array([c, c, c])
		w.draft.drafting = true
		w.draft.pending = 1
		w.queue(SimCommand.pick_card(w.tick, 0))
		w.step()
	for z in range(-6, 7):
		w.queue(SimCommand.place_tower(w.tick, "tower_pip", 8.0, z))
	w.queue(SimCommand.place_tower(w.tick, "tower_pip", 22.0, 0.0))  # only inside 23
	for i in 1800:
		w.step()
	assert_eq(w.build_radius, 23.0)
	assert_eq(w.towers.count(), 14, "the expanded placement went through")
	return w.state_hash()
