class_name BuildBar
extends HBoxContainer
## Build bar (D-122): one button per run tower with name, price and hotkey. A click selects the
## tower like the slot key (PlayerInput.select_tower). Greyed (still clickable) when gold is
## short, disabled when not RUNNING or paused (D-105). Prices from TowerBuilding.price only.

const GREYED := Color(0.55, 0.55, 0.55, 1.0)

var world: SimWorld
var input: PlayerInput
var _run: RunData
# Last [price, affordable, selected, enabled] shown per button (text rebuilt on change only).
var _shown: Array = []


func setup(w: SimWorld, p_input: PlayerInput) -> void:
	world = w
	input = p_input
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	if input == null:
		return
	if world.run != _run:
		_build()
	var enabled := PlayerInput.can_build(world)
	for s in get_child_count():
		var b: Button = get_child(s)
		var type := world.run.tower_types[s]
		var price := TowerBuilding.price(world, type)
		var state := [price, world.gold >= price, input.selected_tower == world.tower_catalog.ids[type], enabled]
		if state == _shown[s]:
			continue
		_shown[s] = state
		b.text = tr("build.slot").format({"n": s + 1, "name": tr(world.tower_catalog.name_key[type])}) \
				+ "\n" + tr("build.gold").format({"gold": price})
		b.modulate = Color.WHITE if state[1] else GREYED
		b.set_pressed_no_signal(state[2])
		b.disabled = not enabled


func _build() -> void:
	_run = world.run
	for c in get_children():
		c.free()
	_shown.clear()
	if _run == null:
		return
	for type in _run.tower_types:
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE  # the gamepad uses the radial, not GUI focus
		b.pressed.connect(input.select_tower.bind(world.tower_catalog.ids[type]))
		add_child(b)
		_shown.append([])
