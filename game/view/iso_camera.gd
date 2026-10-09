class_name IsoCamera
extends Node3D
## Camera rig at the focus point on the ground, with a child orthographic Camera3D.
## Tunables in data/camera (D-086). Reads no device: PlayerInput calls pan, zoom_step and
## recentre (D-119, docs/09_CONTROLS.md). View state only, no game rules.

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


static func step_zoom(index: int, dir: int, n: int) -> int:
	return clampi(index + dir, 0, n - 1)


func _ready() -> void:
	config = load_config()
	rotation.y = deg_to_rad(config.yaw_deg)
	var pitch := deg_to_rad(config.pitch_deg)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * float(config.distance)
	_camera.look_at(global_position)
	set_zoom(int(config.default_zoom))


## Moves the focus by a screen-axis direction (x right, y down) for one frame.
func pan(dir: Vector2, delta: float) -> void:
	if dir == Vector2.ZERO:
		return
	var zoom_scale := _camera.size / float(config.zoom_sizes[config.default_zoom])
	# Rig yaw maps screen up to the far side of the ground.
	var move := basis * Vector3(dir.x, 0.0, dir.y).limit_length(1.0)
	move *= float(config.pan_speed) * zoom_scale * delta
	var p := clamp_focus(Vector2(position.x + move.x, position.z + move.z),
		config.bounds_radius + config.bounds_margin)
	position = Vector3(p.x, 0.0, p.y)


## -1 zooms in, +1 zooms out, clamped to the zoom sizes.
func zoom_step(dir: int) -> void:
	set_zoom(step_zoom(zoom_index, dir, config.zoom_sizes.size()))


## Focus back on the Guardian, instantly.
func recentre() -> void:
	position = Vector3.ZERO


## Ground point (x, z) at the screen centre.
func focus() -> Vector2:
	return Vector2(position.x, position.z)


func set_zoom(index: int) -> void:
	zoom_index = index
	_camera.size = config.zoom_sizes[index]
