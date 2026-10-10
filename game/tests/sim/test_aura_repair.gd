extends GutTest
## Hymn's aura and Poppy's repair (10_M3_CONTENT.md 3.1, D-135, D-150).

const M := SimModifiers.Op.MULT
const A := SimModifiers.Op.ADD
const SWARMER := "enemy_swarmer_01"

var world: SimWorld


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.run.first_wave_tick = 1 << 30  # no spawns
	world.run.final_boss_tick = -1
	world.run.boss_ticks = PackedInt32Array()
	world.gold = 1 << 30


func _built(id: String, x: float, z: float) -> int:
	var u := TowerBuilding.add_built(world, world.tower_catalog.type_of(id), x, z)
	assert_gt(u, -1)
	return u


func _t(u: int) -> int:
	return world.towers.uid.find(u)


func _set_level(u: int, level: int) -> void:
	world.towers.level[_t(u)] = level
	world.towers.stats_dirty = true


# [a, value] of the TOWER_REPAIRED events of the last step.
func _repairs() -> Array:
	var out := []
	var ev := world.events
	for e in ev.count:
		if ev.kind[e] == SimEvents.Kind.TOWER_REPAIRED:
			out.append([ev.a[e], ev.value[e]])
	return out


func test_hymn_never_targets_or_fires() -> void:
	var h := _built("tower_hymn", 5.0, 0.0)
	world.enemies.add(world.catalog.type_of(SWARMER), 6.0, 0.0, 1000.0)
	for n in 30:
		world.step()
		assert_eq(world.towers.target[_t(h)], -1)
		for e in world.events.count:
			assert_ne(world.events.kind[e], SimEvents.Kind.TOWER_FIRED)


func test_aura_reach() -> void:
	_built("tower_hymn", 5.0, 5.0)
	var near := _built("tower_pip", 5.0, 8.0)
	var far := _built("tower_pip", 8.5, 5.0)
	world.step()
	assert_almost_eq(world.towers.damage[_t(near)], 7.2, 0.001, "at 3.0: damage x1.2")
	assert_eq(world.towers.reload[_t(near)], TowerStats.reload_ticks(0.5, Vector2(0.0, -0.1)))
	assert_lt(world.towers.reload[_t(near)], 15)
	assert_almost_eq(world.towers.damage[_t(far)], 6.0, 0.001, "at 3.5: none")
	assert_eq(world.towers.reload[_t(far)], 15)


func test_strongest_hymn_only_plus_cards_and_clamp() -> void:
	_built("tower_hymn", 5.0, 3.0)
	var h4 := _built("tower_hymn", 5.0, 7.0)
	var p := _built("tower_pip", 5.0, 5.0)
	_set_level(h4, 4)
	world.step()
	assert_almost_eq(world.towers.damage[_t(p)], 8.4, 0.001, "only the L4 Hymn: +40%")
	assert_eq(world.towers.reload[_t(p)], TowerStats.reload_ticks(0.5, Vector2(0.0, -0.2)))
	world.add_modifier("damage", M, 0.1, "all_towers")
	world.step()
	assert_almost_eq(world.towers.damage[_t(p)], 6.0 * 1.5, 0.001, "aura and a card add up")
	world.add_modifier("cooldown", M, -0.6, "all_towers")
	world.step()
	assert_eq(world.towers.reload[_t(p)], 8, "clamped at 50% of 15 ticks")


func test_repair_lowest_fraction_on_cooldown() -> void:
	var poppy := _built("tower_poppy", 5.0, 0.0)
	var a := _built("tower_pip", 7.0, 0.0)
	var b := _built("tower_mallow", 5.0, 2.0)
	var husk := _built("tower_pip", 3.0, 0.0)
	var out := _built("tower_pip", 10.0, 0.0)  # 5 away, range 4
	world.towers.hp[_t(a)] = 50.0  # 0.5
	world.towers.hp[_t(b)] = 60.0  # 0.75
	world.towers.hp[_t(out)] = 10.0
	world.damage_tower(_t(husk), 1e9)
	world.step()
	assert_eq(_repairs(), [[a, 20.0]], "lowest fraction in range first")
	assert_eq(world.towers.hp[_t(a)], 70.0)
	for n in DataFiles.ticks(2.0) - 1:
		world.step()
		assert_eq(_repairs(), [], "not between pulses")
	world.step()
	assert_eq(_repairs(), [[a, 20.0]], "70/100 is still below 60/80")
	world.step()
	for n in DataFiles.ticks(2.0) - 1:
		world.step()
	assert_eq(_repairs(), [[b, 20.0]])
	assert_eq(world.towers.hp[_t(husk)], 0.0, "a husk is never healed")
	assert_eq(world.towers.hp[_t(out)], 10.0, "out of range")
	assert_eq(world.towers.cooldown[_t(poppy)], DataFiles.ticks(2.0))


func test_repair_herself_cap_and_signature() -> void:
	var poppy := _built("tower_poppy", 5.0, 0.0)
	world.towers.hp[_t(poppy)] = 70.0
	world.step()
	assert_eq(_repairs(), [[poppy, 10.0]], "she counts herself, capped at max HP")
	_set_level(poppy, 4)
	var a := _built("tower_pip", 7.0, 0.0)
	var b := _built("tower_pip", 5.0, 2.0)
	var c := _built("tower_pip", 3.0, 0.0)
	for n in DataFiles.ticks(2.0) - 1:
		world.step()
	world.towers.hp[_t(a)] = 20.0
	world.towers.hp[_t(b)] = 30.0
	world.towers.hp[_t(c)] = 90.0
	world.step()
	assert_eq(_repairs(), [[a, 40.0], [b, 40.0]], "L4: the two lowest, 40 each")
	assert_eq(world.towers.hp[_t(c)], 90.0)


func test_guardian_fallback() -> void:
	var poppy := _built("tower_poppy", 4.0, 0.0)  # her body edge 3 away, range 4
	var max_hp := world.guardian_max_hp
	world.guardian_hp = max_hp - 50.0
	world.step()
	assert_eq(_repairs(), [[-1, 10.0]])
	assert_eq(world.guardian_hp, max_hp - 40.0)
	world.guardian_hp = max_hp - 5.0
	for n in DataFiles.ticks(2.0):
		world.step()
	assert_eq(_repairs(), [[-1, 5.0]], "capped at her max HP")
	world.queue(SimCommand.sell_tower(world.tick, poppy))
	_built("tower_poppy", 6.5, 0.0)  # edge 5.5 away
	world.guardian_hp = max_hp - 50.0
	world.step()
	world.step()
	assert_eq(_repairs(), [])
	assert_eq(world.guardian_hp, max_hp - 50.0, "out of range: nothing")


func test_empty_pulse_spends_cooldown() -> void:
	var poppy := _built("tower_poppy", 5.0, 0.0)
	world.step()
	assert_eq(_repairs(), [])
	assert_eq(world.towers.cooldown[_t(poppy)], DataFiles.ticks(2.0))
