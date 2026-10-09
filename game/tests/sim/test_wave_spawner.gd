extends GutTest
## Run timeline: waves, breaks, spawn ring, bosses (D-106).

const RUN := "run_m2"
const SIXTEEN_MIN: int = 16 * 60 * 30

var _catalog: EnemyCatalog
var _run: RunData


func before_all() -> void:
	_catalog = EnemyCatalog.load_dir()
	_run = RunData.load_id(RUN, _catalog, TowerCatalog.load_dir())


## Runs WaveSpawner over clocks [from, to) on a bare SimEnemies (no movement).
## Returns per clock: WAVE_STARTED events in `waves`, spawned [clock, index] pairs in `spawns`.
func _simulate(from: int, to: int) -> Dictionary:
	var enemies := SimEnemies.new()
	var events := SimEvents.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var waves := {}
	var spawn_clock := PackedInt32Array()
	for clock in range(from, to):
		events.clear()
		WaveSpawner.step(clock, _run, _catalog, enemies, rng, events)
		for k in events.count:
			if events.kind[k] == SimEvents.Kind.WAVE_STARTED:
				waves[clock] = events.a[k]
		while spawn_clock.size() < enemies.count():
			spawn_clock.append(clock)
	return {"waves": waves, "enemies": enemies, "clock": spawn_clock}


func _period() -> int:
	return _run.wave_ticks + _run.break_ticks


func test_sixteen_minutes() -> void:
	var start := Time.get_ticks_msec()
	var r := _simulate(0, SIXTEEN_MIN)
	gut.p("16 simulated minutes of spawns: %d ms" % (Time.get_ticks_msec() - start))
	var waves: Dictionary = r.waves
	var enemies: SimEnemies = r.enemies
	var clocks: PackedInt32Array = r.clock
	assert_eq(waves.size(), 13)
	for w in 13:
		assert_eq(waves.get(_run.first_wave_tick + w * _period(), -1), w, "wave %d start" % w)
	var horde := PackedInt32Array()
	horde.resize(13)
	var bosses := []
	for i in enemies.count():
		var c := clocks[i]
		var ti := enemies.type_id[i]
		var d := Vector2(enemies.pos_x[i], enemies.pos_z[i]).length()
		assert_between(d, _run.spawn_ring_min - 1e-3, _run.spawn_ring_max + 1e-3)
		assert_eq(enemies.hp[i], _catalog.hp[ti])
		if _catalog.is_boss[ti]:
			bosses.append([c, ti])
			continue
		var rel := c - _run.first_wave_tick
		var w := rel / _period()
		assert_lt(rel % _period(), _run.wave_ticks, "no horde spawn in a break (clock %d)" % c)
		assert_has(_run.wave_mix_types[w], ti, "type from the wave mix")
		horde[w] += 1
	for w in 13:
		assert_eq(horde[w], _run.wave_count[w], "wave %d count" % w)
	assert_eq(bosses, [
		[9000, _run.boss_types[0]], [18000, _run.boss_types[1]], [27000, _run.final_boss_type]])
	assert_gt(clocks[clocks.size() - 1], 27000, "horde keeps coming after the final boss (D-096)")


func test_last_entry_repeats() -> void:
	var start := _run.first_wave_tick + 13 * _period()
	var r := _simulate(start, start + _run.wave_ticks)
	assert_eq(r.waves, {start: 13})
	var enemies: SimEnemies = r.enemies
	var last := _run.wave_count.size() - 1
	assert_eq(enemies.count(), _run.wave_count[last])
	for ti in enemies.type_id:
		assert_has(_run.wave_mix_types[last], ti)


func test_spawn_ring_outside_camera_bounds() -> void:
	var cam := DataFiles.read_id("res://data/camera", "camera_default")
	assert_gt(_run.spawn_ring_min, float(cam.bounds_radius) + float(cam.bounds_margin))
