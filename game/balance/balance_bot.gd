class_name BalanceBot
extends RefCounted
## M2 balance bot (task 022, D-126). A sim client like PlayerInput: it only queues
## SimCommands and reads state and the read-only queries (check_place, price,
## rebuild_price). No randomness. Strategies: passive, spread, ring.

## The bot acts every ACT_TICKS ticks (0.5 s).
const ACT_TICKS: int = 15
## Ring radius: the smallest run tower range (5) minus the Guardian contact radius (1),
## so every ring tower covers the Guardian and the corridor.
const RING_R: float = 4.0
const RING_GAP: float = 2.0
## Ring bot: the first towers go on the kill zone inside the gap, then the ring.
const KILL_ZONE_FIRST: int = 6
const KILL_ZONE: Vector2 = Vector2(RING_R - RING_GAP, 0.0)
## Sunflower spacing (units per sqrt(index)).
const SPIRAL_STEP: float = 1.0
const MAX_TRIES: int = 64
const GOLDEN_ANGLE: float = 2.39996

var strategy: String
var _spiral: int = 0
var _ring: PackedFloat32Array = PackedFloat32Array()
var _ring_next: int = 0


func _init(p_strategy: String) -> void:
	strategy = p_strategy


## Queues this act's commands: skills that are ready, then at most one build command.
func act(w: SimWorld) -> void:
	if w.run_state != SimWorld.RunState.RUNNING or w.paused:
		return
	if w.draft.drafting:  # always the first card (D-147), so runs stay comparable
		w.queue(SimCommand.pick_card(w.tick, 0))
		return
	for slot in w.run.skill_ids.size():
		if w.skills.ready_at[slot] <= w.clock:
			w.queue(SimCommand.use_skill(w.tick, w.run.skill_ids[slot]))
	if strategy == "passive":
		return
	for t in w.towers.count():
		if w.towers.husk[t] and w.gold >= TowerBuilding.rebuild_price(w, t):
			w.queue(SimCommand.rebuild_tower(w.tick, w.towers.uid[t]))
			return
	var type := _cheapest(w)
	if w.gold < TowerBuilding.price(w, type):
		return
	var id := w.tower_catalog.ids[type]
	var spot: Variant = null
	if strategy == "ring":
		# Kill zone (a sunflower inside the gap) first, then the ring, then extras on the kill zone.
		if w.towers.count() >= KILL_ZONE_FIRST:
			spot = _ring_spot(w, id)
		if spot == null:
			spot = _spiral_spot(w, id, KILL_ZONE, true)
	else:
		spot = _spiral_spot(w, id, Vector2.ZERO, false)
	if spot != null:
		w.queue(SimCommand.place_tower(w.tick, id, spot.x, spot.y))


# Lowest current price; ties go to run order.
func _cheapest(w: SimWorld) -> int:
	var best := w.run.tower_types[0]
	for type in w.run.tower_types:
		if TowerBuilding.price(w, type) < TowerBuilding.price(w, best):
			best = type
	return best


# Next free sunflower point around `centre`; a spot rejected once stays rejected
# (occupied, out of radius or too close), so the scan resumes after it.
func _spiral_spot(w: SimWorld, id: String, centre: Vector2, keep_corridor: bool) -> Variant:
	for n in MAX_TRIES:
		var k := _spiral
		_spiral += 1
		var p := centre + Vector2.from_angle(k * GOLDEN_ANGLE) * SPIRAL_STEP * sqrt(k)
		if keep_corridor and p.x > 0.0 and absf(p.y) < RING_GAP:
			continue  # keep the path from the gap to the Guardian open
		if TowerBuilding.check_place(w, id, p.x, p.y).reason == TowerBuilding.Reason.OK:
			return p
	return null


# Ring slots from angle PI toward the gap at angle 0, on both sides; null once all tried.
func _ring_spot(w: SimWorld, id: String) -> Variant:
	if _ring.is_empty():
		_build_ring(TowerBuilding.check_place(w, id, 0.0, 0.0).footprint * w.build.step)
	for n in MAX_TRIES:
		if _ring_next >= _ring.size():
			return null
		var p := Vector2.from_angle(_ring[_ring_next]) * RING_R
		_ring_next += 1
		if TowerBuilding.check_place(w, id, p.x, p.y).reason == TowerBuilding.Reason.OK:
			return p
	return null


func _build_ring(side: float) -> void:
	var slots := floori(TAU * RING_R / side)
	var d := TAU / slots
	for m in slots / 2 + 1:
		for a in ([PI + m * d, PI - m * d] if m > 0 else [PI]):
			# Chord to the gap centre at (RING_R, 0): keep the gap width plus half a tower clear.
			if Vector2.from_angle(a).distance_to(Vector2.RIGHT) * RING_R < RING_GAP * 0.5 + side * 0.5:
				continue
			if not _ring.has(fposmod(a, TAU)):
				_ring.append(fposmod(a, TAU))
