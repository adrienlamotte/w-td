extends Node
## Perf benchmark runner (task 008, D-088). Runs every scenario of data/bench/bench_m1.json
## in the real main scene, then writes a JSON report and quits.
## User args (after --): --out=<path> (default user://perf_<date>.json), --commit=<sha>.

const CONFIG_PATH := "res://data/bench/bench_m1.json"
const MAIN_SCENE := preload("res://view/main.tscn")
const PHASES: Array[String] = ["commands", "path", "separation", "movement", "deaths", "spawn", "grid", "targeting", "attacks"]

var _cfg: Dictionary
var _out: String = "user://perf_%s.json" % Time.get_date_string_from_system()
var _commit: String = ""
var _index: int = -1
var _results: Array[Dictionary] = []
var _view: Node
var _measuring: bool = false
var _start_usec: int = 0
var _last_usec: int = 0
var _start_tick: int = 0
var _frames: PackedInt64Array = PackedInt64Array()
var _fill_usec: int = 0
var _render_cpu_ms: float = 0.0
var _gpu_ms: float = 0.0
var _deaths: int = 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--commit="):
			_commit = arg.trim_prefix("--commit=")
	_cfg = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _view == null:
		_next_scenario(now)
		return
	var sc: Dictionary = _cfg.scenarios[_index]
	var world: SimWorld = _view.world
	if sc.get("churn", false):
		_churn(world)
	if sc.get("combat", false):
		BenchScenario.refill(world, _cfg, sc)
	if not _measuring:
		if now - _start_usec >= float(sc.warmup_sec) * 1e6:
			_measuring = true
			_start_usec = now
			_start_tick = world.tick
			world.phase_usec_sum.resize(SimWorld.Phase.size())
			world.phase_usec_sum.fill(0)
			_deaths = 0
		_last_usec = now
		return
	_frames.append(now - _last_usec)
	_last_usec = now
	_fill_usec += _view.get_node("HordeRenderer").last_fill_usec
	var vp := get_viewport().get_viewport_rid()
	_render_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	if now - _start_usec >= float(_cfg.measure_sec) * 1e6:
		_results.append(_finish(sc, world))
		_view.queue_free()
		_view = null


func _next_scenario(now: int) -> void:
	_index += 1
	if _index >= _cfg.scenarios.size():
		_write_report()
		return
	var sc: Dictionary = _cfg.scenarios[_index]
	_view = MAIN_SCENE.instantiate()
	_view.demo = false
	_view.world = SimWorld.new(int(_cfg.seed))
	_view.driver = SimDriver.new(_view.world)
	BenchScenario.apply(_view.world, _cfg, sc)
	add_child(_view)
	var fx: Callable = _view.driver.on_step
	_view.driver.on_step = func() -> void:
		fx.call()
		_count_deaths(_view.world)
	var rig: IsoCamera = _view.get_node("CameraRig")
	_view.get_node("PlayerInput").process_mode = Node.PROCESS_MODE_DISABLED  # no player input during a run
	rig.set_zoom(int(sc.zoom))
	get_viewport().scaling_3d_scale = float(sc.render_scale)
	_measuring = false
	_start_usec = now
	_frames = PackedInt64Array()
	_fill_usec = 0
	_render_cpu_ms = 0.0
	_gpu_ms = 0.0
	_deaths = 0


# Events are valid until the next step (D-120): read them right after each step.
func _count_deaths(world: SimWorld) -> void:
	var ev := world.events
	for e in ev.count:
		if ev.kind[e] == SimEvents.Kind.ENEMY_DIED:
			_deaths += 1


# Worst case (D-115): one maze tower's cells flip every frame, so a recompute is always in
# flight. Harness only, like spawn_ring: the tower stays live in the arrays.
func _churn(world: SimWorld) -> void:
	var t := world.towers.count() - 1
	var i0 := world.towers.cell_i[t]
	var j0 := world.towers.cell_j[t]
	var b := world.build
	b.fill(i0, j0, world.towers.footprint[t], world.towers.uid[t], 1 - b.solid[j0 * b.size + i0])


func _finish(sc: Dictionary, world: SimWorld) -> Dictionary:
	var n := maxi(1, _frames.size())
	var ticks := world.tick - _start_tick
	var elapsed := (_last_usec - _start_usec) / 1e6
	var phase_ms := {}
	var step_usec := 0
	for p in PHASES.size():
		phase_ms[PHASES[p]] = world.phase_usec_sum[p] / 1000.0 / maxi(1, ticks)
		step_usec += world.phase_usec_sum[p]
	# Mean speed over the last tick, skipping recycle jumps (> 2 units, as HordeBatcher snaps).
	var speed := 0.0
	var moved := 0
	var e := world.enemies
	for i in e.count():
		var d := Vector2(e.pos_x[i] - e.prev_x[i], e.pos_z[i] - e.prev_z[i]).length()
		if d <= 2.0:
			speed += d / SimWorld.SIM_DT
			moved += 1
	var render_size := Vector2(get_viewport().get_visible_rect().size) * float(sc.render_scale)
	var r := sc.duplicate()
	for k in ["enemies", "towers", "zoom"]:
		r[k] = int(r[k])
	if sc.get("maze", false):
		r["maze_towers"] = world.towers.count()
	if sc.get("combat", false):
		r["towers_built"] = world.towers.count()
		r["deaths_per_sec"] = _deaths / elapsed
	r.merge({
		"render_size": [roundi(render_size.x), roundi(render_size.y)],
		"frame": BenchStats.summarize(_frames),
		"sim": {
			"ticks": ticks,
			"ticks_per_sec": ticks / elapsed,
			"step_ms_avg": step_usec / 1000.0 / maxi(1, ticks),
			"phase_ms_avg": phase_ms,
		},
		"view": {"fill_ms_avg": _fill_usec / 1000.0 / n},
		"cpu_gpu": {
			# Sim steps + view fill per frame: Performance.TIME_PROCESS is a per-second max.
			"process_ms_avg": (step_usec + _fill_usec) / 1000.0 / n,
			"render_cpu_ms_avg": _render_cpu_ms / n,
			"gpu_ms_avg": _gpu_ms / n,
		},
		"mean_speed": speed / maxi(1, moved),
	})
	return r


func _machine() -> Dictionary:
	return {
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"gpu_api": RenderingServer.get_video_adapter_api_version(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"godot": Engine.get_version_info().string,
		"release": not OS.is_debug_build(),
		"window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"commit": _commit,
		"datetime": Time.get_datetime_string_from_system(),
	}


func _write_report() -> void:
	set_process(false)
	var report := {"bench": _cfg.id, "machine": _machine(), "scenarios": _results}
	for r in _results:
		var f: Dictionary = r.frame
		print("%-18s avg %6.1f fps  1%%-low %6.1f  frame %6.2f ms  step %6.2f ms  gpu %6.2f ms  speed %.2f" % [
			r.name, f.avg_fps, f.low1_fps, f.frame_ms_avg, r.sim.step_ms_avg, r.cpu_gpu.gpu_ms_avg, r.mean_speed])
	var file := FileAccess.open(_out, FileAccess.WRITE)
	if file == null:
		push_error("bench: cannot write %s" % _out)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "  ") + "\n")
	file.close()
	print("bench: wrote %s" % ProjectSettings.globalize_path(_out))
	get_tree().quit(0)
