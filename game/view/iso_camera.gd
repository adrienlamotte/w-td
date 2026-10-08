class_name IsoCamera
extends Node3D
## Camera rig at the focus point on the ground, with a child orthographic Camera3D.
## Tunables in data/camera (D-086). PC controls (D-041): WASD/arrows and edge scroll
## pan, the mouse wheel steps through the 3 zoom sizes. View state only, no game rules.

const CONFIG_PATH := "res://data/camera/camera_default.json"

var config: Dictionary
var zoom_index: int = 0
@onready var _camera: Camera3D = $Camera3D


static func load_config(path: String = CONFIG_PATH) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(data is Dictionary, "IsoCamera: cannot read %s" % path)
	return data


## Keeps a ground point (x, z) within max_r of the Guardian.
static func clamp_focus(p: Vector2, max_r: float) -> Vector2:
	return p.limit_length(max_r)


## Pan direction from the mouse near a viewport edge, in screen axes (x right, y down).
static func edge_dir(mouse: Vector2, viewport: Vector2, margin: float) -> Vector2:
	var d := Vector2.ZERO
	if mouse.x < margin: d.x = -1.0
	elif mouse.x > viewport.x - margin: d.x = 1.0
	if mouse.y < margin: d.y = -1.0
	elif mouse.y > viewport.y - margin: d.y = 1.0
	return d


static func step_zoom(index: int, dir: int, n: int) -> int:
	return clampi(index + dir, 0, n - 1)


func _ready() -> void:
	config = load_config()
	rotation.y = deg_to_rad(config.yaw_deg)
	var pitch := deg_to_rad(config.pitch_deg)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * float(config.distance)
	_camera.look_at(global_position)
	_set_zoom(int(config.default_zoom))


func _process(delta: float) -> void:
	var dir := Input.get_vector("cam_pan_left", "cam_pan_right", "cam_pan_up", "cam_pan_down")
	var vp := get_viewport()
	var mouse := vp.get_mouse_position()
	var size := vp.get_visible_rect().size
	if get_window().has_focus() and Rect2(Vector2.ZERO, size).has_point(mouse):
		dir += edge_dir(mouse, size, config.edge_scroll_px)
	if dir == Vector2.ZERO:
		return
	var zoom_scale := _camera.size / float(config.zoom_sizes[config.default_zoom])
	# Rig yaw maps screen up to the far side of the ground.
	var move := basis * Vector3(dir.x, 0.0, dir.y).limit_length(1.0)
	move *= float(config.pan_speed) * zoom_scale * delta
	var focus := clamp_focus(Vector2(position.x + move.x, position.z + move.z),
		config.bounds_radius + config.bounds_margin)
	position = Vector3(focus.x, 0.0, focus.y)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_zoom_in"):
		_set_zoom(step_zoom(zoom_index, -1, config.zoom_sizes.size()))
	elif event.is_action_pressed("cam_zoom_out"):
		_set_zoom(step_zoom(zoom_index, 1, config.zoom_sizes.size()))


func _set_zoom(index: int) -> void:
	zoom_index = index
	_camera.size = config.zoom_sizes[index]
