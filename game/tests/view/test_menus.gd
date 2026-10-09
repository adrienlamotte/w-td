extends GutTest
## Start screen, pause menu, end screen (D-125).

const START := preload("res://view/ui/start_screen.tscn")
const PAUSE := preload("res://view/ui/pause_menu.tscn")
const END := preload("res://view/ui/end_screen.tscn")
const KEYS := ["flow.title", "flow.start", "flow.quit", "flow.resume", "flow.restart",
	"flow.main_menu", "flow.slow_time", "flow.won", "flow.lost", "flow.time_survived", "hud.paused"]

var world: SimWorld
var input: PlayerInput
var pause: PauseMenu
var end: EndScreen


func before_each() -> void:
	world = SimWorld.new(1)
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
	pause = PAUSE.instantiate()
	add_child_autofree(pause)
	pause.set_process(false)
	pause.setup(world, input)
	end = END.instantiate()
	add_child_autofree(end)
	end.set_process(false)
	end.setup(world)


func after_each() -> void:
	RunFlow.slow_time_placing = false
	RunFlow.autostart = false


func _start() -> void:
	world.queue(SimCommand.start_run(world.tick, 7, "run_m2"))
	_step()


func _step() -> void:
	world.step()
	pause.refresh()
	end.refresh()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = true
	return e


func _cancel() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = &"ui_cancel"
	e.pressed = true
	return e


func test_pause_menu_visibility() -> void:
	assert_false(pause.visible, "before StartRun")
	_start()
	assert_false(pause.visible, "running")
	world.queue(SimCommand.pause(world.tick, true))
	_step()
	assert_true(pause.visible, "paused")
	assert_true(pause.get_node("Panel/Box/Resume").has_focus(), "focus on Resume")
	world.paused = false
	world.run_state = SimWorld.RunState.LOST
	pause.refresh()
	assert_false(pause.visible, "LOST")


func test_resume_button_and_cancel() -> void:
	_start()
	input.set_paused(true)
	_step()
	assert_true(world.paused)
	(pause.get_node("Panel/Box/Resume") as Button).pressed.emit()
	_step()
	assert_false(world.paused, "Resume")
	assert_false(pause.visible)
	input.set_paused(true)
	_step()
	pause._unhandled_input(_cancel())
	_step()
	assert_false(world.paused, "ui_cancel resumes")


func test_pausing_clears_the_selection() -> void:
	_start()
	input.selected_tower = "tower_single_01"
	input.menu_open = true
	input.handle(_key(KEY_P))
	assert_eq(input.selected_tower, "")
	assert_false(input.menu_open)
	_step()
	assert_true(world.paused)


func test_no_pause_outside_a_run() -> void:
	input.handle(_key(KEY_P))
	_step()
	assert_false(world.paused, "IDLE")
	_start()
	for s: SimWorld.RunState in [SimWorld.RunState.WON, SimWorld.RunState.LOST]:
		world.run_state = s
		input.handle(_key(KEY_P))
		_step()
		assert_false(world.paused, str(s))


func test_end_screen() -> void:
	assert_false(end.visible, "IDLE")
	_start()
	assert_false(end.visible, "running")
	for i in 70:
		world.step()
	world.run_state = SimWorld.RunState.LOST  # the Guardian fell (as test_tower_building forces it)
	end.refresh()
	assert_true(end.visible)
	var title: Label = end.get_node("Panel/Box/Title")
	assert_eq(title.text, "flow.lost")
	assert_eq((end.get_node("Panel/Box/Time") as Label).text,
			tr("flow.time_survived").format({"time": Hud.mmss(world.clock / SimWorld.TICK_RATE)}))
	assert_true(end.get_node("Panel/Box/Restart").has_focus())
	world.run_state = SimWorld.RunState.WON
	end.refresh()
	assert_eq(title.text, "flow.won")


func test_start_screen_toggle_and_signals() -> void:
	var start: StartScreen = START.instantiate()
	add_child_autofree(start)
	assert_true(start.get_node("Panel/Box/Start").has_focus())
	(start.get_node("Panel/Box/SlowTime") as CheckButton).button_pressed = true
	assert_true(RunFlow.slow_time_placing)
	watch_signals(start)
	(start.get_node("Panel/Box/Start") as Button).pressed.emit()
	(start.get_node("Panel/Box/Quit") as Button).pressed.emit()
	assert_signal_emitted(start, "start_pressed")
	assert_signal_emitted(start, "quit_pressed")


func test_menu_signals() -> void:
	watch_signals(pause)
	watch_signals(end)
	for m: CanvasLayer in [pause, end]:
		(m.get_node("Panel/Box/Restart") as Button).pressed.emit()
		(m.get_node("Panel/Box/MainMenu") as Button).pressed.emit()
		assert_signal_emitted(m, "restart_pressed")
		assert_signal_emitted(m, "main_menu_pressed")
	(pause.get_node("Panel/Box/SlowTime") as CheckButton).button_pressed = true
	assert_true(RunFlow.slow_time_placing)


func test_readable_and_keys_translate() -> void:
	var start: StartScreen = START.instantiate()
	add_child_autofree(start)
	for layer: CanvasLayer in [start, pause, end]:
		for c: Control in layer.find_children("*", "Control", true, false):
			if c is Label or c is Button:
				assert_gte(c.get_theme_font_size("font_size"), 32, "%s font size" % c.name)
			if c is Button:
				assert_eq(c.mouse_filter, Control.MOUSE_FILTER_STOP, c.name)
	for k: String in KEYS:
		assert_ne(tr(k), k, k)


func test_gamepad_navigates_menus() -> void:
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.pressed = true
	var b := InputEventJoypadButton.new()
	b.button_index = JOY_BUTTON_B
	b.pressed = true
	assert_true(a.is_action(&"ui_accept"), "A accepts")
	assert_true(b.is_action(&"ui_cancel"), "B cancels")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	assert_true(esc.is_action(&"ui_cancel"), "Esc still cancels")
