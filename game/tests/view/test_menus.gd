extends GutTest
## Start screen, pause menu, end screen (D-125, D-154).

const START := preload("res://view/ui/start_screen.tscn")
const PAUSE := preload("res://view/ui/pause_menu.tscn")
const END := preload("res://view/ui/end_screen.tscn")
const KEYS := ["flow.title", "flow.play", "flow.quit", "flow.resume", "flow.restart",
	"flow.abandon", "flow.abandon_confirm", "flow.cancel", "flow.continue", "flow.hearts_earned",
	"flow.unlocked", "flow.slow_time", "flow.won", "flow.lost", "flow.time_survived", "hud.paused",
	"flow.suspend_failed"]
const DIR := "user://test_menus/"

var world: SimWorld
var input: PlayerInput
var pause: PauseMenu
var end: EndScreen


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	RunFlow.save_dir = DIR
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
	RunFlow.screen = RunFlow.Screen.START
	RunFlow.restart_waifu = ""
	SuspendStore.last_error = ""
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)
	RunFlow.save_dir = "user://"


func _start() -> void:
	world.queue(SimCommand.start_run(world.tick, 7, "run_m2"))
	_step()


# A paused run_m3 with Cinder's Guardian at run clock `clock`.
func _paused_m3(clock: int) -> void:
	world.queue(SimCommand.start_run(world.tick, 7, "run_m3", "guardian_cinder"))
	world.queue(SimCommand.pause(world.tick, true))
	_step()
	world.clock = clock
	pause.refresh()


func _profile() -> MetaProfile:
	return ProfileStore.load_profile(MetaCatalog.load_dir(), DIR)


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
	assert_true(end.get_node("Panel/Box/Continue").has_focus())
	assert_false(end.get_node("Panel/Box/Unlock").visible, "a loss unlocks nothing")
	world.run_state = SimWorld.RunState.WON
	end.refresh()
	assert_eq(title.text, "flow.won")
	assert_eq(_profile().runs, 1, "recorded once")


func test_end_screen_win_records_and_shows_the_unlock() -> void:
	world.queue(SimCommand.start_run(world.tick, 7, "run_m3", "guardian_cinder"))
	_step()
	world.run_state = SimWorld.RunState.WON
	world.clock = 27000
	end.refresh()
	end._state = -1  # force a second refresh pass
	end.refresh()
	var p := _profile()
	assert_eq([p.hearts, p.runs, p.wins], [100, 1, 1], "recorded once")
	assert_eq(p.unlocked, PackedStringArray(["waifu_cinder"]))
	assert_eq((end.get_node("Panel/Box/Hearts") as Label).text, tr("flow.hearts_earned").format({"n": 100}))
	var unlock: Label = end.get_node("Panel/Box/Unlock")
	assert_true(unlock.visible)
	assert_string_contains(unlock.text, tr("waifu.cinder.name"))
	watch_signals(end)
	(end.get_node("Panel/Box/Continue") as Button).pressed.emit()
	assert_signal_emitted(end, "continue_pressed")
	assert_eq(RunFlow.screen, RunFlow.Screen.HUB)


func test_abandon_confirm() -> void:
	_paused_m3(13500)
	watch_signals(pause)
	(pause.get_node("Panel/Box/Abandon") as Button).pressed.emit()
	assert_true(pause.get_node("Panel/Confirm").visible)
	assert_eq((pause.get_node("Panel/Confirm/Text") as Label).text, tr("flow.abandon_confirm").format({"n": 40}))
	assert_true(pause.get_node("Panel/Confirm/Cancel").has_focus(), "Cancel by default (D-155)")
	(pause.get_node("Panel/Confirm/Cancel") as Button).pressed.emit()
	assert_false(pause.get_node("Panel/Confirm").visible)
	assert_false(FileAccess.file_exists(DIR + ProfileStore.FILE), "Cancel writes nothing")
	(pause.get_node("Panel/Box/Abandon") as Button).pressed.emit()
	pause._unhandled_input(_cancel())
	assert_false(pause.get_node("Panel/Confirm").visible, "ui_cancel closes the confirm")
	assert_true(world.paused, "and does not resume")
	(pause.get_node("Panel/Box/Abandon") as Button).pressed.emit()
	(pause.get_node("Panel/Confirm/Abandon") as Button).pressed.emit()
	var p := _profile()
	assert_eq([p.hearts, p.runs, p.losses], [40, 1, 1])
	assert_eq(RunFlow.screen, RunFlow.Screen.HUB)
	assert_signal_emitted(pause, "abandon_confirmed")


