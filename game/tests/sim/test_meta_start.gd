extends GutTest
## StartRun applies the bought meta nodes (D-152 rules 8 and 9).

var all_nodes: PackedStringArray = MetaCatalog.load_dir().ids


func _start(run_id: String, nodes: PackedStringArray) -> SimWorld:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, 7, run_id, "", PackedStringArray(), nodes))
	w.step()
	w.run.first_wave_tick = 1 << 30  # no wave spawns
	return w


func test_every_node_on_run_m3() -> void:
	var w := _start("run_m3", all_nodes)
	assert_eq(w.gold, 300, "200 + 2 x 50")
	assert_almost_eq(w.guardian_max_hp, 480.0, 0.01, "x1.2")
	assert_almost_eq(w.guardian_hp, 480.0, 0.01)
	assert_almost_eq(w.xp_mult, 1.1, 1e-5)
	var pip := w.tower_catalog.type_of("tower_pip")
	assert_eq(TowerBuilding.price(w, pip), 47, "50 x 0.95 rounds down")
	w.queue(SimCommand.place_tower(w.tick, "tower_pip", 6.0, 0.0))
	w.step()
	var t := 0
	assert_eq(w.towers.count(), 1)
	assert_eq(w.towers.paid[t], 47)
	assert_almost_eq(w.towers.max_hp[t], 115.0, 0.01, "x1.15")
	assert_eq(TowerBuilding.sell_refund(w, t), floori(47 * 0.65))
	w.damage_tower(t, 1e9)
	assert_eq(TowerBuilding.rebuild_price(w, t), 9, "floor(47 x 0.2)")


func test_no_nodes_is_the_old_start() -> void:
	var w := _start("run_m3", PackedStringArray())
	assert_eq(w.gold, 200)
	assert_eq(w.modifiers.stat.size(), 0)
	assert_null(w.meta, "catalog not loaded")
	assert_eq(TowerBuilding.price(w, w.tower_catalog.type_of("tower_pip")), 50)


func test_radius_sizes_the_grid() -> void:
	var w := _start("run_m2", PackedStringArray(["meta_radius"]))
	assert_eq(w.build.size, 120, "2 x ceil((20 + 2 + 6 + 2) / 0.5)")
	assert_eq(w.build_radius, 22.0)
	w.gold = 100000
	var ok := TowerBuilding.check_place(w, "tower_single_01", 21.0, 0.0)
	assert_eq(ok.reason, TowerBuilding.Reason.OK)
	var out := TowerBuilding.check_place(w, "tower_single_01", 23.0, 0.0)
	assert_eq(out.reason, TowerBuilding.Reason.OUT_OF_RADIUS)


func test_node_order_does_not_matter() -> void:
	var reversed := all_nodes.duplicate()
	reversed.reverse()
	var a := _start("run_m3", all_nodes)
	var b := _start("run_m3", reversed)
	for i in 30:
		a.step()
		b.step()
	assert_eq(a.state_hash(), b.state_hash())
