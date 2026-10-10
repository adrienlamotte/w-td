extends GutTest
## Meta profile rules (D-152): offer, hearts, run end, tree purchase, StartRun config, migration.

var cat: MetaCatalog = MetaCatalog.load_dir()
var run: RunData = RunData.load_id("run_m3", EnemyCatalog.load_dir(), TowerCatalog.load_dir())
var p: MetaProfile


func before_each() -> void:
	p = MetaProfile.fresh(cat)


func _rescue(ids: Array) -> void:
	p.unlocked = PackedStringArray(ids)


func test_offer() -> void:
	assert_eq(p.offer(cat), PackedStringArray(["waifu_cinder", "waifu_bastia", "waifu_clover"]))
	_rescue(["waifu_cinder"])
	assert_eq(p.offer(cat), PackedStringArray(["waifu_bastia", "waifu_clover", "waifu_hymn"]))
	_rescue(["waifu_cinder", "waifu_bastia", "waifu_clover", "waifu_hymn"])
	assert_eq(p.offer(cat), PackedStringArray(["waifu_tansy", "waifu_poppy"]))
	_rescue(cat.offer_order)
	assert_eq(p.offer(cat), PackedStringArray(["waifu_cinder", "waifu_bastia", "waifu_clover",
		"waifu_hymn", "waifu_tansy", "waifu_poppy"]), "all 6 rescued: all 6 in offer order (D-142)")


func test_hearts() -> void:
	assert_eq(run.hearts_min_tick, 60 * SimWorld.TICK_RATE)
	assert_eq(MetaProfile.hearts_for(run, false, 0), 0, "before 60 s (D-165)")
	assert_eq(MetaProfile.hearts_for(run, false, 1799), 0, "59.97 s")
	assert_eq(MetaProfile.hearts_for(run, false, 1800), 30 + 20 * 1800 / run.final_boss_tick, "60 s")
	assert_eq(MetaProfile.hearts_for(run, true, 0), 100, "a win at clock 0")
	assert_eq(MetaProfile.hearts_for(run, false, 13500), 40, "7:30")
	assert_eq(MetaProfile.hearts_for(run, false, run.final_boss_tick), 50)
	assert_eq(MetaProfile.hearts_for(run, false, run.final_boss_tick + 900), 50)
	assert_eq(MetaProfile.hearts_for(run, true, 1000), 100)


func test_record_run_win_unlocks_once() -> void:
	run.guardian_id = "guardian_cinder"
	assert_eq(p.record_run(cat, run, true, 27030), 100)
	assert_eq(p.unlocked, PackedStringArray(["waifu_cinder"]))
	p.record_run(cat, run, true, 27000)
	assert_eq(p.unlocked, PackedStringArray(["waifu_cinder"]), "no duplicate")
	assert_eq(p.hearts, 200)
	assert_eq([p.runs, p.wins, p.losses], [2, 2, 0])
	assert_eq(p.best_sec["guardian_cinder"], 901)


func test_record_run_loss_and_placeholder() -> void:
	run.guardian_id = "guardian_cinder"
	assert_eq(p.record_run(cat, run, false, 13500), 40)
	assert_eq(p.unlocked.size(), 0, "a loss unlocks nothing")
	assert_eq([p.runs, p.wins, p.losses], [1, 0, 1])
	assert_eq(p.best_sec["guardian_cinder"], 450)
	p.record_run(cat, run, false, 300)
	assert_eq(p.best_sec["guardian_cinder"], 450, "longest kept")
	run.guardian_id = "guardian_placeholder_01"
	p.record_run(cat, run, true, 27000)
	assert_eq(p.unlocked.size(), 0, "the placeholder Guardian unlocks nothing")


func test_record_run_before_hearts_min_sec() -> void:
	run.guardian_id = "guardian_cinder"
	assert_eq(p.record_run(cat, run, false, 0), 0)
	assert_eq([p.hearts, p.runs, p.losses], [0, 1, 1], "still counted (D-165 is hearts only, D-166)")


