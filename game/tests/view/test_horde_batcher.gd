extends GutTest

const S := HordeBatcher.STRIDE

var cull: PackedFloat32Array


func before_each() -> void:
	# Camera 10 above the ground looking straight down: screen x = world x, screen y = -world z.
	var cam := Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 10, 0))
	cull = HordeBatcher.make_cull(cam, 10.0, 2.0, 1.0)  # half extents 11 x 6


func test_fill_interpolates_culls_flips_and_snaps() -> void:
	var b := HordeBatcher.new(2, 4)
	var xs := PackedFloat32Array([2, -3, 100, 5])
	var zs := PackedFloat32Array([0, 1, 0, 0])
	var px := PackedFloat32Array([0, -3, 100, 0])
	var pz := PackedFloat32Array([0, 1, 0, 0])
	b.fill(xs, zs, px, pz, 0.5, PackedInt32Array([0, 1, 0, 0]), cull)
	assert_eq(b.counts, PackedInt32Array([2, 1]), "enemy 2 is off-screen")
	var b0 := b.buffers[0]
	assert_almost_eq(b0[3], 1.0, 1e-5, "interpolated x")
	assert_eq(b0[12], 0.0, "frame offset of enemy 0")
	assert_eq(b0[13], 1.0, "right of the Guardian: flipped")
	assert_almost_eq(b0[S + 3], 5.0, 1e-5, "jump above snap distance: current position")
	assert_eq(b0[S + 12], 3.0, "frame offset of enemy 3")
	var b1 := b.buffers[1]
	assert_almost_eq(b1[3], -3.0, 1e-5)
	assert_almost_eq(b1[11], 1.0, 1e-5)
	assert_eq(b1[12], 1.0)
	assert_eq(b1[13], 0.0, "left of the Guardian: not flipped")


func test_growth_keeps_instances_and_identity() -> void:
	var b := HordeBatcher.new(1, 8)
	var n := HordeBatcher.INITIAL_CAPACITY + 36
	var xs := PackedFloat32Array()
	for i in n:
		xs.append(i * 0.01)
	var zs := PackedFloat32Array()
	zs.resize(n)
	var types := PackedInt32Array()
	types.resize(n)
	b.fill(xs, zs, PackedFloat32Array(), PackedFloat32Array(), 0.0, types, cull)
	assert_eq(b.counts[0], n)
	assert_eq(b.capacity(0), HordeBatcher.INITIAL_CAPACITY * 2)
	var buf := b.buffers[0]
	assert_almost_eq(buf[10 * S + 3], 0.1, 1e-5, "earlier instance intact")
	assert_almost_eq(buf[(n - 1) * S + 3], (n - 1) * 0.01, 1e-5)
	var last := (b.capacity(0) - 1) * S
	assert_eq([buf[last], buf[last + 5], buf[last + 10]], [1.0, 1.0, 1.0], "identity basis in new slots")


func test_skips_corpses_and_flags_flash() -> void:
	var b := HordeBatcher.new(1, 4)
	var xs := PackedFloat32Array([1, 2, 3])
	var zs := PackedFloat32Array([0, 0, 0])
	b.fill(xs, zs, xs, zs, 0.0, PackedInt32Array([0, 0, 0]), cull,
		PackedFloat32Array([5, 0, 5]), PackedInt32Array([10, 10, 2]), 8)
	assert_eq(b.counts[0], 2, "corpse not packed")
	var buf := b.buffers[0]
	assert_almost_eq(buf[3], 1.0, 1e-5)
	assert_eq(buf[14], 1.0, "hit at tick 10: flashing")
	assert_almost_eq(buf[S + 3], 3.0, 1e-5)
	assert_eq(buf[S + 14], 0.0, "hit at tick 2: not flashing")


func test_mark_flag_tints_only_active_marks() -> void:
	var b := HordeBatcher.new(1, 4)
	var xs := PackedFloat32Array([1, 2, 3])
	var zs := PackedFloat32Array([0, 0, 0])
	b.fill(xs, zs, xs, zs, 0.0, PackedInt32Array([0, 0, 0]), cull,
		PackedFloat32Array([5, 5, 5]), PackedInt32Array([0, 0, 0]), 8,
		PackedInt32Array([50, 40, 0]), 40)
	var buf := b.buffers[0]
	assert_eq([buf[15], buf[S + 15], buf[2 * S + 15]], [1.0, 0.0, 0.0], "marked, expired, never marked")


func test_tint_all_flags_every_tower() -> void:
	var b := HordeBatcher.new(1, 1)
	var xs := PackedFloat32Array([1, 2])
	var zs := PackedFloat32Array([0, 0])
	var types := PackedInt32Array([0, 0])
	b.fill(xs, zs, xs, zs, 0.0, types, cull, PackedFloat32Array(), PackedInt32Array(), 0,
		PackedInt32Array(), 0, true)
	assert_eq([b.buffers[0][15], b.buffers[0][S + 15]], [1.0, 1.0])
	b.fill(xs, zs, xs, zs, 0.0, types, cull)
	assert_eq([b.buffers[0][15], b.buffers[0][S + 15]], [0.0, 0.0], "cleared when Crescendo ends")
