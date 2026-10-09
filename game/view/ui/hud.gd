class_name Hud
extends CanvasLayer
## In-run HUD (D-121): reads sim state each frame, writes none. Text is rebuilt only
## when the value behind it changed. Strings are localisation keys (game/loc/strings.csv).

var world: SimWorld
# Last value shown per label (no per-frame string churn).
var _last: Dictionary = {}
var _skill_state: Array[Label] = []
var _skill_bar: Array[ProgressBar] = []

@onready var _hp_bar: ProgressBar = $Root/TopLeft/HpBar
@onready var _hp: Label = $Root/TopLeft/Hp
@onready var _clock: Label = $Root/TopCentre/Clock
@onready var _wave: Label = $Root/TopCentre/Wave
@onready var _gold: Label = $Root/TopRight/Gold
@onready var _skills: HBoxContainer = $Root/Skills
@onready var _paused: Label = $Root/Paused


func setup(w: SimWorld) -> void:
	world = w
	refresh()


## Whole seconds as m:ss.
static func mmss(sec: int) -> String:
	return "%d:%02d" % [sec / 60, sec % 60]


## Run clock text (m:ss) for a tick count.
static func clock_text(ticks: int) -> String:
	return mmss(ticks / SimWorld.TICK_RATE)


## Whole seconds until `ready_at` (rounded up), 0 when ready.
static func seconds_left(ready_at: int, clock: int) -> int:
	return maxi(0, ceili(float(ready_at - clock) / SimWorld.TICK_RATE))


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	visible = world != null and world.run != null
	if not visible:
		return
	var run := world.run
	if _skill_state.size() != run.skill_ids.size():
		_build_skills(run)
	_hp_bar.value = world.guardian_hp / run.guardian_hp
	var hp := ceili(world.guardian_hp)
	if _changed(_hp, hp):
		_hp.text = tr("hud.hp").format({"hp": hp, "max": ceili(run.guardian_hp)})
	if _changed(_clock, world.clock / SimWorld.TICK_RATE):
		_clock.text = clock_text(world.clock)
	var tl := WaveSpawner.timeline(world.clock, run)
	var left := seconds_left(world.clock + tl.z, world.clock)
	# One int per shown state: wave number, or break countdown (negative).
	if _changed(_wave, -1 - left if tl.y else tl.x):
		_wave.text = tr("hud.break").format({"time": mmss(left)}) if tl.y \
				else tr("hud.wave").format({"n": tl.x + 1})
	if _changed(_gold, world.gold):
		_gold.text = tr("hud.gold").format({"value": world.gold})
	for i in _skill_state.size():
		var ready_at := world.skills.ready_at[i]
		var s := seconds_left(ready_at, world.clock)
		_skill_bar[i].value = 1.0 - float(maxi(0, ready_at - world.clock)) / maxi(1, run.skill_cooldown[i])
		if _changed(_skill_state[i], s):
			_skill_state[i].text = tr("hud.ready") if s == 0 else tr("hud.seconds").format({"value": s})
	_paused.visible = world.paused


func _changed(label: Label, value: int) -> bool:
	if _last.get(label) == value:
		return false
	_last[label] = value
	return true


# One panel per skill slot: name, key hint, state, cooldown bar.
func _build_skills(run: RunData) -> void:
	for c in _skills.get_children():
		c.free()
	_skill_state.clear()
	_skill_bar.clear()
	_last.clear()
	for i in run.skill_ids.size():
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		for key in [run.skill_name_key[i], "hud.hint.skill_%d" % (i + 1)]:
			var l := Label.new()
			l.text = key  # auto-translated
			box.add_child(l)
		var state := Label.new()
		box.add_child(state)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(280, 24)
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(bar)
		_skills.add_child(panel)
		_skill_state.append(state)
		_skill_bar.append(bar)
