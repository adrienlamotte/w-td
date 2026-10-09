class_name SimCommand
extends RefCounted
## One player input for the sim, applied at the start of tick `tick` (D-100,
## 02_TECH_ARCHITECTURE.md 3a). Only the fields of its type are used.

enum Type { START_RUN, PAUSE, PLACE_TOWER, SELL_TOWER, USE_SKILL }

var tick: int = 0
var type: Type = Type.START_RUN
var run_seed: int = 0
## StartRun config: a data/runs id.
var run_id: String = ""
var paused: bool = false
## A data/towers id.
var tower_id: String = ""
var x: float = 0.0
var z: float = 0.0
## Stable tower id assigned on placement (task 015), never an array index (D-081).
var tower_uid: int = -1
## A data/skills id.
var skill_id: String = ""


static func start_run(p_tick: int, p_seed: int, p_run_id: String) -> SimCommand:
	var c := _make(p_tick, Type.START_RUN)
	c.run_seed = p_seed
	c.run_id = p_run_id
	return c


static func pause(p_tick: int, on: bool) -> SimCommand:
	var c := _make(p_tick, Type.PAUSE)
	c.paused = on
	return c


static func place_tower(p_tick: int, p_tower_id: String, p_x: float, p_z: float) -> SimCommand:
	var c := _make(p_tick, Type.PLACE_TOWER)
	c.tower_id = p_tower_id
	c.x = p_x
	c.z = p_z
	return c


static func sell_tower(p_tick: int, p_tower_uid: int) -> SimCommand:
	var c := _make(p_tick, Type.SELL_TOWER)
	c.tower_uid = p_tower_uid
	return c


static func use_skill(p_tick: int, p_skill_id: String) -> SimCommand:
	var c := _make(p_tick, Type.USE_SKILL)
	c.skill_id = p_skill_id
	return c


static func _make(p_tick: int, p_type: Type) -> SimCommand:
	var c := SimCommand.new()
	c.tick = p_tick
	c.type = p_type
	return c
