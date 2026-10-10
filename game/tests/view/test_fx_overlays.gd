extends GutTest
## FxOverlays: relationship markers, aura and bounty rings from the world state (D-163).

var world: SimWorld
var ov: FxOverlays


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.gold = 1 << 30
	ov = FxOverlays.new(HordeRenderer.load_config())


func _built(id: String, x: float, z: float) -> int:
	var u := TowerBuilding.add_built(world, world.tower_catalog.type_of(id), x, z)
	assert_gt(u, -1)
	return world.towers.uid.find(u)


func test_link_marker_only_on_live_linked_towers() -> void:
	var linked := _built("tower_pip", 5.0, 0.0)
	_built("tower_pip", -5.0, 0.0)
	var husk := _built("tower_pip", 0.0, 5.0)
	world.towers.syn_mask[linked] = 1
	world.towers.syn_mask[husk] = 1
	world.damage_tower(husk, 1e9)
	ov.read_state(world)
	assert_eq(Array(ov.kind), [FxOverlays.Kind.LINK])
	assert_eq([ov.x[0], ov.z[0]], [5.0, 0.0])


func test_aura_ring_of_reach() -> void:
	var h := _built("tower_hymn", 5.0, 5.0)
	ov.read_state(world)
	assert_eq(Array(ov.kind), [FxOverlays.Kind.RING])
	assert_eq([ov.x[0], ov.z[0], ov.r[0]], [5.0, 5.0, world.towers.reach[h]])
	assert_gt(ov.r[0], 0.0)


func test_bounty_ring_while_active() -> void:
	world.skills.bounty_until = world.clock + 10
	ov.read_state(world)
	assert_eq(Array(ov.kind), [FxOverlays.Kind.RING])
	assert_almost_eq(ov.r[0], float(ov.fx.bounty_radius), 1e-5)
	world.skills.bounty_until = world.clock
	ov.read_state(world)
	assert_eq(ov.count(), 0, "expired: none")


func test_rebuilt_every_call_and_empty_without_run() -> void:
	world.towers.syn_mask[_built("tower_pip", 5.0, 0.0)] = 1
	ov.read_state(world)
	ov.read_state(world)
	assert_eq(ov.count(), 1, "never accumulates")
	var idle := SimWorld.new(1)
	idle.towers.add(1.0, 1.0, 5.0)
	ov.read_state(idle)
	assert_eq(ov.count(), 0)
