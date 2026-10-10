class_name BalanceBot
extends RefCounted
## M3 balance bot (task 041, D-164; M2: D-126). A sim client like PlayerInput: it only queues
## SimCommands and reads state and the read-only queries (check_place, price, rebuild_price,
## TowerUpgrade.check). No randomness. Strategies: passive, spread, maze.

## The bot acts every ACT_TICKS ticks (0.5 s).
const ACT_TICKS: int = 15
## Maze rings (D-164): walls 1 unit thick, corridors about 2 units, all inside every tower's range.
const MAZE_RINGS: PackedFloat32Array = [2.5, 5.5, 8.5]
## One gap per ring, alternating at angle 0 and PI (the bench maze shape, D-115).
const MAZE_GAP: float = 2.0
## Sunflower spacing (units per sqrt(index)).
const SPIRAL_STEP: float = 1.0
const MAX_TRIES: int = 64
const GOLDEN_ANGLE: float = 2.39996

var strategy: String
var _spiral: int = 0
## Spread: index of the next tower type, round robin over the non-wall buildable types.
var _rr: int = 0
## Maze slots in build order: {"pos": Vector2, "k": angular slot index on its ring}.
var _maze: Array[Dictionary] = []
var _maze_next: int = 0


func _init(p_strategy: String) -> void:
	strategy = p_strategy


## Queues this act's commands: a card pick while drafting; else ready skills, then at most one
## build command.
func act(w: SimWorld) -> void:
	if w.run_state != SimWorld.RunState.RUNNING or w.paused:
		return
	if w.draft.drafting:
		w.queue(SimCommand.pick_card(w.tick, pick_slot(w)))
		return
	for slot in w.run.skill_ids.size():
		if w.skills.ready_at[slot] <= w.clock:
			w.queue(SimCommand.use_skill(w.tick, w.run.skill_ids[slot]))
	if strategy == "passive":
		return
	var cmd := spend(w)
	if cmd:
		w.queue(cmd)


## Open draft slot whose card ranks first: CardCatalog.Type order, ties by lower card index.
static func pick_slot(w: SimWorld) -> int:
	var d := w.draft.draft
	var best := 0
	for s in d.size():
		if _rank(w, d[s]) < _rank(w, d[best]):
			best = s
	return best


static func _rank(w: SimWorld, c: int) -> int:
	return w.cards.type[c] * 100000 + c


## This act's build command, or null (D-164): the first affordable husk; else the cheaper of the
## next placement and the cheapest affordable upgrade (ties: placement); no spot left: upgrade.
func spend(w: SimWorld) -> SimCommand:
	for t in w.towers.count():
		if w.towers.husk[t] and w.gold >= TowerBuilding.rebuild_price(w, t):
			return SimCommand.rebuild_tower(w.tick, w.towers.uid[t])
	var up_uid := -1
	var up_price := 0
	for t in w.towers.count():
		var c := TowerUpgrade.check(w, w.towers.uid[t])
		if c.reason == TowerUpgrade.Reason.OK and (up_uid < 0 or c.price < up_price
				or (c.price == up_price and w.towers.uid[t] < up_uid)):
			up_uid = w.towers.uid[t]
			up_price = c.price
	var place := _next_place(w)
	if up_uid >= 0 and (place == null or up_price < place.price):
		return SimCommand.upgrade_tower(w.tick, up_uid)
	if place == null or place.reason != TowerBuilding.Reason.OK:
		return null  # waits for gold rather than changing the plan
	if strategy == "spread":
		_rr += 1
	return SimCommand.place_tower(w.tick, w.tower_catalog.ids[place.type], place.x, place.z)


