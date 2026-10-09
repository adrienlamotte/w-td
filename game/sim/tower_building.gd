class_name TowerBuilding
extends RefCounted
## PlaceTower, SellTower, RebuildTower and tower damage (D-109), split out of SimWorld.
## The caller applies the gate (RUNNING and not paused, D-105); a rejected command
## changes nothing and pushes no event.


## Verdicts of check_place, in check order (D-121).
enum Reason { OK, NOT_OFFERED, OCCUPIED, OUT_OF_RADIUS, TOO_CLOSE, NO_GOLD }


## Result of check_place: the verdict and, from OCCUPIED on, where the tower would stand.
class Check:
	var reason: Reason = Reason.NOT_OFFERED
	var type: int = -1
	## Snapped footprint centre.
	var x: float = 0.0
	var z: float = 0.0
	## Cells per side, and the first cell of the footprint.
	var footprint: int = 0
	var i0: int = 0
	var j0: int = 0
	var price: int = 0


## The single placement rule (D-121): the build UI shows this, place() commits it.
## Read-only. The RUNNING/not-paused gate is the caller's (SimWorld._apply).
static func check_place(w: SimWorld, tower_id: String, x: float, z: float) -> Check:
	var c := Check.new()
	var cat := w.tower_catalog
	c.type = cat.type_of(tower_id)
	if c.type < 0 or not w.run.tower_types.has(c.type):
		return c
	var b := w.build
	var radius := cat.radius[c.type]
	c.footprint = BuildGrid.footprint(radius, b.step)
	c.i0 = b.first_cell(x, c.footprint)
	c.j0 = b.first_cell(z, c.footprint)
	c.x = b.cell_centre(c.i0, c.footprint)
	c.z = b.cell_centre(c.j0, c.footprint)
	c.price = price(w, c.type)
	var dist := sqrt(c.x * c.x + c.z * c.z)
	if not b.is_free(c.i0, c.j0, c.footprint):  # out of the grid, or a tower or husk is there
		c.reason = Reason.OCCUPIED
	elif dist + radius > w.run.build_radius:
		c.reason = Reason.OUT_OF_RADIUS
	elif dist < w.run.guardian_contact_radius + radius:
		c.reason = Reason.TOO_CLOSE
	elif w.gold < c.price:
		c.reason = Reason.NO_GOLD
	else:
		c.reason = Reason.OK
	return c


## Price of the next tower of this catalog type: rises per copy, husks count (D-113).
static func price(w: SimWorld, type: int) -> int:
	return w.tower_catalog.cost[type] + w.tower_catalog.cost_per_copy[type] * w.towers.copies(type)


## Price to rebuild husk t: a fraction of what was paid (D-113).
static func rebuild_price(w: SimWorld, t: int) -> int:
	return floori(w.towers.paid[t] * w.tower_catalog.rebuild_fraction[w.towers.type_id[t]])


## Gold back for selling tower t; 0 for a husk (D-113).
static func sell_refund(w: SimWorld, t: int) -> int:
	if w.towers.husk[t]:
		return 0
	return floori(w.towers.paid[t] * w.tower_catalog.sell_refund[w.towers.type_id[t]])


static func place(w: SimWorld, cmd: SimCommand) -> void:
	var c := check_place(w, cmd.tower_id, cmd.x, cmd.z)
	if c.reason != Reason.OK:
		return
	w.gold -= c.price
	add_built(w, c.type, c.x, c.z, c.price)


## Snaps and appends a built tower of catalog type `type` and fills its cells; returns its
## uid, or -1 when a cell is out of the grid or taken. No gate, gold, radius or run checks:
## place() is the command path; tests and the bench lay out mazes with this (D-115).
static func add_built(w: SimWorld, type: int, x: float, z: float, paid: int = 0) -> int:
	var b := w.build
	var n := BuildGrid.footprint(w.tower_catalog.radius[type], b.step)
	var i0 := b.first_cell(x, n)
	var j0 := b.first_cell(z, n)
	if not b.is_free(i0, j0, n):
		return -1
	x = b.cell_centre(i0, n)
	z = b.cell_centre(j0, n)
	var uid := w.next_tower_uid
	w.next_tower_uid += 1
	var towers := w.towers
	var t := towers.add(x, z, w.tower_catalog.attack_range[type])
	towers.uid[t] = uid
	towers.type_id[t] = type
	towers.paid[t] = paid
	towers.cell_i[t] = i0
	towers.cell_j[t] = j0
	towers.footprint[t] = n
	towers.hp[t] = w.tower_catalog.hp[type]
	# Enemies standing on the footprint are allowed; FlowField pushes them out (D-112, D-115).
	b.fill(i0, j0, n, uid, 1)
	w.events.push(SimEvents.Kind.TOWER_PLACED, uid, x, z, type)
	return uid


static func sell(w: SimWorld, tower_uid: int) -> void:
	var towers := w.towers
	var t := _find(towers, tower_uid)
	if t < 0:
		return
	var refund := sell_refund(w, t)  # selling a husk just clears it (D-113)
	w.gold += refund
	w.build.fill(towers.cell_i[t], towers.cell_j[t], towers.footprint[t], -1, 0)
	w.events.push(SimEvents.Kind.TOWER_SOLD, tower_uid, towers.pos_x[t], towers.pos_z[t], refund)
	towers.remove(t)


static func rebuild(w: SimWorld, tower_uid: int) -> void:
	var towers := w.towers
	var t := _find(towers, tower_uid)
	if t < 0 or not towers.husk[t]:
		return
	var type := towers.type_id[t]
	var price := rebuild_price(w, t)
	if w.gold < price:
		return
	w.gold -= price
	towers.hp[t] = w.tower_catalog.hp[type]
	towers.husk[t] = 0
	towers.cooldown[t] = 0
	w.build.fill(towers.cell_i[t], towers.cell_j[t], towers.footprint[t], tower_uid, 1)
	w.events.push(SimEvents.Kind.TOWER_PLACED, tower_uid, towers.pos_x[t], towers.pos_z[t], type)


## A lethal hit leaves a walkable husk that keeps its cells (D-104); a husk ignores damage.
static func damage(w: SimWorld, t: int, amount: float) -> void:
	var towers := w.towers
	if towers.husk[t]:
		return
	towers.hp[t] -= amount
	if towers.hp[t] > 0.0:
		return
	towers.hp[t] = 0.0
	towers.husk[t] = 1
	towers.target[t] = -1
	if w.build:  # a bare tower (add()) has no cells
		w.build.fill(towers.cell_i[t], towers.cell_j[t], towers.footprint[t], towers.uid[t], 0)
	w.events.push(SimEvents.Kind.TOWER_DIED, towers.uid[t], towers.pos_x[t], towers.pos_z[t], 0.0)


# Bare towers have uid -1 and are never addressed by a command.
static func _find(towers: SimTowers, tower_uid: int) -> int:
	return -1 if tower_uid < 0 else towers.uid.find(tower_uid)
