extends SceneTree
## M3 balance runner (task 041, D-164; replaces the M2 runner of D-126). Headless: plays every
## strategy x profile x Guardian of the profile's offer x seed of run_m3 through SimWorld.step()
## (no SimDriver, no scene) and writes a Markdown report.
## godot --headless --path game -s res://balance/balance_runner.gd -- --runs N --out <path>
##   [--commit C] [--only passive,spread,maze] [--profiles fresh,full]
## Exit code 0 even when the targets are missed (the report says so).

const RUN_ID: String = "run_m3"
const STRATEGIES: PackedStringArray = ["passive", "spread", "maze"]
const PROFILES: PackedStringArray = ["fresh", "full"]
## A run still alive at MAX_SEC is a timeout (not won). The final boss spawns at 900 s.
const MAX_SEC: int = 1000
const MINUTE: int = 60 * SimWorld.TICK_RATE
## D-143: maze wins >= spread + 20 points per profile; maze 50-80 % on fresh, >= 80 % on full.
const TARGET_MAZE_LEAD: int = 20
const TARGET_RATE: Dictionary = {"fresh": [50, 80], "full": [80, 100]}


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var runs := 2
	var meta := {"date": Time.get_date_string_from_system(), "commit": "?"}
	var out := ""
	var strategies := STRATEGIES
	var profiles := PROFILES
	for i in args.size() - 1:
		match args[i]:
			"--runs": runs = int(args[i + 1])
			"--out": out = args[i + 1]
			"--commit": meta.commit = args[i + 1]
			"--only": strategies = args[i + 1].split(",")
			"--profiles": profiles = args[i + 1].split(",")
	if out == "":
		out = "res://../reports/balance_%s.md" % meta.date
	var cat := MetaCatalog.load_dir()
	var results: Array[Dictionary] = []
	for strategy in strategies:
		for profile in profiles:
			for guardian in profile_preset(profile, cat).offer(cat):
				for s in range(1, runs + 1):
					var r := run_one(strategy, profile, guardian, s, MAX_SEC)
					print("%s %s %s seed %d: %s at %s, %d towers, %.1f s wall" % [strategy, profile, guardian, s,
						r.outcome, _mmss(r.end_sec), r.towers_bought, r.wall_ms / 1000.0])
					results.append(r)
	var text := report(results, runs, meta)
	var f := FileAccess.open(out, FileAccess.WRITE)
	if f == null:
		push_error("cannot write " + out)
		quit(1)
		return
	f.store_string(text)
	f.close()
	print(text.substr(0, text.find("\n## ", text.find("Maze vs spread"))))
	quit(0)


## `fresh`: nothing rescued, no meta; `full`: every Guardian rescued and every meta node.
static func profile_preset(profile: String, cat: MetaCatalog) -> MetaProfile:
	var p := MetaProfile.fresh(cat)
	if profile == "full":
		p.unlocked = cat.offer_order.duplicate()
		p.meta_nodes = cat.ids.duplicate()
	return p


