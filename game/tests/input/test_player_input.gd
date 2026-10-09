extends GutTest
## PlayerInput: bindings, commands, D-105 gates, device mode (D-119, docs/09_CONTROLS.md).

## Every action of docs/09_CONTROLS.md; keep equal to the spec's table.
const ACTIONS: Array[String] = ["cam_pan_up", "cam_pan_down", "cam_pan_left", "cam_pan_right",
	"menu_up", "menu_down", "menu_left", "menu_right", "cam_zoom_in", "cam_zoom_out",
	"cam_recentre", "build_menu", "build_slot_1", "build_slot_2", "build_slot_3", "build_place",
	"build_cancel", "tower_sell", "skill_1", "skill_2", "pause"]
## Gamepad only: keyboard/mouse pans with WASD and builds with the slot keys instead.
const PAD_ONLY: Array[String] = ["menu_up", "menu_down", "menu_left", "menu_right", "build_menu"]
## Keyboard only: the gamepad picks a tower with the radial menu (build_menu) instead.
const KEY_ONLY: Array[String] = ["build_slot_1", "build_slot_2", "build_slot_3"]
const SINGLE := "tower_single_01"

var world: SimWorld
var cam: IsoCamera
var input: PlayerInput


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	cam = IsoCamera.new()
	var c3 := Camera3D.new()
	c3.name = "Camera3D"
	cam.add_child(c3)
	add_child_autofree(cam)
	input = PlayerInput.new()
	input.world = world
	input.camera = cam
	add_child_autofree(input)
	input.set_process(false)  # the tests drive cursor and mode, not the real mouse


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = pressed
	return e


