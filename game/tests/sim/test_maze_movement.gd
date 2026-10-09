extends GutTest
## Maze movement (D-115): steer around towers, push-out (D-112), queue key, D-118 line of sight.

const SWARMER := "enemy_swarmer_01"
const RANGED := "enemy_ranged_01"
const SINGLE := "tower_single_01"
const HP := 1e9

var world: SimWorld
var sw: int


func before_each() -> void:
	world = _new_run()
	sw = world.catalog.type_of(SWARMER)


func _new_run() -> SimWorld:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, 7, "run_m2"))
	w.step()
	w.run.first_wave_tick = 1 << 30  # no spawns: these tests place their own enemies
	w.run.final_boss_tick = -1
	w.run.boss_ticks = PackedInt32Array()
	w.guardian_hp = HP
	w.gold = 1 << 30
	return w


func _tower(x: float, z: float) -> int:
	return TowerBuilding.add_built(world, world.tower_catalog.type_of(SINGLE), x, z)


# Towers every 0.25 units of arc, except a gap of `gap` units centred on gap_angle.
func _ring(radius: float, gap_angle: float, gap: float) -> void:
	var count := ceili(TAU * radius / 0.25)
	for k in count:
		var a := k * TAU / count
		if gap > 0.0 and absf(angle_difference(a, gap_angle)) * radius < gap / 2.0:
			continue
		_tower(cos(a) * radius, sin(a) * radius)


func _settle() -> void:
	world.step()
	var n := 0
	while world.field.busy() and n < 100:
		world.step()
		n += 1


func _in_tower(i: int) -> bool:
	var c := world.build.cell_of(world.enemies.pos_x[i], world.enemies.pos_z[i])
	return c >= 0 and world.build.solid[c] == 1


func _radius(i: int) -> float:
	return Vector2(world.enemies.pos_x[i], world.enemies.pos_z[i]).length()


func _angle(i: int) -> float:
	return atan2(world.enemies.pos_z[i], world.enemies.pos_x[i])


func test_no_towers_is_the_straight_chase() -> void:
	var ref := _new_run()
	ref.field = null
	ref.build = null  # no field: the 014 steer and queue compare
	for w: SimWorld in [world, ref]:
		for k in 24:
			var a := k * TAU / 24
			w.enemies.add(sw, cos(a) * (6.0 + k % 3), sin(a) * (6.0 + k % 3), HP)
	for t in 120:
		world.step()
		ref.step()
	assert_eq(world.enemies.pos_x, ref.enemies.pos_x)
	assert_eq(world.enemies.pos_z, ref.enemies.pos_z)
	assert_eq(world.enemies.state, ref.enemies.state)


func test_routes_around_a_wall() -> void:
	for z in range(-4, 5):
		_tower(6.0, z)
	_settle()
	world.enemies.add(sw, 12.0, 0.3, HP)
	var n := 0
	while world.enemies.state[0] != SimEnemies.State.ATTACKING and n < 2000:
		world.step()
		assert_false(_in_tower(0), "tick %d: centre in a tower" % n)
		n += 1
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING, "reached the Guardian")


func test_serpentine() -> void:
	_ring(9.0, PI, 2.0)
	_ring(5.0, 0.0, 2.0)
	_settle()
	world.enemies.add(sw, 12.0, 0.3, HP)
	# Ring towers span about +-0.85 around their radius: r < 8 is past the outer ring,
	# r < 4 past the inner one. The first tick past each must be at its gap.
	var crossed := [false, false]
	var n := 0
	while world.enemies.state[0] != SimEnemies.State.ATTACKING and n < 5000:
		world.step()
		assert_false(_in_tower(0), "tick %d: centre in a tower" % n)
		var r := _radius(0)
		if not crossed[0] and r < 8.0:
			assert_lt(absf(angle_difference(_angle(0), PI)) * r, 2.0, "outer ring crossed at its gap")
			crossed[0] = true
		if not crossed[1] and r < 4.0:
			assert_lt(absf(_angle(0)) * r, 2.0, "inner ring crossed at its gap")
			crossed[1] = true
		n += 1
	assert_eq(crossed, [true, true])
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING, "reached the Guardian")