# The next placement as a TowerBuilding.Check (OK or NO_GOLD), null when no spot is left.
# A spot rejected for another reason stays rejected; the bot's own tower makes it OCCUPIED.
func _next_place(w: SimWorld) -> TowerBuilding.Check:
	if strategy == "maze":
		return _maze_place(w)
	var types: Array[int] = []
	for type in w.tower_types:
		if not _is_wall(w, type):  # a lone wall does nothing in a spread
			types.append(type)
	if types.is_empty():
		return null
	var id := w.tower_catalog.ids[types[_rr % types.size()]]
	for n in MAX_TRIES:
		var p := Vector2.from_angle(_spiral * GOLDEN_ANGLE) * SPIRAL_STEP * sqrt(_spiral)
		var c := TowerBuilding.check_place(w, id, p.x, p.y)
		if c.reason == TowerBuilding.Reason.OK or c.reason == TowerBuilding.Reason.NO_GOLD:
			return c
		_spiral += 1
	return null


func _maze_place(w: SimWorld) -> TowerBuilding.Check:
	if _maze.is_empty():
		var any := w.tower_catalog.ids[w.tower_types[0]]
		_build_maze(TowerBuilding.check_place(w, any, 0.0, 0.0).footprint * w.build.step)
	var pair := maze_pair(w)
	while _maze_next < _maze.size():
		var slot := _maze[_maze_next]
		var id := w.tower_catalog.ids[pair[slot.k % 2]]
		var c := TowerBuilding.check_place(w, id, slot.pos.x, slot.pos.y)
		if c.reason == TowerBuilding.Reason.OK or c.reason == TowerBuilding.Reason.NO_GOLD:
			return c
		_maze_next += 1
	return null


## The two tower types the maze alternates (D-164): the first pair in buildable order with a
## min-distance-0 relationship rule, preferring one with a wall kind; none: the cheapest type twice.
static func maze_pair(w: SimWorld) -> Array[int]:
	var types := w.tower_types
	var first: Array[int] = []
	for i in types.size():
		for j in range(i + 1, types.size()):
			if not _linked(w, types[i], types[j]):
				continue
			var pair: Array[int] = [types[i], types[j]]
			if _is_wall(w, types[i]) or _is_wall(w, types[j]):
				return pair
			if first.is_empty():
				first = pair
	if not first.is_empty():
		return first
	var best := types[0]
	for type in types:
		if TowerBuilding.price(w, type) < TowerBuilding.price(w, best):
			best = type
	return [best, best]


static func _is_wall(w: SimWorld, type: int) -> bool:
	return w.tower_catalog.attack[type] == TowerCatalog.Attack.WALL


# A rule with min_distance 0 (bff, mentor) between the two types' waifus; rivals are not used.
static func _linked(w: SimWorld, a: int, b: int) -> bool:
	var syn := w.synergies
	var wa := syn.waifu_of_tower[a]
	var wb := syn.waifu_of_tower[b]
	if wa < 0 or wb < 0:
		return false
	for r in syn.rules_for(wa, wb):
		if syn.min_d[r] <= 0.0:
			return true
	return false


## Gap angle of maze ring `ring`: 0, PI, 0, ...
static func gap_angle(ring: int) -> float:
	return 0.0 if ring % 2 == 0 else PI


# Inner ring first; each ring from the side opposite its gap toward the gap, both sides in turn.
func _build_maze(side: float) -> void:
	for ring in MAZE_RINGS.size():
		var r := MAZE_RINGS[ring]
		var g := gap_angle(ring)
		var slots := floori(TAU * r / side)
		var d := TAU / slots
		var gap_centre := Vector2.from_angle(g) * r
		var j0 := slots / 2
		var order: Array[int] = [j0]
		for m in range(1, slots / 2 + 1):
			order.append_array([posmod(j0 + m, slots), posmod(j0 - m, slots)])
		var seen := {}
		for j in order:
			var p := Vector2.from_angle(g + j * d) * r
			# Keep the gap width plus half a tower clear around the gap centre.
			if seen.has(j) or p.distance_to(gap_centre) < MAZE_GAP * 0.5 + side * 0.5:
				continue
			seen[j] = true
			_maze.append({"pos": p, "k": j})
