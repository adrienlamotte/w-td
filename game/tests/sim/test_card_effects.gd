extends GutTest
## Card effects (D-147 rule 6, 10_M3_CONTENT.md 2.5).

var world: SimWorld


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m3"))
	world.step()
	world.run.first_wave_tick = 1 << 30
	world.run.final_boss_tick = -1
	world.run.boss_ticks = PackedInt32Array()
	world.gold = 1000


func _apply(id: String) -> void:
	for e: Dictionary in world.cards.effects[world.cards.index_of(id)]:
		CardEffects.apply(world, e)


func _store_has(stat: String, target: String) -> bool:
	for e in world.modifiers.stat.size():
		if world.modifiers.stat[e] == stat and world.modifiers.target[e] == target:
			return true
	return false


func _kill_gold(enemy_id: String, mark := 0) -> int:
	world.enemies.add(world.catalog.type_of(enemy_id), 20.0, 0.0, 1.0)
	var i := world.enemies.count() - 1
	if mark > 0:
		world.enemies.mark_gold[i] = mark
		world.enemies.mark_until[i] = world.clock + 100
	world.damage_enemy(i, 10.0)
	var gold := world.gold
	world.step()
	return world.gold - gold


func test_purse_through_a_pick() -> void:
	var purse := world.cards.index_of("card_purse")
	world.draft.draft = PackedInt32Array([purse, purse, purse])
	world.draft.drafting = true
	world.draft.pending = 1
	world.queue(SimCommand.pick_card(world.tick, 1))
	world.step()
	assert_eq(world.gold, 1040)
	assert_eq(world.draft.picks[purse], 1)
	var picked := -1
	for e in world.events.count:
		if world.events.kind[e] == SimEvents.Kind.CARD_PICKED:
			picked = e
	assert_eq(world.events.a[picked], purse)
	assert_eq(world.events.value[picked], 1.0, "slot")


func test_unlock_tower() -> void:
	assert_eq(TowerBuilding.check_place(world, "tower_cinder", 4.0, 4.0).reason, TowerBuilding.Reason.NOT_OFFERED)
	_apply("card_tower_cinder")
	_apply("card_tower_cinder")
	assert_eq(TowerBuilding.check_place(world, "tower_cinder", 4.0, 4.0).reason, TowerBuilding.Reason.OK)
	assert_eq(world.tower_types.size(), world.run.tower_types.size() + 1, "added once")
	assert_eq(world.run.tower_types.size(), 2, "the run file is untouched")


func test_signature_unlocks_level_4() -> void:
	var uid := TowerBuilding.add_built(world, world.tower_catalog.type_of("tower_pip"), 4.0, 4.0)
	world.towers.level[world.towers.uid.find(uid)] = 3
	assert_eq(TowerUpgrade.check(world, uid).reason, TowerUpgrade.Reason.LOCKED)
	_apply("card_sig_pip")
	assert_eq(TowerUpgrade.check(world, uid).reason, TowerUpgrade.Reason.OK)


func test_sharp_twice() -> void:
	TowerBuilding.add_built(world, world.tower_catalog.type_of("tower_pip"), 4.0, 4.0)
	var base := world.towers.damage[0]
	_apply("perk_sharp")
	_apply("perk_sharp")
	world.step()
	assert_almost_eq(world.towers.damage[0], base * 1.2, 1e-4)


func test_bounty_floors_per_kill_before_mark_gold() -> void:
	assert_eq(_kill_gold("enemy_swarmer_01"), 2)
	_apply("perk_bounty")
	world.step()
	assert_almost_eq(world.kill_gold_mult, 1.2, 1e-6)
	assert_eq(_kill_gold("enemy_swarmer_01"), 2, "2 x 1.2 floors to 2")
	assert_eq(_kill_gold("enemy_brute_01"), 7, "6 x 1.2 = 7.2")
	assert_eq(_kill_gold("enemy_swarmer_01", 3), 5, "mark gold added after the floor")


func test_masonry() -> void:
	TowerBuilding.add_built(world, world.tower_catalog.type_of("tower_pip"), 4.0, 4.0)
	var hp := world.towers.max_hp[0]
	_apply("perk_masonry")
	world.step()
	assert_almost_eq(world.towers.max_hp[0], hp * 1.3, 1e-3)
	assert_true(_store_has("rebuild_price", "run"), "stored for 045")


func test_skill_and_run_stats_land_in_the_store() -> void:
	for id: String in ["perk_expand", "perk_maze", "card_skill_sig_quick", "card_skill_shield_plus", "perk_study"]:
		_apply(id)
	assert_true(_store_has("build_radius", "run"))
	assert_true(_store_has("detour_damage", "all_towers"))
	assert_true(_store_has("skill_cooldown", "signature"))
	assert_true(_store_has("shield_absorb", "skill:skill_shield"))
	world.step()
	assert_almost_eq(world.xp_mult, 1.15, 1e-6)
