class_name RunData
extends RefCounted
## A run file (data/runs) with its Guardian and her skills, every id resolved to a
## catalog index and every duration in ticks (D-099). A typed view of the file:
## the wave/timeline logic lives elsewhere (task 013).

enum Skill { AREA_BLAST, SHIELD }

const DIR := "res://data"
const _SKILLS := {"area_blast": Skill.AREA_BLAST, "shield": Skill.SHIELD}

var id: String = ""
var starting_gold: int = 0
var build_radius: float = 0.0
var grid_step: float = 0.0
var spawn_ring_min: float = 0.0
var spawn_ring_max: float = 0.0
var first_wave_tick: int = 0
var wave_ticks: int = 0
var break_ticks: int = 0
## Per wave entry; the last entry repeats once the list runs out (D-096, D-099).
var wave_count: PackedInt32Array = PackedInt32Array()
var wave_mix_types: Array[PackedInt32Array] = []
var wave_mix_weights: Array[PackedFloat32Array] = []
## Mini-bosses (final boss not included).
var boss_ticks: PackedInt32Array = PackedInt32Array()
var boss_types: PackedInt32Array = PackedInt32Array()
var final_boss_tick: int = 0
var final_boss_type: int = -1
## Tower catalog indices offered in the build menu.
var tower_types: PackedInt32Array = PackedInt32Array()

var guardian_hp: float = 0.0
var guardian_contact_radius: float = 0.0
## Skills, indexed by skill slot. Fields a kind does not use are 0.
var skill_ids: PackedStringArray = PackedStringArray()
## Localisation key of each skill's name (D-063).
var skill_name_key: PackedStringArray = PackedStringArray()
var skill_kind: PackedInt32Array = PackedInt32Array()
var skill_cooldown: PackedInt32Array = PackedInt32Array()
var skill_radius: PackedFloat32Array = PackedFloat32Array()
var skill_damage: PackedFloat32Array = PackedFloat32Array()
var skill_absorb: PackedFloat32Array = PackedFloat32Array()
var skill_duration: PackedInt32Array = PackedInt32Array()


static func load_id(run_id: String, enemies: EnemyCatalog, towers: TowerCatalog) -> RunData:
	var d := DataFiles.read_id(DIR + "/runs", run_id)
	var run := RunData.new()
	run.id = run_id
	run.starting_gold = int(d.starting_gold)
	run.build_radius = d.build_radius
	run.grid_step = d.grid_step
	run.spawn_ring_min = d.spawn_ring_min
	run.spawn_ring_max = d.spawn_ring_max
	run.first_wave_tick = DataFiles.ticks(d.first_wave_sec)
	run.wave_ticks = DataFiles.ticks(d.wave_sec)
	run.break_ticks = DataFiles.ticks(d.break_sec)
	for wave: Dictionary in d.waves:
		var types := PackedInt32Array()
		var weights := PackedFloat32Array()
		for entry: Dictionary in wave.mix:
			types.append(_resolve(enemies.type_of(entry.enemy), entry.enemy))
			weights.append(entry.weight)
		run.wave_count.append(int(wave.count))
		run.wave_mix_types.append(types)
		run.wave_mix_weights.append(weights)
	for boss: Dictionary in d.bosses:
		run.boss_ticks.append(DataFiles.ticks(boss.at_sec))
		run.boss_types.append(_resolve(enemies.type_of(boss.enemy), boss.enemy))
	run.final_boss_tick = DataFiles.ticks(d.final_boss.at_sec)
	run.final_boss_type = _resolve(enemies.type_of(d.final_boss.enemy), d.final_boss.enemy)
	for tower_id: String in d.towers:
		run.tower_types.append(_resolve(towers.type_of(tower_id), tower_id))
	run._load_guardian(d.guardian)
	return run


func _load_guardian(guardian_id: String) -> void:
	var g := DataFiles.read_id(DIR + "/guardians", guardian_id)
	guardian_hp = g.hp
	guardian_contact_radius = g.contact_radius
	for skill_id: String in g.skills:
		var s := DataFiles.read_id(DIR + "/skills", skill_id)
		skill_ids.append(skill_id)
		skill_name_key.append(s.name_key)
		skill_kind.append(_resolve(_SKILLS.get(s.get("kind"), -1), skill_id))
		skill_cooldown.append(DataFiles.ticks(s.cooldown_sec))
		skill_radius.append(s.get("radius", 0.0))
		skill_damage.append(s.get("damage", 0.0))
		skill_absorb.append(s.get("absorb", 0.0))
		skill_duration.append(DataFiles.ticks(s.get("duration_sec", 0.0)))


static func _resolve(index: int, ref: String) -> int:
	if index < 0:
		push_error("RunData: unknown id %s" % ref)
		assert(false, "RunData: unknown id %s" % ref)
	return index
