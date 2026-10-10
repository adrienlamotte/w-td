class_name StartScreen
extends CanvasLayer
## Start screen (D-125, D-154): Play (-> hub), slow-time toggle (saved, D-157), Quit game.
## Signals only; game_view acts.

signal start_pressed
signal quit_pressed

@onready var _start: Button = $Panel/Box/Start
@onready var _slow: CheckButton = $Panel/Box/SlowTime


func _ready() -> void:
	_start.pressed.connect(start_pressed.emit)
	$Panel/Box/Quit.pressed.connect(quit_pressed.emit)
	_slow.toggled.connect(func(on: bool) -> void:
		RunFlow.slow_time_placing = on
		SettingsStore.save(RunFlow.save_dir))
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


# game_view loads the settings after this node's _ready: read the toggle on every show.
func _on_visibility_changed() -> void:
	if visible:
		_slow.set_pressed_no_signal(RunFlow.slow_time_placing)
		_start.grab_focus()
