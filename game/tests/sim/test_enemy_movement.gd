extends GutTest
## Steer/advance movement and stop distances (D-107).

const SWARMER := "enemy_swarmer_01"  # catalog sorted by id: type 0 is not the swarmer
const RANGED := "enemy_ranged_01"

var world: SimWorld
var speed: float
var radius: float
var sw: int


func before_each() -> void:
	world = SimWorld.new(1)
	sw = world.catalog.type_of(SWARMER)
	speed = world.catalog.speed[sw]
	radius = world.catalog.radius[sw]


func _start_run() -> void:
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()  # the first wave spawn is ~44 ticks away: no spawns in these tests


func test_moves_speed_times_dt_toward_origin() -> void:
	world.enemies.add(sw, 10.0, 0.0, 1.0)
	world.step()
	assert_almost_eq(world.enemies.pos_x[0], 10.0 - speed * SimWorld.SIM_DT, 1e-4)
	assert_almost_eq(world.enemies.pos_z[0], 0.0, 1e-6)


func test_moves_along_diagonal() -> void:
	world.enemies.add(sw, 6.0, -8.0, 1.0)  # distance 10
	world.step()
	var f := (10.0 - speed * SimWorld.SIM_DT) / 10.0
	assert_almost_eq(world.enemies.pos_x[0], 6.0 * f, 1e-4)
	assert_almost_eq(world.enemies.pos_z[0], -8.0 * f, 1e-4)


func test_idle_stops_at_own_radius() -> void:
	world.enemies.add(sw, radius + speed * SimWorld.SIM_DT * 0.5, 0.0, 1.0)
	world.step()
	assert_almost_eq(world.enemies.pos_x[0], radius, 1e-5)
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING)
	for i in 10:
		world.step()
	assert_almost_eq(world.enemies.pos_x[0], radius, 1e-5)
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING)


func test_run_melee_stops_at_contact() -> void:
	_start_run()
	var stop := world.run.guardian_contact_radius + radius
	world.enemies.add(sw, stop + speed * SimWorld.SIM_DT * 0.5, 0.0, 1.0)
	world.step()
	assert_almost_eq(world.enemies.pos_x[0], stop, 1e-5)
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING)


func test_run_ranged_stops_at_range() -> void:
	_start_run()
	var rg := world.catalog.type_of(RANGED)
	var stop := world.run.guardian_contact_radius + world.catalog.radius[rg] + world.catalog.attack_range[rg]
	assert_almost_eq(stop, 7.35, 1e-5)
	world.enemies.add(rg, 0.0, stop + 0.01, 1.0)
	world.step()
	assert_almost_eq(world.enemies.pos_z[0], stop, 1e-5)
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING)


func test_pushed_out_attacker_walks_back() -> void:
	_start_run()
	var stop := world.run.guardian_contact_radius + radius
	var i := world.enemies.add(sw, stop + 0.05, 0.0, 1.0)
	world.enemies.state[i] = SimEnemies.State.ATTACKING
	world.step()
	assert_almost_eq(world.enemies.pos_x[0], stop, 1e-5)
	assert_eq(world.enemies.state[0], SimEnemies.State.ATTACKING)


func test_far_enemy_keeps_moving() -> void:
	_start_run()
	var stop := world.run.guardian_contact_radius + radius
	world.enemies.add(sw, stop + speed * SimWorld.SIM_DT * 2.0, 0.0, 1.0)
	world.step()
	assert_almost_eq(world.enemies.pos_x[0], stop + speed * SimWorld.SIM_DT, 1e-5)
	assert_eq(world.enemies.state[0], SimEnemies.State.MOVING)


func test_corpse_does_not_move() -> void:
	world.enemies.add(sw, 10.0, 0.0, 0.0)
	world.movement.steer(world.enemies)
	world.movement.advance(world.enemies, world.catalog.speed, SimWorld.SIM_DT)
	assert_eq(world.enemies.pos_x[0], 10.0)
	assert_eq(world.enemies.state[0], SimEnemies.State.MOVING)
