class_name StartScreen
extends CanvasLayer
## Start screen (D-125): Start run, slow-time toggle, Quit game. Signals only; game_view acts.

signal start_pressed
signal quit_pressed

@onready var _start: Button = $Panel/Box/Start
@onready var _slow: CheckButton = $Panel/Box/SlowTime


func _ready() -> void:
	_start.pressed.connect(start_pressed.emit)
	$Panel/Box/Quit.pressed.connect(quit_pressed.emit)
	_slow.button_pressed = RunFlow.slow_time_placing
	_slow.toggled.connect(func(on: bool) -> void: RunFlow.slow_time_placing = on)
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _on_visibility_changed() -> void:
	if visible:
		_start.grab_focus()
