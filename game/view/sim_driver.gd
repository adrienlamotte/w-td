class_name SimDriver
extends RefCounted
## Runs the sim at a fixed step from the frame delta and interpolates enemy
## positions between the previous and current tick (02_TECH_ARCHITECTURE.md 3a, D-086).
## No Node, so it is testable headless.

const MAX_STEPS_PER_FRAME: int = 5

var world: SimWorld
var prev_x: PackedFloat32Array = PackedFloat32Array()
var prev_z: PackedFloat32Array = PackedFloat32Array()
var _acc: float = 0.0


func _init(p_world: SimWorld) -> void:
	world = p_world


## Adds delta to the accumulator and runs whole ticks; returns the number run.
## Time beyond MAX_STEPS_PER_FRAME ticks is dropped (no spiral of death after a hitch).
func advance(delta: float) -> int:
	_acc += delta
	var steps := 0
	while _acc >= SimWorld.SIM_DT and steps < MAX_STEPS_PER_FRAME:
		# Packed arrays are shared on assignment: copy explicitly (once per tick, not per frame).
		prev_x = world.enemies.pos_x.duplicate()
		prev_z = world.enemies.pos_z.duplicate()
		world.step()
		_acc -= SimWorld.SIM_DT
		steps += 1
	if _acc >= SimWorld.SIM_DT:
		_acc = fmod(_acc, SimWorld.SIM_DT)
	return steps


## Fraction of the next tick already elapsed, in [0, 1).
func alpha() -> float:
	return _acc / SimWorld.SIM_DT


# ponytail: after a swap-remove (D-081) prev[i] belongs to another enemy for one tick.
# HordeBatcher snaps on jumps above 2 units (D-087); these helpers do not.
func interp_x(i: int) -> float:
	var cur := world.enemies.pos_x[i]
	return cur if i >= prev_x.size() else lerpf(prev_x[i], cur, alpha())


func interp_z(i: int) -> float:
	var cur := world.enemies.pos_z[i]
	return cur if i >= prev_z.size() else lerpf(prev_z[i], cur, alpha())
