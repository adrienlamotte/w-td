extends GutTest
## PlaceTower, SellTower, RebuildTower, tower HP and husks (D-109, D-104, D-105, D-113).

const SINGLE := "tower_single_01"
const SPLASH := "tower_splash_01"
const SWARMER := "enemy_swarmer_01"

var world: SimWorld
var single: int


func before_each() -> void:
	world = SimWorld.new(1)
	single = world.tower_catalog.type_of(SINGLE)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()


func _do(cmd: SimCommand) -> void:
	world.queue(cmd)
	world.step()


func _place(x: float, z: float, id: String = SINGLE) -> void:
	_do(SimCommand.place_tower(world.tick, id, x, z))


func _events_of(kind: SimEvents.Kind) -> Array[int]:
	var out: Array[int] = []
	for e in world.events.count:
		if world.events.kind[e] == kind:
			out.append(e)
	return out


func _cell(i: int, j: int) -> int:
	return j * world.build.size + i


func _assert_rejected(cmd: SimCommand, why: String) -> void:
	var gold := world.gold
	var n := world.towers.count()
	_do(cmd)
	assert_eq(world.gold, gold, why + ": gold")
	assert_eq(world.towers.count(), n, why + ": towers")
	assert_eq(_events_of(SimEvents.Kind.TOWER_PLACED).size(), 0, why + ": event")


func test_place() -> void:
	var v := world.build.version
	_place(3.2, 4.1)
	assert_eq(world.towers.count(), 1)
	assert_eq(world.towers.pos_x[0], 3.0)
	assert_eq(world.towers.pos_z[0], 4.0)
	assert_eq(world.towers.uid[0], 0)
	assert_eq(world.towers.hp[0], world.tower_catalog.hp[single])
	assert_eq(world.gold, world.run.starting_gold - world.tower_catalog.cost[single])
	var ev := _events_of(SimEvents.Kind.TOWER_PLACED)
	assert_eq(ev.size(), 1)
	assert_eq(world.events.a[ev[0]], 0)
	assert_eq(world.events.x[ev[0]], 3.0)
	assert_eq(world.events.z[ev[0]], 4.0)
	assert_eq(world.events.value[ev[0]], float(single))
	# Centre 3.0 with 2 cells: cells 45..46 in x, 47..48 in z.
	for c in [_cell(45, 47), _cell(46, 47), _cell(45, 48), _cell(46, 48)]:
		assert_eq(world.build.owner[c], 0)
		assert_eq(world.build.solid[c], 1)
	assert_eq(world.build.owner[_cell(47, 47)], -1)
	assert_eq(world.build.version, v + 1)


func test_rejections() -> void:
	_assert_rejected(SimCommand.place_tower(world.tick, SINGLE, 15.0, 15.0), "outside the radius")
	_assert_rejected(SimCommand.place_tower(world.tick, SINGLE, 1.0, 0.0), "on the Guardian")
	_assert_rejected(SimCommand.place_tower(world.tick, "tower_nope", 3.0, 4.0), "not in the run")
	_place(3.0, 4.0)
	_assert_rejected(SimCommand.place_tower(world.tick, SINGLE, 3.5, 4.0), "overlaps by one cell")
	_place(4.0, 4.0)
	assert_eq(world.towers.count(), 2, "adjacent is fine")
	world.gold = 10
	_assert_rejected(SimCommand.place_tower(world.tick, SINGLE, 8.0, 4.0), "not enough gold")


func test_edge_of_radius_is_inside() -> void:
	_place(19.6, 0.0)
	assert_eq(world.towers.count(), 1)
	assert_eq(world.towers.pos_x[0], 19.5)


func test_rejected_while_paused() -> void:
	world.gold = 1000
	_do(SimCommand.pause(world.tick, true))
	_assert_rejected(SimCommand.place_tower(world.tick, SINGLE, 3.0, 4.0), "paused")


func test_rejected_before_start_and_after_loss() -> void:
	var idle := SimWorld.new(1)
	idle.queue(SimCommand.place_tower(0, SINGLE, 3.0, 4.0))
	idle.step()
	assert_eq(idle.towers.count(), 0, "IDLE")
	world.run_state = SimWorld.RunState.LOST
	_assert_rejected(SimCommand.place_tower(world.tick, SINGLE, 3.0, 4.0), "LOST")


func test_cost_grows_per_copy() -> void:
	var cat := world.tower_catalog
	world.gold = 1000
	_place(3.0, 4.0)
	_place(6.0, 4.0)
	assert_eq(world.towers.paid[1], cat.cost[single] + cat.cost_per_copy[single])
	_place(9.0, 4.0, SPLASH)
	assert_eq(world.towers.paid[2], cat.cost[cat.type_of(SPLASH)], "other type: base cost")
	_do(SimCommand.sell_tower(world.tick, 0))
	_place(3.0, 8.0)
	assert_eq(world.towers.paid[world.towers.uid.find(3)], cat.cost[single] + cat.cost_per_copy[single], "price drops back")


