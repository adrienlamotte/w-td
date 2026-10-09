class_name RunFlow
extends RefCounted
## Session-only run flow settings (D-125). Static vars survive the scene reload used as
## Restart / Main menu, not a restart of the game (saved settings are M3).

## Set before a Restart reload: the new scene starts a run at once (no start screen).
static var autostart: bool = false
## Accessibility option (D-046): slow the sim while placing a tower. Default off.
static var slow_time_placing: bool = false


## Factor applied to the frame delta fed to SimDriver.advance (never Engine.time_scale).
## Only the rate of whole SIM_DT ticks changes, so the run stays deterministic.
static func time_scale(on: bool, placing: bool, can_build: bool, slow: float) -> float:
	return slow if on and placing and can_build else 1.0
