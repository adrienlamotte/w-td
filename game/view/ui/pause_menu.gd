class_name PauseMenu
extends CanvasLayer
## Pause menu (D-125): shown while a run is RUNNING and paused. Resume and ui_cancel
## (Esc / B) queue Pause(false) through PlayerInput; it reads the sim, writes none.

signal restart_pressed
signal main_menu_pressed

var world: SimWorld
var input: PlayerInput

@onready var _resume: Button = $Panel/Box/Resume
@onready var _slow: CheckButton = $Panel/Box/SlowTime


func _ready() -> void:
	visible = false
	_resume.pressed.connect(resume)
	$Panel/Box/Restart.pressed.connect(restart_pressed.emit)
	$Panel/Box/MainMenu.pressed.connect(main_menu_pressed.emit)
	_slow.toggled.connect(func(on: bool) -> void: RunFlow.slow_time_placing = on)


func setup(w: SimWorld, p_input: PlayerInput) -> void:
	world = w
	input = p_input
	refresh()


func resume() -> void:
	input.set_paused(false)


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var show := world != null and world.run_state == SimWorld.RunState.RUNNING and world.paused
	if show == visible:
		return
	visible = show
	if show:
		_slow.set_pressed_no_signal(RunFlow.slow_time_placing)
		_resume.grab_focus()


# After PlayerInput in the tree, so this runs first and Esc does not also reach it.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		resume()
		get_viewport().set_input_as_handled()