func test_sell() -> void:
	world.gold = 1000
	_place(3.0, 4.0)
	_place(6.0, 4.0)
	_place(9.0, 4.0)
	var paid := world.towers.paid[0]
	var gold := world.gold
	var v := world.build.version
	_do(SimCommand.sell_tower(world.tick, 0))
	var refund := floori(paid * world.tower_catalog.sell_refund[single])
	assert_eq(world.gold, gold + refund)
	assert_eq(world.build.owner[_cell(45, 47)], -1)
	assert_eq(world.build.solid[_cell(45, 47)], 0)
	assert_eq(world.build.version, v + 1)
	var ev := _events_of(SimEvents.Kind.TOWER_SOLD)
	assert_eq(ev.size(), 1)
	assert_eq(world.events.a[ev[0]], 0)
	assert_eq(world.events.value[ev[0]], float(refund))
	# Swap-remove keeps the others' uids, positions and cells.
	assert_eq(world.towers.count(), 2)
	for u in [1, 2]:
		var t := world.towers.uid.find(u)
		assert_eq(world.towers.pos_x[t], 3.0 + 3.0 * u)
		assert_eq(world.build.owner[_cell(world.towers.cell_i[t], world.towers.cell_j[t])], u)
	gold = world.gold
	_do(SimCommand.sell_tower(world.tick, 99))
	assert_eq(world.gold, gold, "unknown uid")
	assert_eq(world.towers.count(), 2)


func test_damage_and_husk() -> void:
	_place(3.0, 4.0)
	var hp := world.towers.hp[0]
	world.damage_tower(0, 10.0)
	assert_eq(world.towers.hp[0], hp - 10.0)
	world.enemies.add(world.catalog.type_of(SWARMER), 3.5, 4.0, 100.0)
	var v := world.build.version
	world.events.clear()
	world.damage_tower(0, 1000.0)
	assert_eq(world.towers.hp[0], 0.0)
	assert_eq(world.towers.husk[0], 1)
	assert_eq(_events_of(SimEvents.Kind.TOWER_DIED).size(), 1)
	assert_eq(world.build.owner[_cell(45, 47)], 0)
	assert_eq(world.build.solid[_cell(45, 47)], 0)
	assert_eq(world.build.version, v + 1)
	world.step()
	assert_eq(world.towers.target[0], -1, "a husk never targets")
	world.events.clear()
	world.damage_tower(0, 5.0)
	assert_eq(world.towers.hp[0], 0.0, "husk ignores damage")
	assert_eq(world.events.count, 0)
	_assert_rejected(SimCommand.place_tower(world.tick, SINGLE, 3.0, 4.0), "on a husk")
	var gold := world.gold
	_do(SimCommand.sell_tower(world.tick, 0))
	assert_eq(world.gold, gold, "a husk refunds nothing")
	assert_eq(world.build.owner[_cell(45, 47)], -1)


func test_live_tower_targets() -> void:
	_place(3.0, 4.0)
	world.enemies.add(world.catalog.type_of(SWARMER), 3.5, 4.0, 100.0)
	world.step()
	assert_ne(world.towers.target[0], -1)


func test_rebuild() -> void:
	_place(3.0, 4.0)
	var gold := world.gold
	_do(SimCommand.rebuild_tower(world.tick, 0))
	assert_eq(world.gold, gold, "a live tower is not rebuilt")
	world.damage_tower(0, 1000.0)
	var price := floori(world.towers.paid[0] * world.tower_catalog.rebuild_fraction[single])
	world.gold = price - 1
	_do(SimCommand.rebuild_tower(world.tick, 0))
	assert_eq(world.towers.husk[0], 1, "not enough gold")
	world.gold = price
	_do(SimCommand.pause(world.tick, true))
	_do(SimCommand.rebuild_tower(world.tick, 0))
	assert_eq(world.towers.husk[0], 1, "paused")
	_do(SimCommand.pause(world.tick, false))
	var v := world.build.version
	_do(SimCommand.rebuild_tower(world.tick, 0))
	assert_eq(world.gold, 0)
	assert_eq(world.towers.husk[0], 0)
	assert_eq(world.towers.hp[0], world.tower_catalog.hp[single])
	assert_eq(world.build.solid[_cell(45, 47)], 1)
	assert_eq(world.build.version, v + 1)
	var ev := _events_of(SimEvents.Kind.TOWER_PLACED)
	assert_eq(ev.size(), 1)
	assert_eq(world.events.a[ev[0]], 0, "same uid")