## Plays one run with `guardian` (a waifu id of the profile's offer). on_step (optional) is called
## with the world after every step.
static func run_one(strategy: String, profile: String, guardian: String, run_seed: int, max_sec: int,
		on_step: Callable = Callable()) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var cat := MetaCatalog.load_dir()
	var w := SimWorld.new(run_seed)
	var bot := BalanceBot.new(strategy)
	w.queue(profile_preset(profile, cat).start_command(cat, 0, run_seed, RUN_ID, guardian))
	var r := {"strategy": strategy, "profile": profile, "guardian": guardian, "seed": run_seed,
		"towers_bought": 0, "husks_rebuilt": 0, "skills_used": 0, "upgrades": 0, "cards": [],
		"damage": {}, "minutes": []}
	var seen := {}
	var earned := 0
	var max_ticks := max_sec * SimWorld.TICK_RATE
	while w.run_state != SimWorld.RunState.WON and w.run_state != SimWorld.RunState.LOST and w.clock < max_ticks:
		if w.tick % BalanceBot.ACT_TICKS == 0:
			bot.act(w)
		w.step()
		var ev := w.events
		var src := "other"  # damage source: the latest TOWER_FIRED, TOWER_HIT or SKILL_USED (D-164)
		for e in ev.count:
			match ev.kind[e]:
				SimEvents.Kind.ENEMY_HIT:
					r.damage[src] = r.damage.get(src, 0.0) + ev.value[e]
				SimEvents.Kind.TOWER_FIRED:
					src = w.tower_catalog.ids[int(ev.value[e])]
				SimEvents.Kind.TOWER_HIT:  # thorns of the hit tower follow
					var t := w.towers.uid.find(ev.a[e])
					src = w.tower_catalog.ids[w.towers.type_id[t]] if t >= 0 else "other"
				SimEvents.Kind.ENEMY_DIED:
					earned += int(ev.value[e])
				SimEvents.Kind.SKILL_USED:
					r.skills_used += 1
					src = "skills"
				SimEvents.Kind.TOWER_UPGRADED:
					r.upgrades += 1
				SimEvents.Kind.CARD_PICKED:
					r.cards.append(w.cards.ids[ev.a[e]])
				SimEvents.Kind.TOWER_PLACED:
					if seen.has(ev.a[e]):
						r.husks_rebuilt += 1
					else:
						seen[ev.a[e]] = true
						r.towers_bought += 1
		if on_step.is_valid():
			on_step.call(w)
		if w.run_state == SimWorld.RunState.RUNNING and w.clock / MINUTE > r.minutes.size():  # once per run minute
			var alive := 0
			var linked := 0
			for t in w.towers.count():
				alive += 1 - w.towers.husk[t]
				linked += int(not w.towers.husk[t] and w.towers.syn_mask[t] != 0)
			r.minutes.append({"hp": int(w.guardian_hp), "gold": w.gold, "earned": earned, "towers": alive,
				"enemies": w.enemies.count(), "level": w.draft.level, "linked": linked})
	var mask := 0
	for t in w.towers.count():
		if not w.towers.husk[t]:
			mask |= w.towers.syn_mask[t]
	r.links = []
	for b in w.synergies.rule_ids.size():
		if mask & (1 << b):
			r.links.append(w.synergies.rule_ids[b])
	r.outcome = {SimWorld.RunState.WON: "won", SimWorld.RunState.LOST: "lost"}.get(w.run_state, "timeout")
	r.end_sec = w.clock / SimWorld.TICK_RATE
	r.earned = earned
	r.hash = w.state_hash()
	r.wall_ms = Time.get_ticks_msec() - t0
	return r


## The Markdown report for `results` (run_one dictionaries), `runs` seeds per Guardian.
static func report(results: Array[Dictionary], runs: int, meta: Dictionary = {}) -> String:
	var s := "# Balance M3 (headless bots, task 041, D-164)\n\n"
	s += "Generated by `scripts\\balance.ps1`. Run date %s, commit %s, N = %d seeds per (strategy, profile, Guardian), MAX_SEC = %d. " % [
		meta.get("date", "?"), meta.get("commit", "?"), runs, MAX_SEC]
	s += "Placeholder numbers: the owner reviews at CP-M3 (needs-human:balance).\n\n"
	s += _targets(results) + "\n"
	s += "| Strategy | Profile | Wins | Win rate | Death time median (min-max) | Win times | Wall s (total) |\n|---|---|---|---|---|---|---|\n"
	for strategy in STRATEGIES:
		for profile in PROFILES:
			var rs := _group(results, strategy, profile)
			if rs.is_empty():
				continue
			var deaths: Array = rs.filter(func(r: Dictionary) -> bool: return r.outcome == "lost").map(
				func(r: Dictionary) -> int: return r.end_sec)
			var won: Array = rs.filter(func(r: Dictionary) -> bool: return r.outcome == "won").map(
				func(r: Dictionary) -> String: return _mmss(r.end_sec))
			deaths.sort()
			var death := "-" if deaths.is_empty() else "%s (%s-%s)" % [_mmss(deaths[deaths.size() / 2]),
				_mmss(deaths[0]), _mmss(deaths[-1])]
			var wall := 0
			for r: Dictionary in rs:
				wall += r.wall_ms
			s += "| %s | %s | %d / %d | %d %% | %s | %s | %.1f |\n" % [strategy, profile, won.size(), rs.size(),
				_rate(rs), death, ", ".join(won) if won else "-", wall / 1000.0]
	s += _guardian_wins(results)
	for strategy in STRATEGIES:
		for profile in PROFILES:
			var rs := _group(results, strategy, profile)
			if not rs.is_empty():
				s += _section(strategy, profile, rs)
	return s + "\n" + _damage(results) + "\n" + _data()


