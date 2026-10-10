extends GutTest
## TowerLevels: "Lv n" labels over towers that can level up (D-151).

var world: SimWorld
var pip: int


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m2"))
	world.step()
	world.gold = 1000
	pip = TowerBuilding.add_built(world, world.tower_catalog.type_of("tower_pip"), 4.0, 4.0, 50)
	world.step()


func _upgrade() -> void:
	world.queue(SimCommand.upgrade_tower(world.tick, pip))
	world.step()


func test_labels_list_levelled_towers() -> void:
	var p := world.towers.uid.find(pip)
	var want := {"uid": pip, "level": 1, "x": world.towers.pos_x[p], "z": world.towers.pos_z[p]}
	assert_eq(TowerLevels.labels(world), [want] as Array[Dictionary])
	_upgrade()
	assert_eq(TowerLevels.labels(world)[0].level, 2)
	world.queue(SimCommand.place_tower(world.tick, "tower_single_01", -5.0, -5.0))
	world.step()
	assert_eq(TowerLevels.labels(world).size(), 1, "M2 tower skipped")
	world.damage_tower(p, 1e9)
	world.step()
	assert_eq(TowerLevels.labels(world).size(), 1, "husk kept")
	assert_eq(TowerLevels.labels(SimWorld.new(1)).size(), 0, "no run")


func test_pool_and_text() -> void:
	var cam := Camera3D.new()
	add_child_autofree(cam)
	var node := TowerLevels.new()
	add_child_autofree(node)
	node.set_process(false)
	node.setup(world, cam)
	assert_eq(node.get_child_count(), 1)
	var label: Label = node.get_child(0)
	assert_eq(label.text, "Lv 1")
	label.text = "marker"
	node.refresh()
	assert_eq(label.text, "marker", "unchanged level: text not rebuilt")
	_upgrade()
	node.refresh()
	assert_eq(label.text, "Lv 2")
	TowerBuilding.add_built(world, world.tower_catalog.type_of("tower_pip"), -4.0, 4.0, 50)
	node.refresh()
	assert_eq(node.get_child_count(), 2)
	world.queue(SimCommand.sell_tower(world.tick, pip))
	world.step()
	node.refresh()
	assert_eq(node.get_child_count(), 1)
