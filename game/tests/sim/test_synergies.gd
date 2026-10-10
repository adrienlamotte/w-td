extends GutTest
## Relationship synergies (10_M3_CONTENT.md 5, D-150): windows, no stacking, re-evaluation,
## the Guardian as a partner and her layout entries in the modifier store.

const M := SimModifiers.Op.MULT

var world: SimWorld


func _start(guardian_id := "") -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2", guardian_id))
	world.step()
	world.run.first_wave_tick = 1 << 30  # no spawns
	world.run.final_boss_tick = -1
	world.run.boss_ticks = PackedInt32Array()
	world.gold = 1 << 30


func before_each() -> void:
	_start()


func _built(id: String, x: float, z: float) -> int:
	var u := TowerBuilding.add_built(world, world.tower_catalog.type_of(id), x, z)
	assert_gt(u, -1, "placed %s at %s, %s" % [id, x, z])
	return u


# Tower index of a uid after the last step.
func _t(u: int) -> int:
	return world.towers.uid.find(u)


func _active(u: int, rule: String) -> bool:
	return world.towers.syn_mask[_t(u)] & (1 << Array(world.synergies.rule_ids).find(rule)) != 0


func _guardian_entries() -> Array:
	var out := []
	var m := world.modifiers
	for e in m.stat.size():
		if m.layout[e]:
			out.append([m.stat[e], m.op[e], snappedf(m.value[e], 0.001), m.target[e]])
	return out


func test_catalog() -> void:
	var syn := world.synergies
	assert_eq(syn.rule_ids.size(), 7, "the 7 M3 rules; M5 rival rows have no waifu file")
	assert_eq(TowerStats.MODDED.size(), 10, "TowerLinks._N")
	assert_eq(syn.waifu_of_tower[world.tower_catalog.type_of("tower_single_01")], -1)
	assert_eq(syn.waifu_of_guardian("guardian_placeholder_01"), -1)
	assert_gt(syn.waifu_of_guardian("guardian_cinder"), -1)


# Each 5.2 row: [a, b, a stat, a expected, b stat, b expected], pair 2.0 apart.
func test_each_row_both_sides() -> void:
	var rows := [
		["tower_pip", "tower_mallow", "damage", 7.2, "slow_ticks", 90.0],
		["tower_bastia", "tower_pip", "max_hp", 520.0, "damage", 7.5],
		["tower_bastia", "tower_clover", "thorns", 6.0, "mark_gold", 3.0],
		["tower_hymn", "tower_poppy", "reach", 4.0, "heal", 30.0],
		["tower_hymn", "tower_tansy", "reach", 4.0, "slow_ticks", 90.0],
		["tower_cinder", "tower_tansy", "attack_range", 6.0, "reload", 36.0],
	]
	for row: Array in rows:
		_start()
		var a := _built(row[0], 5.0, 0.0)
		var b := _built(row[1], 7.0, 0.0)
		world.step()
		var ta: Variant = world.towers.get(row[2])
		var tb: Variant = world.towers.get(row[4])
		assert_almost_eq(float(ta[_t(a)]), float(row[3]), 0.001, "%s %s" % [row[0], row[2]])
		assert_almost_eq(float(tb[_t(b)]), float(row[5]), 0.001, "%s %s" % [row[1], row[4]])
	# Rivals at 4.0: Mallow reload x0.8 (30 -> 24), Cinder damage x1.25.
	_start()
	var m := _built("tower_mallow", 4.0, 0.0)
	var c := _built("tower_cinder", 8.0, 0.0)
	world.step()
	assert_eq(world.towers.reload[_t(m)], 24)
	assert_almost_eq(world.towers.damage[_t(c)], 3.75, 0.001)


func test_window_edges() -> void:
	# [a, b, distance, active, rule], each pair in a fresh run.
	var cases := [
		["tower_pip", "tower_mallow", 2.5, true, "syn_bff_pip_mallow"],
		["tower_pip", "tower_mallow", 3.0, false, "syn_bff_pip_mallow"],
		["tower_mallow", "tower_cinder", 1.5, false, "syn_rivals_mallow_cinder"],
		["tower_mallow", "tower_cinder", 2.0, true, "syn_rivals_mallow_cinder"],
		["tower_mallow", "tower_cinder", 6.0, true, "syn_rivals_mallow_cinder"],
		["tower_mallow", "tower_cinder", 6.5, false, "syn_rivals_mallow_cinder"],
	]
	for k in cases.size():
		var cs: Array = cases[k]
		_start()
		var a := _built(cs[0], 3.0, 0.0)
		var b := _built(cs[1], 3.0 + cs[2], 0.0)
		world.step()
		assert_eq(_active(a, cs[4]), cs[3], "%s at %s" % [cs[4], cs[2]])
		assert_eq(_active(b, cs[4]), cs[3], "both sides at %s" % cs[2])


func test_no_stacking_per_partner_rules_add_up() -> void:
	var p := _built("tower_pip", 5.0, 5.0)
	_built("tower_mallow", 3.0, 5.0)
	_built("tower_mallow", 7.0, 5.0)
	world.step()
	assert_almost_eq(world.towers.damage[_t(p)], 7.2, 0.001, "two Mallows: x1.2 once")
	_built("tower_bastia", 5.0, 7.0)
	world.step()
	assert_almost_eq(world.towers.damage[_t(p)], 6.0 * 1.45, 0.001, "Mallow and Bastia rules add up")