func _walled_in_then_opened(open: Callable) -> void:
	_ring(6.0, 0.0, 0.0)
	_settle()
	world.enemies.add(sw, 10.0, 0.0, HP)
	for t in 300:
		world.step()
		assert_false(_in_tower(0), "tick %d: centre in a tower" % t)
	assert_gt(_radius(0), 5.5, "pressed against the ring, outside")
	assert_gt(world.enemies.target_id[0], -1, "attacks the ring (D-116)")
	assert_eq(world.guardian_hp, HP, "Guardian untouched")
	# Open the ring at the tower nearest to the enemy.
	var best := 0
	for t in world.towers.count():
		if world.towers.pos_x[t] > world.towers.pos_x[best] or (world.towers.pos_x[t] == world.towers.pos_x[best]
				and absf(world.towers.pos_z[t]) < absf(world.towers.pos_z[best])):
			best = t
	open.call(best)
	var n := 0
	while world.guardian_hp == HP and n < 1000:
		world.step()
		n += 1
	assert_lt(world.guardian_hp, HP, "went through the opening")


func test_full_ring_then_husk() -> void:
	_walled_in_then_opened(func(t: int) -> void: world.damage_tower(t, 1e9))


func test_full_ring_then_sold() -> void:
	_walled_in_then_opened(func(t: int) -> void:
		world.queue(SimCommand.sell_tower(world.tick, world.towers.uid[t])))


func test_push_out_after_placing_on_an_enemy() -> void:
	var rg := world.catalog.type_of(RANGED)
	world.enemies.add(rg, 7.0, 0.1, HP)  # within its range: stands still, attacking
	for t in 3:
		world.step()
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING)
	world.queue(SimCommand.place_tower(world.tick, SINGLE, 7.0, 0.0))
	world.step()
	assert_eq(world.towers.count(), 1)
	assert_true(_in_tower(0), "placed on the enemy (D-112)")
	var n := 0
	while world.field.busy() and n < 100:
		world.step()
		n += 1
	world.step()
	assert_false(_in_tower(0), "pushed out once the field caught up")


func test_ranged_needs_a_clear_line() -> void:
	var rg := world.catalog.type_of(RANGED)
	for z in range(-3, 4):
		_tower(4.0, z)
	_settle()
	world.enemies.add(rg, 6.0, 0.0, HP)  # in range, but the wall is in the way (D-118)
	var hp := world.guardian_hp
	for t in 20:
		world.step()
		assert_ne(world.enemies.state[0], SimEnemies.State.ATTACKING, "tick %d" % t)
	assert_eq(world.guardian_hp, hp, "no shot through the wall")
	var n := 0
	while world.enemies.state[0] != SimEnemies.State.ATTACKING and n < 1000:
		world.step()
		n += 1
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING, "shoots once the line is clear")
	var c := world.build.cell_of(world.enemies.pos_x[0], world.enemies.pos_z[0])
	assert_eq(world.field.hit[world.field.escape[c]], -1)


func test_corridor_queue_uses_path_cost() -> void:
	for z in range(-6, 7):
		_tower(4.0, z)  # wall x in [3.5, 4.5], z in [-6.5, 6.5]
	_settle()
	var a := world.enemies.add(sw, 5.0, 6.2, HP)  # nearer along the path, farther radially
	var bb := world.enemies.add(sw, 5.0, 5.6, HP)
	assert_gt(_radius(a), _radius(bb))
	var f := world.field
	var ca := world.build.cell_of(5.0, 6.2)
	var cb := world.build.cell_of(5.0, 5.6)
	assert_lt(f.dist[ca], f.dist[cb])
	world.enemies.state[a] = SimEnemies.State.QUEUED  # a was stopped last tick
	world.step()
	assert_eq(world.enemies.state[bb], SimEnemies.State.QUEUED, "queued behind a along the corridor")
	assert_eq(world.enemies.state[a], SimEnemies.State.MOVING)
