extends GutTest
## Radial build menu (D-046, D-122): slice layout and release rule.

var world: SimWorld
var input: PlayerInput
var radial: RadialMenu


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	input = PlayerInput.new()
	input.world = world
	add_child_autofree(input)
	input.set_process(false)
	radial = RadialMenu.new()
	add_child_autofree(radial)
	radial.setup(world, input, PlacementGhost.load_config())


func _at(deg: float) -> Vector2:
	return Vector2.from_angle(deg_to_rad(deg))


func test_slice_layout() -> void:
	# Screen y is down: -90 deg is up. Slice 0 centred at the top, clockwise.
	assert_eq(RadialMenu.slice(Vector2.UP, 4, 0.4), 0)
	assert_eq(RadialMenu.slice(Vector2.RIGHT, 4, 0.4), 1)
	assert_eq(RadialMenu.slice(Vector2.DOWN, 4, 0.4), 2)
	assert_eq(RadialMenu.slice(Vector2.LEFT, 4, 0.4), 3)
	assert_eq(RadialMenu.slice(Vector2.UP, 3, 0.4), 0)
	assert_eq(RadialMenu.slice(_at(30.0), 3, 0.4), 1)
	assert_eq(RadialMenu.slice(_at(150.0), 3, 0.4), 2)
	# Boundaries: 0 | 1 at -45 deg for n = 4, 0 | 1 at -30 deg for n = 3.
	assert_eq(RadialMenu.slice(_at(-46.0), 4, 0.4), 0)
	assert_eq(RadialMenu.slice(_at(-44.0), 4, 0.4), 1)
	assert_eq(RadialMenu.slice(_at(-31.0), 3, 0.4), 0)
	assert_eq(RadialMenu.slice(_at(-29.0), 3, 0.4), 1)
	assert_eq(RadialMenu.slice(_at(-149.0), 3, 0.4), 0)
	assert_eq(RadialMenu.slice(_at(-151.0), 3, 0.4), 2)


func test_deadzone() -> void:
	assert_eq(RadialMenu.slice(Vector2(0.1, 0.0), 3, 0.4), -1)
	assert_eq(RadialMenu.slice(Vector2.ZERO, 3, 0.4), -1)
	assert_eq(RadialMenu.slice(Vector2.UP, 0, 0.4), -1)


func test_release_selects_or_keeps() -> void:
	var ids := world.tower_catalog.ids
	var types := world.tower_types
	input.select_tower(ids[types[0]])
	input.build_menu_closed.emit(_at(30.0))
	assert_eq(input.selected_tower, ids[types[1]])
	input.build_menu_closed.emit(Vector2(0.1, 0.0))
	assert_eq(input.selected_tower, ids[types[1]], "centre release keeps the selection")


func test_shown_while_open() -> void:
	radial.refresh()
	assert_false(radial.visible)
	input.menu_open = true
	input.menu_dir = _at(150.0)
	radial.refresh()
	assert_true(radial.visible)
	assert_eq(radial.get_child_count(), world.tower_types.size())
	assert_eq(world.tower_types.size(), 3, "run_m2 offers 3 towers")
	assert_eq(radial.hover, 2)
	var price := TowerBuilding.price(world, world.tower_types[0])
	assert_string_contains((radial.get_child(0) as Label).text, str(price))


func test_grows_with_card_unlocks() -> void:
	var c := world.cards.index_of("card_tower_cinder")
	CardEffects.apply(world, world.cards.effects[c][0])
	input.menu_open = true
	radial.refresh()
	assert_eq(radial.get_child_count(), 4)
	input.build_menu_closed.emit(Vector2.LEFT)
	assert_eq(input.selected_tower, "tower_cinder", "slice 3 of 4 is the unlocked tower")
