extends Node3D
## Root of main.tscn: owns the sim and drives it at a fixed step (D-086). No game rules here.

const RUN_SEED: int = 1
const RUN_ID := "run_m2"

## Set false before _ready to skip the run flow (the benchmark sets its own scenario).
var demo: bool = true
var world: SimWorld = SimWorld.new(RUN_SEED)
var driver: SimDriver = SimDriver.new(world)
var _slow_scale: float = 1.0


func _ready() -> void:
	$PlayerInput.world = world
	$PlayerInput.camera = $CameraRig
	# Release templates refuse a scene path on the command line: the bench starts from here (D-088).
	if demo and "--bench" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file("res://view/bench/bench.tscn")
		return
	_slow_scale = float(PlacementGhost.load_config().slow_time_scale)
	$StartScreen.visible = demo and not RunFlow.autostart
	if demo:
		$StartScreen.start_pressed.connect(start_run)
		$StartScreen.quit_pressed.connect(get_tree().quit)
		$PauseMenu.setup(world, $PlayerInput)
		for menu: CanvasLayer in [$PauseMenu, $EndScreen]:
			menu.restart_pressed.connect(restart)
			menu.main_menu_pressed.connect(main_menu)
		$EndScreen.setup(world)
		if RunFlow.autostart:
			RunFlow.autostart = false
			start_run()
	$HordeRenderer.setup(driver, $CameraRig/Camera3D)
	$FxLayer.setup(driver, $Guardian)
	driver.on_step = $FxLayer.on_step
	$PlacementGhost.setup(world, $PlayerInput)
	$Hud.setup(world, $PlayerInput, $PlacementGhost)


## Queues StartRun with a fresh seed (logged for repro). Commands only: the view writes no sim state.
func start_run() -> void:
	$StartScreen.visible = false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var run_seed := rng.randi()
	print("Run start: seed %d, run %s" % [run_seed, RUN_ID])
	world.queue(SimCommand.start_run(world.tick, run_seed, RUN_ID))


## Restart and Main menu reload the scene: a fresh SimWorld and fresh views (D-125).
func restart() -> void:
	RunFlow.autostart = true
	get_tree().reload_current_scene()


func main_menu() -> void:
	RunFlow.autostart = false
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	var input: PlayerInput = $PlayerInput
	driver.advance(delta * RunFlow.time_scale(RunFlow.slow_time_placing, input.is_placing(),
			PlayerInput.can_build(world), _slow_scale))
