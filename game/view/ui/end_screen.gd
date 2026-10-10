class_name EndScreen
extends CanvasLayer
## Win / lose screen (D-125, D-154 rule 5): title, time survived, hearts earned, the new
## unlock on a win; Continue -> hub. It writes the run end to the profile once, on the
## first refresh that sees WON or LOST (the bench never sets it up, so never writes).

signal continue_pressed

var world: SimWorld
var _state: int = -1
var _recorded: bool = false

@onready var _title: Label = $Panel/Box/Title
@onready var _time: Label = $Panel/Box/Time
@onready var _hearts: Label = $Panel/Box/Hearts
@onready var _unlock: Label = $Panel/Box/Unlock
@onready var _continue: Button = $Panel/Box/Continue


func _ready() -> void:
	visible = false
	_continue.pressed.connect(func() -> void:
		RunFlow.screen = RunFlow.Screen.HUB
		continue_pressed.emit())


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
	if not _recorded:
		_recorded = true
		var result := ProfileStore.record_run_end(world, RunFlow.save_dir)
		_hearts.text = tr("flow.hearts_earned").format({"n": result.hearts})
		var w: String = result.unlocked
		_unlock.visible = w != ""
		if w != "":
			var cat := world.meta if world.meta else MetaCatalog.load_dir()
			_unlock.text = tr("flow.unlocked").format({"name": tr(cat.waifu_name_key[w])})
	_continue.grab_focus()
