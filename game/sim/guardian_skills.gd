class_name GuardianSkills
extends RefCounted
## Guardian skill state: per-slot cooldowns and the Shield (D-110).
## Everything runs on the run clock; nothing is decremented per tick.

## Run clock tick at which each skill slot is ready again; 0 at StartRun.
var ready_at: PackedInt32Array = PackedInt32Array()
## Damage the Shield can still absorb.
var shield_left: float = 0.0
## Run clock tick at which the Shield ends (absorbs while clock < shield_until).
var shield_until: int = 0


func reset(slots: int) -> void:
	ready_at = PackedInt32Array()
	ready_at.resize(slots)
	shield_left = 0.0
	shield_until = 0


## Returns false (nothing changed) while the slot is on cooldown. A Shield recast
## replaces the active one, never stacks.
func try_use(slot: int, clock: int, run: RunData) -> bool:
	if clock < ready_at[slot]:
		return false
	ready_at[slot] = clock + run.skill_cooldown[slot]
	if run.skill_kind[slot] == RunData.Skill.SHIELD:
		shield_left = run.skill_absorb[slot]
		shield_until = clock + run.skill_duration[slot]
	return true


## Returns the damage the Shield lets through.
func absorb(dmg: float, clock: int) -> float:
	if clock >= shield_until:
		return dmg
	var absorbed := minf(dmg, shield_left)
	shield_left -= absorbed
	return dmg - absorbed
