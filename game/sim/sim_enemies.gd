class_name SimEnemies
extends RefCounted
## Enemy state as structure-of-arrays (02_TECH_ARCHITECTURE.md 3a).
## Every array has size() == count(). Indices are only valid within one tick:
## remove() swap-removes, so the last enemy takes the removed slot (D-081).

## QUEUED: stopped behind the crowd, does not attack (D-107).
enum State { MOVING = 0, ATTACKING = 1, QUEUED = 2 }

## hit_tick of an enemy never hit.
const NEVER_HIT: int = -1000000

var pos_x: PackedFloat32Array = PackedFloat32Array()
var pos_z: PackedFloat32Array = PackedFloat32Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var type_id: PackedInt32Array = PackedInt32Array()
var state: PackedInt32Array = PackedInt32Array()
var anim_frame: PackedInt32Array = PackedInt32Array()
## Attack cooldown in ticks; 0 = ready (D-107).
var cooldown: PackedInt32Array = PackedInt32Array()
## Speed multiplier while slowed, 1 = none; slow_ticks MOVE phases left, 0 = none (D-114, D-117).
var slow_factor: PackedFloat32Array = PackedFloat32Array()
var slow_ticks: PackedInt32Array = PackedInt32Array()
## Attack target: tower uid, -1 = the Guardian. Set by EnemyMovement.steer() every tick (D-116).
var target_id: PackedInt32Array = PackedInt32Array()
## Presentation only (D-120): no rule reads them, not in state_hash(). Kept here so they
## follow every swap-remove. prev_* = position at the start of the tick; hit_tick = tick of
## the last damage_enemy (NEVER_HIT before).
var prev_x: PackedFloat32Array = PackedFloat32Array()
var prev_z: PackedFloat32Array = PackedFloat32Array()
var hit_tick: PackedInt32Array = PackedInt32Array()


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
	cooldown.append(0)
	slow_factor.append(1.0)
	slow_ticks.append(0)
	target_id.append(-1)
	prev_x.append(x)
	prev_z.append(z)
	hit_tick.append(NEVER_HIT)
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
	cooldown[i] = cooldown[last]
	slow_factor[i] = slow_factor[last]
	slow_ticks[i] = slow_ticks[last]
	target_id[i] = target_id[last]
	prev_x[i] = prev_x[last]
	prev_z[i] = prev_z[last]
	hit_tick[i] = hit_tick[last]
	pos_x.resize(last)
	pos_z.resize(last)
	hp.resize(last)
	type_id.resize(last)
	state.resize(last)
	anim_frame.resize(last)
	cooldown.resize(last)
	slow_factor.resize(last)
	slow_ticks.resize(last)
	target_id.resize(last)
	prev_x.resize(last)
	prev_z.resize(last)
	hit_tick.resize(last)

