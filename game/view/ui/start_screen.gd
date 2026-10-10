class_name StartScreen
extends CanvasLayer
## Start screen (D-125, D-154): Play (-> hub), slow-time toggle (saved, D-157), Quit game.
## With a suspend save (D-167 rule 4), Play is replaced by Resume and Abandon run; Abandon
## run asks the D-155 confirm (Cancel focused), then records the saved run as a loss.
## A failed restore shows a notice until dismissed (rule 6). Resume is game_view's.

signal start_pressed
signal quit_pressed
signal resume_pressed

@onready var _start: Button = $Panel/Box/Start
@onready var _resume: Button = $Panel/Box/Resume
@onready var _abandon: Button = $Panel/Box/Abandon
@onready var _slow: CheckButton = $Panel/Box/SlowTime
@onready var _box: VBoxContainer = $Panel/Box
@onready var _confirm: VBoxContainer = $Panel/Confirm
@onready var _cancel: Button = $Panel/Confirm/Cancel
@onready var _notice: Panel = $Notice
@onready var _ok: Button = $Notice/Box/OK


func _ready() -> void:
	_start.pressed.connect(start_pressed.emit)
	_resume.pressed.connect(resume_pressed.emit)
	_abandon.pressed.connect(ask)
	_cancel.pressed.connect(close_confirm)
	$Panel/Confirm/Abandon.pressed.connect(confirm)
	_ok.pressed.connect(close_notice)
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
		refresh()


## Play or Resume / Abandon run from the suspend file; the notice while a restore failed.
func refresh() -> void:
	var suspended := SuspendStore.exists(RunFlow.save_dir)
	_start.visible = not suspended
	_resume.visible = suspended
	_abandon.visible = suspended
	_notice.visible = SuspendStore.last_error != ""
	close_confirm()


## Opens the confirm with the loss hearts at the saved clock (0 if the header is unreadable).
func ask() -> void:
	var h := SuspendStore.header(RunFlow.save_dir)
	var n := 0
	if not h.is_empty():
		var run := RunData.load_id(h.run_id, EnemyCatalog.load_dir(), TowerCatalog.load_dir(), h.guardian_id)
		n = MetaProfile.hearts_for(run, false, int(h.clock))
	$Panel/Confirm/Text.text = tr("flow.abandon_confirm").format({"n": n})
	_box.visible = false
	_confirm.visible = true
	_cancel.grab_focus()


func close_confirm() -> void:
	_confirm.visible = false
	_box.visible = true
	_focus()


## Records the suspended run as abandoned (a loss at the saved clock, D-165, D-166).
func confirm() -> void:
	SuspendStore.abandon(RunFlow.save_dir)
	refresh()


func close_notice() -> void:
	SuspendStore.last_error = ""
	_notice.visible = false
	_focus()


func _focus() -> void:
	if _notice.visible:
		_ok.grab_focus()
	elif _resume.visible:
		_resume.grab_focus()
	else:
		_start.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and _confirm.visible and event.is_action_pressed(&"ui_cancel"):
		close_confirm()
		get_viewport().set_input_as_handled()
