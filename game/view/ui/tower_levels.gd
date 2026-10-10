class_name TowerLevels
extends Control
## "Lv n" label above every tower (live or husk) whose type can level up (D-151). Reads the
## sim, writes none. A label's text is rebuilt only when its level changes; positions follow
## the camera every frame.

var world: SimWorld
var camera: Camera3D
## World height of the label anchor above the tower (data/ui level_label_height).
var height: float = 0.0
var _labels: Array[Label] = []
var _shown: Array[int] = []  # level shown per pool label


## {uid, level, x, z} per tower whose type has max_level > 1, in tower order.
static func labels(w: SimWorld) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if w == null or w.run == null:
		return out
	var towers := w.towers
	for t in towers.count():
		if w.tower_catalog.max_level[towers.type_id[t]] > 1:
			out.append({"uid": towers.uid[t], "level": towers.level[t],
				"x": towers.pos_x[t], "z": towers.pos_z[t]})
	return out


func setup(w: SimWorld, cam: Camera3D) -> void:
	world = w
	camera = cam
	height = float(PlacementGhost.load_config().level_label_height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var list := labels(world)
	while _labels.size() < list.size():
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_labels.append(l)
		_shown.append(-1)
	while _labels.size() > list.size():
		_labels.pop_back().free()
		_shown.pop_back()
	for i in list.size():
		var d: Dictionary = list[i]
		var l := _labels[i]
		if _shown[i] != d.level:
			_shown[i] = d.level
			l.text = tr("tower.level").format({"level": d.level})
			l.size = Vector2.ZERO  # shrink to the text
		var p := camera.unproject_position(Vector3(d.x, height, d.z))
		l.position = p - Vector2(l.size.x / 2.0, l.size.y)