func test_husk_bare_sell_rebuild_upgrade_reevaluate() -> void:
	var p := _built("tower_pip", 5.0, 5.0)
	world.towers.add(6.0, 5.0, 0.0)  # bare tower: never a partner
	var m := _built("tower_mallow", 7.0, 5.0)
	world.step()
	assert_almost_eq(world.towers.damage[_t(p)], 7.2, 0.001)
	world.damage_tower(_t(m), 1e9)
	world.step()
	assert_eq(world.towers.husk[_t(m)], 1)
	assert_almost_eq(world.towers.damage[_t(p)], 6.0, 0.001, "a husk is no partner")
	world.queue(SimCommand.rebuild_tower(world.tick, m))
	world.step()
	assert_almost_eq(world.towers.damage[_t(p)], 7.2, 0.001, "rebuilt")
	world.queue(SimCommand.sell_tower(world.tick, m))
	world.step()
	assert_almost_eq(world.towers.damage[_t(p)], 6.0, 0.001, "sold")
	# Upgrade: Bastia max HP x1.3 follows her level, HP gains the difference (D-144).
	var b := _built("tower_bastia", 5.0, 3.0)
	world.step()
	assert_almost_eq(world.towers.max_hp[_t(b)], 520.0, 0.001)
	world.towers.hp[_t(b)] = 500.0
	world.queue(SimCommand.upgrade_tower(world.tick, b))
	world.step()
	assert_almost_eq(world.towers.max_hp[_t(b)], 780.0, 0.001)
	assert_almost_eq(world.towers.hp[_t(b)], 760.0, 0.001)
	world.queue(SimCommand.upgrade_tower(world.tick, p))
	world.step()
	assert_almost_eq(world.towers.damage[_t(p)], 10.0, 0.001, "Pip L2 damage 8 x1.25")


func test_guardian_partner_and_layout_entries() -> void:
	_start("guardian_cinder")
	var m1 := _built("tower_mallow", 4.0, 0.0)  # 3 from her edge (contact 1)
	world.add_modifier("skill_power", M, 0.1, "guardian")  # a card entry
	world.step()
	assert_eq(world.towers.reload[_t(m1)], 24, "rivals with the Guardian: Mallow x0.8")
	assert_eq(_guardian_entries(), [["skill_power", M, 0.25, "guardian"]])
	assert_ne(world.guardian_syn_mask, 0)
	var m2 := _built("tower_mallow", 0.0, 4.0)
	world.step()
	assert_eq(_guardian_entries().size(), 1, "once per relationship")
	assert_almost_eq(world.modifiers.skill_sums("skill_power", "skill_big_finish", true).y, 0.35, 0.001)
	world.queue(SimCommand.sell_tower(world.tick, m1))
	world.queue(SimCommand.sell_tower(world.tick, m2))
	world.step()
	assert_eq(_guardian_entries(), [])
	assert_eq(world.guardian_syn_mask, 0)
	assert_eq(world.modifiers.stat.size(), 1, "the card entry survives")
	# Too close to her edge (1.5): no rivals.
	var m3 := _built("tower_mallow", 2.5, 0.0)
	world.step()
	assert_eq(world.towers.reload[_t(m3)], 30)


func test_m2_towers_unchanged() -> void:
	var ids := ["tower_single_01", "tower_slow_01", "tower_splash_01"]
	var us: Array[int] = []
	for k in ids.size():
		us.append(_built(ids[k], 4.0 + k, 4.0))
	world.step()
	assert_true(world.links.extra.is_empty(), "no waifu tower: the link pass is skipped")
	for k in ids.size():
		var t := _t(us[k])
		var type := world.towers.type_id[t]
		var cat := world.tower_catalog
		assert_eq(world.towers.damage[t], cat.damage[type])
		assert_eq(world.towers.reload[t], cat.cooldown[type])
		assert_eq(world.towers.attack_range[t], cat.attack_range[type])
		assert_eq(world.towers.slow_ticks[t], cat.slow_ticks[type])
		assert_eq(world.towers.syn_mask[t], 0)


# A guard against a quadratic pass (D-150 rule 9): 300 mixed waifu towers, touching.
func test_recompute_300_towers_time() -> void:
	var ids := ["tower_pip", "tower_mallow", "tower_cinder", "tower_bastia", "tower_clover",
			"tower_hymn", "tower_tansy", "tower_poppy"]
	var n := 0
	for gz in range(-9, 10):
		for gx in range(-9, 10):
			if n == 300 or (absi(gx) < 2 and absi(gz) < 2):
				continue
			_built(ids[n % ids.size()], gx, gz)
			n += 1
	assert_eq(world.towers.count(), 300)
	world.step()
	var t0 := Time.get_ticks_usec()
	TowerStats.recompute(world)
	var usec := Time.get_ticks_usec() - t0
	gut.p("recompute of 300 towers: %d usec" % usec)
	assert_lt(usec, 30000)
