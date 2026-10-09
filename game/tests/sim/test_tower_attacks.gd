extends GutTest
## Tower attacks: single, splash, slow, cooldown, hold rule (D-114), slow rule (D-117).

const SINGLE := "tower_single_01"
const SPLASH := "tower_splash_01"
const SLOW := "tower_slow_01"
const SWARMER := "enemy_swarmer_01"

var world: SimWorld
var cat: TowerCatalog
var sw: int


func before_each() -> void:
	world = SimWorld.new(1)
	cat = world.tower_catalog
	sw = world.catalog.type_of(SWARMER)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.run.first_wave_tick = 1 << 30  # no wave spawns: the test places every enemy
	world.gold = 100000
	world.guardian_hp = 1e9


func _do(cmd: SimCommand) -> void:
	world.queue(cmd)
	world.step()


func _place(id: String, x: float, z: float) -> void:
	_do(SimCommand.place_tower(world.tick, id, x, z))


func _events_of(kind: SimEvents.Kind) -> Array[int]:
	var out: Array[int] = []
	for e in world.events.count:
		if world.events.kind[e] == kind:
			out.append(e)
	return out


func _in_range(t: int, i: int) -> bool:
	var dx := world.enemies.pos_x[i] - world.towers.pos_x[t]
	var dz := world.enemies.pos_z[i] - world.towers.pos_z[t]
	return dx * dx + dz * dz <= world.towers.attack_range[t] * world.towers.attack_range[t]


func test_single_fires_on_cooldown() -> void:
	var type := cat.type_of(SINGLE)
	_place(SINGLE, 5.0, 0.0)
	world.enemies.add(sw, 9.0, 0.0, 1000.0)
	world.step()
	var fired := _events_of(SimEvents.Kind.TOWER_FIRED)
	assert_eq(fired.size(), 1)
	assert_eq(world.events.a[fired[0]], world.towers.uid[0])
	assert_eq(world.events.x[fired[0]], world.enemies.pos_x[0])
	assert_eq(world.events.z[fired[0]], world.enemies.pos_z[0])
	assert_eq(world.events.value[fired[0]], float(type))
	var hits := _events_of(SimEvents.Kind.ENEMY_HIT)
	assert_eq(hits.size(), 1)
	assert_eq(world.events.value[hits[0]], cat.damage[type])
	assert_eq(world.towers.cooldown[0], cat.cooldown[type])
	var steps := 0
	while steps < 100:
		world.step()
		steps += 1
		if _events_of(SimEvents.Kind.ENEMY_HIT).size() > 0:
			break
	assert_eq(steps, cat.cooldown[type], "next shot exactly cooldown ticks later")
	assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 1)


func test_fires_the_step_an_enemy_enters_range() -> void:
	_place(SINGLE, 5.0, 0.0)
	world.enemies.add(sw, 12.5, 0.0, 1000.0)
	var entered := false
	for n in 40:
		world.step()
		var fired := _events_of(SimEvents.Kind.TOWER_FIRED).size()
		if _in_range(0, 0):
			entered = true
			assert_eq(fired, 1, "shot in the entering step")
			break
		assert_eq(fired, 0)
		assert_eq(world.towers.cooldown[0], 0)
	assert_true(entered)


func test_kill_removes_enemy_next_step_with_gold() -> void:
	_place(SINGLE, 5.0, 0.0)
	world.enemies.add(sw, 9.0, 0.0, cat.damage[cat.type_of(SINGLE)])
	world.step()
	assert_eq(world.enemies.hp[0], 0.0)
	var gold := world.gold
	world.step()
	assert_eq(world.enemies.count(), 0)
	var died := _events_of(SimEvents.Kind.ENEMY_DIED)
	assert_eq(died.size(), 1)
	assert_eq(world.gold, gold + int(world.events.value[died[0]]))


func _assert_no_shot(why: String) -> void:
	world.step()
	assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 0, why)
	assert_eq(_events_of(SimEvents.Kind.ENEMY_HIT).size(), 0, why)


func test_husk_does_not_fire() -> void:
	_place(SINGLE, 5.0, 0.0)
	world.damage_tower(0, 1e9)
	world.enemies.add(sw, 9.0, 0.0, 1000.0)
	_assert_no_shot("husk")


func test_bare_tower_does_not_fire() -> void:
	world.towers.add(5.0, 0.0, 6.0)
	world.enemies.add(sw, 9.0, 0.0, 1000.0)
	_assert_no_shot("bare")
	assert_eq(world.towers.target[0], 0)


func test_idle_world_does_not_fire() -> void:
	world = SimWorld.new(1)
	var t := world.towers.add(5.0, 0.0, 6.0)
	world.towers.type_id[t] = cat.type_of(SINGLE)  # like a placed tower
	world.enemies.add(sw, 9.0, 0.0, 1000.0)
	_assert_no_shot("idle")


func test_paused_does_not_fire() -> void:
	_place(SINGLE, 5.0, 0.0)
	world.enemies.add(sw, 9.0, 0.0, 1000.0)
	_do(SimCommand.pause(world.tick, true))
	assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 0)
	_do(SimCommand.pause(world.tick, false))
	assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 1)


