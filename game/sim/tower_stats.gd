class_name TowerStats
extends RefCounted
## Derived tower stats (D-144): level table value, then the modifier store. Written into the
## SimTowers derived arrays on add_built (apply) and, when `stats_dirty`, once at the end of
## the PATH phase (recompute); never per tick otherwise. Bare towers (type -1) are skipped.

## Stats the modifier store and the synergies can change, in the order of the cached sums
## (TowerLinks indexes them).
const MODDED: PackedStringArray = ["range", "damage", "cooldown", "hp", "slow_sec", "thorns",
		"mark_gold", "aura_radius", "heal", "guardian_heal"]
## Kinds that never shoot enemies: range 0, so they skip targeting (D-145).
const _NO_TARGET: Array[int] = [TowerCatalog.Attack.WALL, TowerCatalog.Attack.AURA, TowerCatalog.Attack.REPAIR]


## Fills tower t's derived arrays at once, with full HP (a newly built tower).
static func apply(w: SimWorld, t: int) -> void:
	_derive(w, t, _sums(w, w.towers.type_id[t]))
	w.towers.hp[t] = w.towers.max_hp[t]


## Every built tower, with the modifier sums cached per type plus each tower's links (synergies,
## aura; TowerLinks, D-150). A live tower whose max HP rises gains the difference, a fall clamps
## `hp`; husks keep 0. Clears `stats_dirty`.
static func recompute(w: SimWorld) -> void:
	var towers := w.towers
	var cache: Array = []
	cache.resize(w.tower_catalog.ids.size())
	for t in towers.count():
		var type := towers.type_id[t]
		if type >= 0 and cache[type] == null:
			cache[type] = _sums(w, type)
	w.links.compute(w, cache)
	var extra := w.links.extra
	var n := MODDED.size()
	for t in towers.count():
		var type := towers.type_id[t]
		if type < 0:
			continue
		var s: PackedVector2Array = cache[type]
		if not extra.is_empty():
			s = s.duplicate()
			for k in n:
				s[k] += extra[t * n + k]
		var old_max := towers.max_hp[t]
		_derive(w, t, s)
		if towers.husk[t]:
			continue
		var new_max := towers.max_hp[t]
		if new_max > old_max:
			towers.hp[t] += new_max - old_max
		elif new_max < old_max:
			towers.hp[t] = minf(towers.hp[t], new_max)
	towers.stats_dirty = false


## (level value + sum of add) * (1 + sum of mult); multipliers add up (10_M3_CONTENT.md 2.5).
static func value(level_value: float, s: Vector2) -> float:
	return (level_value + s.x) * (1.0 + s.y)


## Cooldown in ticks, clamped at 50% of the level value and at least 1 tick.
static func reload_ticks(level_sec: float, s: Vector2) -> int:
	return clamped_ticks(DataFiles.ticks(level_sec), s)


## Cooldown of `base` ticks with modifier sums (add in seconds), clamped at 50% and at least
## 1 tick; shared with the Guardian skills (D-144, D-146).
static func clamped_ticks(base: int, s: Vector2) -> int:
	return maxi(maxi(1, ceili(base * 0.5)), roundi(value(base, Vector2(s.x * SimWorld.TICK_RATE, s.y))))


static func _sums(w: SimWorld, type: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for s in MODDED:
		out.append(w.modifiers.sums(s, w.tower_catalog.ids[type]))
	return out


static func _derive(w: SimWorld, t: int, s: PackedVector2Array) -> void:
	var towers := w.towers
	var lv: Dictionary = w.tower_catalog.level_stats[towers.type_id[t]][towers.level[t] - 1]
	var kind := w.tower_catalog.attack[towers.type_id[t]]
	towers.attack_range[t] = 0.0 if kind in _NO_TARGET else value(lv.range, s[0])
	towers.damage[t] = value(lv.damage, s[1])
	towers.reload[t] = reload_ticks(lv.cooldown_sec, s[2])
	towers.max_hp[t] = value(lv.hp, s[3])
	towers.splash_radius[t] = lv.splash_radius
	towers.slow_factor[t] = lv.slow_factor
	towers.slow_ticks[t] = DataFiles.ticks(value(lv.slow_sec, s[4]))
	towers.thorns[t] = value(lv.thorns, s[5])
	towers.mark_gold[t] = roundi(value(lv.mark_gold, s[6]))
	towers.mark_ticks[t] = DataFiles.ticks(lv.mark_sec)
	towers.reach[t] = value(lv.aura_radius, s[7]) if kind == TowerCatalog.Attack.AURA 			else value(lv.range, s[0]) if kind == TowerCatalog.Attack.REPAIR else 0.0
	towers.heal[t] = value(lv.heal, s[8])
	towers.guardian_heal[t] = value(lv.guardian_heal, s[9])
	towers.heal_targets[t] = int(lv.heal_targets)
