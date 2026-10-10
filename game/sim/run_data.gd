class_name RunData
extends RefCounted
## A run file (data/runs) with its Guardian and her skills, every id resolved to a
## catalog index and every duration in ticks (D-099). A typed view of the file:
## the wave/timeline logic lives elsewhere (task 013).

enum Skill { AREA_BLAST, SHIELD, GUARD, BOUNTY, HASTE, SNARE, REBUILD }

const DIR := "res://data"
const _SKILLS := {"area_blast": Skill.AREA_BLAST, "shield": Skill.SHIELD, "guard": Skill.GUARD,
	"bounty": Skill.BOUNTY, "haste": Skill.HASTE, "snare": Skill.SNARE, "rebuild": Skill.REBUILD}

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
## XP curve: level L to L + 1 costs xp_base + xp_step * (L - 1) (D-147).
var xp_base: float = 0.0
var xp_step: float = 0.0
## Draft type weights in CardCatalog.Type order (new_tower, signature, skill, perk).
var card_type_weights: PackedFloat32Array = PackedFloat32Array()

## The Guardian file of this run (StartRun's choice, else the run file's).
var guardian_id: String = ""
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
var skill_damage_factor: PackedFloat32Array = PackedFloat32Array()
var skill_gold_per_kill: PackedInt32Array = PackedInt32Array()
var skill_cooldown_factor: PackedFloat32Array = PackedFloat32Array()
var skill_slow_factor: PackedFloat32Array = PackedFloat32Array()
var skill_guardian_heal: PackedFloat32Array = PackedFloat32Array()
## Fields `skill_power` multiplies (10_M3_CONTENT.md 4.1).
var skill_power_stats: Array[PackedStringArray] = []
## Her signature skill: the first whose kind is not Shield; -1 if none (D-146).
var signature_slot: int = -1


## An empty `guardian_id` keeps the run file's Guardian (D-146).
static func load_id(run_id: String, enemies: EnemyCatalog, towers: TowerCatalog, p_guardian_id := "") -> RunData:
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
	run.xp_base = d.xp_base
	run.xp_step = d.xp_step
	for k in CardCatalog.Type.FILLER:
		run.card_type_weights.append(d.card_type_weights[CardCatalog.TYPE_NAMES[k]])
	run._load_guardian(p_guardian_id if p_guardian_id != "" else String(d.guardian))
	return run


func _load_guardian(p_id: String) -> void:
	guardian_id = p_id
	var g := DataFiles.read_id(DIR + "/guardians", p_id)
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
		skill_damage_factor.append(s.get("damage_factor", 0.0))
		skill_gold_per_kill.append(int(s.get("gold_per_kill", 0)))
		skill_cooldown_factor.append(s.get("cooldown_factor", 0.0))
		skill_slow_factor.append(s.get("slow_factor", 0.0))
		skill_guardian_heal.append(s.get("guardian_heal", 0.0))
		skill_power_stats.append(PackedStringArray(s.get("power_stats", [])))
		if signature_slot < 0 and skill_kind[-1] != Skill.SHIELD:
			signature_slot = skill_kind.size() - 1


static func _resolve(index: int, ref: String) -> int:
	if index < 0:
		push_error("RunData: unknown id %s" % ref)
		assert(false, "RunData: unknown id %s" % ref)
	return index
