extends GutTest
## UPGRADE_TOWER and TowerUpgrade.check (D-144, D-113, D-105).

const PIP := "tower_pip"
const R := TowerUpgrade.Reason

var world: SimWorld
var pip_t: int
var pip_uid: int


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.gold = 1000
	pip_uid = TowerBuilding.add_built(world, world.tower_catalog.type_of(PIP), 4.0, 4.0, 50)
	pip_t = world.towers.uid.find(pip_uid)
	world.step()


func _upgrade(uid: int = pip_uid) -> void:
	world.queue(SimCommand.upgrade_tower(world.tick, uid))
	world.step()


func _upgraded_events() -> Array[int]:
	var out: Array[int] = []
	for e in world.events.count:
		if world.events.kind[e] == SimEvents.Kind.TOWER_UPGRADED:
			out.append(e)
	return out


func _assert_refused(uid: int, reason: TowerUpgrade.Reason, why: String) -> void:
	if world.run_state == SimWorld.RunState.RUNNING and not world.paused:
		assert_eq(TowerUpgrade.check(world, uid).reason, reason, why + ": check")
	var gold := world.gold
	var level := world.towers.level[pip_t]
	var paid := world.towers.paid[pip_t]
	_upgrade(uid)
	assert_eq(world.gold, gold, why + ": gold")
	assert_eq(world.towers.level[pip_t], level, why + ": level")
	assert_eq(world.towers.paid[pip_t], paid, why + ": paid")
	assert_eq(_upgraded_events().size(), 0, why + ": event")


func test_upgrade_two_levels() -> void:
	for want in [[2, 40], [3, 60]]:
		var c := TowerUpgrade.check(world, pip_uid)
		assert_eq(c.reason, R.OK)
		assert_eq([c.level, c.price], want)
		var gold := world.gold
		var paid := world.towers.paid[pip_t]
		_upgrade()
		assert_eq(world.gold, gold - want[1])
		assert_eq(world.towers.paid[pip_t], paid + want[1])
		assert_eq(world.towers.level[pip_t], want[0])
		var ev := _upgraded_events()
		assert_eq(ev.size(), 1)
		assert_eq(world.events.a[ev[0]], pip_uid)
		assert_eq(world.events.x[ev[0]], world.towers.pos_x[pip_t])
		assert_eq(world.events.z[ev[0]], world.towers.pos_z[pip_t])
		assert_eq(world.events.value[ev[0]], float(want[0]))
	assert_eq(world.towers.paid[pip_t], 150)


func test_refusals() -> void:
	_assert_refused(999, R.NO_TOWER, "unknown uid")
	var single := TowerBuilding.add_built(world, world.tower_catalog.type_of("tower_single_01"), -4.0, 4.0)
	assert_eq(TowerUpgrade.check(world, single).reason, R.MAX_LEVEL, "M2 tower has 1 level")
	world.gold = 39
	_assert_refused(pip_uid, R.NO_GOLD, "no gold")
	world.gold = 1000
	world.queue(SimCommand.pause(world.tick, true))
	world.step()
	_assert_refused(pip_uid, R.OK, "paused")
	world.queue(SimCommand.pause(world.tick, false))
	_upgrade()
	_upgrade()
	_assert_refused(pip_uid, R.LOCKED, "level 4 without the signature card")
	world.add_modifier("unlock_level", SimModifiers.Op.ADD, 4, "tower:" + PIP)
	assert_eq(TowerUpgrade.check(world, pip_uid).price, 100)
	_upgrade()
	assert_eq(world.towers.level[pip_t], 4)
	_assert_refused(pip_uid, R.MAX_LEVEL, "max level")
	world.damage_tower(pip_t, 1e9)
	_assert_refused(pip_uid, R.HUSK, "husk")


func test_refused_while_idle() -> void:
	var idle := SimWorld.new(1)
	idle.queue(SimCommand.upgrade_tower(0, 0))
	idle.step()
	assert_eq(idle.events.count, 0)
	assert_eq(TowerUpgrade.check(idle, 0).reason, R.NO_TOWER)


func test_sell_and_rebuild_follow_upgrade_gold() -> void:
	_upgrade()  # paid 50 + 40
	assert_eq(TowerBuilding.sell_refund(world, pip_t), floori(90 * 0.5))
	world.damage_tower(pip_t, 1e9)
	world.step()
	assert_eq(TowerBuilding.rebuild_price(world, pip_t), floori(90 * 0.3))
	var gold := world.gold
	world.queue(SimCommand.rebuild_tower(world.tick, pip_uid))
	world.step()
	assert_eq(world.gold, gold - floori(90 * 0.3))
	assert_eq(world.towers.husk[pip_t], 0)
	assert_eq(world.towers.level[pip_t], 2)
	assert_eq(world.towers.hp[pip_t], world.towers.max_hp[pip_t])
	assert_eq(world.towers.damage[pip_t], 8.0)

