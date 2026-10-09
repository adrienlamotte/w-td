class_name EndScreen
extends CanvasLayer
## Win / lose screen (D-125): title and time survived, Restart, Main menu. Reads the sim.

signal restart_pressed
signal main_menu_pressed

var world: SimWorld
var _state: int = -1

@onready var _title: Label = $Panel/Box/Title
@onready var _time: Label = $Panel/Box/Time
@onready var _restart: Button = $Panel/Box/Restart


func _ready() -> void:
	visible = false
	_restart.pressed.connect(restart_pressed.emit)
	$Panel/Box/MainMenu.pressed.connect(main_menu_pressed.emit)


func setup(w: SimWorld) -> void:
	world = w
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var state: int = world.run_state if world != null else -1
	if state == _state:
		return
	_state = state
	visible = state == SimWorld.RunState.WON or state == SimWorld.RunState.LOST
	if not visible:
		return
	_title.text = "flow.won" if state == SimWorld.RunState.WON else "flow.lost"
	_time.text = tr("flow.time_survived").format({"time": Hud.clock_text(world.clock)})
	_restart.grab_focus()
