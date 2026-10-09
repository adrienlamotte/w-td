class_name WaveSpawner
extends RefCounted
## Spawns the run timeline (D-106, 02_TECH_ARCHITECTURE.md 3a). Stateless: every
## decision derives from the run clock and the spawn RNG, so nothing new to hash.


## Spawns what is due at run tick `clock`. RNG draws per spawn: type, angle, radius.
static func step(clock: int, run: RunData, catalog: EnemyCatalog, enemies: SimEnemies,
		rng: RandomNumberGenerator, events: SimEvents) -> void:
	if clock >= run.first_wave_tick:
		var rel := clock - run.first_wave_tick
		var w := rel / (run.wave_ticks + run.break_ticks)
		var t := rel % (run.wave_ticks + run.break_ticks)
		if t == 0:
			events.push(SimEvents.Kind.WAVE_STARTED, w, 0.0, 0.0, 0.0)
		if t < run.wave_ticks:  # else break: no spawns (D-032)
			var e := mini(w, run.wave_count.size() - 1)  # last entry repeats (D-096)
			var n := run.wave_count[e]
			var due := ((t + 1) * n) / run.wave_ticks - (t * n) / run.wave_ticks
			for k in due:
				_spawn(_pick(run.wave_mix_types[e], run.wave_mix_weights[e], rng), run, catalog, enemies, rng)
	for k in run.boss_ticks.size():
		if clock == run.boss_ticks[k]:
			_spawn(run.boss_types[k], run, catalog, enemies, rng)
	if clock == run.final_boss_tick:
		_spawn(run.final_boss_type, run, catalog, enemies, rng)


static func _pick(types: PackedInt32Array, weights: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for wt in weights:
		total += wt
	var roll := rng.randf() * total
	for i in types.size():
		roll -= weights[i]
		if roll < 0.0:
			return types[i]
	return types[types.size() - 1]  # float rounding at the top end


static func _spawn(type_id: int, run: RunData, catalog: EnemyCatalog, enemies: SimEnemies,
		rng: RandomNumberGenerator) -> void:
	var angle := rng.randf() * TAU
	var r := lerpf(run.spawn_ring_min, run.spawn_ring_max, rng.randf())
	enemies.add(type_id, cos(angle) * r, sin(angle) * r, catalog.hp[type_id])
