extends GutTest
## Damage, deaths, gold, enemy attacks, win and lose (D-107).

const SWARMER := "enemy_swarmer_01"  # catalog sorted by id: type 0 is not the swarmer
const RANGED := "enemy_ranged_01"
const MINIBOSS := "enemy_miniboss_01"

var world: SimWorld
var sw: int


func before_each() -> void:
	world = SimWorld.new(1)
	sw = world.catalog.type_of(SWARMER)


func _start_run() -> void:
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()  # the first wave spawn is ~44 ticks away


func _stop(t: int) -> float:
	return world.run.guardian_contact_radius + world.catalog.radius[t] + world.catalog.attack_range[t]


func _events_of(kind: SimEvents.Kind) -> Array[int]:
	var out: Array[int] = []
	for e in world.events.count:
		if world.events.kind[e] == kind:
			out.append(e)
	return out


func test_damage_lowers_hp_and_pushes_hit() -> void:
	world.enemies.add(sw, 10.0, 3.0, 8.0)
	world.damage_enemy(0, 5.0)
	assert_eq(world.enemies.hp[0], 3.0)
	assert_eq(world.events.count, 1)
	assert_eq(world.events.kind[0], SimEvents.Kind.ENEMY_HIT)
	assert_eq(world.events.a[0], sw)
	assert_eq(world.events.x[0], 10.0)
	assert_eq(world.events.z[0], 3.0)
	assert_eq(world.events.value[0], 5.0)


func test_hit_on_corpse_does_nothing() -> void:
	world.enemies.add(sw, 10.0, 0.0, 8.0)
	world.damage_enemy(0, 8.0)
	world.damage_enemy(0, 3.0)
	assert_eq(world.enemies.hp[0], 0.0)
	assert_eq(world.events.count, 1)


func test_corpse_removed_next_step_with_gold() -> void:
	_start_run()
	assert_eq(world.gold, world.run.starting_gold)
	var mb := world.catalog.type_of(MINIBOSS)
	world.enemies.add(mb, 20.0, 0.0, 1.0)
	world.damage_enemy(0, 5.0)
	assert_eq(world.enemies.count(), 1)  # a corpse stays until the next DEATHS phase
	world.step()
	assert_eq(world.enemies.count(), 0)
	var died := _events_of(SimEvents.Kind.ENEMY_DIED)
	assert_eq(died.size(), 1)
	assert_eq(world.events.a[died[0]], mb)
	assert_eq(world.events.value[died[0]], float(world.catalog.gold[mb]))
	assert_eq(world.gold, world.run.starting_gold + world.catalog.gold[mb])
	assert_eq(world.run_state, SimWorld.RunState.RUNNING)  # a mini-boss never wins
	assert_eq(_events_of(SimEvents.Kind.RUN_ENDED).size(), 0)


func test_two_deaths_keep_survivors() -> void:
	for k in 5:
		world.enemies.add(sw, 20.0 + 5.0 * k, 0.0, 8.0)
	world.damage_enemy(1, 8.0)
	world.damage_enemy(3, 8.0)
	world.step()
	assert_eq(world.enemies.count(), 3)
	var xs := Array(world.enemies.pos_x)
	xs.sort()
	var d := world.catalog.speed[sw] * SimWorld.SIM_DT
	for k in 3:
		assert_almost_eq(xs[k], 20.0 + 10.0 * k - d, 1e-4)
	assert_eq(_events_of(SimEvents.Kind.ENEMY_DIED).size(), 2)


func test_melee_hits_on_arrival_then_every_cooldown() -> void:
	_start_run()
	world.enemies.add(sw, _stop(sw), 0.0, 8.0)
	var hits: Array[int] = []
	for t in 70:
		world.step()
		for e in _events_of(SimEvents.Kind.GUARDIAN_HIT):
			hits.append(t)
			assert_eq(world.events.a[e], sw)
			assert_eq(world.events.value[e], world.catalog.damage[sw])
	var cd := world.catalog.attack_cooldown[sw]
	assert_eq(hits, [0, cd, 2 * cd] as Array[int])
	assert_eq(world.guardian_hp, world.run.guardian_hp - 3.0 * world.catalog.damage[sw])


