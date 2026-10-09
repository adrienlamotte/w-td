extends Node3D
## Root of main.tscn: owns the sim and drives it at a fixed step (D-086). No game rules here.

const RUN_SEED: int = 1
const RUN_ID := "run_m2"
# Placeholder run until the start screen (021) and the build UI (020/027), D-120:
# [tick, tower_id, x, z]; a placement the gold does not cover is rejected silently.
const SCRIPTED_TOWERS: Array = [
	[0, "tower_single_01", 4.0, 0.0],
	[0, "tower_slow_01", -4.0, 0.0],
	[900, "tower_splash_01", 0.0, 5.0],
]

## Set false before _ready to skip the placeholder run (the benchmark sets its own scenario).
var demo: bool = true
var world: SimWorld = SimWorld.new(RUN_SEED)
var driver: SimDriver = SimDriver.new(world)


func _ready() -> void:
	$PlayerInput.world = world
	$PlayerInput.camera = $CameraRig
	# Release templates refuse a scene path on the command line: the bench starts from here (D-088).
	if demo and "--bench" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file("res://view/bench/bench.tscn")
		return
	if demo:
		# Commands only: the view writes no sim state.
		world.queue(SimCommand.start_run(0, RUN_SEED, RUN_ID))
		for t: Array in SCRIPTED_TOWERS:
			world.queue(SimCommand.place_tower(t[0], t[1], t[2], t[3]))
	$HordeRenderer.setup(driver, $CameraRig/Camera3D)
	$FxLayer.setup(driver, $Guardian)
	driver.on_step = $FxLayer.on_step


func _process(delta: float) -> void:
	driver.advance(delta)
