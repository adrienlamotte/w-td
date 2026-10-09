class_name TowerAttacks
extends RefCounted
## Tower attacks in the ATTACKS phase, before the enemy attacks (D-114). Instant hits (D-098);
## every damage goes through SimWorld.damage_enemy (D-107). Slow rule: D-117.

## Splash buffer, reused: no allocation once the peak is reached.
var _hits: PackedInt32Array = PackedInt32Array()


## Each built live tower counts its cooldown down, then fires at its target when ready.
## A target killed earlier in this phase is not shot: the tower holds and fires next tick.
func fire(w: SimWorld) -> void:
	var towers := w.towers
	var cat := w.tower_catalog
	var enemies := w.enemies
	var cd := towers.cooldown
	for t in towers.count():
		var type := towers.type_id[t]
		if type < 0 or towers.husk[t]:  # bare towers (M1 demo, bench) never fire
			continue
		if cd[t] > 0:
			cd[t] -= 1
		var target := towers.target[t]
		if cd[t] > 0 or target < 0 or enemies.hp[target] <= 0.0:
			continue
		cd[t] = cat.cooldown[type]
		var x := enemies.pos_x[target]
		var z := enemies.pos_z[target]
		w.events.push(SimEvents.Kind.TOWER_FIRED, towers.uid[t], x, z, type)
		var dmg := cat.damage[type]
		match cat.attack[type]:
			TowerCatalog.Attack.SPLASH:
				w.grid.query_radius(x, z, cat.splash_radius[type], enemies.pos_x, enemies.pos_z, _hits)
				for i in _hits:
					w.damage_enemy(i, dmg)
			TowerCatalog.Attack.SLOW:
				w.damage_enemy(target, dmg)
				apply_slow(enemies, target, cat.slow_factor[type], cat.slow_ticks[type])
			_:
				w.damage_enemy(target, dmg)


## D-117: no stacking. The strongest factor applies; a hit refreshes the duration to the longer.
static func apply_slow(enemies: SimEnemies, i: int, factor: float, ticks: int) -> void:
	if enemies.slow_ticks[i] == 0 or factor < enemies.slow_factor[i]:
		enemies.slow_factor[i] = factor
	enemies.slow_ticks[i] = maxi(enemies.slow_ticks[i], ticks)
