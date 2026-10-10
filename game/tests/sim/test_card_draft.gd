extends GutTest
## XP, levels and the level-up draft (D-147, 10_M3_CONTENT.md 1-2).

const SWARMER := "enemy_swarmer_01"
const BRUTE := "enemy_brute_01"
const T := CardCatalog.Type

var world: SimWorld


func before_each() -> void:
	world = _new_run(7)


func _new_run(run_seed: int, run_id := "run_m3", unlocked := PackedStringArray()) -> SimWorld:
	var w := SimWorld.new(1)
	w.queue(SimCommand.start_run(0, run_seed, run_id, "", unlocked))
	w.step()
	w.run.first_wave_tick = 1 << 30  # no spawns: these tests place their own enemies
	w.run.final_boss_tick = -1
	w.run.boss_ticks = PackedInt32Array()
	w.gold = 10000
	return w


func _kill(id: String, n: int) -> void:
	for k in n:
		world.enemies.add(world.catalog.type_of(id), 20.0, 0.0, 1.0)
		world.damage_enemy(world.enemies.count() - 1, 10.0)
	world.step()


func _events(kind: SimEvents.Kind) -> Array[int]:
	var out: Array[int] = []
	for e in world.events.count:
		if world.events.kind[e] == kind:
			out.append(world.events.a[e])
	return out


func _pick(slot: int) -> void:
	world.queue(SimCommand.pick_card(world.tick, slot))
	world.step()


func _card(id: String) -> int:
	return world.cards.index_of(id)


func _apply(id: String) -> void:
	for e: Dictionary in world.cards.effects[_card(id)]:
		CardEffects.apply(world, e)


# Card ids offered over n fresh draws of the world's draft state (the cards RNG advances).
func _offered(w: SimWorld, n: int) -> Dictionary:
	var seen := {}
	for k in n:
		w.draft.open(w)
		for c in w.draft.draft:
			seen[w.cards.ids[c]] = true
	w.draft.drafting = false
	return seen


func test_xp_per_kill() -> void:
	_kill(SWARMER, 3)
	_kill(BRUTE, 1)
	assert_almost_eq(world.draft.xp, 7.0, 1e-9)
	_apply("perk_study")
	world.step()  # the cached multiplier is recomputed in PATH
	_kill(SWARMER, 1)
	assert_almost_eq(world.draft.xp, 8.15, 1e-6, "xp +15%, float total")


func test_thresholds() -> void:
	world.draft.xp = 29.9
	world.step()
	assert_eq(world.draft.level, 1)
	assert_false(world.draft.drafting)
	world.draft.xp = 30.0
	world.step()
	assert_eq(world.draft.level, 2)
	assert_eq(_events(SimEvents.Kind.LEVEL_UP), [2] as Array[int])
	assert_true(world.draft.drafting)
	assert_eq(world.draft.draft.size(), 3)
	assert_eq(world.draft.xp_next, 90.0, "30 + 60")
	_pick(0)
	assert_false(world.draft.drafting)
	world.draft.xp = 89.0
	world.step()
	assert_eq(world.draft.level, 2)
	world.draft.xp = 90.0
	world.step()
	assert_eq(world.draft.level, 3)
	assert_eq(world.draft.xp_next, 180.0, "+ 90")


func test_several_level_ups_in_one_tick() -> void:
	world.draft.xp = 180.0
	world.step()
	assert_eq(_events(SimEvents.Kind.LEVEL_UP), [2, 3, 4] as Array[int])
	assert_eq(world.draft.pending, 3)
	for left: int in [2, 1, 0]:
		assert_true(world.draft.drafting)
		_pick(0)
		assert_eq(_events(SimEvents.Kind.CARD_PICKED).size(), 1)
		assert_eq(world.draft.pending, left)
		assert_eq(world.draft.drafting, left > 0, "the next draft opens at once")


func test_frozen_while_drafting() -> void:
	var pip := TowerBuilding.add_built(world, world.tower_catalog.type_of("tower_pip"), 4.0, 4.0)
	world.enemies.add(world.catalog.type_of(SWARMER), 25.0, 0.0, 8.0)
	world.run.first_wave_tick = world.clock + 1  # a spawn would come next tick
	world.draft.xp = 30.0
	world.step()
	assert_true(world.draft.drafting)
	var clock := world.clock
	var x := world.enemies.pos_x[0]
	var count := world.enemies.count()
	var gold := world.gold
	var ready := world.skills.ready_at.duplicate()
	world.queue(SimCommand.place_tower(world.tick, "tower_pip", -4.0, -4.0))
	world.queue(SimCommand.upgrade_tower(world.tick, pip))
	world.queue(SimCommand.use_skill(world.tick, world.run.skill_ids[0]))
	world.step()
	world.queue(SimCommand.sell_tower(world.tick, pip))
	world.queue(SimCommand.rebuild_tower(world.tick, pip))
	for k in 10:
		world.step()
	assert_eq(world.clock, clock, "no clock")
	assert_eq(world.enemies.pos_x[0], x, "no movement")
	assert_eq(world.enemies.count(), count, "no spawn")
	assert_eq(world.towers.count(), 1, "place refused, sell refused")
	assert_eq(world.towers.level[0], 1, "upgrade refused")
	assert_eq(world.gold, gold)
	assert_eq(world.skills.ready_at, ready, "skill refused")
	world.queue(SimCommand.pause(world.tick, true))
	world.step()
	assert_true(world.paused, "pause accepted")
	assert_true(world.draft.drafting, "the draft stays open")
	_pick(0)
	assert_true(world.draft.drafting, "pick refused while paused")
	world.queue(SimCommand.pause(world.tick, false))
	world.step()
	_pick(3)
	_pick(-1)
	assert_true(world.draft.drafting, "bad slot refused")
	_pick(2)
	assert_false(world.draft.drafting)
	world.step()
	assert_eq(world.clock, clock + 2, "running again")


