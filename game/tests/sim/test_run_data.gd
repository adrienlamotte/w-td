extends GutTest

var _enemies: EnemyCatalog
var _towers: TowerCatalog
var _run: RunData
var _json: Dictionary


func _ticks(sec: Variant) -> int:
	return roundi(float(sec) * SimWorld.TICK_RATE)


func before_all() -> void:
	_enemies = EnemyCatalog.load_dir()
	_towers = TowerCatalog.load_dir()
	_run = RunData.load_id("run_m2", _enemies, _towers)
	_json = JSON.parse_string(FileAccess.get_file_as_string("res://data/runs/run_m2.json"))


func test_timeline_in_ticks() -> void:
	assert_eq(_run.wave_ticks, _ticks(_json.wave_sec))
	assert_eq(_run.wave_ticks, 1800)
	assert_eq(_run.break_ticks, _ticks(_json.break_sec))
	assert_eq(_run.first_wave_tick, _ticks(_json.first_wave_sec))
	assert_eq(_run.final_boss_tick, 27000)
	assert_eq(_run.boss_ticks, PackedInt32Array([9000, 18000]))


func test_scalars() -> void:
	assert_eq(_run.starting_gold, int(_json.starting_gold))
	assert_almost_eq(_run.build_radius, float(_json.build_radius), 1e-6)
	assert_almost_eq(_run.grid_step, float(_json.grid_step), 1e-6)
	assert_almost_eq(_run.spawn_ring_min, float(_json.spawn_ring_min), 1e-6)
	assert_almost_eq(_run.spawn_ring_max, float(_json.spawn_ring_max), 1e-6)


func test_ids_resolve() -> void:
	assert_eq(_run.wave_count.size(), _json.waves.size())
	for w in _run.wave_count.size():
		assert_eq(_run.wave_count[w], int(_json.waves[w].count))
		assert_eq(_run.wave_mix_types[w].size(), _run.wave_mix_weights[w].size())
		for type in _run.wave_mix_types[w]:
			assert_true(type >= 0, "wave %d" % w)
	for type in _run.boss_types:
		assert_eq(_enemies.is_boss[type], 1)
	assert_eq(_enemies.ids[_run.final_boss_type], _json.final_boss.enemy)
	assert_eq(_enemies.is_boss[_run.final_boss_type], 1)
	assert_eq(_run.tower_types.size(), _json.towers.size())
	for i in _run.tower_types.size():
		assert_eq(_towers.ids[_run.tower_types[i]], _json.towers[i])


func test_guardian_and_skills() -> void:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/guardians/%s.json" % _json.guardian))
	assert_almost_eq(_run.guardian_hp, float(g.hp), 1e-6)
	assert_almost_eq(_run.guardian_contact_radius, float(g.contact_radius), 1e-6)
	assert_eq(_run.skill_ids, PackedStringArray(g.skills))
	assert_eq(_run.skill_ids.size(), 2)
	for i in _run.skill_ids.size():
		var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/skills/%s.json" % _run.skill_ids[i]))
		assert_eq(_run.skill_cooldown[i], _ticks(s.cooldown_sec))
		assert_eq(_run.skill_name_key[i], s.name_key)
		assert_eq(_run.skill_kind[i], RunData.Skill.AREA_BLAST if s.kind == "area_blast" else RunData.Skill.SHIELD)
		assert_almost_eq(_run.skill_radius[i], float(s.get("radius", 0.0)), 1e-6)
		assert_almost_eq(_run.skill_damage[i], float(s.get("damage", 0.0)), 1e-6)
		assert_almost_eq(_run.skill_absorb[i], float(s.get("absorb", 0.0)), 1e-6)
		assert_eq(_run.skill_duration[i], _ticks(s.get("duration_sec", 0.0)))
