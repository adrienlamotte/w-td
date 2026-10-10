class_name PauseMenu
extends CanvasLayer
## Pause menu (D-125, D-154 rule 6): shown while a run is RUNNING and paused. Resume and
## ui_cancel (Esc / B) queue Pause(false) through PlayerInput. Restart and Abandon run go
## through a confirm (D-155, Cancel focused) that records the run as a loss, then signal
## game_view to reload the scene.

signal restart_confirmed
signal abandon_confirmed

var world: SimWorld
var input: PlayerInput
# The confirm is for Restart (true) or Abandon run (false).
var _restart: bool = false

@onready var _resume: Button = $Panel/Box/Resume
@onready var _slow: CheckButton = $Panel/Box/SlowTime
@onready var _box: VBoxContainer = $Panel/Box
@onready var _confirm: VBoxContainer = $Panel/Confirm
@onready var _cancel: Button = $Panel/Confirm/Cancel


func _ready() -> void:
	visible = false
	_resume.pressed.connect(resume)
	$Panel/Box/Restart.pressed.connect(ask.bind(true))
	$Panel/Box/Abandon.pressed.connect(ask.bind(false))
	_cancel.pressed.connect(close_confirm)
	$Panel/Confirm/Abandon.pressed.connect(confirm)
	_slow.toggled.connect(func(on: bool) -> void:
		RunFlow.slow_time_placing = on
		SettingsStore.save(RunFlow.save_dir))


func setup(w: SimWorld, p_input: PlayerInput) -> void:
	world = w
	input = p_input
	refresh()


func resume() -> void:
	input.set_paused(false)


## Opens the confirm: "Abandon run? You keep {n} hearts." (the loss hearts at this clock).
func ask(restart: bool) -> void:
	_restart = restart
	var n := MetaProfile.hearts_for(world.run, false, world.clock)
	$Panel/Confirm/Text.text = tr("flow.abandon_confirm").format({"n": n})
	_box.visible = false
	_confirm.visible = true
	_cancel.grab_focus()


func close_confirm() -> void:
	_confirm.visible = false
	_box.visible = true
	_resume.grab_focus()


## Records the run as a loss at the time reached, then hands off to game_view.
func confirm() -> void:
	ProfileStore.record_run_end(world, RunFlow.save_dir)
	RunFlow.screen = RunFlow.Screen.HUB
	if _restart:
		var cat := world.meta if world.meta else MetaCatalog.load_dir()
		RunFlow.restart_waifu = cat.waifu_of(world.run.guardian_id)
		restart_confirmed.emit()
	else:
		abandon_confirmed.emit()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var show := world != null and world.run_state == SimWorld.RunState.RUNNING and world.paused
	if show == visible:
		return
	visible = show
	if show:
		_slow.set_pressed_no_signal(RunFlow.slow_time_placing)
		close_confirm()


# After PlayerInput in the tree, so this runs first and Esc does not also reach it.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		if _confirm.visible:
			close_confirm()
		else:
			resume()
		get_viewport().set_input_as_handled()
