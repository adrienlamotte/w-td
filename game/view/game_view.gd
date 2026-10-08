extends Node3D
## Root of main.tscn: owns the sim and drives it at a fixed step (D-086). No game rules here.

const RUN_SEED: int = 1  # placeholder until StartRun exists (M2)
# Demo horde for CP-M1 (D-087), placeholders until StartRun and waves (M2).
const DEMO_ENEMIES: int = 1500
const DEMO_RINGS: int = 6
const DEMO_RING_MIN: float = 24.0
const DEMO_RING_MAX: float = 44.0
const DEMO_RECYCLE_RADIUS: float = 40.0
const DEMO_TOWERS: int = 12
const DEMO_TOWER_RING: float = 10.0
const DEMO_TOWER_RANGE: float = 6.0

## Set false before _ready to skip the demo horde (the benchmark sets its own scenario).
var demo: bool = true
var world: SimWorld = SimWorld.new(RUN_SEED)
var driver: SimDriver = SimDriver.new(world)


func _ready() -> void:
	# Release templates refuse a scene path on the command line: the bench starts from here (D-088).
	if demo and "--bench" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file("res://view/bench/bench.tscn")
		return
	if demo:
		_setup_demo()
	$HordeRenderer.setup(driver, $CameraRig/Camera3D)


# Placeholder scenario through the sim's test/benchmark APIs.
func _setup_demo() -> void:
	var type := world.catalog.type_of("enemy_swarmer_01")
	for r in DEMO_RINGS:
		var radius := lerpf(DEMO_RING_MIN, DEMO_RING_MAX, float(r) / (DEMO_RINGS - 1))
		world.spawn_ring(type, DEMO_ENEMIES / DEMO_RINGS, radius)
	world.recycle_radius = DEMO_RECYCLE_RADIUS
	for t in DEMO_TOWERS:
		var angle := TAU * t / DEMO_TOWERS
		world.towers.add(cos(angle) * DEMO_TOWER_RING, sin(angle) * DEMO_TOWER_RING, DEMO_TOWER_RANGE)


func _process(delta: float) -> void:
	driver.advance(delta)
