class_name HordeRenderer
extends Node3D
## Draws enemies (one MultiMeshInstance3D per type) and towers (one more) as billboard
## sprites from the sim arrays (D-087). Never one Node per enemy. View only, no rules.

const CONFIG_PATH := "res://data/render/render_default.json"
const SHADER := preload("res://view/billboard.gdshader")
const CELL_PX: int = 64

## Wall-clock usec of the last fill + upload (diagnostics for task 008).
var last_fill_usec: int = 0
var config: Dictionary
var _driver: SimDriver
var _camera: Camera3D
var _enemy_batcher: HordeBatcher
var _tower_batcher: HordeBatcher
var _enemy_mm: Array[MultiMesh] = []
var _tower_mm: MultiMesh
var _tower_type: PackedInt32Array = PackedInt32Array()


func setup(driver: SimDriver, camera: Camera3D) -> void:
	_driver = driver
	_camera = camera
	config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	assert(config is Dictionary, "HordeRenderer: cannot read %s" % CONFIG_PATH)
	var frames := int(config.walk_frames)
	var types := driver.world.catalog.ids.size()
	var area := driver.world.grid.half_extent
	_enemy_batcher = HordeBatcher.new(types, frames)
	_tower_batcher = HordeBatcher.new(1, 1)
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0.0, 0.5, 0.0)  # bottom edge on the ground
	for t in types:
		var strip := PlaceholderArt.enemy_strip(PlaceholderArt.type_color(t), frames, CELL_PX)
		_enemy_mm.append(_add_batch(quad, strip, frames, float(config.walk_fps),
			float(config.enemy_sprite_height), area))
	var tower := PlaceholderArt.tower_image(Color(0.95, 0.85, 0.3), CELL_PX)
	_tower_mm = _add_batch(quad, tower, 1, 0.0, float(config.tower_sprite_height), area)


func _add_batch(quad: QuadMesh, img: Image, frames: int, fps: float, h: float, area: float) -> MultiMesh:
	img.generate_mipmaps()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("frames", frames)
	mat.set_shader_parameter("fps", fps)
	mat.set_shader_parameter("sprite_size", Vector2(h * img.get_width() / frames / img.get_height(), h))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D  # format changes only while instance_count is 0
	mm.use_custom_data = true
	mm.mesh = quad
	# Fixed AABB over the sim area: no recompute per upload, never culled by a stale AABB.
	mm.custom_aabb = AABB(Vector3(-area - h, -h, -area - h), Vector3(2.0 * (area + h), 2.0 * h, 2.0 * (area + h)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
	return mm


func _process(_delta: float) -> void:
	if not _driver:
		return
	var start := Time.get_ticks_usec()
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var cam := _camera.global_transform
	var e := _driver.world.enemies
	_enemy_batcher.fill(e.pos_x, e.pos_z, _driver.prev_x, _driver.prev_z, _driver.alpha(), e.type_id,
		HordeBatcher.make_cull(cam, _camera.size, aspect, float(config.enemy_sprite_height)))
	for t in _enemy_mm.size():
		_upload(_enemy_mm[t], _enemy_batcher, t)
	var towers := _driver.world.towers
	_tower_type.resize(towers.count())  # zeros: one tower batch
	_tower_batcher.fill(towers.pos_x, towers.pos_z, towers.pos_x, towers.pos_z, 0.0, _tower_type,
		HordeBatcher.make_cull(cam, _camera.size, aspect, float(config.tower_sprite_height)))
	_upload(_tower_mm, _tower_batcher, 0)
	last_fill_usec = Time.get_ticks_usec() - start


func _upload(mm: MultiMesh, batcher: HordeBatcher, t: int) -> void:
	if mm.instance_count != batcher.capacity(t):
		mm.instance_count = batcher.capacity(t)
	mm.buffer = batcher.buffers[t]
	mm.visible_instance_count = batcher.counts[t]
