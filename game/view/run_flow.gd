class_name RunFlow
extends RefCounted
## Run flow state across the scene reloads used to leave a run (D-125, D-154). Static vars
## last for the session; the slow-time toggle is also saved (SettingsStore, D-157).

enum Screen { START, HUB }

## The screen shown after a scene reload (no run queued).
static var screen: Screen = Screen.START
## Set before a Restart reload: the new scene rescues this waifu's Guardian at once ("" = none).
static var restart_waifu: String = ""
## Folder of profile.json and settings.json; tests point it at a scratch folder.
static var save_dir: String = "user://"
## Accessibility option (D-046): slow the sim while placing a tower. Default off.
static var slow_time_placing: bool = false


## Factor applied to the frame delta fed to SimDriver.advance (never Engine.time_scale).
## Only the rate of whole SIM_DT ticks changes, so the run stays deterministic.
static func time_scale(on: bool, placing: bool, can_build: bool, slow: float) -> float:
	return slow if on and placing and can_build else 1.0


## Queues the M3 run with `waifu`'s Guardian and a fresh seed (logged for repro, D-125).
## False when she is not in the offer. Commands only: the view writes no sim state.
static func start_rescue(world: SimWorld, profile: MetaProfile, cat: MetaCatalog, waifu: String) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var run_seed := rng.randi()
	var cmd := profile.start_command(cat, world.tick, run_seed, "run_m3", waifu)
	if cmd == null:
		return false
	print("Run start: seed %d, run run_m3, guardian %s, meta %s" % [run_seed, cmd.guardian_id, cmd.meta_nodes])
	world.queue(cmd)
	return true
