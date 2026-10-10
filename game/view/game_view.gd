extends Node3D
## Root of main.tscn: owns the sim and drives it at a fixed step (D-086). No game rules here.

const RUN_SEED: int = 1

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
	$StartScreen.visible = false
	if demo:
		SettingsStore.load_into_run_flow(RunFlow.save_dir)  # every load: the file is the one truth (D-157)
		$StartScreen.start_pressed.connect(open_hub)
		$StartScreen.quit_pressed.connect(get_tree().quit)
		$StartScreen.resume_pressed.connect(resume)
		$Hub.setup(world)
		$Hub.back_pressed.connect(open_start)
		$PauseMenu.setup(world, $PlayerInput)
		$PauseMenu.restart_confirmed.connect(reload)
		$PauseMenu.abandon_confirmed.connect(reload)
		$EndScreen.continue_pressed.connect(reload)
		$EndScreen.setup(world)
		$DraftOverlay.setup(world)
		_open_first_screen()
	$HordeRenderer.setup(driver, $CameraRig/Camera3D)
	$FxLayer.setup(driver, $Guardian)
	driver.on_step = $FxLayer.on_step
	if demo:  # card and wave boundary saves (D-167); never in the bench or the balance bot
		var saver := SuspendSaver.new(RunFlow.save_dir)
		driver.on_step = func() -> void:
			$FxLayer.on_step()
			saver.on_step(world)
	$PlacementGhost.setup(world, $PlayerInput)
	$Hud.setup(world, $PlayerInput, $PlacementGhost)


# After a reload (D-154 rule 1): a Restart rescues the same waifu again, else RunFlow.screen.
func _open_first_screen() -> void:
	var waifu := RunFlow.restart_waifu
	RunFlow.restart_waifu = ""
	if waifu != "":
		var cat: MetaCatalog = $Hub.cat
		if RunFlow.start_rescue(world, ProfileStore.load_profile(cat, RunFlow.save_dir), cat, waifu):
			return
	if RunFlow.screen == RunFlow.Screen.HUB:
		open_hub()
	else:
		open_start()


func open_hub() -> void:
	$StartScreen.visible = false
	$Hub.open()


func open_start() -> void:
	$Hub.visible = false
	$StartScreen.visible = true


## Resume the suspend save (D-167 rule 5); the views poll the world. A failed restore counts
## as an abandon when the header was readable, then the start screen shows the notice (rule 6).
func resume() -> void:
	if SuspendStore.load_into(world, RunFlow.save_dir):
		$StartScreen.visible = false
		return
	if world.run != null:
		ProfileStore.record_run_end(world, RunFlow.save_dir)
	RunFlow.screen = RunFlow.Screen.START
	reload()


## Leaving a run reloads the scene: a fresh SimWorld and fresh views (D-125).
func reload() -> void:
	get_tree().reload_current_scene()


func _process(delta: float) -> void:
	var input: PlayerInput = $PlayerInput
	driver.advance(delta * RunFlow.time_scale(RunFlow.slow_time_placing, input.is_placing(),
			PlayerInput.can_build(world), _slow_scale))
