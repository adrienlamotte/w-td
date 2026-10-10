extends GutTest
## M3 balance bots and runner (task 041, D-164). Short runs (60 s of run clock).

const Runner := preload("res://balance/balance_runner.gd")
const SEC: int = 60


func _no_wall(r: Dictionary) -> Dictionary:
	var d := r.duplicate(true)
	d.erase("wall_ms")
	return d


# A fresh run_m3 with Cinder (first of the fresh offer), stepped once so StartRun is applied.
func _world() -> SimWorld:
	var cat := MetaCatalog.load_dir()
	var w := SimWorld.new(1)
	w.queue(Runner.profile_preset("fresh", cat).start_command(cat, 0, 1, Runner.RUN_ID, "waifu_cinder"))
	w.step()
	return w


func test_run_is_deterministic() -> void:
	var a := Runner.run_one("maze", "full", "waifu_bastia", 3, SEC)
	var b := Runner.run_one("maze", "full", "waifu_bastia", 3, SEC)
	assert_eq_deep(_no_wall(a), _no_wall(b))
	assert_eq(a.hash, b.hash)


func test_profile_presets_offer_their_guardians() -> void:
	var cat := MetaCatalog.load_dir()
	assert_eq(Runner.profile_preset("fresh", cat).offer(cat), cat.offer_order.slice(0, 3))
	var full := Runner.profile_preset("full", cat)
	assert_eq(full.offer(cat), cat.offer_order)
	assert_eq(full.meta_nodes, cat.ids)


# Bots go through commands: gold never negative, every tower came with a TOWER_PLACED event.
func test_bots_only_use_commands() -> void:
	for strategy: String in ["spread", "maze"]:
		var st := {"min_gold": 1 << 30, "placed": {}, "w": null}
		var r := Runner.run_one(strategy, "fresh", "waifu_cinder", 1, SEC, func(w: SimWorld) -> void:
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
	var r := Runner.run_one("passive", "fresh", "waifu_cinder", 1, SEC)
	assert_eq(r.towers_bought, 0)
	assert_gt(r.skills_used, 0)


func test_card_pick_takes_the_best_ranked_slot() -> void:
	var w := _world()
	var cards := w.cards
	var perk := Array(cards.type).find(CardCatalog.Type.PERK)
	var tower := Array(cards.type).find(CardCatalog.Type.NEW_TOWER)
	w.draft.draft = PackedInt32Array([cards.filler, perk, tower])
	w.draft.drafting = true
	w.draft.pending = 1
	BalanceBot.new("spread").act(w)
	w.step()
	var picked := -1
	for e in w.events.count:
		if w.events.kind[e] == SimEvents.Kind.CARD_PICKED:
			picked = w.events.a[e]
	assert_eq(picked, tower, "new_tower ranks before perk and filler")


# Cheaper of placement and upgrade: Pip placed (50), then upgrading her (40) beats Mallow (60).
func test_spend_takes_the_cheaper_of_placement_and_upgrade() -> void:
	var w := _world()
	w.gold = 10000  # test-only gold poke
	var bot := BalanceBot.new("spread")
	var first := bot.spend(w)
	assert_eq(first.type, SimCommand.Type.PLACE_TOWER, "nothing to upgrade yet")
	w.queue(first)
	w.step()
	var second := bot.spend(w)
	assert_eq(second.type, SimCommand.Type.UPGRADE_TOWER)
	assert_eq(second.tower_uid, w.towers.uid[0])


# Maze: every tower on a MAZE_RINGS ring, outside its gap; the Pip-Mallow pair is linked.
func test_maze_towers_on_rings_outside_gaps() -> void:
	var st := {"w": null}
	Runner.run_one("maze", "fresh", "waifu_cinder", 1, SEC, func(w: SimWorld) -> void: st.w = w)
	var w: SimWorld = st.w
	assert_gt(w.towers.count(), 1)
	var linked := 0
	for t in w.towers.count():
		var p := Vector2(w.towers.pos_x[t], w.towers.pos_z[t])
		var side := w.towers.footprint[t] * w.build.step
		var ring := -1
		for k in BalanceBot.MAZE_RINGS.size():
			if absf(p.length() - BalanceBot.MAZE_RINGS[k]) <= side:
				ring = k
		assert_gte(ring, 0, "tower %d at %s on a ring" % [t, p])
		if ring >= 0:
			var gap := Vector2.from_angle(BalanceBot.gap_angle(ring)) * BalanceBot.MAZE_RINGS[ring]
			assert_gte(p.distance_to(gap), BalanceBot.MAZE_GAP * 0.5, "tower %d not in the gap" % t)
		linked += int(w.towers.syn_mask[t] != 0)
	assert_gt(linked, 0, "the Pip-Mallow pair is active")


func test_damage_sources_sum_to_all_hits() -> void:
	var st := {"total": 0.0}
	var r := Runner.run_one("maze", "full", "waifu_bastia", 2, SEC, func(w: SimWorld) -> void:
		for e in w.events.count:
			if w.events.kind[e] == SimEvents.Kind.ENEMY_HIT:
				st.total += w.events.value[e])
	var sum := 0.0
	for k: String in r.damage:
		sum += r.damage[k]
	assert_gt(st.total, 0.0)
	assert_almost_eq(sum, st.total, 0.01 * st.total)
	assert_false(r.damage.has("other"), "every hit has a source")


func test_report_smoke() -> void:
	var results: Array[Dictionary] = [Runner.run_one("maze", "fresh", "waifu_cinder", 1, SEC),
		Runner.run_one("spread", "full", "waifu_poppy", 1, SEC)]
	var text := Runner.report(results, 1, {"date": "2026-01-01", "commit": "abc"})
	assert_string_contains(text, "**Targets (D-143):**")
	assert_string_contains(text, "**Maze vs spread:** fresh maze")
	assert_string_contains(text, "## Damage per source")
	assert_string_contains(text, "| maze | fresh | tower_pip |")
	assert_string_contains(text, "## Data")
	assert_string_contains(text, "tower_bastia")
	assert_string_contains(text, "commit abc")
	assert_string_contains(text, "NOT met")
