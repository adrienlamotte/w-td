class_name SimEnemies
extends RefCounted
## Enemy state as structure-of-arrays (02_TECH_ARCHITECTURE.md 3a).
## Every array has size() == count(). Indices are only valid within one tick:
## remove() swap-removes, so the last enemy takes the removed slot (D-081).

enum State { MOVING = 0, AT_GUARDIAN = 1 }

var pos_x: PackedFloat32Array = PackedFloat32Array()
var pos_z: PackedFloat32Array = PackedFloat32Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var type_id: PackedInt32Array = PackedInt32Array()
var state: PackedInt32Array = PackedInt32Array()
var anim_frame: PackedInt32Array = PackedInt32Array()


func count() -> int:
	return pos_x.size()


## Appends one enemy and returns its index.
func add(p_type_id: int, x: float, z: float, p_hp: float) -> int:
	pos_x.append(x)
	pos_z.append(z)
	hp.append(p_hp)
	type_id.append(p_type_id)
	state.append(State.MOVING)
	anim_frame.append(0)
	return pos_x.size() - 1


## O(1) removal: the last enemy moves into slot i. Every per-enemy array goes here.
func remove(i: int) -> void:
	var last := pos_x.size() - 1
	pos_x[i] = pos_x[last]
	pos_z[i] = pos_z[last]
	hp[i] = hp[last]
	type_id[i] = type_id[last]
	state[i] = state[last]
	anim_frame[i] = anim_frame[last]
	pos_x.resize(last)
	pos_z.resize(last)
	hp.resize(last)
	type_id.resize(last)
	state.resize(last)
	anim_frame.resize(last)


## Moves every MOVING enemy straight toward the Guardian at (0, 0) by speed * dt,
## stopping at a distance equal to its own radius (placeholder until the Guardian
## gets a contact radius in M2), where it switches to AT_GUARDIAN.
func chase_guardian(type_speed: PackedFloat32Array, type_radius: PackedFloat32Array, dt: float) -> void:
	for i in pos_x.size():
		if state[i] != State.MOVING:
			continue
		var t := type_id[i]
		var x := pos_x[i]
		var z := pos_z[i]
		var r := type_radius[t]
		var d := sqrt(x * x + z * z)
		var move := type_speed[t] * dt
		if d - r <= move:
			if d > r:
				pos_x[i] = x * r / d
				pos_z[i] = z * r / d
			state[i] = State.AT_GUARDIAN
		else:
			var f := (d - move) / d
			pos_x[i] = x * f
			pos_z[i] = z * f
