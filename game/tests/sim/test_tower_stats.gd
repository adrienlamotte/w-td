extends GutTest
## Level tables, derived tower stats and the modifier store (D-144).

const PIP := "tower_pip"
const BASTIA := "tower_bastia"
const MULT := SimModifiers.Op.MULT
const ADD := SimModifiers.Op.ADD

var world: SimWorld


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.gold = 1 << 20


func _built(id: String, x: float = 4.0, z: float = 4.0) -> int:
	var u := TowerBuilding.add_built(world, world.tower_catalog.type_of(id), x, z)
	return world.towers.uid.find(u)


func _upgrade(t: int) -> void:
	world.queue(SimCommand.upgrade_tower(world.tick, world.towers.uid[t]))
	world.step()


func test_level_tables() -> void:
	var cat := world.tower_catalog
	var pip := cat.type_of(PIP)
	assert_eq(cat.max_level[pip], 4)
	assert_eq(cat.max_level[cat.type_of("tower_single_01")], 1)
	var l4: Dictionary = cat.level_stats[pip][3]
	assert_eq(float(l4.damage), 10.0, "inherited from L3")
	assert_eq(float(l4.range), 7.0, "inherited from L3")
	assert_eq(float(l4.cooldown_sec), 0.35)
	assert_eq(float(cat.level_stats[pip][0].cost), 50.0, "L1 cost = placement cost")
	var hps: Array = []
	for lv: Dictionary in cat.level_stats[cat.type_of(BASTIA)]:
		hps.append(float(lv.hp))
	assert_eq(hps, [400.0, 600.0, 800.0, 1200.0])


func test_level_1_matches_catalog() -> void:
	var t := _built(PIP)
	var type := world.towers.type_id[t]
	assert_eq(world.towers.attack_range[t], world.tower_catalog.attack_range[type])
	assert_eq(world.towers.damage[t], world.tower_catalog.damage[type])
	assert_eq(world.towers.reload[t], world.tower_catalog.cooldown[type])
	assert_eq(world.towers.hp[t], world.tower_catalog.hp[type])
	assert_eq(world.towers.max_hp[t], world.tower_catalog.hp[type])


func test_derived_per_level() -> void:
	var t := _built(PIP)
	world.add_modifier("unlock_level", ADD, 4, "tower:" + PIP)
	for i in 3:
		_upgrade(t)
	assert_eq(world.towers.level[t], 4)
	assert_eq(world.towers.damage[t], 10.0)
	assert_eq(world.towers.attack_range[t], 7.0)
	assert_eq(world.towers.reload[t], DataFiles.ticks(0.35))


func test_upgrade_of_damaged_tower_adds_the_difference() -> void:
	var t := _built(BASTIA)
	world.damage_tower(t, 150.0)
	_upgrade(t)
	assert_eq(world.towers.max_hp[t], 600.0)
	assert_eq(world.towers.hp[t], 450.0)


func test_multipliers_add_up_and_add_comes_first() -> void:
	var t := _built(PIP)
	world.add_modifier("damage", MULT, 0.1, "all_towers")
	world.add_modifier("damage", MULT, 0.1, "all_towers")
	world.add_modifier("damage", ADD, 2.0, "all_towers")
	world.step()
	assert_almost_eq(world.towers.damage[t], (6.0 + 2.0) * 1.2, 1e-4)


func test_tower_target_touches_only_that_type() -> void:
	var pip := _built(PIP)
	var bastia := _built(BASTIA, -4.0, 4.0)
	world.add_modifier("hp", MULT, 0.5, "tower:" + BASTIA)
	world.step()
	assert_eq(world.towers.max_hp[bastia], 600.0)
	assert_eq(world.towers.hp[bastia], 600.0, "a rise adds the difference")
	assert_eq(world.towers.max_hp[pip], 100.0)


func test_cooldown_clamp() -> void:
	var t := _built(PIP)
	world.add_modifier("cooldown", MULT, -0.9, "all_towers")
	world.step()
	assert_eq(world.towers.reload[t], ceili(DataFiles.ticks(0.5) * 0.5), "50% of the level value")
	assert_eq(TowerStats.reload_ticks(0.01, Vector2(0.0, -0.9)), 1, "at least 1 tick")


func test_max_hp_fall_clamps() -> void:
	var t := _built(PIP)
	world.add_modifier("hp", MULT, -0.5, "all_towers")
	world.step()
	assert_eq(world.towers.max_hp[t], 50.0)
	assert_eq(world.towers.hp[t], 50.0)


func test_no_recompute_without_change() -> void:
	var t := _built(PIP)
	world.step()
	assert_false(world.towers.stats_dirty)
	world.towers.damage[t] = 123.0  # a recompute would overwrite it
	for i in 30:
		world.step()
		assert_false(world.towers.stats_dirty)
	assert_eq(world.towers.damage[t], 123.0)


func test_remove_moves_derived_arrays() -> void:
	_built(PIP)
	var b := _built(BASTIA, -4.0, 4.0)
	_upgrade(b)
	world.queue(SimCommand.sell_tower(world.tick, world.towers.uid[0]))
	world.step()
	assert_eq(world.towers.count(), 1)
	assert_eq(world.towers.level[0], 2)
	assert_eq(world.towers.max_hp[0], 600.0)
	assert_eq(world.towers.thorns[0], 3.0)
	for a in [world.towers.level, world.towers.damage, world.towers.reload, world.towers.max_hp,
			world.towers.splash_radius, world.towers.slow_factor, world.towers.slow_ticks,
			world.towers.thorns, world.towers.mark_gold, world.towers.mark_ticks]:
		assert_eq(a.size(), 1)


func test_kind_fields() -> void:
	var b := _built(BASTIA, -4.0, 4.0)
	var c := _built("tower_clover")
	assert_eq(world.towers.attack_range[b], 0.0, "wall: no targeting (D-145)")
	assert_eq(world.towers.thorns[b], 3.0)
	assert_eq([world.towers.mark_gold[c], world.towers.mark_ticks[c]], [2, DataFiles.ticks(4.0)])
	_upgrade(c)
	_upgrade(c)
	world.towers.level[c] = 4  # L4 needs a card
	world.towers.stats_dirty = true
	world.step()
	assert_eq([world.towers.mark_gold[c], world.towers.mark_ticks[c]], [5, DataFiles.ticks(6.0)])
