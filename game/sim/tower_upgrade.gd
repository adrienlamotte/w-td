class_name TowerUpgrade
extends RefCounted
## UPGRADE_TOWER (D-144): buys the next level of a placed tower. The caller applies the gate
## (RUNNING and not paused, D-105); a rejected upgrade changes nothing and pushes no event.

## Verdicts of check, in check order (D-121).
enum Reason { OK, NO_TOWER, HUSK, MAX_LEVEL, LOCKED, NO_GOLD }


class Check:
	var reason: Reason = Reason.NO_TOWER
	## Price and level of the next level; 0 from NO_TOWER to MAX_LEVEL.
	var price: int = 0
	var level: int = 0


## The single upgrade rule (D-121): the UI shows this, upgrade() commits it. Read-only.
static func check(w: SimWorld, tower_uid: int) -> Check:
	var c := Check.new()
	var towers := w.towers
	var t := -1 if tower_uid < 0 else towers.uid.find(tower_uid)
	if t < 0:
		return c
	if towers.husk[t]:
		c.reason = Reason.HUSK
		return c
	var cat := w.tower_catalog
	var type := towers.type_id[t]
	if towers.level[t] >= cat.max_level[type]:
		c.reason = Reason.MAX_LEVEL
		return c
	c.level = towers.level[t] + 1
	var next: Dictionary = cat.level_stats[type][c.level - 1]
	c.price = int(next.cost)  # never grows with copies (10_M3_CONTENT.md 3.2)
	if next.has("needs_card") and w.modifiers.unlocked_level(cat.ids[type]) < c.level:
		c.reason = Reason.LOCKED
	elif w.gold < c.price:
		c.reason = Reason.NO_GOLD
	else:
		c.reason = Reason.OK
	return c


static func upgrade(w: SimWorld, tower_uid: int) -> void:
	var c := check(w, tower_uid)
	if c.reason != Reason.OK:
		return
	var towers := w.towers
	var t := towers.uid.find(tower_uid)
	w.gold -= c.price
	towers.paid[t] += c.price  # sell and rebuild follow (D-113)
	towers.level[t] = c.level
	towers.stats_dirty = true
	w.events.push(SimEvents.Kind.TOWER_UPGRADED, tower_uid, towers.pos_x[t], towers.pos_z[t], c.level)
