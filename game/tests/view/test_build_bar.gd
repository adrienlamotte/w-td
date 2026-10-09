extends GutTest
## Build bar (D-122): one button per run tower, prices from TowerBuilding.price, D-105 gate.

var world: SimWorld
var input: PlayerInput
var bar: BuildBar


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	input = PlayerInput.new()
	input.world = world
	add_child_autofree(input)
	input.set_process(false)
	bar = BuildBar.new()
	add_child_autofree(bar)
	bar.setup(world, input)


func _button(s: int) -> Button:
	return bar.get_child(s)


func test_one_button_per_tower_with_price() -> void:
	var types := world.run.tower_types
	assert_eq(bar.get_child_count(), types.size())
	for s in types.size():
		var t := _button(s).text
		assert_string_contains(t, "[%d]" % (s + 1))
		assert_string_contains(t, tr(world.tower_catalog.name_key[types[s]]))
		assert_string_contains(t, tr("build.gold").format({"gold": TowerBuilding.price(world, types[s])}))
		assert_eq(_button(s).focus_mode, Control.FOCUS_NONE)


func test_price_rises_after_placing() -> void:
	var type := world.run.tower_types[0]
	var before := TowerBuilding.price(world, type)
	world.queue(SimCommand.place_tower(world.tick, world.tower_catalog.ids[type], 5.0, 5.0))
	world.step()
	bar.refresh()
	var after := TowerBuilding.price(world, type)
	assert_gt(after, before)
	assert_string_contains(_button(0).text, tr("build.gold").format({"gold": after}))


func test_click_selects_and_highlights() -> void:
	_button(1).pressed.emit()
	var id := world.tower_catalog.ids[world.run.tower_types[1]]
	assert_eq(input.selected_tower, id)
	bar.refresh()
	assert_true(_button(1).button_pressed)
	assert_false(_button(0).button_pressed)


func test_greyed_when_short_of_gold() -> void:
	world.gold = 0
	bar.refresh()
	assert_eq(_button(0).modulate, BuildBar.GREYED)
	assert_false(_button(0).disabled, "still clickable: the ghost says why")
	world.gold = 10000
	bar.refresh()
	assert_eq(_button(0).modulate, Color.WHITE)


func test_disabled_when_paused_or_no_run() -> void:
	world.queue(SimCommand.pause(world.tick, true))
	world.step()
	bar.refresh()
	assert_true(_button(0).disabled)
	world.queue(SimCommand.pause(world.tick, false))
	world.step()
	bar.refresh()
	assert_false(_button(0).disabled)
	bar.setup(SimWorld.new(1), input)
	assert_eq(bar.get_child_count(), 0)