func test_300_towers() -> void:
	world.gold = 1 << 40
	var placed := 0
	for i in range(-13, 14):
		for j in range(-13, 14):
			if placed == 300:
				break
			var x := i * 1.5
			var z := j * 1.5
			var d := sqrt(x * x + z * z)
			if d + 0.5 > 20.0 or d < 1.5:
				continue
			world.queue(SimCommand.place_tower(world.tick, SINGLE, x, z))
			placed += 1
	world.step()
	assert_eq(placed, 300)
	assert_eq(world.towers.count(), 300)
	var uids := {}
	for u in world.towers.uid:
		uids[u] = true
	assert_eq(uids.size(), 300)
	assert_eq(world.build.solid.count(1), 4 * 300)


func _hash_run(run_seed: int) -> int:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, run_seed, "run_m2"))
	w.queue(SimCommand.place_tower(2, SINGLE, 3.0, 4.0))
	w.queue(SimCommand.place_tower(2, SINGLE, -3.0, 4.0))
	w.queue(SimCommand.sell_tower(10, 1))
	for i in 20:
		w.step()
	w.damage_tower(0, 1000.0)
	w.queue(SimCommand.rebuild_tower(w.tick, 0))
	for i in 20:
		w.step()
	return w.state_hash()


func test_determinism() -> void:
	var h := _hash_run(7)
	assert_eq(_hash_run(7), h)
	assert_ne(_hash_run(8), h)


# check_place (D-121): each reason, and place() is accepted iff OK.
func _check_then_place(id: String, x: float, z: float, want: TowerBuilding.Reason, why: String) -> void:
	var c := TowerBuilding.check_place(world, id, x, z)
	assert_eq(c.reason, want, why)
	var gold := world.gold
	var n := world.towers.count()
	var owned := world.build.owner.duplicate()
	_place(x, z, id)
	if want != TowerBuilding.Reason.OK:
		assert_eq(world.gold, gold, why + ": gold")
		assert_eq(world.towers.count(), n, why + ": towers")
		assert_eq(world.build.owner, owned, why + ": grid")
		return
	var t := world.towers.count() - 1
	assert_eq(world.towers.count(), n + 1, why)
	assert_eq(world.towers.pos_x[t], c.x, why + ": snapped x")
	assert_eq(world.towers.pos_z[t], c.z, why + ": snapped z")
	assert_eq(gold - world.gold, c.price, why + ": price")
	assert_eq(world.towers.footprint[t], c.footprint, why + ": footprint")


func test_check_place_reasons() -> void:
	var R := TowerBuilding.Reason
	world.gold = 1000
	_check_then_place("tower_nope", 3.0, 4.0, R.NOT_OFFERED, "not offered")
	_check_then_place(SINGLE, 3.2, 4.1, R.OK, "ok")
	_check_then_place(SINGLE, 3.5, 4.0, R.OCCUPIED, "tower there")
	_check_then_place(SINGLE, 100.0, 0.0, R.OCCUPIED, "outside the grid")
	_check_then_place(SINGLE, 15.0, 15.0, R.OUT_OF_RADIUS, "out of radius")
	_check_then_place(SINGLE, 1.0, 0.0, R.TOO_CLOSE, "too close")
	_place(6.0, 4.0)
	world.damage_tower(world.towers.count() - 1, 1000.0)
	_check_then_place(SINGLE, 6.0, 4.0, R.OCCUPIED, "husk there")
	world.gold = 0
	_check_then_place(SINGLE, 9.0, 4.0, R.NO_GOLD, "no gold")


func test_prices_match_commands() -> void:
	var cat := world.tower_catalog
	world.gold = 1000
	assert_eq(TowerBuilding.price(world, single), cat.cost[single])
	_place(3.0, 4.0)
	_place(6.0, 4.0)
	world.damage_tower(1, 1000.0)
	assert_eq(TowerBuilding.price(world, single), cat.cost[single] + 2 * cat.cost_per_copy[single], "husks count")
	var refund := TowerBuilding.sell_refund(world, 0)
	assert_gt(refund, 0)
	assert_eq(TowerBuilding.sell_refund(world, 1), 0, "husk refunds 0")
	var rebuild := TowerBuilding.rebuild_price(world, 1)
	var gold := world.gold
	_do(SimCommand.rebuild_tower(world.tick, 1))
	assert_eq(gold - world.gold, rebuild, "rebuild charges rebuild_price")
	gold = world.gold
	_do(SimCommand.sell_tower(world.tick, 0))
	assert_eq(world.gold - gold, refund, "sell refunds sell_refund")
