extends GutTest
## Placement ghost and cursor hints (D-122): everything from check_place and the sim queries.

const SINGLE := "tower_single_01"

var world: SimWorld
var input: PlayerInput
var ghost: PlacementGhost


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	input = PlayerInput.new()
	input.world = world
	add_child_autofree(input)
	input.set_process(false)
	ghost = PlacementGhost.new()
	add_child_autofree(ghost)
	ghost.set_process(false)
	ghost.setup(world, input)


func _rgba(key: String) -> Color:
	var a: Array = ghost.config[key]
	return Color(a[0], a[1], a[2], a[3])


func _aim(x: float, z: float) -> void:
	input.selected_tower = SINGLE
	input.cursor = Vector2(x, z)
	ghost.update()


func _place(x: float, z: float) -> int:
	world.queue(SimCommand.place_tower(world.tick, SINGLE, x, z))
	world.step()
	return world.towers.count() - 1


func test_valid_spot_snaps_to_check_place() -> void:
	_aim(5.1, 5.2)
	var c := TowerBuilding.check_place(world, SINGLE, 5.1, 5.2)
	assert_eq(c.reason, TowerBuilding.Reason.OK)
	assert_true(ghost.visible)
	assert_eq(ghost.material.albedo_color, _rgba("ghost_valid_color"))
	assert_eq(ghost.position, Vector3(c.x, 0.0, c.z))
	assert_ne(ghost.position, Vector3(5.1, 0.0, 5.2), "snapped, not the raw cursor")
	assert_eq(ghost.hints, [{"key": "build.cost", "values": {"gold": c.price}}] as Array[Dictionary])


func _assert_invalid(x: float, z: float, reason: TowerBuilding.Reason, key: String) -> void:
	_aim(x, z)
	assert_eq(ghost.check.reason, reason, key)
	assert_true(ghost.visible)
	assert_eq(ghost.material.albedo_color, _rgba("ghost_invalid_color"))
	assert_eq(ghost.hints[0].key, key)


func test_invalid_reasons() -> void:
	_place(5.0, 5.0)
	_assert_invalid(5.0, 5.0, TowerBuilding.Reason.OCCUPIED, "build.reason.occupied")
	_assert_invalid(14.0, 14.0, TowerBuilding.Reason.OUT_OF_RADIUS, "build.reason.out_of_radius")
	_assert_invalid(0.5, 0.5, TowerBuilding.Reason.TOO_CLOSE, "build.reason.too_close")
	world.gold = 0
	_assert_invalid(-5.0, -5.0, TowerBuilding.Reason.NO_GOLD, "build.reason.no_gold")
	assert_eq(ghost.hints[0].values.gold, TowerBuilding.price(world, world.tower_catalog.type_of(SINGLE)))
	input.selected_tower = "tower_unknown"
	ghost.update()
	assert_false(ghost.visible, "no footprint to show")
	assert_eq(ghost.hints[0].key, "build.reason.not_offered")


func test_hidden_when_nothing_to_build() -> void:
	input.selected_tower = ""
	ghost.update()
	assert_false(ghost.visible)
	_aim(5.0, 5.0)
	assert_true(ghost.visible)
	world.queue(SimCommand.pause(world.tick, true))
	world.step()
	ghost.update()
	assert_false(ghost.visible)
	assert_eq(ghost.hints.size(), 0)
	ghost.world = SimWorld.new(1)
	ghost.update()
	assert_false(ghost.visible, "before StartRun")
	assert_eq(ghost.hints.size(), 0)


func test_sell_and_rebuild_hints() -> void:
	var t := _place(5.0, 5.0)
	input.selected_tower = ""
	input.cursor = Vector2(5.0, 5.0)
	var refund := TowerBuilding.sell_refund(world, t)
	assert_gt(refund, 0)
	assert_eq(PlacementGhost.hint(world, input),
		[{"key": "build.hint.sell", "values": {"key": "input.kbm.tower_sell", "gold": refund}}] as Array[Dictionary])
	input.gamepad = true
	assert_eq(PlacementGhost.hint(world, input)[0].values.key, "input.pad.tower_sell")
	TowerBuilding.damage(world, t, 1.0e9)
	var h := PlacementGhost.hint(world, input)
	assert_eq(h, [
		{"key": "build.hint.rebuild", "values": {"key": "input.pad.build_place", "gold": TowerBuilding.rebuild_price(world, t)}},
		{"key": "build.hint.sell", "values": {"key": "input.pad.tower_sell", "gold": 0}},
	] as Array[Dictionary])
	input.gamepad = false
	assert_eq(PlacementGhost.text(PlacementGhost.hint(world, input)),
		"Left click: rebuild (%d)\nX: sell (+0)" % TowerBuilding.rebuild_price(world, t))
	input.cursor = Vector2(-5.0, -5.0)
	assert_eq(PlacementGhost.hint(world, input).size(), 0, "nothing under the cursor")


func test_upgrade_hints() -> void:
	var uid := TowerBuilding.add_built(world, world.tower_catalog.type_of("tower_pip"), 5.0, 5.0, 50)
	var t := world.towers.uid.find(uid)
	world.gold = 1000
	input.selected_tower = ""
	input.cursor = Vector2(5.0, 5.0)
	var h := PlacementGhost.hint(world, input)
	assert_eq(h, [
		{"key": "upgrade.hint", "values": {"key": "input.kbm.tower_upgrade", "gold": 40, "level": 2}},
		{"key": "build.hint.sell", "values": {"key": "input.kbm.tower_sell", "gold": TowerBuilding.sell_refund(world, t)}},
	] as Array[Dictionary])
	assert_eq(PlacementGhost.text([h[0]] as Array[Dictionary]), "R: upgrade to Lv 2 (40)")
	input.gamepad = true
	assert_eq(PlacementGhost.hint(world, input)[0].values.key, "input.pad.tower_upgrade")
	world.gold = 0
	assert_eq(PlacementGhost.hint(world, input)[0].key, "upgrade.reason.no_gold")
	world.gold = 1000
	world.towers.level[t] = 3
	h = PlacementGhost.hint(world, input)
	assert_eq(h[0].key, "upgrade.reason.locked")
	assert_eq(PlacementGhost.text([h[0]] as Array[Dictionary]), "Lv 4 needs her signature card")
	world.add_modifier("unlock_level", SimModifiers.Op.ADD, 4, "tower:tower_pip")
	world.towers.level[t] = 4
	assert_eq(PlacementGhost.hint(world, input)[0].key, "upgrade.reason.max_level")
	TowerBuilding.damage(world, t, 1.0e9)
	h = PlacementGhost.hint(world, input)
	assert_eq(h.size(), 2)
	assert_eq(h[0].key, "build.hint.rebuild", "husk: no upgrade line")
	_place(-5.0, -5.0)
	input.cursor = Vector2(-5.0, -5.0)
	assert_eq(PlacementGhost.hint(world, input).size(), 1, "M2 tower: sell line only")
