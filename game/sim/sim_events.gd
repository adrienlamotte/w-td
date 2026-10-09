class_name SimEvents
extends RefCounted
## Events of the last SimWorld.step(), as SoA: no object per event (D-100).
## Cleared at the start of every step; the view reads them after each step.
## Payload per kind: 02_TECH_ARCHITECTURE.md 3a. Never holds enemy indices (D-081).

enum Kind { ENEMY_DIED, ENEMY_HIT, TOWER_PLACED, TOWER_DIED, SKILL_USED, GUARDIAN_HIT, WAVE_STARTED, RUN_ENDED, TOWER_SOLD, TOWER_FIRED, TOWER_HIT }

const _START_CAPACITY: int = 64

var kind: PackedInt32Array = PackedInt32Array()
var a: PackedInt32Array = PackedInt32Array()
var x: PackedFloat32Array = PackedFloat32Array()
var z: PackedFloat32Array = PackedFloat32Array()
var value: PackedFloat32Array = PackedFloat32Array()
## Number of valid entries; the arrays may be larger (capacity is kept).
var count: int = 0


func _init() -> void:
	_resize(_START_CAPACITY)


func clear() -> void:
	count = 0


func push(p_kind: Kind, p_a: int, p_x: float, p_z: float, p_value: float) -> void:
	if count == kind.size():
		_resize(count * 2)
	kind[count] = p_kind
	a[count] = p_a
	x[count] = p_x
	z[count] = p_z
	value[count] = p_value
	count += 1


func _resize(n: int) -> void:
	kind.resize(n)
	a.resize(n)
	x.resize(n)
	z.resize(n)
	value.resize(n)
