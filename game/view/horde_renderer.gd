class_name HordeRenderer
extends Node3D
## Draws enemies (one MultiMeshInstance3D per type) and towers (one per tower type, plus
## husk and bare) as billboard sprites from the sim arrays (D-087). Looks come from
## render data by enemy archetype and tower attack kind (D-120). Never one Node per enemy.

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
var _tower_mm: Array[MultiMesh] = []
## Per-frame batch index of each tower: catalog type, then husk, then bare.
var _tower_batch: PackedInt32Array = PackedInt32Array()
var _flash_ticks: int = 0
## Tallest enemy sprite: cull margin, so a boss never pops at the screen edge.
var _enemy_margin: float = 0.0


static func load_config() -> Dictionary:
	var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	assert(c is Dictionary, "HordeRenderer: cannot read %s" % CONFIG_PATH)
	return c


static func enemy_look(cfg: Dictionary, catalog: EnemyCatalog, t: int) -> Dictionary:
	return cfg.enemy_looks[catalog.archetype[t]]


## type -1 = bare tower.
static func tower_look(cfg: Dictionary, catalog: TowerCatalog, type: int) -> Dictionary:
	if type < 0:
		return cfg.tower_looks.bare
	return cfg.tower_looks[TowerCatalog.Attack.keys()[catalog.attack[type]].to_lower()]


static func rgb(a: Array) -> Color:
	return Color(a[0], a[1], a[2], a[3] if a.size() > 3 else 1.0)


func setup(driver: SimDriver, camera: Camera3D) -> void:
	_driver = driver
	_camera = camera
	config = load_config()
	_flash_ticks = ceili(float(config.fx.flash_sec) * SimWorld.TICK_RATE)
	var frames := int(config.walk_frames)
	var catalog := driver.world.catalog
	var tcat := driver.world.tower_catalog
	var area := driver.world.grid.half_extent
	_enemy_batcher = HordeBatcher.new(catalog.ids.size(), frames)
	_tower_batcher = HordeBatcher.new(tcat.ids.size() + 2, 1)
	var quad := QuadMesh.new()
	quad.center_offset = Vector3(0.0, 0.5, 0.0)  # bottom edge on the ground
	for t in catalog.ids.size():
		var look := enemy_look(config, catalog, t)
		var strip := PlaceholderArt.enemy_strip(rgb(look.color), frames, CELL_PX, look.shape)
		var h := float(config.enemy_sprite_height) * float(look.height_scale)
		_enemy_margin = maxf(_enemy_margin, h)
		_enemy_mm.append(_add_batch(quad, strip, frames, float(config.walk_fps), h, area, config.fx.mark_tint))
	var looks: Array = []
	for type in tcat.ids.size():
		looks.append(tower_look(config, tcat, type))
	looks.append(config.tower_looks.husk)
	looks.append(config.tower_looks.bare)
	for look: Dictionary in looks:
		var img := PlaceholderArt.tower_image(rgb(look.color), CELL_PX, look.shape)
		_tower_mm.append(_add_batch(quad, img, 1, 0.0,
			float(config.tower_sprite_height) * float(look.height_scale), area, config.fx.haste_tint))


func _add_batch(quad: QuadMesh, img: Image, frames: int, fps: float, h: float, area: float,
		tint: Array) -> MultiMesh:
	img.generate_mipmaps()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("frames", frames)
	mat.set_shader_parameter("fps", fps)
	mat.set_shader_parameter("tint", rgb(tint))
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
	var world := _driver.world
	var e := world.enemies
	_enemy_batcher.fill(e.pos_x, e.pos_z, e.prev_x, e.prev_z, _driver.alpha(), e.type_id,
		HordeBatcher.make_cull(cam, _camera.size, aspect, _enemy_margin),
		e.hp, e.hit_tick, world.tick - _flash_ticks, e.mark_until, world.clock)
	for t in _enemy_mm.size():
		_upload(_enemy_mm[t], _enemy_batcher, t)
	var towers := world.towers
	var husk_batch := _tower_mm.size() - 2
	_tower_batch.resize(towers.count())
	for t in towers.count():
		var type := towers.type_id[t]
		_tower_batch[t] = husk_batch + 1 if type < 0 else (husk_batch if towers.husk[t] else type)
	_tower_batcher.fill(towers.pos_x, towers.pos_z, towers.pos_x, towers.pos_z, 0.0, _tower_batch,
		HordeBatcher.make_cull(cam, _camera.size, aspect, float(config.tower_sprite_height)),
		PackedFloat32Array(), PackedInt32Array(), 0, PackedInt32Array(), 0,
		world.run != null and world.clock < world.skills.haste_until)
	for t in _tower_mm.size():
		_upload(_tower_mm[t], _tower_batcher, t)
	last_fill_usec = Time.get_ticks_usec() - start


func _upload(mm: MultiMesh, batcher: HordeBatcher, t: int) -> void:
	if mm.instance_count != batcher.capacity(t):
		mm.instance_count = batcher.capacity(t)
	mm.buffer = batcher.buffers[t]
	mm.visible_instance_count = batcher.counts[t]
