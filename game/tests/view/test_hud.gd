extends GutTest
## HUD (D-121): shows sim state, translated keys, readable font sizes.

const HUD_SCENE := preload("res://view/ui/hud.tscn")
const KEYS := ["hud.hp", "hud.gold", "hud.wave", "hud.break", "hud.ready", "hud.seconds",
	"hud.hint.skill_1", "hud.hint.skill_2", "guardian.placeholder_01.name",
	"build.slot", "build.gold", "build.cost", "build.reason.occupied", "build.reason.out_of_radius",
	"build.reason.too_close", "build.reason.no_gold", "build.reason.not_offered", "build.hint.sell",
	"build.hint.rebuild", "input.kbm.build_place", "input.pad.build_place", "input.kbm.tower_sell",
	"input.pad.tower_sell"]

var world: SimWorld
var hud: Hud
var input: PlayerInput
var ghost: PlacementGhost


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	var cam := IsoCamera.new()
	var c3 := Camera3D.new()
	c3.name = "Camera3D"
	cam.add_child(c3)
	add_child_autofree(cam)
	input = PlayerInput.new()
	input.world = world
	input.camera = cam
	add_child_autofree(input)
	input.set_process(false)
	ghost = PlacementGhost.new()
	add_child_autofree(ghost)
	ghost.setup(world, input)
	hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	hud.setup(world, input, ghost)


func _label(path: String) -> Label:
	return hud.get_node("Root/" + path)


func _steps(n: int) -> void:
	for i in n:
		world.step()
	hud.refresh()


func test_shows_state() -> void:
	assert_true(hud.visible)
	assert_eq(_label("TopRight/Gold").text, tr("hud.gold").format({"value": world.run.starting_gold}))
	var max_hp := ceili(world.run.guardian_hp)
	assert_eq(_label("TopLeft/Hp").text, "%d / %d" % [max_hp, max_hp])
	assert_eq((hud.get_node("Root/TopLeft/HpBar") as ProgressBar).value, 1.0)
	assert_eq(_label("TopCentre/Wave").text, "Wave 1")
	_steps(29)
	assert_eq(_label("TopCentre/Clock").text, "0:01")
	world.gold = 12
	world.guardian_hp = 10.2
	hud.refresh()
	assert_eq(_label("TopRight/Gold").text, "Gold 12")
	assert_eq(_label("TopLeft/Hp").text, "11 / %d" % max_hp)
	world.clock = world.run.wave_ticks
	hud.refresh()
	assert_eq(_label("TopCentre/Wave").text, "Break " + Hud.mmss(world.run.break_ticks / SimWorld.TICK_RATE))


func test_skill_cooldown() -> void:
	var slots := hud.get_node("Root/Skills").get_children()
	assert_eq(slots.size(), world.run.skill_ids.size())
	world.queue(SimCommand.use_skill(world.tick, world.run.skill_ids[0]))
	_steps(1)
	var s0: Label = slots[0].get_child(0).get_child(2)
	var s1: Label = slots[1].get_child(0).get_child(2)
	var secs := world.run.skill_cooldown[0] / SimWorld.TICK_RATE
	assert_eq(s0.text, "%ds" % secs)
	assert_eq(s1.text, tr("hud.ready"))


func test_hidden_without_run() -> void:
	hud.setup(SimWorld.new(1))
	assert_false(hud.visible)


func test_clock_text_and_seconds_left() -> void:
	assert_eq(Hud.clock_text(0), "0:00")
	assert_eq(Hud.clock_text(29), "0:00")
	assert_eq(Hud.clock_text(30 * 61), "1:01")
	assert_eq(Hud.clock_text(30 * 600), "10:00")
	assert_eq(Hud.seconds_left(100, 100), 0)
	assert_eq(Hud.seconds_left(50, 100), 0)
	assert_eq(Hud.seconds_left(101, 100), 1)
	assert_eq(Hud.seconds_left(130, 100), 1)
	assert_eq(Hud.seconds_left(131, 100), 2)


func test_cursor_label() -> void:
	var cursor := _label("Cursor")
	assert_false(cursor.visible)
	input.selected_tower = "tower_single_01"
	input.cursor = Vector2(5.0, 5.0)
	ghost.update()
	hud.refresh()
	assert_true(cursor.visible)
	assert_eq(cursor.text, PlacementGhost.text(ghost.hints))


func test_readable_and_click_through() -> void:
	input.menu_open = true  # the radial builds its labels
	(hud.get_node("Root/Radial") as RadialMenu).refresh()
	input.selected_tower = "tower_single_01"
	ghost.update()
	hud.refresh()
	var controls := hud.find_children("*", "Control", true, false)
	assert_gt(controls.size(), 18)
	for c: Control in controls:
		if c is Button:  # the build bar is clickable
			assert_eq(c.get_parent(), hud.get_node("Root/BuildBar"), c.name)
		else:
			assert_eq(c.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s ignores the mouse" % c.name)
		if c is Label or c is Button:
			assert_gte(c.get_theme_font_size("font_size"), 32, "%s font size" % c.name)


func test_keys_translate() -> void:
	var keys: Array = KEYS.duplicate()
	keys.append_array(world.catalog.name_key)
	keys.append_array(world.tower_catalog.name_key)
	keys.append_array(world.run.skill_name_key)
	for k: String in keys:
		assert_ne(tr(k), k, k)
