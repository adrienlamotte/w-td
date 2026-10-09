class_name SimDriver
extends RefCounted
## Runs the sim at a fixed step from the frame delta and interpolates enemy
## positions between the previous and current tick (02_TECH_ARCHITECTURE.md 3a, D-086).
## No Node, so it is testable headless.

const MAX_STEPS_PER_FRAME: int = 5

var world: SimWorld
## Called after each world.step() when valid (events are cleared at the next step, D-120).
var on_step: Callable
var _acc: float = 0.0


func _init(p_world: SimWorld) -> void:
	world = p_world


## Adds delta to the accumulator and runs whole ticks; returns the number run.
## Time beyond MAX_STEPS_PER_FRAME ticks is dropped (no spiral of death after a hitch).
func advance(delta: float) -> int:
	_acc += delta
	var steps := 0
	while _acc >= SimWorld.SIM_DT and steps < MAX_STEPS_PER_FRAME:
		world.step()
		if on_step.is_valid():
			on_step.call()
		_acc -= SimWorld.SIM_DT
		steps += 1
	if _acc >= SimWorld.SIM_DT:
		_acc = fmod(_acc, SimWorld.SIM_DT)
	return steps


## Fraction of the next tick already elapsed, in [0, 1).
func alpha() -> float:
	return _acc / SimWorld.SIM_DT


# prev_* live in SimEnemies and follow every swap-remove (D-120). HordeBatcher also snaps
# on jumps above 2 units (D-087); these helpers do not.
func interp_x(i: int) -> float:
	return lerpf(world.enemies.prev_x[i], world.enemies.pos_x[i], alpha())


func interp_z(i: int) -> float:
	return lerpf(world.enemies.prev_z[i], world.enemies.pos_z[i], alpha())
