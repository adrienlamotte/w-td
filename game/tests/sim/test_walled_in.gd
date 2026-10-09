extends GutTest
## Walled-in enemies attack the blocking tower (D-103, D-116); a gap lets them through.

const SWARMER := "enemy_swarmer_01"
const RANGED := "enemy_ranged_01"
const SINGLE := "tower_single_01"
const HP := 1e9

var world: SimWorld
var sw: int


func before_each() -> void:
	world = _new_run(7)
	sw = world.catalog.type_of(SWARMER)


func _new_run(run_seed: int) -> SimWorld:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	w.step()
	w.run.first_wave_tick = 1 << 30  # no spawns: these tests place their own enemies
	w.run.final_boss_tick = -1
	w.run.boss_ticks = PackedInt32Array()
	w.guardian_hp = HP
	w.gold = 1 << 30
	return w


func _tower(x: float, z: float) -> int:
	return TowerBuilding.add_built(world, world.tower_catalog.type_of(SINGLE), x, z)


# Full ring: towers every 0.25 units of arc (add_built skips taken cells).
func _ring(radius: float) -> void:
	var count := ceili(TAU * radius / 0.25)
	for k in count:
		var a := k * TAU / count
		_tower(cos(a) * radius, sin(a) * radius)


func _settle() -> void:
	world.step()
	var n := 0
	while world.field.busy() and n < 100:
		world.step()
		n += 1


func _count(kind: SimEvents.Kind) -> int:
	var n := 0
	for e in world.events.count:
		if world.events.kind[e] == kind:
			n += 1
	return n


# Steps until enemy 0 attacks a tower; returns that tower's index.
func _until_attacking_tower() -> int:
	var n := 0
	while not (world.enemies.state[0] == SimEnemies.State.ATTACKING and world.enemies.target_id[0] >= 0) \
			and n < 600:
		world.step()
		n += 1
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING, "reached the wall")
	return world.towers.uid.find(world.enemies.target_id[0])


func _until_guardian_hit() -> void:
	var n := 0
	while world.guardian_hp == HP and n < 1000:
		world.step()
		n += 1
	assert_lt(world.guardian_hp, HP, "went through the gap")


func test_full_ring_attacks_the_tower_on_its_line() -> void:
	_ring(6.0)
	_settle()
	world.enemies.add(sw, 10.0, 0.3, HP)
	var t := _until_attacking_tower()
	assert_gte(t, 0)
	var ta := atan2(world.towers.pos_z[t], world.towers.pos_x[t])
	assert_lt(absf(ta), 0.3, "the tower between it and the Guardian")
	var dmg := world.catalog.damage[sw]
	var hp0 := world.towers.hp[t]
	assert_eq(hp0, world.tower_catalog.hp[world.towers.type_id[t]] - dmg, "first hit on arrival")
	var hits := 0
	for k in 3 * world.catalog.attack_cooldown[sw]:
		world.step()
		hits += _count(SimEvents.Kind.TOWER_HIT)
	assert_eq(hits, 3)
	assert_eq(world.towers.hp[t], hp0 - 3 * dmg)
	assert_eq(world.guardian_hp, HP, "Guardian untouched")


func test_ranged_stops_at_its_range_from_the_tower() -> void:
	var rg := world.catalog.type_of(RANGED)
	_ring(6.0)
	_settle()
	world.enemies.add(rg, 16.0, 0.3, HP)
	var t := _until_attacking_tower()
	var d := Vector2(world.towers.pos_x[t] - world.enemies.pos_x[0],
		world.towers.pos_z[t] - world.enemies.pos_z[0]).length()
	var stop := world.tower_catalog.radius[world.towers.type_id[t]] + world.catalog.radius[rg] \
		+ world.catalog.attack_range[rg]
	assert_almost_eq(d, stop, 0.05)
	assert_lt(world.towers.hp[t], world.tower_catalog.hp[world.towers.type_id[t]])
	assert_eq(world.guardian_hp, HP)


func test_husk_gap() -> void:
	_ring(6.0)
	_settle()
	world.enemies.add(sw, 10.0, 0.3, HP)
	var t := _until_attacking_tower()
	var u := world.towers.uid[t]
	world.towers.hp[t] = 0.5  # the next hit kills it
	var died := false
	for k in 2 * world.catalog.attack_cooldown[sw]:
		world.step()
		if _count(SimEvents.Kind.TOWER_DIED) > 0:
			died = true
			break
	assert_true(died, "TOWER_DIED")
	assert_eq(world.towers.husk[world.towers.uid.find(u)], 1)
	_settle()
	world.step()
	assert_eq(world.enemies.target_id[0], -1, "the field caught up: a path")
	_until_guardian_hit()


func test_sold_gap() -> void:
	_ring(6.0)
	_settle()
	world.enemies.add(sw, 10.0, 0.3, HP)
	var t := _until_attacking_tower()
	while world.enemies.cooldown[0] != 1:  # it would hit in the next tick
		world.step()
	world.queue(SimCommand.sell_tower(world.tick, world.towers.uid[t]))
	world.step()
	assert_eq(_count(SimEvents.Kind.TOWER_SOLD), 1)
	assert_eq(_count(SimEvents.Kind.TOWER_HIT), 0, "no hit on the sold tower")
	assert_eq(world.guardian_hp, HP)
	assert_eq(world.enemies.target_id[0], -1)
	_until_guardian_hit()


func test_pocket() -> void:
	var uids: Array[int] = []
	for k in range(-2, 3):
		for p in [Vector2(8, k), Vector2(12, k), Vector2(10 + k, -2), Vector2(10 + k, 2)]:
			var u := _tower(p.x, p.y)
			if u >= 0:
				uids.append(u)
	_settle()
	world.enemies.add(sw, 10.0, 0.0, HP)
	var t := _until_attacking_tower()
	assert_has(uids, world.towers.uid[t])
	assert_lt(world.towers.pos_x[t], 9.0, "the wall toward the Guardian")
	assert_eq(world.guardian_hp, HP)


func test_target_follows_swap_remove() -> void:
	_ring(6.0)
	_settle()
	world.enemies.add(sw, 10.0, 0.3, HP)
	world.enemies.add(sw, -10.0, 0.3, HP)
	for k in 300:
		world.step()
	var u1 := world.enemies.target_id[1]
	assert_gt(u1, -1)
	assert_ne(u1, world.enemies.target_id[0])
	world.damage_enemy(0, 2 * HP)
	world.step()
	assert_eq(world.enemies.count(), 1)
	assert_eq(world.enemies.target_id[0], u1)


func _broken_ring(run_seed: int) -> int:
	world = _new_run(run_seed)
	_ring(6.0)
	for t in world.towers.count():
		world.towers.hp[t] = 3.0  # the horde breaks it
	world.spawn_ring(sw, 300, 12.0)
	var died := 0
	for k in 900:
		world.step()
		died += _count(SimEvents.Kind.TOWER_DIED)
	assert_gt(died, 0, "the ring broke")
	assert_lt(world.guardian_hp, HP, "and the horde got through")
	return world.state_hash()


func test_determinism() -> void:
	var h := _broken_ring(7)
	assert_eq(_broken_ring(7), h)
	assert_ne(_broken_ring(8), h)
