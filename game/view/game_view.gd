extends Node3D
## Root of main.tscn: owns the sim and drives it at a fixed step (D-086). No game rules here.

const RUN_SEED: int = 1  # placeholder until StartRun exists (M2)

var world: SimWorld = SimWorld.new(RUN_SEED)
var driver: SimDriver = SimDriver.new(world)


func _process(delta: float) -> void:
	driver.advance(delta)