# D-143 targets, each met / NOT met, then the maze vs spread summary line.
static func _targets(results: Array[Dictionary]) -> String:
	var items: Array[String] = []
	var summary: Array[String] = []
	for profile in PROFILES:
		var maze := _group(results, "maze", profile)
		var spread := _group(results, "spread", profile)
		if maze.is_empty() and spread.is_empty():
			continue
		var lo: int = TARGET_RATE[profile][0]
		var hi: int = TARGET_RATE[profile][1]
		items.append("%s maze - spread >= %d points (%d): %s" % [profile, TARGET_MAZE_LEAD, _rate(maze) - _rate(spread),
			_met(_rate(maze) - _rate(spread) >= TARGET_MAZE_LEAD)])
		items.append("%s maze wins %d-%d %% (%d %%): %s" % [profile, lo, hi, _rate(maze), _met(_rate(maze) >= lo and _rate(maze) <= hi)])
		summary.append("%s maze %d %% (median end %s) vs spread %d %% (median end %s)" % [profile, _rate(maze),
			_median_end(maze), _rate(spread), _median_end(spread)])
	var passive := results.filter(func(r: Dictionary) -> bool: return r.strategy == "passive")
	items.append("passive wins none (%d): %s" % [_wins(passive), _met(_wins(passive) == 0)])
	return "**Targets (D-143):** %s.\n\n**Maze vs spread:** %s.\n" % ["; ".join(items), "; ".join(summary)]


static func _guardian_wins(results: Array[Dictionary]) -> String:
	var s := "\nWins per Guardian:\n\n| Profile | Guardian | %s |\n|---|---|%s\n" % [" | ".join(STRATEGIES), "---|".repeat(STRATEGIES.size())]
	for profile in PROFILES:
		var guardians: Array = []
		for r: Dictionary in results:
			if r.profile == profile and not guardians.has(r.guardian):
				guardians.append(r.guardian)
		for g: String in guardians:
			var cells: Array[String] = []
			for strategy in STRATEGIES:
				var rs := _group(results, strategy, profile).filter(func(r: Dictionary) -> bool: return r.guardian == g)
				cells.append("%d / %d" % [_wins(rs), rs.size()] if rs else "-")
			s += "| %s | %s | %s |\n" % [profile, g, " | ".join(cells)]
	return s


static func _section(strategy: String, profile: String, rs: Array) -> String:
	var s := "\n## %s, %s\n\n| Guardian | Seed | Outcome | End | Towers bought | Upgrades | Husks rebuilt | Skills used | Gold earned | Wall s | Cards picked | Relationships at the end |\n|---|---|---|---|---|---|---|---|---|---|---|---|\n" % [strategy, profile]
	for r: Dictionary in rs:
		s += "| %s | %d | %s | %s | %d | %d | %d | %d | %d | %.1f | %s | %s |\n" % [r.guardian, r.seed, r.outcome,
			_mmss(r.end_sec), r.towers_bought, r.upgrades, r.husks_rebuilt, r.skills_used, r.earned, r.wall_ms / 1000.0,
			", ".join(r.cards) if r.cards else "-", ", ".join(r.links) if r.links else "-"]
	s += "\nMedian per minute across the runs still alive:\n\n| Min | Runs | Guardian hp | Gold earned | Gold on hand | Towers alive | Linked towers | Level | Live enemies |\n|---|---|---|---|---|---|---|---|---|\n"
	var m := 0
	while true:
		var rows := rs.filter(func(r: Dictionary) -> bool: return r.minutes.size() > m).map(
			func(r: Dictionary) -> Dictionary: return r.minutes[m])
		if rows.is_empty():
			break
		s += "| %d | %d | %d | %d | %d | %d | %d | %d | %d |\n" % [m + 1, rows.size(), _median(rows, "hp"),
			_median(rows, "earned"), _median(rows, "gold"), _median(rows, "towers"), _median(rows, "linked"),
			_median(rows, "level"), _median(rows, "enemies")]
		m += 1
	return s


# Damage per source: each ENEMY_HIT value is the amount applied, overkill included.
static func _damage(results: Array[Dictionary]) -> String:
	var s := "## Damage per source\n\nEach `ENEMY_HIT` value credited to the latest `TOWER_FIRED` (tower kind), `TOWER_HIT` (thorns of the hit tower) or `SKILL_USED` (`skills`) of its step. Overkill included (the value is the amount applied).\n\n"
	s += "| Strategy | Profile | Source | Damage | Share |\n|---|---|---|---|---|\n"
	for strategy in STRATEGIES:
		for profile in PROFILES:
			var sums := {}
			var total := 0.0
			for r: Dictionary in _group(results, strategy, profile):
				for k: String in r.damage:
					sums[k] = sums.get(k, 0.0) + r.damage[k]
					total += r.damage[k]
			var keys := sums.keys()
			keys.sort()
			for k: String in keys:
				s += "| %s | %s | %s | %d | %d %% |\n" % [strategy, profile, k, roundi(sums[k]), roundi(100.0 * sums[k] / total)]
	return s


