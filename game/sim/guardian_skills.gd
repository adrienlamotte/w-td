class_name GuardianSkills
extends RefCounted
## Guardian skill state: per-slot cooldowns, the Shield (D-110) and the timed signature
## effects (D-146). Everything runs on the run clock; nothing is decremented per tick.
## The casts are in SignatureSkills.

## Run clock tick at which each skill slot is ready again; 0 at StartRun.
var ready_at: PackedInt32Array = PackedInt32Array()
## Damage the Shield can still absorb.
var shield_left: float = 0.0
## Run clock tick at which the Shield ends (absorbs while clock < shield_until).
var shield_until: int = 0
## Stand Firm: towers and the Guardian take reduced damage while clock < guard_until.
var guard_until: int = 0
## Clearance Sale: every kill drops `bounty_gold` more while clock < bounty_until.
var bounty_until: int = 0
var bounty_gold: int = 0
## Crescendo: tower cooldown resets are shortened while clock < haste_until.
var haste_until: int = 0


func reset(slots: int) -> void:
	ready_at = PackedInt32Array()
	ready_at.resize(slots)
	shield_left = 0.0
	shield_until = 0
	guard_until = 0
	bounty_until = 0
	bounty_gold = 0
	haste_until = 0


## Returns false (nothing changed) while the slot is on cooldown; else starts the cooldown.
func try_use(slot: int, clock: int, cooldown_ticks: int) -> bool:
	if clock < ready_at[slot]:
		return false
	ready_at[slot] = clock + cooldown_ticks
	return true


## A recast replaces the active Shield, never stacks.
func raise_shield(clock: int, absorb_amount: float, ticks: int) -> void:
	shield_left = absorb_amount
	shield_until = clock + ticks


## Returns the damage the Shield lets through.
func absorb(dmg: float, clock: int) -> float:
	if clock >= shield_until:
		return dmg
	var absorbed := minf(dmg, shield_left)
	shield_left -= absorbed
	return dmg - absorbed