func test_hold_on_target_killed_this_phase() -> void:
	var type := cat.type_of(SINGLE)
	_place(SINGLE, 6.0, 0.0)
	_place(SINGLE, 10.0, 0.0)
	world.enemies.add(sw, 8.0, 0.0, cat.damage[type])  # nearest to both towers
	world.enemies.add(sw, 14.0, 0.0, 1000.0)  # only in range of tower 1
	world.step()
	assert_eq(world.towers.target[1], 0)
	assert_eq(_events_of(SimEvents.Kind.ENEMY_HIT).size(), 1)
	assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 1)
	assert_eq(world.towers.cooldown[1], 0)
	world.step()
	assert_eq(world.enemies.count(), 1)
	var fired := _events_of(SimEvents.Kind.TOWER_FIRED)
	assert_eq(fired.size(), 1)
	assert_eq(world.events.a[fired[0]], world.towers.uid[1])
	assert_eq(world.enemies.hp[0], 1000.0 - cat.damage[type])


func test_splash() -> void:
	var dmg := cat.damage[cat.type_of(SPLASH)]
	_place(SINGLE, 8.0, -4.0)  # tower 0 kills D first: D is a corpse in the splash
	_place(SPLASH, 4.0, 0.0)
	world.enemies.add(sw, 8.0, 0.0, 100.0)  # A: the splash target
	world.enemies.add(sw, 9.2, 0.0, 100.0)  # B: 1.2 from A, outside the splash tower range
	world.enemies.add(sw, 8.0, 1.6, 100.0)  # C: 1.6 from A, outside the splash
	world.enemies.add(sw, 8.0, -1.0, cat.damage[cat.type_of(SINGLE)])  # D
	world.step()
	assert_false(_in_range(1, 1), "B outside the splash tower range")
	assert_eq(world.towers.target[0], 3)
	assert_eq(world.towers.target[1], 0)
	assert_eq(world.enemies.hp[0], 100.0 - dmg)
	assert_eq(world.enemies.hp[1], 100.0 - dmg)
	assert_eq(world.enemies.hp[2], 100.0)
	assert_eq(world.enemies.hp[3], 0.0)
	assert_eq(_events_of(SimEvents.Kind.ENEMY_HIT).size(), 3, "D once, by tower 0")
	assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 2)


func test_slow_hit_duration_and_speed() -> void:
	var type := cat.type_of(SLOW)
	var f := cat.slow_factor[type]
	var n := cat.slow_ticks[type]
	_place(SLOW, 4.0, 0.0)
	world.enemies.add(sw, 8.0, 0.0, 1000.0)
	world.step()  # MOVE at full speed, then the hit
	assert_eq(world.enemies.slow_factor[0], f)
	assert_eq(world.enemies.slow_ticks[0], n)
	assert_eq(world.enemies.hp[0], 1000.0 - cat.damage[type])
	var full := world.catalog.speed[sw] * SimWorld.SIM_DT
	var x := world.enemies.pos_x[0]
	_do(SimCommand.sell_tower(world.tick, world.towers.uid[0]))  # no more hits
	assert_eq(world.towers.count(), 0)
	assert_almost_eq(x - world.enemies.pos_x[0], full * f, 1e-4, "slowed move 0")
	x = world.enemies.pos_x[0]
	for k in range(1, n):
		world.step()
		assert_almost_eq(x - world.enemies.pos_x[0], full * f, 1e-4, "slowed move %d" % k)
		x = world.enemies.pos_x[0]
	assert_eq(world.enemies.slow_ticks[0], 0)
	assert_eq(world.enemies.slow_factor[0], 1.0)
	world.step()
	assert_almost_eq(x - world.enemies.pos_x[0], full, 1e-4, "full speed after the slow")


func test_slow_second_hit_refreshes() -> void:
	var type := cat.type_of(SLOW)
	_place(SLOW, 4.0, 0.0)
	world.enemies.add(sw, 8.0, 0.0, 1000.0)
	world.step()
	for k in cat.cooldown[type]:
		world.step()
	assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 1)
	assert_eq(world.enemies.slow_factor[0], cat.slow_factor[type])
	assert_eq(world.enemies.slow_ticks[0], cat.slow_ticks[type])


func test_apply_slow_rule() -> void:
	var e := SimEnemies.new()
	e.add(sw, 0.0, 0.0, 1.0)
	TowerAttacks.apply_slow(e, 0, 0.5, 60)
	assert_eq([e.slow_factor[0], e.slow_ticks[0]], [0.5, 60])
	TowerAttacks.apply_slow(e, 0, 0.25, 10)  # stronger replaces, keeps the longer duration
	assert_eq([e.slow_factor[0], e.slow_ticks[0]], [0.25, 60])
	TowerAttacks.apply_slow(e, 0, 0.75, 90)  # weaker keeps the factor, extends the duration
	assert_eq([e.slow_factor[0], e.slow_ticks[0]], [0.25, 90])


func _run(run_seed: int, deaths: Array) -> int:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	w.step()
	w.gold = 100000
	w.guardian_hp = 1e9
	w.queue(SimCommand.place_tower(w.tick, SINGLE, 4.0, 0.0))
	w.queue(SimCommand.place_tower(w.tick, SPLASH, -4.0, 0.0))
	w.queue(SimCommand.place_tower(w.tick, SLOW, 0.0, 4.0))
	var died := 0
	for n in 900:
		w.step()
		for e in w.events.count:  # events are cleared each step: count every step
			if w.events.kind[e] == SimEvents.Kind.ENEMY_DIED:
				died += 1
	assert_eq(w.towers.count(), 3)
	deaths.append(died)
	return w.state_hash()


func test_determinism_with_tower_kills() -> void:
	var d := []
	var h := _run(7, d)
	assert_gt(d[0], 0, "towers are the only damage source")
	assert_eq(_run(7, d), h)
	assert_eq(d[1], d[0])
	assert_ne(_run(8, []), h)