static func _group(results: Array[Dictionary], strategy: String, profile: String) -> Array:
	return results.filter(func(r: Dictionary) -> bool: return r.strategy == strategy and r.profile == profile)


static func _wins(rs: Array) -> int:
	return rs.filter(func(r: Dictionary) -> bool: return r.outcome == "won").size()


static func _rate(rs: Array) -> int:
	return roundi(100.0 * _wins(rs) / rs.size()) if rs else 0


static func _median_end(rs: Array) -> String:
	return _mmss(_median(rs, "end_sec")) if rs else "-"


static func _met(ok: bool) -> String:
	return "met" if ok else "NOT met"


static func _median(rows: Array, key: String) -> int:
	var v: Array = rows.map(func(r: Dictionary) -> int: return int(r[key]))
	v.sort()
	return v[v.size() / 2]


# Short form for data floats (float32 -> "3.2", not "3.20000004768372").
static func _n(v: float) -> String:
	return str(snappedf(v, 0.01))


static func _mmss(sec: int) -> String:
	return "%d:%02d" % [sec / 60, sec % 60]


# The numbers the runs used, from the data files.
static func _data() -> String:
	var ec := EnemyCatalog.load_dir()
	var tc := TowerCatalog.load_dir()
	var run := RunData.load_id(RUN_ID, ec, tc)
	var tps := float(SimWorld.TICK_RATE)
	var s := "## Data\n\n`%s`: starting gold %d, build radius %.0f, wave %d s + break %d s, xp base %s + step %s, " % [
		RUN_ID, run.starting_gold, run.build_radius, run.wave_ticks / tps, run.break_ticks / tps, _n(run.xp_base), _n(run.xp_step)]
	s += "wave counts %s (last repeats), run towers %s.\n\n" % [", ".join(Array(run.wave_count).map(
		func(c: int) -> String: return str(c))), ", ".join(Array(run.tower_types).map(func(t: int) -> String: return tc.ids[t]))]
	s += "| Guardian | HP | Skills |\n|---|---|---|\n"
	for g in DataFiles.read_dir("res://data/guardians"):
		s += "| %s | %s | %s |\n" % [g.id, _n(g.hp), ", ".join(g.skills)]
	s += "\n| Skill | Numbers |\n|---|---|\n"
	for k in DataFiles.read_dir("res://data/skills"):
		var parts: Array[String] = []
		for key: String in k:
			if not key in ["schema_version", "id", "name_key", "desc_key", "placeholder"]:
				parts.append("%s %s" % [key, k[key]])
		s += "| %s | %s |\n" % [k.id, ", ".join(parts)]
	s += "\nM3 towers, level 1 (levels: max level; upgrade costs from level 2):\n\n"
	s += "| Tower | Kind | Cost | Per copy | Damage | Cooldown s | Range | HP | Levels |\n|---|---|---|---|---|---|---|---|---|\n"
	for t in tc.ids.size():
		if tc.max_level[t] <= 1:
			continue  # M2 towers
		var costs: Array = tc.level_stats[t].slice(1).map(func(l: Dictionary) -> String: return str(int(l.cost)))
		s += "| %s | %s | %d | %d | %s | %.2f | %s | %s | %d (%s) |\n" % [tc.ids[t],
			TowerCatalog.Attack.keys()[tc.attack[t]].to_lower(), tc.cost[t], tc.cost_per_copy[t], _n(tc.damage[t]),
			tc.cooldown[t] / tps, _n(tc.attack_range[t]), _n(tc.hp[t]), tc.max_level[t], ", ".join(costs)]
	s += "\n| Enemy | HP | Speed | Damage | Gold (chance) | XP | Spawns |\n|---|---|---|---|---|---|---|\n"
	for e in ec.ids.size():
		var when := ""
		if e == run.final_boss_type:
			when = "final boss %d s" % (run.final_boss_tick / SimWorld.TICK_RATE)
		elif run.boss_types.has(e):
			when = "mini-boss %d s" % (run.boss_ticks[run.boss_types.find(e)] / SimWorld.TICK_RATE)
		s += "| %s | %s | %s | %s | %d (%s) | %s | %s |\n" % [ec.ids[e], _n(ec.hp[e]), _n(ec.speed[e]), _n(ec.damage[e]),
			ec.gold[e], _n(ec.gold_chance[e]), _n(ec.xp[e]), when if when else "waves"]
	return s
