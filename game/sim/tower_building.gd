class_name TowerBuilding
extends RefCounted
## PlaceTower, SellTower, RebuildTower and tower damage (D-109), split out of SimWorld.
## The caller applies the gate (RUNNING and not paused, D-105); a rejected command
## changes nothing and pushes no event.


static func place(w: SimWorld, cmd: SimCommand) -> void:
	var cat := w.tower_catalog
	var type := cat.type_of(cmd.tower_id)
	if type < 0 or not w.run.tower_types.has(type):
		return
	var b := w.build
	var radius := cat.radius[type]
	var n := BuildGrid.footprint(radius, b.step)
	var i0 := b.first_cell(cmd.x, n)
	var j0 := b.first_cell(cmd.z, n)
	if not b.is_free(i0, j0, n):  # out of the grid, or a tower or husk is there
		return
	var cx := b.cell_centre(i0, n)
	var cz := b.cell_centre(j0, n)
	var dist := sqrt(cx * cx + cz * cz)
	if dist + radius > w.run.build_radius or dist < w.run.guardian_contact_radius + radius:
		return
	var price := cat.cost[type] + cat.cost_per_copy[type] * w.towers.copies(type)  # husks count (D-113)
	if w.gold < price:
		return
	w.gold -= price
	var uid := w.next_tower_uid
	w.next_tower_uid += 1
	var towers := w.towers
	var t := towers.add(cx, cz, cat.attack_range[type])
	towers.uid[t] = uid
	towers.type_id[t] = type
	towers.paid[t] = price
	towers.cell_i[t] = i0
	towers.cell_j[t] = j0
	towers.footprint[t] = n
	towers.hp[t] = cat.hp[type]
	# Enemies standing on the footprint are allowed; task 024 pushes them out (D-112).
	b.fill(i0, j0, n, uid, 1)
	w.events.push(SimEvents.Kind.TOWER_PLACED, uid, cx, cz, type)


static func sell(w: SimWorld, tower_uid: int) -> void:
	var towers := w.towers
	var t := _find(towers, tower_uid)
	if t < 0:
		return
	var refund := 0  # selling a husk just clears it (D-113)
	if not towers.husk[t]:
		refund = floori(towers.paid[t] * w.tower_catalog.sell_refund[towers.type_id[t]])
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
	var price := floori(towers.paid[t] * w.tower_catalog.rebuild_fraction[type])  # of the price paid (D-113)
	if w.gold < price:
		return
	w.gold -= price
	towers.hp[t] = w.tower_catalog.hp[type]
	towers.husk[t] = 0
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
