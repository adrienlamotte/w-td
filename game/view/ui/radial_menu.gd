class_name RadialMenu
extends Control
## Gamepad radial build menu (D-046, D-122): shown while PlayerInput.menu_open, one slice per
## buildable tower (world.tower_types, up to 8), slice 0 centred at the top, clockwise.
## Releasing on a slice selects its tower, releasing in the centre keeps the selection.
## Prices from TowerBuilding.price only.

const BG := Color(0.0, 0.0, 0.0, 0.55)
const HOVER := Color(1.0, 1.0, 1.0, 0.35)
const GREYED := Color(0.55, 0.55, 0.55, 1.0)
const ARC_POINTS: int = 16

var world: SimWorld
var input: PlayerInput
var radius: float = 260.0
var deadzone: float = 0.4
var hover: int = -1
var _labels: Array[Label] = []


## Slice under dir for n slices (0 at the top, clockwise; screen y down), -1 inside the deadzone.
static func slice(dir: Vector2, n: int, p_deadzone: float) -> int:
	if n <= 0 or dir.length() < p_deadzone:
		return -1
	var a := fposmod(dir.angle() + PI / 2.0 + PI / n, TAU)
	return mini(floori(a / (TAU / n)), n - 1)


func setup(w: SimWorld, p_input: PlayerInput, config: Dictionary) -> void:
	world = w
	input = p_input
	radius = float(config.radial_radius_px)
	deadzone = float(config.radial_deadzone)
	input.build_menu_closed.connect(_on_closed)


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	visible = input != null and input.menu_open and world.run != null
	if not visible:
		return
	var types := world.tower_types
	if _labels.size() != types.size():
		_build_labels(types.size())
	hover = slice(input.menu_dir, types.size(), deadzone)
	for s in types.size():
		var price := TowerBuilding.price(world, types[s])
		var l := _labels[s]
		l.text = tr(world.tower_catalog.name_key[types[s]]) + "\n" + tr("build.gold").format({"gold": price})
		l.modulate = Color.WHITE if world.gold >= price else GREYED
		var a := -PI / 2.0 + TAU * s / types.size()
		l.size = l.get_combined_minimum_size()
		l.position = size / 2.0 + Vector2.from_angle(a) * radius * 0.6 - l.size / 2.0
	queue_redraw()


func _draw() -> void:
	var n := _labels.size()
	var c := size / 2.0
	for s in n:
		var a0 := -PI / 2.0 + TAU * (s - 0.5) / n
		var pts := PackedVector2Array([c])
		for k in ARC_POINTS + 1:
			pts.append(c + Vector2.from_angle(a0 + TAU / n * k / ARC_POINTS) * radius)
		draw_colored_polygon(pts, HOVER if s == hover else BG)
		draw_line(c, pts[1], Color.WHITE, 2.0)


func _on_closed(dir: Vector2) -> void:
	if world.run == null:
		return
	var s := slice(dir, world.tower_types.size(), deadzone)
	if s >= 0:
		input.select_tower(world.tower_catalog.ids[world.tower_types[s]])


func _build_labels(n: int) -> void:
	for l in _labels:
		l.free()
	_labels.clear()
	for s in n:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_labels.append(l)
