class_name HordeBatcher
extends RefCounted
## Packs sim positions into MultiMesh buffers, one batch per type (D-087). No Node,
## testable headless. Per instance: TRANSFORM_3D (12 floats, row-major 3x4, identity
## basis: the shader sizes and orients the quad) + 4 custom floats (r = frame offset,
## g = flip, b = 1 while hit-flashing, D-120; a = 1 while tinted: marked enemy or every
## tower under Crescendo, D-163). Corpses (hp <= 0) are skipped (D-120).
## Visible instances are packed from slot 0; buffers grow by doubling, never shrink.

const STRIDE: int = 16
const INITIAL_CAPACITY: int = 64
## Squared jump above which the view snaps to the current position instead of
## interpolating (no enemy moves 2 units per tick; hides swap-remove and recycling).
const SNAP_DIST_SQ: float = 4.0

var counts: PackedInt32Array = PackedInt32Array()
var buffers: Array[PackedFloat32Array] = []
var walk_frames: int


func _init(batches: int, p_walk_frames: int) -> void:
	walk_frames = p_walk_frames
	counts.resize(batches)
	for t in batches:
		buffers.append(_grow(PackedFloat32Array(), INITIAL_CAPACITY))


## Cull values for an orthographic camera: camera-space x and y of a ground point
## (x, 0, z) are a*x + b*z + c; [ax, bx, cx, ay, by, cy, half_w, half_h], halves grown by margin.
static func make_cull(cam: Transform3D, size: float, aspect: float, margin: float) -> PackedFloat32Array:
	var inv := cam.affine_inverse()
	return PackedFloat32Array([inv.basis.x.x, inv.basis.z.x, inv.origin.x,
		inv.basis.x.y, inv.basis.z.y, inv.origin.y,
		size * 0.5 * aspect + margin, size * 0.5 + margin])


func capacity(t: int) -> int:
	return buffers[t].size() / STRIDE


func fill(xs: PackedFloat32Array, zs: PackedFloat32Array, prev_x: PackedFloat32Array,
		prev_z: PackedFloat32Array, alpha: float, type_id: PackedInt32Array, cull: PackedFloat32Array,
		hp: PackedFloat32Array = PackedFloat32Array(), hit_tick: PackedInt32Array = PackedInt32Array(),
		flash_from: int = 0, mark_until: PackedInt32Array = PackedInt32Array(), clock: int = 0,
		tint_all: bool = false) -> void:
	var ax := cull[0]; var bx := cull[1]; var cx := cull[2]
	var ay := cull[3]; var by := cull[4]; var cy := cull[5]
	var hw := cull[6]; var hh := cull[7]
	var n := xs.size()
	var n_prev := mini(prev_x.size(), n)
	var has_hp := hp.size() == n  # towers pass none: never skipped, never flash
	var has_mark := mark_until.size() == n
	var all_tint := 1.0 if tint_all else 0.0
	# ponytail: one pass over all enemies per batch, because writing buffers[t][k] in one
	# pass would copy the packed array on every write. Sort by type if many types appear.
	for t in counts.size():
		if not type_id.has(t):  # native scan: skips the GDScript pass for absent types
			counts[t] = 0
			continue
		var buf := buffers[t]
		buffers[t] = PackedFloat32Array()  # sole owner of buf: writes stay in place
		var cap := buf.size() / STRIDE
		var c := 0
		for i in n:
			if type_id[i] != t:
				continue
			if has_hp and hp[i] <= 0.0:
				continue  # corpse, removed at the next DEATHS phase
			var x := xs[i]
			var z := zs[i]
			if i < n_prev:
				var px := prev_x[i]
				var pz := prev_z[i]
				if (x - px) * (x - px) + (z - pz) * (z - pz) <= SNAP_DIST_SQ:
					x = px + (x - px) * alpha
					z = pz + (z - pz) * alpha
			var sx := ax * x + bx * z + cx
			if absf(sx) > hw:
				continue
			if absf(ay * x + by * z + cy) > hh:
				continue
			if c == cap:
				cap *= 2
				buf = _grow(buf, cap)
			var k := c * STRIDE
			buf[k + 3] = x
			buf[k + 11] = z
			buf[k + 12] = i % walk_frames
			# Faces the Guardian: flipped when right of it on screen.
			buf[k + 13] = 1.0 if sx > cx else 0.0
			buf[k + 14] = 1.0 if has_hp and hit_tick[i] >= flash_from else 0.0
			buf[k + 15] = 1.0 if has_mark and mark_until[i] > clock else all_tint
			c += 1
		counts[t] = c
		buffers[t] = buf


static func _grow(buf: PackedFloat32Array, cap: int) -> PackedFloat32Array:
	var old := buf.size() / STRIDE
	buf.resize(cap * STRIDE)
	for s in range(old, cap):
		buf[s * STRIDE] = 1.0
		buf[s * STRIDE + 5] = 1.0
		buf[s * STRIDE + 10] = 1.0
	return buf
