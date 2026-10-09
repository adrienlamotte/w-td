extends GutTest
## Guardian skills: Area blast, Shield, cooldowns (D-110).

const SWARMER := "enemy_swarmer_01"
const BRUTE := "enemy_brute_01"
const MINIBOSS := "enemy_miniboss_01"
const BLAST := "skill_area_blast"
const SHIELD := "skill_shield"

var world: SimWorld
var sw: int


func before_each() -> void:
	world = SimWorld.new(1)
	sw = world.catalog.type_of(SWARMER)


func _start_run() -> void:
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()  # the first wave spawn is ~44 ticks away


func _events_of(kind: SimEvents.Kind) -> Array[int]:
	var out: Array[int] = []
	for e in world.events.count:
		if world.events.kind[e] == kind:
			out.append(e)
	return out


## Queues the skill for this tick and steps; true if SKILL_USED was pushed.
func _use(skill_id: String) -> bool:
	world.queue(SimCommand.use_skill(world.tick, skill_id))
	world.step()
	return _events_of(SimEvents.Kind.SKILL_USED).size() == 1


func _slot(skill_id: String) -> int:
	return world.run.skill_ids.find(skill_id)


func test_blast_hits_bodies_touching_the_disk() -> void:
	_start_run()
	var s := _slot(BLAST)
	var reach := world.run.skill_radius[s]
	var dmg := world.run.skill_damage[s]
	var br := world.catalog.type_of(BRUTE)
	var mb := world.catalog.type_of(MINIBOSS)
	var r_br := world.catalog.radius[br]
	var r_mb := world.catalog.radius[mb]
	world.enemies.add(br, reach + r_br - 0.05, 0.0, 100.0)  # edge just inside
	world.enemies.add(br, -(reach + r_br + 0.05), 0.0, 100.0)  # edge just outside
	world.enemies.add(mb, 0.0, reach + r_mb - 0.05, 1000.0)  # centre outside, body touches
	world.enemies.add(br, 0.0, -2.0, 0.0)  # corpse
	assert_gt(reach + r_mb - 0.05, reach)
	assert_true(_use(BLAST))
	var used := _events_of(SimEvents.Kind.SKILL_USED)
	assert_eq(world.events.a[used[0]], s)
	var hits := _events_of(SimEvents.Kind.ENEMY_HIT)
	assert_eq(hits.size(), 2)
	assert_gt(hits[0], used[0], "SKILL_USED before the hits")
	for e in hits:
		assert_eq(world.events.value[e], dmg)
	# The corpse was removed in DEATHS; survivors keep their order shifted by the swap-remove.
	var hp := Array(world.enemies.hp)
	hp.sort()
	assert_eq(hp, [100.0 - dmg, 100.0, 1000.0 - dmg])


func test_blast_kill_drops_gold() -> void:
	_start_run()
	world.enemies.add(sw, 2.0, 0.0, 5.0)
	var gold := world.gold
	assert_true(_use(BLAST))  # COMMANDS phase; the DEATHS phase of the same step removes it
	assert_eq(world.enemies.count(), 0)
	var died := _events_of(SimEvents.Kind.ENEMY_DIED)
	assert_eq(died.size(), 1)
	assert_eq(world.gold, gold + int(world.events.value[died[0]]))


func test_cooldown() -> void:
	_start_run()
	var s := _slot(BLAST)
	world.enemies.add(world.catalog.type_of(BRUTE), 30.0, 0.0, 100.0)
	world.run.skill_radius[s] = 100.0  # reach the far brute
	var dmg := world.run.skill_damage[s]
	var used_clock := world.clock
	assert_true(_use(BLAST))
	assert_eq(world.skills.ready_at[s], used_clock + world.run.skill_cooldown[s])
	assert_false(_use(BLAST), "on cooldown")
	assert_eq(world.events.count, 0, "rejected: no event")
	assert_eq(world.enemies.hp[0], 100.0 - dmg)
	while world.clock < world.skills.ready_at[s]:
		world.step()
	assert_true(_use(BLAST), "ready at exactly ready_at")
	assert_eq(world.enemies.hp[0], 100.0 - 2.0 * dmg)


