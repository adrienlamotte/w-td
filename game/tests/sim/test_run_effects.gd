extends GutTest
## Run-scope card effects (D-148): build radius, rebuild price, detour damage.

const SINGLE := "tower_single_01"

var world: SimWorld


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.run.first_wave_tick = 1 << 30  # no wave spawns
	world.gold = 100000
	world.guardian_hp = 1e9


# Applies a card's effects; the run caches update in the next PATH phase.
func _pick(id: String) -> void:
	for e: Dictionary in world.cards.effects[world.cards.index_of(id)]:
		CardEffects.apply(world, e)
	world.step()


func _reason(x: float) -> TowerBuilding.Reason:
	return TowerBuilding.check_place(world, SINGLE, x, 0.0).reason


func test_build_radius() -> void:
	assert_eq(world.cards.max_build_radius_bonus, 6.0)
	assert_eq(world.build.size, 112)
	assert_eq(world.build_radius, 20.0)
	assert_eq(_reason(19.5), TowerBuilding.Reason.OK)
	assert_eq(_reason(21.0), TowerBuilding.Reason.OUT_OF_RADIUS)
	var h := world.state_hash()
	_pick("perk_expand")
	assert_eq(world.build_radius, 23.0)
	assert_ne(world.state_hash(), h)
	assert_eq(_reason(21.0), TowerBuilding.Reason.OK)
	assert_eq(_reason(25.5), TowerBuilding.Reason.OUT_OF_RADIUS)
	var b := world.build
	var f := world.field
	_pick("perk_expand")
	assert_eq(world.build_radius, 26.0)
	assert_eq(_reason(25.5), TowerBuilding.Reason.OK)
	assert_eq(_reason(27.0), TowerBuilding.Reason.OUT_OF_RADIUS)
	assert_same(world.build, b, "no grid reallocation")
	assert_same(world.field, f, "no flow field reallocation")


func test_rebuild_price() -> void:
	var uid := TowerBuilding.add_built(world, world.tower_catalog.type_of(SINGLE), 6.0, 0.0, 55)
	var t := world.towers.uid.find(uid)
	world.damage_tower(t, 1e9)
	assert_eq(TowerBuilding.rebuild_price(world, t), 16, "floor(55 x 0.3)")
	_pick("perk_masonry")
	assert_eq(TowerBuilding.rebuild_price(world, t), 8, "floor(55 x 0.3 x 0.5)")
	var gold := world.gold
	world.queue(SimCommand.rebuild_tower(world.tick, uid))
	world.step()
	assert_eq(world.towers.husk[t], 0)
	assert_eq(gold - world.gold, 8, "the command charges what check shows")


# A wall at x = 8 shoots an enemy at x = 10 (behind it: detouring) or at x = 6 (clear line).
func _hit_values(enemy_x: float) -> Array[float]:
	for z in range(-3, 4):
		TowerBuilding.add_built(world, world.tower_catalog.type_of(SINGLE), 8.0, z)
	world.towers.hp.fill(1e9)
	var done := world.field.recomputes
	while world.field.recomputes == done:  # sliced (CELLS_PER_TICK): wait for the wall's field
		world.step()
	world.enemies.add(world.catalog.type_of("enemy_swarmer_01"), enemy_x, 0.0, 1e9)
	world.step()
	var out: Array[float] = []
	for e in world.events.count:
		if world.events.kind[e] == SimEvents.Kind.ENEMY_HIT:
			out.append(world.events.value[e])
	assert_gt(out.size(), 0, "the wall fired")
	return out


func test_detour_damage_behind_wall() -> void:
	_pick("perk_maze")
	assert_almost_eq(world.detour_mult, 0.2, 1e-6)
	var values := _hit_values(10.0)
	var dmg := world.towers.damage[0]
	for v in values:
		assert_almost_eq(v, dmg * 1.2, 1e-4)


func test_detour_damage_clear_line() -> void:
	_pick("perk_maze")
	var values := _hit_values(6.0)
	var dmg := world.towers.damage[0]
	for v in values:
		assert_almost_eq(v, dmg, 1e-4)


func test_no_perk_no_bonus() -> void:
	var values := _hit_values(10.0)
	var dmg := world.towers.damage[0]
	for v in values:
		assert_almost_eq(v, dmg, 1e-4)
