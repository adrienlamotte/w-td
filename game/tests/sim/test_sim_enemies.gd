extends GutTest

const SWARMER := "enemy_swarmer_01"  # catalog sorted by id: type 0 is not the swarmer

var world: SimWorld
var sw: int


func before_each() -> void:
	world = SimWorld.new(1)
	sw = world.catalog.type_of(SWARMER)


func test_spawn_ring_count_and_distance() -> void:
	world.spawn_ring(sw, 1000, 30.0)
	assert_eq(world.enemies.count(), 1000)
	for i in 1000:
		var x := world.enemies.pos_x[i]
		var z := world.enemies.pos_z[i]
		assert_almost_eq(sqrt(x * x + z * z), 30.0, 1e-3)


func test_remove_middle_swaps_last_in() -> void:
	var e := world.enemies
	for i in 3:
		e.add(i, float(i), float(i) + 10.0, float(i) + 20.0)
	e.state[2] = SimEnemies.State.ATTACKING
	e.anim_frame[2] = 7
	e.cooldown[2] = 9
	e.mark_gold[2] = 3
	e.mark_until[2] = 77
	e.remove(1)
	assert_eq(e.count(), 2)
	assert_eq(e.pos_x[1], 2.0)
	assert_eq(e.pos_z[1], 12.0)
	assert_eq(e.hp[1], 22.0)
	assert_eq(e.type_id[1], 2)
	assert_eq(e.state[1], SimEnemies.State.ATTACKING)
	assert_eq(e.anim_frame[1], 7)
	assert_eq(e.cooldown[1], 9)
	assert_eq([e.mark_gold[1], e.mark_until[1]], [3, 77])
	for arr in [e.pos_x, e.pos_z, e.hp, e.type_id, e.state, e.anim_frame, e.cooldown, e.mark_gold, e.mark_until]:
		assert_eq(arr.size(), 2)


func test_remove_last() -> void:
	var e := world.enemies
	e.add(0, 1.0, 1.0, 1.0)
	e.add(0, 2.0, 2.0, 2.0)
	e.remove(1)
	assert_eq(e.count(), 1)
	assert_eq(e.pos_x[0], 1.0)


func test_presentation_fields_follow_remove() -> void:
	var e := world.enemies
	for i in 3:
		e.add(i, float(i), float(i) + 10.0, 1.0)
	assert_eq([e.prev_x[2], e.prev_z[2]], [2.0, 12.0], "add: prev = spawn position")
	assert_eq(e.hit_tick[2], SimEnemies.NEVER_HIT)
	e.prev_x[2] = 5.0
	e.prev_z[2] = 6.0
	e.hit_tick[2] = 42
	e.remove(1)
	assert_eq([e.prev_x[1], e.prev_z[1], e.hit_tick[1]], [5.0, 6.0, 42])
	for arr in [e.prev_x, e.prev_z, e.hit_tick]:
		assert_eq(arr.size(), 2)
