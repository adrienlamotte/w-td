class_name CardDraft
extends RefCounted
## XP, levels and the level-up draft (D-147, 10_M3_CONTENT.md 1). Reset at StartRun. Hashed.

const SLOTS: int = 3

## Float XP total, added in DEATHS order (deterministic).
var xp: float = 0.0
var level: int = 1
## XP total at which the next level is reached.
var xp_next: float = 0.0
## Level-ups whose draft is not yet picked (the open one included).
var pending: int = 0
## Frozen like a pause while true (rule 4).
var drafting: bool = false
## Card indices of the open draft (SLOTS of them); empty when closed.
var draft: PackedInt32Array = PackedInt32Array()
## Picks per card index this run.
var picks: PackedInt32Array = PackedInt32Array()
## The `cards` RNG, seeded from the run seed by SimWorld (3a).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func reset(xp_base: float, card_count: int) -> void:
	xp = 0.0
	level = 1
	xp_next = xp_base
	pending = 0
	drafting = false
	draft = PackedInt32Array()
	picks = PackedInt32Array()
	picks.resize(card_count)


## End of DEATHS (rule 2): every threshold crossed is a level-up; then a draft opens if none is.
func check_levels(w: SimWorld) -> void:
	while xp >= xp_next:
		level += 1
		pending += 1
		w.events.push(SimEvents.Kind.LEVEL_UP, level, 0.0, 0.0, 0.0)
		xp_next += w.run.xp_base + w.run.xp_step * (level - 1)
	if not drafting and pending > 0:
		open(w)


## Draws SLOTS cards (rule 3): per slot a type by weight, then a card uniformly; filler when none is left.
func open(w: SimWorld) -> void:
	var cat := w.cards
	draft = PackedInt32Array()
	for s in SLOTS:
		var by_type: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array(), PackedInt32Array(), PackedInt32Array()]
		for c in cat.ids.size():
			if cat.type[c] != CardCatalog.Type.FILLER and not draft.has(c) and eligible(w, c):
				by_type[cat.type[c]].append(c)
		var total := 0.0
		for k in by_type.size():
			if not by_type[k].is_empty():
				total += w.run.card_type_weights[k]
		if total <= 0.0:
			draft.append(cat.filler)
			continue
		var r := rng.randf() * total
		var pick_type := -1
		for k in by_type.size():
			if by_type[k].is_empty():
				continue
			pick_type = k
			r -= w.run.card_type_weights[k]
			if r < 0.0:
				break
		var pool := by_type[pick_type]
		draft.append(pool[rng.randi_range(0, pool.size() - 1)])
	drafting = true


## Rule 3 eligibility, without the "not already in this draft" part.
func eligible(w: SimWorld, c: int) -> bool:
	var cat := w.cards
	if picks[c] >= cat.max_picks[c]:
		return false
	if cat.req_unlocked[c] != "" and not w.unlocked.has(cat.req_unlocked[c]):
		return false
	if cat.req_buildable_type[c] >= 0 and not w.tower_types.has(cat.req_buildable_type[c]):
		return false
	return cat.unlock_type[c] < 0 or not w.tower_types.has(cat.unlock_type[c])


## PICK_CARD (rule 5); the caller checks RUNNING and not paused. A bad slot or no draft: ignored.
func pick(w: SimWorld, slot: int) -> void:
	if not drafting or slot < 0 or slot >= draft.size():
		return
	var c := draft[slot]
	for e: Dictionary in w.cards.effects[c]:
		CardEffects.apply(w, e)
	picks[c] += 1
	w.events.push(SimEvents.Kind.CARD_PICKED, c, 0.0, 0.0, slot)
	drafting = false
	draft = PackedInt32Array()
	pending -= 1
	if pending > 0:
		open(w)


func hash_parts() -> Array:
	return [xp, level, xp_next, pending, drafting, draft, picks, rng.state]
