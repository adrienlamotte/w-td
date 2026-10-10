class_name FxLayer
extends Node3D
## Draws the FxPool (D-120) and the FxOverlays (D-163): discs (puffs, coins, sparks,
## relationship markers) in one MultiMesh, ribbons (shots, repair beams) and rings (skill
## blasts, aura and bounty rings) in one ImmediateMesh rebuilt per frame, the Shield and
## Stand Firm discs and the Guardian hit flash. No Node per effect. View only, no rules.

const DISC_SHADER := preload("res://view/fx.gdshader")
const STRIDE: int = 16  # TRANSFORM_3D (12) + COLOR (4)
const RIBBON_Y: float = 0.5
const COIN_ARC: float = 2.0
const RING_SEGMENTS: int = 32

var pool: FxPool
var overlays: FxOverlays
var _world: SimWorld
var _discs: MultiMesh
var _buf: PackedFloat32Array = PackedFloat32Array()
var _ribbons: ImmediateMesh = ImmediateMesh.new()
var _shield: MeshInstance3D
var _guard: MeshInstance3D
var _link_y: float
var _guardian_mat: StandardMaterial3D
var _guardian_color: Color


func setup(driver: SimDriver, guardian: MeshInstance3D) -> void:
	_world = driver.world
	var cfg := HordeRenderer.load_config()
	pool = FxPool.new(cfg, _world)
	overlays = FxOverlays.new(cfg)
	_link_y = float(pool.fx.link_height)
	var discs := pool.max_effects + FxOverlays.MAX_OVERLAYS
	_discs = MultiMesh.new()
	_discs.transform_format = MultiMesh.TRANSFORM_3D
	_discs.use_colors = true
	_discs.mesh = QuadMesh.new()
	_discs.instance_count = discs
	_discs.visible_instance_count = 0
	var area := _world.grid.half_extent + 4.0
	_discs.custom_aabb = AABB(Vector3(-area, -1.0, -area), Vector3(2.0 * area, 2.0 + maxf(COIN_ARC, _link_y), 2.0 * area))
	_buf.resize(discs * STRIDE)
	var disc_mat := ShaderMaterial.new()
	disc_mat.shader = DISC_SHADER
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _discs
	mmi.material_override = disc_mat
	add_child(mmi)
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.vertex_color_use_as_albedo = true
	flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ribbons := MeshInstance3D.new()
	ribbons.mesh = _ribbons
	ribbons.material_override = flat
	add_child(ribbons)
	_shield = _flat_disc(flat, float(pool.fx.shield_radius), pool.fx.shield_color)
	_guard = _flat_disc(flat, float(pool.fx.guard_radius), pool.fx.guard_color)
	_guardian_mat = (guardian.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	_guardian_color = _guardian_mat.albedo_color
	guardian.material_override = _guardian_mat


## SimDriver.on_step: events are only valid until the next step.
func on_step() -> void:
	pool.read_events(_world)


func _process(delta: float) -> void:
	if pool == null:
		return
	pool.advance(delta)
	var s := _world.skills
	_shield.visible = _world.clock < s.shield_until and s.shield_left > 0.0
	_guard.visible = _world.clock < s.guard_until
	overlays.read_state(_world)
	_guardian_mat.albedo_color = Color.WHITE if pool.guardian_flash > 0.0 else _guardian_color
	_ribbons.clear_surfaces()
	var c := 0
	var ribbons := false
	for i in pool.count():
		var k := pool.kind[i]
		var p := pool.progress(i)
		var col := pool.color[i]
		if k == FxPool.Kind.SHOT or k == FxPool.Kind.BEAM or k == FxPool.Kind.RING:
			if not ribbons:
				_ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				ribbons = true
			col.a *= 1.0 - p
			_ribbons.surface_set_color(col)
			if k == FxPool.Kind.RING:
				_ring(0.0, 0.0, pool.x1[i] * p, pool.size[i])
			else:
				_ribbon(pool.x0[i], pool.z0[i], pool.x1[i], pool.z1[i], pool.size[i])
			continue
		var x := pool.x0[i]
		var z := pool.z0[i]
		var y := RIBBON_Y
		var sz := pool.size[i]
		if k == FxPool.Kind.COIN:
			x = lerpf(x, pool.x1[i], p)
			z = lerpf(z, pool.z1[i], p)
			y += sin(p * PI) * COIN_ARC
		else:  # PUFF, SPARK: grow and fade
			sz *= 0.5 + 0.5 * p
			col.a *= 1.0 - p
		_disc(c, x, y, z, sz, col)
		c += 1
	for i in overlays.count():
		if overlays.kind[i] == FxOverlays.Kind.LINK:
			_disc(c, overlays.x[i], _link_y, overlays.z[i], overlays.size[i], overlays.color[i])
			c += 1
			continue
		if not ribbons:
			_ribbons.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			ribbons = true
		_ribbons.surface_set_color(overlays.color[i])
		_ring(overlays.x[i], overlays.z[i], overlays.r[i], overlays.size[i])
	if ribbons:
		_ribbons.surface_end()
	_discs.buffer = _buf
	_discs.visible_instance_count = c


# Flat quad on y = RIBBON_Y from (ax, az) to (bx, bz).
func _ribbon(ax: float, az: float, bx: float, bz: float, width: float) -> void:
	var side := Vector2(bz - az, ax - bx).normalized() * width * 0.5
	var a0 := Vector3(ax + side.x, RIBBON_Y, az + side.y)
	var a1 := Vector3(ax - side.x, RIBBON_Y, az - side.y)
	var b0 := Vector3(bx + side.x, RIBBON_Y, bz + side.y)
	var b1 := Vector3(bx - side.x, RIBBON_Y, bz - side.y)
	for v in [a0, a1, b0, b0, a1, b1]:
		_ribbons.surface_add_vertex(v)


func _disc(c: int, x: float, y: float, z: float, sz: float, col: Color) -> void:
	var o := c * STRIDE
	_buf[o] = sz; _buf[o + 1] = 0.0; _buf[o + 2] = 0.0; _buf[o + 3] = x
	_buf[o + 4] = 0.0; _buf[o + 5] = sz; _buf[o + 6] = 0.0; _buf[o + 7] = y
	_buf[o + 8] = 0.0; _buf[o + 9] = 0.0; _buf[o + 10] = sz; _buf[o + 11] = z
	_buf[o + 12] = col.r; _buf[o + 13] = col.g; _buf[o + 14] = col.b; _buf[o + 15] = col.a


# Translucent disc at the Guardian (Shield, Stand Firm), hidden until its state is on.
func _flat_disc(flat: StandardMaterial3D, radius: float, rgba: Array) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.05
	var mat := flat.duplicate() as StandardMaterial3D
	mat.albedo_color = HordeRenderer.rgb(rgba)
	mat.vertex_color_use_as_albedo = false
	disc.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.position.y = RIBBON_Y
	mi.visible = false
	add_child(mi)
	return mi


# Flat annulus centred on (cx, cz), outer radius r.
func _ring(cx: float, cz: float, r: float, width: float) -> void:
	var inner := maxf(0.0, r - width)
	for n in RING_SEGMENTS:
		var a := TAU * n / RING_SEGMENTS
		var b := TAU * (n + 1) / RING_SEGMENTS
		var o0 := Vector3(cx + cos(a) * r, RIBBON_Y, cz + sin(a) * r)
		var o1 := Vector3(cx + cos(b) * r, RIBBON_Y, cz + sin(b) * r)
		var i0 := Vector3(cx + cos(a) * inner, RIBBON_Y, cz + sin(a) * inner)
		var i1 := Vector3(cx + cos(b) * inner, RIBBON_Y, cz + sin(b) * inner)
		for v in [o0, i0, o1, o1, i0, i1]:
			_ribbons.surface_add_vertex(v)
