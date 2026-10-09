extends GutTest
## M2 balance bot and runner (task 022, D-126). Short runs (60 s of run clock).

const Runner := preload("res://balance/balance_runner.gd")
const SEC: int = 60


func _no_wall(r: Dictionary) -> Dictionary:
	var d := r.duplicate(true)
	d.erase("wall_ms")
	return d


func test_run_is_deterministic() -> void:
	var a := Runner.run_one("spread", 3, SEC)
	var b := Runner.run_one("spread", 3, SEC)
	assert_eq_deep(_no_wall(a), _no_wall(b))
	assert_eq(a.hash, b.hash)


# Bots go through commands: gold never negative, every tower came with a TOWER_PLACED event.
func test_bots_only_use_commands() -> void:
	for strategy: String in ["spread", "ring"]:
		var st := {"min_gold": 1 << 30, "placed": {}, "w": null}
		var r := Runner.run_one(strategy, 1, SEC, func(w: SimWorld) -> void:
			st.min_gold = mini(st.min_gold, w.gold)
			st.w = w
			for e in w.events.count:
				if w.events.kind[e] == SimEvents.Kind.TOWER_PLACED:
					st.placed[w.events.a[e]] = true)
		assert_gte(st.min_gold, 0, strategy)
		var w: SimWorld = st.w
		assert_gt(w.towers.count(), 0, strategy)
		for t in w.towers.count():
			assert_true(st.placed.has(w.towers.uid[t]), "%s tower %d placed by command" % [strategy, w.towers.uid[t]])
		assert_eq(r.towers_bought, st.placed.size())


func test_passive_never_builds_but_casts() -> void:
	var r := Runner.run_one("passive", 1, SEC)
	assert_eq(r.towers_bought, 0)
	assert_gt(r.skills_used, 0)


func test_spread_builds_in_the_first_minute() -> void:
	assert_gt(Runner.run_one("spread", 2, SEC).towers_bought, 0)


func test_ring_towers_on_the_ring_and_not_in_the_gap() -> void:
	var st := {"w": null}
	Runner.run_one("ring", 1, SEC, func(w: SimWorld) -> void: st.w = w)
	var w: SimWorld = st.w
	assert_gt(w.towers.count(), 0)
	for t in w.towers.count():
		var p := Vector2(w.towers.pos_x[t], w.towers.pos_z[t])
		var side := w.towers.footprint[t] * w.build.step
		assert_almost_eq(p.length(), BalanceBot.RING_R, side, "tower %d on the ring" % t)
		assert_false(p.x > 0.0 and absf(p.y) < BalanceBot.RING_GAP * 0.5, "tower %d not in the gap" % t)


func test_report_lists_strategies_rates_and_data() -> void:
	var results: Array[Dictionary] = []
	for strategy: String in Runner.STRATEGIES:
		for s in [1, 2]:
			var won: bool = strategy == "spread" and s == 1
			results.append({"strategy": strategy, "seed": s, "outcome": "won" if won else "lost",
				"end_sec": 930 if won else 100 * s, "towers_bought": 3, "husks_rebuilt": 0, "skills_used": 4,
				"earned": 50, "wall_ms": 1000, "minutes": [{"hp": 100, "gold": 10, "earned": 20, "towers": 3, "enemies": 9}]})
	var text := Runner.report(results, 2, {"date": "2026-01-01", "commit": "abc"})
	for strategy: String in Runner.STRATEGIES:
		assert_string_contains(text, "| %s |" % strategy)
	assert_string_contains(text, "| spread | 1 / 2 | 50 % |")
	assert_string_contains(text, "| passive | 0 / 2 | 0 % |")
	assert_string_contains(text, "NOT met")
	assert_string_contains(text, "## Data")
	assert_string_contains(text, "tower_single_01")
	assert_string_contains(text, "commit abc")
