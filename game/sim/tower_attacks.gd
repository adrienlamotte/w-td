class_name TowerAttacks
extends RefCounted
## Tower attacks in the ATTACKS phase, before the enemy attacks (D-114). Instant hits (D-098);
## every damage goes through SimWorld.damage_enemy (D-107). Slow rule: D-117. Mark,
## slow_area: D-145; wall, aura and repair have no target, so they never reach the match.

## Splash buffer, reused: no allocation once the peak is reached.
var _hits: PackedInt32Array = PackedInt32Array()


## Stats come from the derived tower arrays (D-144). Each built live tower counts its cooldown down, then fires at its target when ready.
## A target killed earlier in this phase is not shot: the tower holds and fires next tick.
func fire(w: SimWorld) -> void:
	var towers := w.towers
	var kind := w.tower_catalog.attack
	var enemies := w.enemies
	var cd := towers.cooldown
	var haste := w.run.skill_cooldown_factor[w.run.signature_slot] if w.clock < w.skills.haste_until else 0.0
	for t in towers.count():
		var type := towers.type_id[t]
		if type < 0 or towers.husk[t]:  # bare towers (M1 demo, bench) never fire
			continue
		if cd[t] > 0:
			cd[t] -= 1
		var target := towers.target[t]
		if cd[t] > 0 or target < 0 or enemies.hp[target] <= 0.0:
			continue
		cd[t] = towers.reload[t] if haste == 0.0 else maxi(1, roundi(towers.reload[t] * haste))  # Crescendo (D-146)
		var x := enemies.pos_x[target]
		var z := enemies.pos_z[target]
		w.events.push(SimEvents.Kind.TOWER_FIRED, towers.uid[t], x, z, type)
		var dmg := towers.damage[t]
		var detour := w.detour_mult if w.field else 0.0
		match kind[type]:
			TowerCatalog.Attack.SPLASH:
				w.grid.query_radius(x, z, towers.splash_radius[t], enemies.pos_x, enemies.pos_z, _hits)
				for i in _hits:
					_hit(w, i, dmg, detour)
			TowerCatalog.Attack.SLOW:
				_hit(w, target, dmg, detour)
				apply_slow(enemies, target, towers.slow_factor[t], towers.slow_ticks[t])
			TowerCatalog.Attack.SLOW_AREA:
				w.grid.query_radius(x, z, towers.splash_radius[t], enemies.pos_x, enemies.pos_z, _hits)
				for i in _hits:
					_hit(w, i, dmg, detour)
					apply_slow(enemies, i, towers.slow_factor[t], towers.slow_ticks[t])
			TowerCatalog.Attack.MARK:
				_hit(w, target, dmg, detour)
				mark(enemies, target, w.clock, towers.mark_gold[t], towers.mark_ticks[t])
			_:
				_hit(w, target, dmg, detour)


## Tower shots only (D-148 rule 3): an enemy whose cell's straight line is blocked (detouring)
## takes dmg * (1 + detour); no lookup when detour is 0, outside the grid counts as clear.
static func _hit(w: SimWorld, i: int, dmg: float, detour: float) -> void:
	if detour != 0.0:
		var c := w.build.cell_of(w.enemies.pos_x[i], w.enemies.pos_z[i])
		if c >= 0 and w.field.hit[c] != -1:
			dmg *= 1.0 + detour
	w.damage_enemy(i, dmg)


## D-145: an expired mark counts as none; higher gold wins, longer expiry wins, no stacking.
static func mark(enemies: SimEnemies, i: int, clock: int, gold: int, ticks: int) -> void:
	var active := clock < enemies.mark_until[i]
	enemies.mark_gold[i] = maxi(enemies.mark_gold[i], gold) if active else gold
	enemies.mark_until[i] = maxi(enemies.mark_until[i], clock + ticks)


## D-117: no stacking. The strongest factor applies; a hit refreshes the duration to the longer.
static func apply_slow(enemies: SimEnemies, i: int, factor: float, ticks: int) -> void:
	if enemies.slow_ticks[i] == 0 or factor < enemies.slow_factor[i]:
		enemies.slow_factor[i] = factor
	enemies.slow_ticks[i] = maxi(enemies.slow_ticks[i], ticks)
