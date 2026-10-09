extends GutTest

const DIR := "res://data/towers"
const ATTACKS := {"single": TowerCatalog.Attack.SINGLE, "splash": TowerCatalog.Attack.SPLASH,
		"slow": TowerCatalog.Attack.SLOW}


func test_values_match_json_for_every_file() -> void:
	var catalog := TowerCatalog.load_dir()
	assert_eq(catalog.ids.size(), DirAccess.get_files_at(DIR).size())
	for t in catalog.ids.size():
		var json: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string(DIR.path_join(catalog.ids[t] + ".json")))
		assert_eq(catalog.name_key[t], json.name_key)
		assert_eq(catalog.attack[t], ATTACKS[json.attack])
		assert_eq(catalog.cost[t], int(json.cost))
		assert_eq(catalog.cost_per_copy[t], int(json.cost_per_copy))
		assert_almost_eq(catalog.hp[t], float(json.hp), 1e-6)
		assert_almost_eq(catalog.radius[t], float(json.radius), 1e-6)
		assert_almost_eq(catalog.attack_range[t], float(json.range), 1e-6)
		assert_almost_eq(catalog.damage[t], float(json.damage), 1e-6)
		assert_eq(catalog.cooldown[t], roundi(json.cooldown_sec * SimWorld.TICK_RATE))
		assert_almost_eq(catalog.splash_radius[t], float(json.get("splash_radius", 0.0)), 1e-6)
		assert_almost_eq(catalog.slow_factor[t], float(json.get("slow_factor", 1.0)), 1e-6)
		assert_eq(catalog.slow_ticks[t], roundi(json.get("slow_sec", 0.0) * SimWorld.TICK_RATE))
		assert_almost_eq(catalog.sell_refund[t], float(json.sell_refund), 1e-6)
		assert_almost_eq(catalog.rebuild_fraction[t], float(json.rebuild_fraction), 1e-6)


func test_sorted_by_id() -> void:
	var ids := Array(TowerCatalog.load_dir().ids)
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted)


func test_defaults_for_absent_splash_and_slow() -> void:
	var catalog := TowerCatalog.load_dir()
	var t := catalog.type_of("tower_single_01")
	assert_true(t >= 0)
	assert_eq(catalog.splash_radius[t], 0.0)
	assert_eq(catalog.slow_factor[t], 1.0)
	assert_eq(catalog.slow_ticks[t], 0)


func test_unknown_id_is_minus_one() -> void:
	assert_eq(TowerCatalog.load_dir().type_of("nope"), -1)


func test_ticks_round_seconds() -> void:
	assert_eq(DataFiles.ticks(1.0), 30)
	assert_eq(DataFiles.ticks(0.5), 15)
	assert_eq(DataFiles.ticks(0.0), 0)
