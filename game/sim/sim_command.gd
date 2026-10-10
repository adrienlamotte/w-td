class_name SimCommand
extends RefCounted
## One player input for the sim, applied at the start of tick `tick` (D-100,
## 02_TECH_ARCHITECTURE.md 3a). Only the fields of its type are used.

enum Type { START_RUN, PAUSE, PLACE_TOWER, SELL_TOWER, USE_SKILL, REBUILD_TOWER, UPGRADE_TOWER, PICK_CARD }

var tick: int = 0
var type: Type = Type.START_RUN
var run_seed: int = 0
## StartRun config: a data/runs id.
var run_id: String = ""
## StartRun: a data/guardians id; empty keeps the run file's Guardian (D-146).
var guardian_id: String = ""
## StartRun: rescued waifu ids (card eligibility, D-147); empty = nothing rescued.
var unlocked: PackedStringArray = PackedStringArray()
## StartRun: bought meta-tree node ids, applied in id order (D-152 rule 8).
var meta_nodes: PackedStringArray = PackedStringArray()
var paused: bool = false
## A data/towers id.
var tower_id: String = ""
var x: float = 0.0
var z: float = 0.0
## Stable tower id assigned on placement (task 015), never an array index (D-081).
var tower_uid: int = -1
## A data/skills id.
var skill_id: String = ""
## PICK_CARD: draft slot 0-2.
var slot: int = -1


static func start_run(p_tick: int, p_seed: int, p_run_id: String, p_guardian_id := "",
		p_unlocked := PackedStringArray(), p_meta_nodes := PackedStringArray()) -> SimCommand:
	var c := _make(p_tick, Type.START_RUN)
	c.run_seed = p_seed
	c.run_id = p_run_id
	c.guardian_id = p_guardian_id
	c.unlocked = p_unlocked
	c.meta_nodes = p_meta_nodes
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


## Rebuilds a husk (D-104, D-113).
static func rebuild_tower(p_tick: int, p_tower_uid: int) -> SimCommand:
	var c := _make(p_tick, Type.REBUILD_TOWER)
	c.tower_uid = p_tower_uid
	return c


## Buys the next level of a placed tower (D-144).
static func upgrade_tower(p_tick: int, p_tower_uid: int) -> SimCommand:
	var c := _make(p_tick, Type.UPGRADE_TOWER)
	c.tower_uid = p_tower_uid
	return c


static func use_skill(p_tick: int, p_skill_id: String) -> SimCommand:
	var c := _make(p_tick, Type.USE_SKILL)
	c.skill_id = p_skill_id
	return c


## Takes the card in `p_slot` of the open draft (D-147).
static func pick_card(p_tick: int, p_slot: int) -> SimCommand:
	var c := _make(p_tick, Type.PICK_CARD)
	c.slot = p_slot
	return c


static func _make(p_tick: int, p_type: Type) -> SimCommand:
	var c := SimCommand.new()
	c.tick = p_tick
	c.type = p_type
	return c