func test_ranged_hits_from_range() -> void:
	_start_run()
	var rg := world.catalog.type_of(RANGED)
	world.enemies.add(rg, 0.0, _stop(rg), 12.0)
	world.step()
	var hit := _events_of(SimEvents.Kind.GUARDIAN_HIT)
	assert_eq(hit.size(), 1)
	assert_eq(world.events.value[hit[0]], world.catalog.damage[rg])


func test_idle_enemies_never_hit() -> void:
	world.enemies.add(sw, world.catalog.radius[sw], 0.0, 8.0)
	for t in 60:
		world.step()
		assert_eq(_events_of(SimEvents.Kind.GUARDIAN_HIT).size(), 0)


func test_lose_freezes_world() -> void:
	_start_run()
	world.guardian_hp = 1.0
	world.enemies.add(sw, _stop(sw), 0.0, 8.0)
	world.enemies.add(sw, 20.0, 0.0, 8.0)
	world.step()
	assert_eq(world.run_state, SimWorld.RunState.LOST)
	var ended := _events_of(SimEvents.Kind.RUN_ENDED)
	assert_eq(ended.size(), 1)
	assert_eq(world.events.a[ended[0]], 0)
	var x := world.enemies.pos_x[1]
	var clock := world.clock
	for t in 10:
		world.step()
		assert_eq(_events_of(SimEvents.Kind.RUN_ENDED).size(), 0)
	assert_eq(world.enemies.pos_x[1], x)
	assert_eq(world.clock, clock)


func test_final_boss_death_wins() -> void:
	_start_run()
	var boss := world.run.final_boss_type
	world.enemies.add(boss, 20.0, 0.0, 10.0)
	world.damage_enemy(0, 10.0)
	world.step()
	assert_eq(world.run_state, SimWorld.RunState.WON)
	var died := _events_of(SimEvents.Kind.ENEMY_DIED)
	var ended := _events_of(SimEvents.Kind.RUN_ENDED)
	assert_eq(died.size(), 1)
	assert_eq(ended.size(), 1)
	assert_gt(ended[0], died[0])
	assert_eq(world.events.a[ended[0]], 1)
	assert_eq(world.events.value[died[0]], 100.0)
	assert_eq(world.gold, world.run.starting_gold + 100)


func _combat_hash(run_seed: int, out_hp: Array) -> int:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	for t in 3000:
		if t % 10 == 0 and w.enemies.count() > 0:
			w.damage_enemy(0, 1.0)  # plan said 5: that kills wave 0 faster than it spawns
		w.step()
	out_hp.append(w.guardian_hp)
	out_hp.append(w.run.guardian_hp)
	return w.state_hash()


func test_determinism_with_combat() -> void:
	var hp := []
	var h := _combat_hash(7, hp)
	assert_lt(hp[0], hp[1])  # enemies reached the Guardian and hit her
	assert_eq(_combat_hash(7, []), h)
	assert_ne(_combat_hash(8, []), h)


func test_combat_phase_cost_3000_piled() -> void:
	_start_run()
	world.guardian_hp = 1e9
	world.spawn_ring(sw, 3000, 10.0)
	for n in 150:  # pile up at the Guardian
		world.step()
	var sums := {SimWorld.Phase.MOVE: 0, SimWorld.Phase.DEATHS: 0, SimWorld.Phase.ATTACKS: 0}
	var ticks := 30
	for n in ticks:
		world.step()
		for p: int in sums:
			sums[p] += world.phase_usec[p]
	gut.p("3000 piled, ms/tick: move %.2f, deaths %.2f, attacks %.2f" % [
		sums[SimWorld.Phase.MOVE] / 1000.0 / ticks, sums[SimWorld.Phase.DEATHS] / 1000.0 / ticks,
		sums[SimWorld.Phase.ATTACKS] / 1000.0 / ticks])
	assert_eq(world.run_state, SimWorld.RunState.RUNNING)


func test_damage_sets_hit_tick_but_not_on_a_corpse() -> void:
	world.enemies.add(sw, 10.0, 0.0, 8.0)
	world.tick = 5
	world.damage_enemy(0, 8.0)
	assert_eq(world.enemies.hit_tick[0], 5)
	world.tick = 6
	world.damage_enemy(0, 1.0)
	assert_eq(world.enemies.hit_tick[0], 5, "corpse hit ignored")
