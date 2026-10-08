extends GutTest


func test_loads_swarmer_stats_from_json() -> void:
	var json: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/enemies/enemy_swarmer_01.json"))
	var catalog := EnemyCatalog.load_dir()
	var t := catalog.type_of("enemy_swarmer_01")
	assert_true(t >= 0)
	assert_almost_eq(catalog.speed[t], float(json.speed), 1e-6)
	assert_almost_eq(catalog.radius[t], float(json.radius), 1e-6)
	assert_almost_eq(catalog.hp[t], float(json.hp), 1e-6)
	assert_almost_eq(catalog.separation_strength[t], float(json.separation_strength), 1e-6)
	assert_almost_eq(catalog.max_radius, float(json.radius), 1e-6)


func test_unknown_id_is_minus_one() -> void:
	assert_eq(EnemyCatalog.load_dir().type_of("nope"), -1)