func test_abandon_in_the_first_minute() -> void:
	_paused_m3(0)
	(pause.get_node("Panel/Box/Abandon") as Button).pressed.emit()
	assert_eq((pause.get_node("Panel/Confirm/Text") as Label).text, tr("flow.abandon_confirm").format({"n": 0}))
	(pause.get_node("Panel/Confirm/Abandon") as Button).pressed.emit()
	var p := _profile()
	assert_eq([p.hearts, p.runs, p.losses], [0, 1, 1], "D-165")


func test_restart_confirm() -> void:
	_paused_m3(13500)
	watch_signals(pause)
	(pause.get_node("Panel/Box/Restart") as Button).pressed.emit()
	assert_true(pause.get_node("Panel/Confirm/Cancel").has_focus())
	(pause.get_node("Panel/Confirm/Abandon") as Button).pressed.emit()
	assert_eq(_profile().losses, 1)
	assert_eq(RunFlow.restart_waifu, "waifu_cinder")
	assert_signal_emitted(pause, "restart_confirmed")


func test_start_screen_toggle_and_signals() -> void:
	var start: StartScreen = START.instantiate()
	add_child_autofree(start)
	assert_true(start.get_node("Panel/Box/Start").has_focus())
	(start.get_node("Panel/Box/SlowTime") as CheckButton).button_pressed = true
	assert_true(RunFlow.slow_time_placing)
	RunFlow.slow_time_placing = false
	SettingsStore.load_into_run_flow(DIR)
	assert_true(RunFlow.slow_time_placing, "the toggle was saved (D-157)")
	watch_signals(start)
	(start.get_node("Panel/Box/Start") as Button).pressed.emit()
	(start.get_node("Panel/Box/Quit") as Button).pressed.emit()
	assert_signal_emitted(start, "start_pressed")
	assert_signal_emitted(start, "quit_pressed")


# A suspend save of a run_m3 run with Cinder's Guardian at run clock `clock` (D-167).
func _suspend(clock: int) -> void:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, 7, "run_m3", "guardian_cinder"))
	w.step()
	w.clock = clock
	assert_eq(SuspendStore.save(w, DIR), OK)


func test_start_screen_abandon_suspended_run() -> void:
	_suspend(13500)
	var start: StartScreen = START.instantiate()
	add_child_autofree(start)
	assert_false(start.get_node("Panel/Box/Start").visible, "Play replaced (D-167 rule 4)")
	assert_true(start.get_node("Panel/Box/Abandon").visible)
	assert_true(start.get_node("Panel/Box/Resume").has_focus())
	watch_signals(start)
	(start.get_node("Panel/Box/Resume") as Button).pressed.emit()
	assert_signal_emitted(start, "resume_pressed")
	(start.get_node("Panel/Box/Abandon") as Button).pressed.emit()
	assert_true(start.get_node("Panel/Confirm/Cancel").has_focus(), "Cancel by default (D-155)")
	assert_eq((start.get_node("Panel/Confirm/Text") as Label).text, tr("flow.abandon_confirm").format({"n": 40}))
	start._unhandled_input(_cancel())
	assert_false(start.get_node("Panel/Confirm").visible, "ui_cancel = Cancel")
	assert_true(SuspendStore.exists(DIR))
	(start.get_node("Panel/Box/Abandon") as Button).pressed.emit()
	(start.get_node("Panel/Confirm/Abandon") as Button).pressed.emit()
	var p := _profile()
	assert_eq([p.hearts, p.runs, p.losses], [40, 1, 1])
	assert_false(SuspendStore.exists(DIR))
	assert_true(start.get_node("Panel/Box/Start").visible, "Play is back")
	assert_false(start.get_node("Notice").visible)


func test_start_screen_failed_restore_notice() -> void:
	var f := FileAccess.open(DIR + SuspendStore.FILE, FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	SuspendStore.abandon(DIR)
	assert_eq(_profile().runs, 0, "no readable header: nothing recorded")
	var start: StartScreen = START.instantiate()
	add_child_autofree(start)
	assert_true(start.get_node("Notice").visible)
	assert_true(start.get_node("Notice/Box/OK").has_focus())
	(start.get_node("Notice/Box/OK") as Button).pressed.emit()
	assert_false(start.get_node("Notice").visible)
	assert_eq(SuspendStore.last_error, "")
	assert_true(start.get_node("Panel/Box/Start").has_focus())


func test_pause_slow_time_toggle_saves() -> void:
	(pause.get_node("Panel/Box/SlowTime") as CheckButton).button_pressed = true
	assert_true(RunFlow.slow_time_placing)
	assert_true(FileAccess.file_exists(DIR + SettingsStore.FILE))


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
