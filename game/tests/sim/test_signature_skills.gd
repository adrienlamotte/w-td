extends GutTest
## Guardians from StartRun, the signature skill kinds and the skill modifiers (D-146).

const GUARDIANS := ["guardian_cinder", "guardian_bastia", "guardian_clover", "guardian_hymn",
	"guardian_tansy", "guardian_poppy"]
const SHIELD := "skill_shield"
const SWARMER := "enemy_swarmer_01"
const BRUTE := "enemy_brute_01"
const MINIBOSS := "enemy_miniboss_01"
const SINGLE := "tower_single_01"
const M := SimModifiers.Op.MULT
const A := SimModifiers.Op.ADD

var world: SimWorld
var sw: int


func _start(guardian_id: String) -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2", guardian_id))
	world.step()
	world.run.first_wave_tick = 1 << 30  # no spawns: these tests place their own enemies
	world.run.final_boss_tick = -1
	world.run.boss_ticks = PackedInt32Array()
	world.gold = 1 << 30
	sw = world.catalog.type_of(SWARMER)


func _events_of(kind: SimEvents.Kind) -> Array[int]:
	var out: Array[int] = []
	for e in world.events.count:
		if world.events.kind[e] == kind:
			out.append(e)
	return out


func _use(skill_id: String) -> bool:
	world.queue(SimCommand.use_skill(world.tick, skill_id))
	world.step()
	return _events_of(SimEvents.Kind.SKILL_USED).size() == 1


func _sig() -> String:
	return world.run.skill_ids[world.run.signature_slot]


func _built(x: float, z: float, id := SINGLE) -> int:
	var u := TowerBuilding.add_built(world, world.tower_catalog.type_of(id), x, z)
	return world.towers.uid.find(u)


func _step_until(clock: int) -> void:
	while world.clock < clock:
		world.step()


func test_start_run_guardian() -> void:
	for gid: String in GUARDIANS:
		_start(gid)
		var g := DataFiles.read_id("res://data/guardians", gid)
		assert_eq(Array(world.run.skill_ids), g.skills, gid)
		assert_eq(world.run.signature_slot, 0, gid)
		assert_eq(world.guardian_hp, float(g.hp), gid)
		assert_eq(world.guardian_max_hp, float(g.hp), gid)
	_start("")
	assert_eq(Array(world.run.skill_ids), ["skill_area_blast", SHIELD], "empty id: the run file's Guardian")


func test_big_finish() -> void:
	_start("guardian_cinder")
	var br := world.catalog.type_of(BRUTE)
	var r := world.catalog.radius[br]
	world.enemies.add(br, 6.0 + r - 0.05, 0.0, 100.0)
	world.enemies.add(br, -(6.0 + r + 0.05), 0.0, 100.0)
	assert_true(_use(_sig()))
	var hits := _events_of(SimEvents.Kind.ENEMY_HIT)
	assert_eq(hits.size(), 1)
	assert_eq(world.events.value[hits[0]], 40.0)


func test_stand_firm() -> void:
	_start("guardian_bastia")
	world.guardian_hp = 1000.0
	var t := _built(4.0, 0.0)
	var thp := world.towers.hp[t]
	assert_true(_use(_sig()))
	world.damage_tower(t, 10.0)
	assert_eq(world.towers.hp[t], thp - 5.0, "tower damage halved")
	world._hit_guardian(sw, 1.0, 0.0, 10.0)
	assert_eq(world.guardian_hp, 995.0, "Guardian damage halved")
	assert_eq(world.events.value[_events_of(SimEvents.Kind.GUARDIAN_HIT)[-1]], 5.0)
	assert_true(_use(SHIELD))
	world._hit_guardian(sw, 1.0, 0.0, 120.0)  # guard first (60), then the Shield absorbs 50
	assert_eq(world.guardian_hp, 985.0)
	_step_until(world.skills.guard_until)
	world.skills.shield_until = 0
	world._hit_guardian(sw, 1.0, 0.0, 10.0)
	assert_eq(world.guardian_hp, 975.0, "expired")


func test_clearance_sale() -> void:
	_start("guardian_clover")
	world.catalog.gold[sw] = 1
	world.catalog.gold_chance[sw] = 1.0
	world.enemies.add(sw, 20.0, 0.0, 0.0)  # a corpse, removed in DEATHS
	assert_true(_use(_sig()))
	assert_eq(world.events.value[_events_of(SimEvents.Kind.ENEMY_DIED)[0]], 5.0, "1 + 4 inside the window")
	_step_until(world.skills.bounty_until)
	world.enemies.add(sw, 20.0, 0.0, 0.0)
	world.step()
	assert_eq(world.events.value[_events_of(SimEvents.Kind.ENEMY_DIED)[0]], 1.0, "expired")


# Steps until tower t fires; returns its cooldown right after the shot.
func _next_shot_cooldown(t: int) -> int:
	for n in 600:
		world.step()
		if _events_of(SimEvents.Kind.TOWER_FIRED).size() > 0:
			return world.towers.cooldown[t]
	fail_test("no shot")
	return -1


func test_crescendo() -> void:
	_start("guardian_hymn")
	world.guardian_hp = 1e9
	var t := _built(3.0, 0.0)
	world.enemies.add(sw, 3.0, 2.0, 1e6)
	var reload := world.towers.reload[t]
	assert_eq(_next_shot_cooldown(t), reload)
	assert_true(_use(_sig()))
	assert_eq(_next_shot_cooldown(t), maxi(1, roundi(reload * 0.6)))
	_step_until(world.skills.haste_until)
	assert_eq(_next_shot_cooldown(t), reload, "expired")