func _pad(button: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.pressed = pressed
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	return e


func _queued() -> Array[SimCommand]:
	return world._queue


func _place_tower(x: float, z: float) -> int:
	world.queue(SimCommand.place_tower(world.tick, SINGLE, x, z))
	world.step()
	return world.towers.uid[world.towers.count() - 1]


func test_every_action_has_both_devices() -> void:
	var actions: Array[String] = []
	for a in InputMap.get_actions():
		if not String(a).begins_with("ui_"):
			actions.append(String(a))
	actions.sort()
	var expected := ACTIONS.duplicate()
	expected.sort()
	assert_eq(actions, expected, "project actions match the spec")
	for a in ACTIONS:
		var key := false
		var pad := false
		for e in InputMap.action_get_events(a):
			key = key or e is InputEventKey or e is InputEventMouseButton
			pad = pad or e is InputEventJoypadButton or e is InputEventJoypadMotion
		assert_eq(key, a not in PAD_ONLY, a + ": keyboard/mouse")
		assert_eq(pad, a not in KEY_ONLY, a + ": gamepad")


func test_pad_place_at_focus() -> void:
	input.handle(_axis(JOY_AXIS_RIGHT_X, 0.9))
	assert_true(input.gamepad)
	cam.position = Vector3(3.0, 0.0, 4.0)
	input.handle(_axis(JOY_AXIS_RIGHT_X, 0.9))
	assert_eq(input.cursor, cam.focus())
	input.select_tower(SINGLE)
	input.handle(_pad(JOY_BUTTON_A))
	var q := _queued()
	assert_eq(q.size(), 1)
	assert_eq(q[0].type, SimCommand.Type.PLACE_TOWER)
	assert_eq(q[0].tower_id, SINGLE)
	assert_eq(Vector2(q[0].x, q[0].z), Vector2(3.0, 4.0))
	assert_eq(input.selected_tower, SINGLE, "the selection stays")


func test_pad_rebuild_and_sell() -> void:
	var uid := _place_tower(3.0, 4.0)
	cam.position = Vector3(3.2, 0.0, 4.1)  # gamepad cursor = screen centre
	input.handle(_pad(JOY_BUTTON_X))
	assert_eq(_queued()[0].type, SimCommand.Type.SELL_TOWER)
	assert_eq(_queued()[0].tower_uid, uid)
	world._queue.clear()
	world.damage_tower(world.towers.uid.find(uid), 1e9)
	input.handle(_pad(JOY_BUTTON_A))
	assert_eq(_queued().size(), 1)
	assert_eq(_queued()[0].type, SimCommand.Type.REBUILD_TOWER)
	assert_eq(_queued()[0].tower_uid, uid)


func test_pad_skills_fire_once_per_pull() -> void:
	input.handle(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	input.handle(_axis(JOY_AXIS_TRIGGER_LEFT, 0.8))
	input.handle(_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
	var q := _queued()
	assert_eq(q.size(), 2)
	assert_eq(q[0].skill_id, world.run.skill_ids[0])
	assert_eq(q[1].skill_id, world.run.skill_ids[1])
	input.handle(_axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
	input.handle(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	assert_eq(_queued().size(), 3)


func test_pad_pause_toggles() -> void:
	input.handle(_pad(JOY_BUTTON_START))
	assert_eq(_queued()[0].type, SimCommand.Type.PAUSE)
	assert_true(_queued()[0].paused)
	world.step()
	input.handle(_pad(JOY_BUTTON_START))
	assert_false(_queued()[0].paused)


func test_pad_cancel_and_menu() -> void:
	input.select_tower(SINGLE)
	input.handle(_pad(JOY_BUTTON_B))
	assert_eq(input.selected_tower, "")
	assert_eq(_queued().size(), 0)
	watch_signals(input)
	input.handle(_pad(JOY_BUTTON_Y))
	assert_true(input.menu_open)
	assert_true(input.is_placing())
	input.handle(_pad(JOY_BUTTON_Y, false))
	assert_false(input.menu_open)
	assert_signal_emitted(input, "build_menu_closed")


func test_keyboard_mouse() -> void:
	input.handle(_key(KEY_2))
	assert_eq(input.selected_tower, world.tower_catalog.ids[world.run.tower_types[1]])
	input.cursor = Vector2(-3.0, 5.0)
	input.handle(_mouse(MOUSE_BUTTON_LEFT))
	assert_false(input.gamepad)
	assert_eq(_queued()[0].type, SimCommand.Type.PLACE_TOWER)
	assert_eq(Vector2(_queued()[0].x, _queued()[0].z), Vector2(-3.0, 5.0))
	world._queue.clear()
	input.handle(_key(KEY_ESCAPE))
	assert_eq(input.selected_tower, "")
	assert_eq(_queued().size(), 0, "Esc cancels, no pause")
	input.handle(_key(KEY_ESCAPE))
	assert_eq(_queued()[0].type, SimCommand.Type.PAUSE)


func _assert_no_building(why: String) -> void:
	input.select_tower(SINGLE)
	input.cursor = Vector2(3.0, 4.0)
	for e: InputEvent in [_pad(JOY_BUTTON_A), _pad(JOY_BUTTON_X), _pad(JOY_BUTTON_Y)]:
		input.handle(e)
	input.select_tower("")
	input.handle(_key(KEY_1))
	assert_eq(_queued().size(), 0, why + ": nothing queued")
	assert_false(input.menu_open, why + ": menu closed")
	assert_eq(input.selected_tower, "", why + ": no slot")
	input.handle(_pad(JOY_BUTTON_RIGHT_SHOULDER))
	assert_eq(cam.zoom_index, 0, why + ": camera works")
	input.handle(_key(KEY_P))
	assert_eq(_queued().size(), 1, why + ": pause works")


func test_no_building_while_paused() -> void:
	world.paused = true
	cam.set_zoom(1)
	_assert_no_building("paused")


func test_no_building_when_idle() -> void:
	world = SimWorld.new(1)
	input.world = world
	cam.set_zoom(1)
	_assert_no_building("idle")


func test_mouse_motion_leaves_gamepad_mode() -> void:
	input.handle(_axis(JOY_AXIS_LEFT_Y, 0.1))
	assert_false(input.gamepad, "inside the deadzone")
	input.handle(_pad(JOY_BUTTON_A))
	assert_true(input.gamepad)
	input.handle(InputEventMouseMotion.new())
	assert_false(input.gamepad)
	input.handle(_key(KEY_W))
	assert_false(input.gamepad, "keys do not switch")


func test_ground_point() -> void:
	var p := PlayerInput.ground_point(Vector3(1, 10, 2), Vector3(0.5, -1, -0.25))
	assert_eq(p, Vector2(6, -0.5))


func test_tower_uid_at() -> void:
	var uid := _place_tower(3.0, 4.0)
	assert_eq(PlayerInput.tower_uid_at(world, Vector2(3.2, 4.1)), uid)
	assert_eq(PlayerInput.tower_uid_at(world, Vector2(-3.0, 4.0)), -1)
	assert_eq(PlayerInput.tower_uid_at(world, Vector2(500, 0)), -1, "outside the grid")
	assert_eq(PlayerInput.tower_uid_at(SimWorld.new(1), Vector2(3, 4)), -1, "no run")


func test_edge_dir() -> void:
	var vp := Vector2(2560, 1440)
	assert_eq(PlayerInput.edge_dir(Vector2(5, 720), vp, 24), Vector2(-1, 0))
	assert_eq(PlayerInput.edge_dir(Vector2(1280, 720), vp, 24), Vector2.ZERO)
	assert_eq(PlayerInput.edge_dir(Vector2(2558, 2), vp, 24), Vector2(1, -1))


func test_camera_zoom_and_recentre() -> void:
	cam.set_zoom(0)
	cam.zoom_step(-1)
	assert_eq(cam.zoom_index, 0)
	for i in 5:
		cam.zoom_step(1)
	assert_eq(cam.zoom_index, cam.config.zoom_sizes.size() - 1)
	cam.position = Vector3(5, 0, -2)
	assert_eq(cam.focus(), Vector2(5, -2))
	cam.recentre()
	assert_eq(cam.focus(), Vector2.ZERO)