func test_pause_blocks_and_freezes_cooldown() -> void:
	_start_run()
	var s := _slot(BLAST)
	assert_true(_use(BLAST))
	var ready := world.skills.ready_at[s]
	world.queue(SimCommand.pause(world.tick, true))
	world.step()
	var clock := world.clock
	for t in 400:
		world.step()
	assert_eq(world.clock, clock)
	assert_false(_use(SHIELD), "no skill while paused")
	assert_eq(world.skills.ready_at[s], ready)
	world.queue(SimCommand.pause(world.tick, false))
	world.step()
	assert_false(_use(BLAST), "cooldown did not advance while paused")


func test_ignored_outside_a_run_and_unknown_id() -> void:
	assert_false(_use(BLAST), "before StartRun")
	_start_run()
	assert_false(_use("skill_nope"))
	world.guardian_hp = 1.0
	world.enemies.add(sw, world.run.guardian_contact_radius + world.catalog.radius[sw], 0.0, 8.0)
	world.step()
	assert_eq(world.run_state, SimWorld.RunState.LOST)
	assert_false(_use(BLAST), "after LOST")


func test_shield_absorbs_attacker_hits() -> void:
	_start_run()
	var s := _slot(SHIELD)
	var absorb := world.run.skill_absorb[s]
	var mb := world.catalog.type_of(MINIBOSS)
	var stop := world.run.guardian_contact_radius + world.catalog.radius[mb] + world.catalog.attack_range[mb]
	world.enemies.add(mb, stop, 0.0, 1000.0)
	var hp := world.guardian_hp
	assert_true(_use(SHIELD))  # the miniboss hits on arrival in this same step
	var hit := _events_of(SimEvents.Kind.GUARDIAN_HIT)
	assert_eq(hit.size(), 1)
	assert_eq(world.events.value[hit[0]], 0.0)
	assert_eq(world.guardian_hp, hp)
	assert_eq(world.skills.shield_left, absorb - world.catalog.damage[mb])
	world.skills.shield_left = 4.0
	hit = []
	while hit.is_empty():
		world.step()
		hit = _events_of(SimEvents.Kind.GUARDIAN_HIT)
	assert_eq(world.events.value[hit[0]], world.catalog.damage[mb] - 4.0, "remainder goes through")
	assert_eq(world.guardian_hp, hp - (world.catalog.damage[mb] - 4.0))


func test_shield_can_still_lose_when_used_up() -> void:
	_start_run()
	assert_true(_use(SHIELD))
	world.skills.shield_left = 0.0
	world.guardian_hp = 5.0
	world._hit_guardian(sw, 1.0, 0.0, 10.0)
	assert_eq(world.run_state, SimWorld.RunState.LOST)


func test_shield_duration_and_recast() -> void:
	var run := RunData.load_id("run_m2", world.catalog, world.tower_catalog)
	var s := run.skill_ids.find(SHIELD)
	var absorb := run.skill_absorb[s]
	var dur := run.skill_duration[s]
	var cd := run.skill_cooldown[s]
	var gs := GuardianSkills.new()
	gs.reset(run.skill_ids.size())
	assert_true(gs.try_use(s, 10, run))
	assert_eq(gs.absorb(3.0, 10), 0.0)
	assert_eq(gs.absorb(3.0, 10 + dur - 1), 0.0, "last shielded tick")
	assert_eq(gs.absorb(3.0, 10 + dur), 3.0, "expired with absorb left")
	assert_false(gs.try_use(s, 10 + cd - 1, run))
	assert_true(gs.try_use(s, 10 + cd, run))
	assert_eq(gs.shield_left, absorb, "recast refills, does not stack")


func _skill_hash(run_seed: int) -> int:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	for t in [100, 500, 900, 1300, 2000]:
		w.queue(SimCommand.use_skill(t, BLAST))
	for t in [300, 1200, 2500]:
		w.queue(SimCommand.use_skill(t, SHIELD))
	for t in 3000:
		w.step()
	return w.state_hash()


func test_determinism_with_skills() -> void:
	var h := _skill_hash(7)
	assert_eq(_skill_hash(7), h)
	assert_ne(_skill_hash(8), h)