func test_tangle() -> void:
	_start("guardian_tansy")
	var mb := world.catalog.type_of(MINIBOSS)
	world.enemies.add(sw, 6.0, 0.0, 100.0)
	world.enemies.add(mb, 0.0, 7.0 + world.catalog.radius[mb] - 0.05, 1000.0)  # body touches
	world.enemies.add(sw, -20.0, 0.0, 100.0)
	assert_true(_use(_sig()))
	for i in 2:
		assert_almost_eq(world.enemies.slow_factor[i], 0.15, 1e-6)
		assert_eq(world.enemies.slow_ticks[i], 90 - 1, "3 s, one MOVE phase counted")
	assert_eq(world.enemies.slow_ticks[2], 0, "outside")


func test_emergency_rebuild() -> void:
	_start("guardian_poppy")
	var a := _built(4.0, 0.0)
	var b := _built(-4.0, 0.0, "tower_pip")  # has levels
	world.towers.level[b] = 2
	world.damage_tower(a, 1e9)
	world.damage_tower(b, 1e9)
	world.guardian_hp = world.guardian_max_hp - 100.0
	assert_true(_use(_sig()))
	assert_eq(_events_of(SimEvents.Kind.TOWER_PLACED).size(), 2)
	for t in [a, b]:
		assert_eq(world.towers.husk[t], 0)
		assert_eq(world.towers.hp[t], world.towers.max_hp[t])
		assert_eq(world.build.solid[world.build.cell_of(world.towers.pos_x[t], world.towers.pos_z[t])], 1)
	assert_eq(world.towers.level[b], 2, "level kept")
	assert_eq(world.guardian_hp, world.guardian_max_hp - 60.0)
	world.guardian_hp = world.guardian_max_hp - 10.0
	world.skills.ready_at[0] = 0
	assert_true(_use(_sig()))
	assert_eq(world.guardian_hp, world.guardian_max_hp, "capped")


func test_timed_effects_freeze_while_paused() -> void:
	_start("guardian_bastia")
	assert_true(_use(_sig()))
	var until := world.skills.guard_until
	world.queue(SimCommand.pause(world.tick, true))
	for n in 1000:
		world.step()
	assert_lt(world.clock, until)
	assert_eq(world.guarded(10.0), 5.0, "still guarded")


func test_skill_power() -> void:
	for gid: String in ["guardian_cinder", "guardian_clover", "guardian_tansy"]:
		_start(gid)
		world.add_modifier("skill_power", M, 0.5, "signature")
		world.enemies.add(sw, 2.0, 0.0, 1000.0)
		assert_true(_use(_sig()))
		if gid == "guardian_cinder":
			assert_eq(world.events.value[_events_of(SimEvents.Kind.ENEMY_HIT)[0]], 60.0)
		elif gid == "guardian_clover":
			assert_eq(world.skills.bounty_gold, 6, "4 x 1.5")
		else:
			assert_eq(world.enemies.slow_ticks[0], 135 - 1, "4.5 s")
		assert_true(_use(SHIELD))
		assert_eq(world.skills.shield_left, 50.0, "the Shield is not powered")
		assert_eq(world.skills.shield_until, world.clock - 1 + 150)


func test_skill_cooldown() -> void:
	_start("guardian_cinder")
	world.add_modifier("skill_cooldown", M, -0.25, "signature")
	world.add_modifier("skill_cooldown", M, -0.1, "guardian")
	var c := world.clock
	assert_true(_use(_sig()))
	assert_true(_use(SHIELD))
	assert_eq(world.skills.ready_at[0], c + roundi(420 * 0.65))
	assert_eq(world.skills.ready_at[1], c + 1 + roundi(750 * 0.9))
	world.add_modifier("skill_cooldown", M, -0.5, "skill:skill_big_finish")
	assert_eq(SignatureSkills.cooldown_ticks(world, 0), 210, "clamped at 50%")


func test_shield_plus_and_mending() -> void:
	_start("guardian_cinder")
	world.add_modifier("shield_absorb", M, 1.0, "skill:skill_shield")
	world.add_modifier("shield_duration", A, 2.0, "skill:skill_shield")
	world.add_modifier("shield_heal", A, 40.0, "guardian")
	world.guardian_hp = world.guardian_max_hp - 100.0
	assert_true(_use(SHIELD))
	assert_eq(world.skills.shield_left, 100.0)
	assert_eq(world.skills.shield_until, world.clock - 1 + 210, "7 s")
	assert_eq(world.guardian_hp, world.guardian_max_hp - 60.0, "Mending")
	world.guardian_hp = world.guardian_max_hp - 10.0
	world.skills.ready_at[1] = 0
	assert_true(_use(SHIELD))
	assert_eq(world.guardian_hp, world.guardian_max_hp, "capped")


func test_guardian_max_hp() -> void:
	_start("guardian_cinder")
	world.guardian_hp = 300.0
	world.add_modifier("hp", M, 0.1, "guardian")
	world.add_modifier("hp", A, 1000.0, "all_towers")  # not hers
	world.step()
	assert_almost_eq(world.guardian_max_hp, 440.0, 1e-3)
	assert_almost_eq(world.guardian_hp, 340.0, 1e-3, "the rise is added")
	world.add_modifier("hp", M, -0.5, "guardian")
	world.guardian_hp = 300.0
	world.step()
	assert_almost_eq(world.guardian_max_hp, 240.0, 1e-3)
	assert_almost_eq(world.guardian_hp, 240.0, 1e-3, "a fall clamps")

