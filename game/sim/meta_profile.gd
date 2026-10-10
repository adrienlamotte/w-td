class_name MetaProfile
extends RefCounted
## The persistent meta profile (10_M3_CONTENT.md 7, D-152): pure rules, no file access
## (game/save/profile_store.gd reads and writes it).

const CURRENT_VERSION := 1

## Verdicts of check_buy, in check order (D-152 rule 6).
enum Buy { OK, UNKNOWN, OWNED, LOCKED, NO_HEARTS }
## Hub roster states (task 039).
enum Roster { STARTER, RESCUED, LOCKED }

## Rescued waifu ids; starters are implicit.
var unlocked: PackedStringArray = PackedStringArray()
var hearts: int = 0
var meta_nodes: PackedStringArray = PackedStringArray()
## Waifu id -> bond, kept at 0 in M3 (D-052): every waifu of the data.
var bond: Dictionary = {}
var runs: int = 0
var wins: int = 0
var losses: int = 0
## Guardian id -> longest run clock reached with her, whole seconds, wins included.
var best_sec: Dictionary = {}


## A profile from a parsed document, migrated to CURRENT_VERSION; null when unreadable
## (not a Dictionary, a wrong type, or a newer schema_version). Unknown ids are dropped.
static func from_dict(data: Variant, cat: MetaCatalog) -> MetaProfile:
	if not data is Dictionary:
		return null
	var d: Dictionary = data.duplicate(true)
	var v: Variant = d.get("schema_version", 0)
	if not _is_int(v) or int(v) < 0 or int(v) > CURRENT_VERSION:
		return null
	for step in range(int(v), CURRENT_VERSION):  # one step per version, in order
		match step:
			0: d = _v0_to_v1(d)
	var stats: Variant = d.get("stats")
	if not (d.get("unlocked") is Array and d.get("meta_nodes") is Array and d.get("bond") is Dictionary
			and stats is Dictionary and _is_int(d.get("hearts")) and d.hearts >= 0
			and _is_int(stats.get("runs")) and _is_int(stats.get("wins")) and _is_int(stats.get("losses"))
			and stats.get("best_sec") is Dictionary):
		return null
	var p := MetaProfile.new()
	for id: Variant in d.unlocked:
		if not id is String:
			return null
		if cat.guardian_of.has(id) and not p.unlocked.has(id):
			p.unlocked.append(id)
	for id: Variant in d.meta_nodes:
		if not id is String:
			return null
		if cat.cost.has(id) and not p.meta_nodes.has(id):
			p.meta_nodes.append(id)
	for g: Variant in stats.best_sec:
		if not _is_int(stats.best_sec[g]):
			return null
		p.best_sec[String(g)] = int(stats.best_sec[g])
	for w in cat.waifu_ids:
		p.bond[w] = 0
	p.hearts = int(d.hearts)
	p.runs = int(stats.runs)
	p.wins = int(stats.wins)
	p.losses = int(stats.losses)
	return p


## A fresh profile: nothing rescued, no hearts, every waifu at bond 0.
static func fresh(cat: MetaCatalog) -> MetaProfile:
	return from_dict({}, cat)


func to_dict() -> Dictionary:
	return {"schema_version": CURRENT_VERSION, "unlocked": Array(unlocked), "hearts": hearts,
		"meta_nodes": Array(meta_nodes), "bond": bond.duplicate(),
		"stats": {"runs": runs, "wins": wins, "losses": losses, "best_sec": best_sec.duplicate()}}


## The locked waifus offered as Guardians (D-050, D-142): the next 3 in offer order;
## all of them again once every one is rescued.
func offer(cat: MetaCatalog) -> PackedStringArray:
	var out := PackedStringArray()
	for w in cat.offer_order:
		if not unlocked.has(w) and out.size() < 3:
			out.append(w)
	return out if not out.is_empty() else cat.offer_order.duplicate()


## Hearts for a run that ended at run clock `clock` (6.1, D-048), in integer arithmetic.
## 0 for a loss before the first wave started (D-158): the spawner starts wave 0 in the
## step that runs clock first_wave_tick, so the clock is past it only after that step.
static func hearts_for(run: RunData, won: bool, clock: int) -> int:
	if won:
		return run.hearts_win
	if clock <= run.first_wave_tick:
		return 0
	var span := run.hearts_loss_max - run.hearts_loss_min
	return run.hearts_loss_min + span * mini(clock, run.final_boss_tick) / run.final_boss_tick


## Run end (D-152 rule 5): hearts, stats, the Guardian unlocked on a win. Returns the hearts earned.
func record_run(cat: MetaCatalog, run: RunData, won: bool, clock: int) -> int:
	var earned := hearts_for(run, won, clock)
	hearts += earned
	runs += 1
	if won:
		wins += 1
		var w := cat.waifu_of(run.guardian_id)
		if w != "" and not unlocked.has(w):
			unlocked.append(w)
	else:
		losses += 1
	best_sec[run.guardian_id] = maxi(best_sec.get(run.guardian_id, 0), clock / SimWorld.TICK_RATE)
	return earned


func roster_state(cat: MetaCatalog, waifu_id: String) -> Roster:
	if cat.starters.has(waifu_id):
		return Roster.STARTER
	return Roster.RESCUED if unlocked.has(waifu_id) else Roster.LOCKED


func check_buy(cat: MetaCatalog, id: String) -> Buy:
	if not cat.cost.has(id):
		return Buy.UNKNOWN
	if meta_nodes.has(id):
		return Buy.OWNED
	for r: String in cat.requires[id]:
		if not meta_nodes.has(r):
			return Buy.LOCKED
	return Buy.NO_HEARTS if hearts < cat.cost[id] else Buy.OK


func buy(cat: MetaCatalog, id: String) -> Buy:
	var verdict := check_buy(cat, id)
	if verdict == Buy.OK:
		hearts -= cat.cost[id]
		meta_nodes.append(id)
	return verdict


## StartRun with `waifu_id` as Guardian; null unless she is in the offer (D-152 rule 7).
func start_command(cat: MetaCatalog, tick: int, run_seed: int, run_id: String, waifu_id: String) -> SimCommand:
	if not offer(cat).has(waifu_id):
		return null
	return SimCommand.start_run(tick, run_seed, run_id, cat.guardian_of[waifu_id], unlocked.duplicate(),
		meta_nodes.duplicate())


# JSON numbers parse as float.
static func _is_int(x: Variant) -> bool:
	return x is int or (x is float and x == floorf(x))


# Step 0 -> 1: the pre-versioned shape; every missing field gets its default.
static func _v0_to_v1(d: Dictionary) -> Dictionary:
	var stats: Variant = d.get("stats", {})
	if stats is Dictionary:
		for k: String in ["runs", "wins", "losses"]:
			stats[k] = stats.get(k, 0)
		stats.best_sec = stats.get("best_sec", {})
	return {"schema_version": 1, "unlocked": d.get("unlocked", []), "hearts": d.get("hearts", 0),
		"meta_nodes": d.get("meta_nodes", []), "bond": d.get("bond", {}), "stats": stats}
