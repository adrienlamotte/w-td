extends GutTest

const DIR := "res://data/enemies"


func _json(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(id + ".json")))


func test_values_match_json_for_every_file() -> void:
	var catalog := EnemyCatalog.load_dir()
	assert_eq(catalog.ids.size(), DirAccess.get_files_at(DIR).size())
	for t in catalog.ids.size():
		var json := _json(catalog.ids[t])
		var drop: Dictionary = json.drops[0]
		assert_eq(catalog.name_key[t], json.name_key)
		assert_almost_eq(catalog.speed[t], float(json.speed), 1e-6)
		assert_almost_eq(catalog.radius[t], float(json.radius), 1e-6)
		assert_almost_eq(catalog.hp[t], float(json.hp), 1e-6)
		assert_almost_eq(catalog.separation_strength[t], float(json.separation_strength), 1e-6)
		assert_almost_eq(catalog.damage[t], float(json.damage), 1e-6)
		assert_almost_eq(catalog.attack_range[t], float(json.attack_range), 1e-6)
		assert_eq(catalog.attack_cooldown[t], roundi(json.attack_cooldown_sec * SimWorld.TICK_RATE))
		assert_eq(catalog.gold[t], int(drop.amount))
		assert_almost_eq(catalog.gold_chance[t], float(drop.chance), 1e-6)
		assert_eq(catalog.is_boss[t] == 1, json.archetype in ["miniboss", "boss"], catalog.ids[t])


func test_sorted_by_id() -> void:
	var ids := Array(EnemyCatalog.load_dir().ids)
	var sorted := ids.duplicate()
	sorted.sort()
	assert_eq(ids, sorted)


func test_max_radius_over_horde_types_only() -> void:
	var catalog := EnemyCatalog.load_dir()
	var horde_max := 0.0
	var any_boss := false
	for t in catalog.ids.size():
		if catalog.is_boss[t] == 1:
			any_boss = true
		else:
			horde_max = maxf(horde_max, catalog.radius[t])
	assert_true(any_boss, "bosses exist in data")
	assert_almost_eq(catalog.max_radius, horde_max, 1e-6)


func test_unknown_id_is_minus_one() -> void:
	assert_eq(EnemyCatalog.load_dir().type_of("nope"), -1)