func test_roster_state() -> void:
	assert_eq(cat.starters, PackedStringArray(["waifu_mallow", "waifu_pip"]))
	_rescue(["waifu_cinder"])
	assert_eq(p.roster_state(cat, "waifu_pip"), MetaProfile.Roster.STARTER)
	assert_eq(p.roster_state(cat, "waifu_cinder"), MetaProfile.Roster.RESCUED)
	assert_eq(p.roster_state(cat, "waifu_bastia"), MetaProfile.Roster.LOCKED)
	assert_eq(cat.branch["meta_gold_1"], "economy")
	assert_eq(cat.name_key["meta_gold_1"], "meta.gold_1.name")
	assert_eq(cat.waifu_name_key["waifu_cinder"], "waifu.cinder.name")


func test_buy() -> void:
	assert_eq(p.check_buy(cat, "meta_nope"), MetaProfile.Buy.UNKNOWN)
	p.hearts = 1000
	assert_eq(p.check_buy(cat, "meta_gold_2"), MetaProfile.Buy.LOCKED)
	p.hearts = 59
	assert_eq(p.buy(cat, "meta_gold_1"), MetaProfile.Buy.NO_HEARTS)
	assert_eq(p.meta_nodes.size(), 0)
	p.hearts = 200
	assert_eq(p.buy(cat, "meta_gold_1"), MetaProfile.Buy.OK)
	assert_eq(p.hearts, 140)
	assert_eq(p.check_buy(cat, "meta_gold_1"), MetaProfile.Buy.OWNED)
	assert_eq(p.check_buy(cat, "meta_gold_2"), MetaProfile.Buy.OK)


func test_start_command() -> void:
	assert_null(p.start_command(cat, 0, 1, "run_m3", "waifu_hymn"), "not offered")
	assert_null(p.start_command(cat, 0, 1, "run_m3", "waifu_pip"), "a starter is never offered")
	_rescue(["waifu_cinder"])
	p.meta_nodes = PackedStringArray(["meta_xp"])
	var c := p.start_command(cat, 5, 9, "run_m3", "waifu_hymn")
	assert_eq(c.type, SimCommand.Type.START_RUN)
	assert_eq([c.tick, c.run_seed, c.run_id, c.guardian_id], [5, 9, "run_m3", "guardian_hymn"])
	assert_eq(c.unlocked, PackedStringArray(["waifu_cinder"]))
	assert_eq(c.meta_nodes, PackedStringArray(["meta_xp"]))


func test_round_trip_dict() -> void:
	p.hearts = 12
	p.unlocked = PackedStringArray(["waifu_bastia"])
	p.best_sec = {"guardian_bastia": 33}
	var back := MetaProfile.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())), cat)
	assert_eq(back.to_dict(), p.to_dict())


func test_migration_from_v0() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/profile_v0.json"))
	var m := MetaProfile.from_dict(d, cat)
	assert_not_null(m)
	assert_eq(m.unlocked, PackedStringArray(["waifu_cinder"]), "unknown waifu dropped")
	assert_eq(m.hearts, 75)
	assert_eq(m.meta_nodes, PackedStringArray(["meta_gold_1"]))
	assert_eq(m.bond.size(), cat.waifu_ids.size())
	assert_eq(m.bond["waifu_pip"], 0)
	assert_eq([m.runs, m.wins, m.losses, m.best_sec], [0, 0, 0, {}])
	assert_eq(m.to_dict().schema_version, MetaProfile.CURRENT_VERSION)


func test_unreadable() -> void:
	var good := p.to_dict()
	assert_not_null(MetaProfile.from_dict(good, cat))
	for bad: Variant in [[1, 2], "x", null]:
		assert_null(MetaProfile.from_dict(bad, cat), "not a Dictionary")
	var newer := good.duplicate(true)
	newer.schema_version = 99
	assert_null(MetaProfile.from_dict(newer, cat), "newer version")
	var cases := [["hearts", "lots"], ["hearts", -5], ["hearts", 1.5], ["unlocked", "waifu_cinder"],
		["meta_nodes", [3]], ["bond", []], ["stats", 7]]
	for c: Array in cases:
		var d := good.duplicate(true)
		d[c[0]] = c[1]
		assert_null(MetaProfile.from_dict(d, cat), "wrong type: %s" % [c])
	var s := good.duplicate(true)
	s.stats.best_sec = {"guardian_cinder": "fast"}
	assert_null(MetaProfile.from_dict(s, cat), "best_sec not an int")