func test_draw_determinism() -> void:
	var a := _new_run(11)
	var b := _new_run(11)
	a.draft.xp = 30.0
	b.draft.xp = 30.0
	a.step()
	b.step()
	assert_eq(a.draft.draft, b.draft.draft, "same seed, same cards")
	var differs := false
	for s: int in [12, 13, 14, 15]:
		var c := _new_run(s)
		c.draft.xp = 30.0
		c.step()
		differs = differs or c.draft.draft != a.draft.draft
	assert_true(differs, "another seed changes the draw")


func test_draw_has_three_distinct_cards() -> void:
	for k in 50:
		world.draft.open(world)
		var d := world.draft.draft
		assert_true(d[0] != d[1] and d[1] != d[2] and d[0] != d[2])


func test_type_weights() -> void:
	var all := PackedStringArray(["waifu_cinder", "waifu_bastia", "waifu_clover", "waifu_hymn", "waifu_tansy", "waifu_poppy"])
	var w := _new_run(3, "run_m3", all)
	var counts := [0, 0, 0, 0]
	var n := 3000
	for k in n:
		w.draft.open(w)
		counts[w.cards.type[w.draft.draft[0]]] += 1
	for k in 4:
		var want: float = [3.0, 2.0, 2.0, 2.0][k] / 9.0
		assert_almost_eq(float(counts[k]) / n, want, 0.04, "type %d share" % k)


func test_eligibility_first_run() -> void:
	var seen := _offered(world, 300)
	for id: String in seen:
		assert_ne(world.cards.type[_card(id)], T.NEW_TOWER, id + ": nothing rescued")
	assert_true(seen.has("card_sig_pip"), "Pip is buildable on run_m3")
	assert_false(seen.has("card_sig_cinder"), "Cinder is not buildable")
	var m2 := _new_run(7, "run_m2")
	for id: String in _offered(m2, 300):
		assert_ne(m2.cards.type[m2.cards.index_of(id)], T.SIGNATURE, id + ": no waifu tower on run_m2")


func test_eligibility_rescued_waifu() -> void:
	world = _new_run(7, "run_m3", PackedStringArray(["waifu_cinder"]))
	var seen := _offered(world, 300)
	assert_true(seen.has("card_tower_cinder"))
	assert_false(seen.has("card_tower_bastia"), "not rescued")
	assert_false(seen.has("card_sig_cinder"), "not buildable yet")
	_apply("card_tower_cinder")
	seen = _offered(world, 300)
	assert_false(seen.has("card_tower_cinder"), "already buildable")
	assert_true(seen.has("card_sig_cinder"), "buildable now")


func test_max_picks() -> void:
	world.draft.picks[_card("perk_sharp")] = 2
	assert_true(world.draft.eligible(world, _card("perk_sharp")))
	world.draft.picks[_card("perk_sharp")] = 3
	assert_false(_offered(world, 300).has("perk_sharp"))


func test_filler_fills_empty_slots() -> void:
	var keep := _card("perk_sharp")
	for c in world.cards.ids.size():
		if c != keep:
			world.draft.picks[c] = maxi(1, world.cards.max_picks[c])
	world.draft.open(world)
	var filler := _card("card_purse")
	assert_eq(world.cards.filler, filler)
	assert_eq(world.draft.draft, PackedInt32Array([keep, filler, filler]))


# A real run_m3 with towers and waves. Without `replay`, picks slot 0 whenever a draft is open
# and records every command; with it, queues those commands only.
func _played(run_seed: int, recorded: Array[SimCommand], replay: Array[SimCommand]) -> SimWorld:
	var w := SimWorld.new(1)
	var cmds: Array[SimCommand] = replay
	if replay.is_empty():
		cmds = [
			SimCommand.start_run(0, run_seed, "run_m3"),
			SimCommand.place_tower(1, "tower_pip", 2.0, 0.0),
			SimCommand.place_tower(1, "tower_pip", -2.0, 0.0),
			SimCommand.place_tower(1, "tower_mallow", 0.0, 2.5),
		]
	for c in cmds:
		w.queue(c)
		recorded.append(c)
	for k in 2400:
		if replay.is_empty() and w.draft.drafting:
			var p := SimCommand.pick_card(w.tick, 0)
			w.queue(p)
			recorded.append(p)
		w.step()
	return w


func test_replay_with_picks() -> void:
	var rec: Array[SimCommand] = []
	var a := _played(5, rec, [])
	var picks := 0
	for c in rec:
		picks += 1 if c.type == SimCommand.Type.PICK_CARD else 0
	assert_gt(picks, 0, "the run levelled up")
	var rec2: Array[SimCommand] = []
	assert_eq(_played(5, rec2, []).state_hash(), a.state_hash(), "same seed and commands")
	var ignored: Array[SimCommand] = []
	assert_eq(_played(5, ignored, rec).state_hash(), a.state_hash(), "replayed from the recorded commands")
