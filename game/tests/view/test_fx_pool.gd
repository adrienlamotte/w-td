extends GutTest
## FxPool: effects from sim events, ageing, cap (D-120).

const SWARMER := "enemy_swarmer_01"
const RANGED := "enemy_ranged_01"

var world: SimWorld
var pool: FxPool
var cfg: Dictionary


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	cfg = HordeRenderer.load_config()
	pool = FxPool.new(cfg, world)
	world.events.clear()


func _push(kind: int, a: int, x: float, z: float, value: float) -> void:
	world.events.push(kind, a, x, z, value)


func test_death_with_gold_gives_puff_and_coin_to_the_guardian() -> void:
	_push(SimEvents.Kind.ENEMY_DIED, world.catalog.type_of(SWARMER), 5.0, 3.0, 1.0)
	_push(SimEvents.Kind.ENEMY_DIED, world.catalog.type_of(SWARMER), 2.0, 1.0, 0.0)
	pool.read_events(world)
	assert_eq(Array(pool.kind), [FxPool.Kind.PUFF, FxPool.Kind.COIN, FxPool.Kind.PUFF])
	assert_eq([pool.x0[1], pool.z0[1], pool.x1[1], pool.z1[1]], [5.0, 3.0, 0.0, 0.0], "coin ends at the Guardian")


func test_tower_fired_draws_shot_from_live_tower_only() -> void:
	world.queue(SimCommand.place_tower(world.tick, "tower_single_01", 4.0, 0.0))
	world.step()
	var uid := world.towers.uid[0]
	world.events.clear()
	_push(SimEvents.Kind.TOWER_FIRED, uid, 6.0, 1.0, world.towers.type_id[0])
	_push(SimEvents.Kind.TOWER_FIRED, uid + 99, 6.0, 1.0, world.towers.type_id[0])
	pool.read_events(world)
	assert_eq(pool.count(), 1)
	assert_eq(pool.kind[0], FxPool.Kind.SHOT)
	assert_eq([pool.x0[0], pool.z0[0], pool.x1[0], pool.z1[0]],
		[world.towers.pos_x[0], world.towers.pos_z[0], 6.0, 1.0])


func test_guardian_hit_ribbon_only_for_ranged_and_flash() -> void:
	_push(SimEvents.Kind.GUARDIAN_HIT, world.catalog.type_of(SWARMER), 1.0, 0.0, 1.0)
	pool.read_events(world)
	assert_eq(pool.count(), 0, "melee: no ribbon")
	assert_gt(pool.guardian_flash, 0.0)
	world.events.clear()
	_push(SimEvents.Kind.GUARDIAN_HIT, world.catalog.type_of(RANGED), 6.0, 0.0, 1.0)
	pool.read_events(world)
	assert_eq(Array(pool.kind), [FxPool.Kind.SHOT])


func test_blast_gives_ring_shield_and_hit_nothing() -> void:
	for slot in world.run.skill_ids.size():
		_push(SimEvents.Kind.SKILL_USED, slot, 0.0, 0.0, 0.0)
	_push(SimEvents.Kind.ENEMY_HIT, 0, 1.0, 1.0, 1.0)
	pool.read_events(world)
	assert_eq(Array(pool.kind), [FxPool.Kind.RING])
	var blast := Array(world.run.skill_kind).find(RunData.Skill.AREA_BLAST)
	assert_eq(pool.x1[0], world.run.skill_radius[blast])


func test_tower_hit_spark() -> void:
	world.queue(SimCommand.place_tower(world.tick, "tower_single_01", 4.0, 0.0))
	world.step()
	world.events.clear()
	_push(SimEvents.Kind.TOWER_HIT, world.towers.uid[0], 5.0, 0.0, 1.0)
	pool.read_events(world)
	assert_eq(Array(pool.kind), [FxPool.Kind.SPARK])


func test_advance_expires_by_life() -> void:
	pool.add(FxPool.Kind.PUFF, 0, 0, 0, 0, 0.5, Color.RED, 1.0)
	pool.add(FxPool.Kind.PUFF, 1, 0, 0, 0, 1.0, Color.RED, 1.0)
	pool.advance(0.6)
	assert_eq(pool.count(), 1)
	assert_eq(pool.x0[0], 1.0)
	assert_almost_eq(pool.progress(0), 0.6, 1e-5)
	pool.advance(0.5)
	assert_eq(pool.count(), 0)


func test_cap_drops_new_effects() -> void:
	for n in pool.max_effects + 5:
		pool.add(FxPool.Kind.SPARK, n, 0, 0, 0, 1.0, Color.RED, 1.0)
	assert_eq(pool.count(), pool.max_effects)
	assert_eq(pool.x0[pool.count() - 1], float(pool.max_effects - 1), "the newest are dropped")
