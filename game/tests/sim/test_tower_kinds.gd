extends GutTest
## Tower kinds wall (thorns), mark and slow_area (D-145).

const BASTIA := "tower_bastia"
const CLOVER := "tower_clover"
const TANSY := "tower_tansy"
const SWARMER := "enemy_swarmer_01"
const HP := 1e9
## Enemy HP: small enough that float32 keeps every subtraction exact.
const EHP := 1000.0

var world: SimWorld
var sw: int


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.run.first_wave_tick = 1 << 30  # no spawns: these tests place their own enemies
	world.run.final_boss_tick = -1
	world.run.boss_ticks = PackedInt32Array()
	world.guardian_hp = HP
	world.gold = 1 << 30
	sw = world.catalog.type_of(SWARMER)


func _built(id: String, x: float, z: float) -> int:
	var u := TowerBuilding.add_built(world, world.tower_catalog.type_of(id), x, z)
	return world.towers.uid.find(u)


func _events_of(kind: SimEvents.Kind) -> Array[int]:
	var out: Array[int] = []
	for e in world.events.count:
		if world.events.kind[e] == kind:
			out.append(e)
	return out


func test_wall_never_targets_or_fires() -> void:
	var t := _built(BASTIA, 4.0, 0.0)
	assert_eq(world.towers.attack_range[t], 0.0)
	world.enemies.add(sw, 5.0, 0.0, EHP)
	for n in 30:
		world.step()
		assert_eq(world.towers.target[t], -1)
		assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 0)


# Steps until enemy 0 hits a tower; returns the thorns ENEMY_HIT values of that step.
func _next_tower_hit() -> Array[float]:
	var out: Array[float] = []
	for n in 600:
		world.step()
		if _events_of(SimEvents.Kind.TOWER_HIT).size() > 0:
			for e in _events_of(SimEvents.Kind.ENEMY_HIT):
				out.append(world.events.value[e])
			return out
	fail_test("no tower hit")
	return out


func test_thorns_per_hit_and_level() -> void:
	var count := ceili(TAU * 6.0 / 0.25)  # full ring of Bastias (test_walled_in.gd)
	for k in count:
		var a := k * TAU / count
		_built(BASTIA, cos(a) * 6.0, sin(a) * 6.0)
	world.enemies.add(sw, 10.0, 0.3, EHP)
	assert_eq(_next_tower_hit(), [3.0], "L1 thorns, a normal ENEMY_HIT")
	assert_eq(world.enemies.hp[0], EHP - 3.0)
	var t := world.towers.uid.find(world.enemies.target_id[0])
	for n in 2:
		world.queue(SimCommand.upgrade_tower(world.tick, world.towers.uid[t]))
	assert_eq(_next_tower_hit(), [6.0], "L3 thorns")
	assert_eq(world.towers.level[t], 3)
	world.towers.hp[t] = 0.5  # the next hit kills it
	assert_eq(_next_tower_hit(), [6.0], "the lethal hit too")
	assert_eq(world.towers.husk[t], 1)


func test_mark_shot() -> void:
	var t := _built(CLOVER, 5.0, 0.0)
	world.enemies.add(sw, 8.0, 0.0, EHP)
	world.step()
	assert_eq(_events_of(SimEvents.Kind.TOWER_FIRED).size(), 1)
	assert_eq(world.enemies.hp[0], EHP - world.towers.damage[t])
	assert_eq(world.enemies.mark_gold[0], 2)
	assert_eq(world.enemies.mark_until[0], world.clock - 1 + DataFiles.ticks(4.0))


func _died_value() -> float:
	var died := _events_of(SimEvents.Kind.ENEMY_DIED)
	assert_eq(died.size(), 1)
	return world.events.value[died[0]]


func test_mark_gold_on_death_until_expiry() -> void:
	world.catalog.gold_chance[sw] = 0.0  # the base roll never drops gold
	world.enemies.add(sw, 20.0, 0.0, EHP)
	TowerAttacks.mark(world.enemies, 0, world.clock, 2, 1)
	world.damage_enemy(0, 2 * EHP)
	var gold := world.gold
	world.step()
	assert_eq(_died_value(), 2.0, "marked: +2")
	assert_eq(world.gold, gold + 2)
	world.enemies.add(sw, 20.0, 0.0, EHP)
	TowerAttacks.mark(world.enemies, 0, world.clock - 5, 2, 5)  # expires at the current clock
	world.damage_enemy(0, 2 * EHP)
	world.step()
	assert_eq(_died_value(), 0.0, "expired: nothing")


func test_mark_rules() -> void:
	var e := world.enemies
	e.add(sw, 20.0, 0.0, EHP)
	TowerAttacks.mark(e, 0, 100, 2, 50)
	TowerAttacks.mark(e, 0, 110, 3, 10)
	assert_eq([e.mark_gold[0], e.mark_until[0]], [3, 150], "higher gold wins, longer expiry kept")
	TowerAttacks.mark(e, 0, 120, 1, 100)
	assert_eq([e.mark_gold[0], e.mark_until[0]], [3, 220], "no stacking")
	TowerAttacks.mark(e, 0, 300, 1, 10)
	assert_eq([e.mark_gold[0], e.mark_until[0]], [1, 310], "an expired mark counts as none")


func test_slow_area_hits_and_slows_the_splash() -> void:
	var t := _built(TANSY, 5.0, 0.0)
	var e := world.enemies
	e.add(sw, 8.0, 0.0, EHP)  # target (nearest)
	e.add(sw, 8.0, 1.0, EHP)  # in splash_radius, already slowed harder
	e.add(sw, 8.0, 3.0, EHP)  # in range, out of the splash
	e.slow_factor[1] = 0.25
	e.slow_ticks[1] = 5
	world.step()
	assert_eq(_events_of(SimEvents.Kind.ENEMY_HIT).size(), 2)
	var dmg := world.towers.damage[t]
	var ticks := world.towers.slow_ticks[t]
	assert_eq([e.hp[0], e.slow_factor[0], e.slow_ticks[0]], [EHP - dmg, world.towers.slow_factor[t], ticks])
	assert_eq([e.hp[1], e.slow_factor[1], e.slow_ticks[1]], [EHP - dmg, 0.25, ticks], "stronger factor wins")
	assert_eq([e.hp[2], e.slow_ticks[2]], [EHP, 0])
