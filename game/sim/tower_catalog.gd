class_name TowerCatalog
extends RefCounted
## Tower types loaded from data/towers (D-099). Index = position sorted by id,
## like EnemyCatalog. Seconds are converted to ticks at load.
## M3 kinds (D-140) are loaded but not simulated yet (030-032): range, damage and
## cooldown default to 0 for kinds that have none. Kind fields are read through level_stats.

## Appended only, so existing values never move; the view looks kinds up by lowercased key.
enum Attack { SINGLE, SPLASH, SLOW, WALL, AURA, REPAIR, MARK, SLOW_AREA }

const _ATTACKS := {"single": Attack.SINGLE, "splash": Attack.SPLASH, "slow": Attack.SLOW,
		"wall": Attack.WALL, "aura": Attack.AURA, "repair": Attack.REPAIR, "mark": Attack.MARK,
		"slow_area": Attack.SLOW_AREA}

var ids: PackedStringArray = PackedStringArray()
var name_key: PackedStringArray = PackedStringArray()
## Attack values.
var attack: PackedInt32Array = PackedInt32Array()
var cost: PackedInt32Array = PackedInt32Array()
## Gold added per copy of this type already on the field (linear, D-099).
var cost_per_copy: PackedInt32Array = PackedInt32Array()
var hp: PackedFloat32Array = PackedFloat32Array()
## Footprint used for blocking.
var radius: PackedFloat32Array = PackedFloat32Array()
var attack_range: PackedFloat32Array = PackedFloat32Array()
var damage: PackedFloat32Array = PackedFloat32Array()
## In ticks.
var cooldown: PackedInt32Array = PackedInt32Array()
## 0 when the tower has no splash.
var splash_radius: PackedFloat32Array = PackedFloat32Array()
## Speed multiplier; 1 when the tower does not slow.
var slow_factor: PackedFloat32Array = PackedFloat32Array()
## In ticks; 0 when the tower does not slow.
var slow_ticks: PackedInt32Array = PackedInt32Array()
var sell_refund: PackedFloat32Array = PackedFloat32Array()
var rebuild_fraction: PackedFloat32Array = PackedFloat32Array()
## 1 + the size of `levels` (D-144); 1 for a type without levels.
var max_level: PackedInt32Array = PackedInt32Array()
## Per type, an Array of resolved stat Dictionaries, index = level - 1 (D-144). Keys as in data
## (seconds, not ticks); a level inherits the level below and overrides what its entry lists.
var level_stats: Array = []

## Level 1 values of the stats a kind may lack.
const _LEVEL_DEFAULTS := {"range": 0.0, "damage": 0.0, "cooldown_sec": 0.0, "splash_radius": 0.0,
		"slow_factor": 1.0, "slow_sec": 0.0}


static func load_dir(path: String = "res://data/towers") -> TowerCatalog:
	var catalog := TowerCatalog.new()
	for data in DataFiles.read_dir(path):
		catalog.ids.append(data.id)
		catalog.name_key.append(data.name_key)
		catalog.attack.append(_ATTACKS[data.attack])
		catalog.cost.append(int(data.cost))
		catalog.cost_per_copy.append(int(data.cost_per_copy))
		catalog.hp.append(data.hp)
		catalog.radius.append(data.radius)
		catalog.attack_range.append(data.get("range", 0.0))
		catalog.damage.append(data.get("damage", 0.0))
		catalog.cooldown.append(DataFiles.ticks(data.get("cooldown_sec", 0.0)))
		catalog.splash_radius.append(data.get("splash_radius", 0.0))
		catalog.slow_factor.append(data.get("slow_factor", 1.0))
		catalog.slow_ticks.append(DataFiles.ticks(data.get("slow_sec", 0.0)))
		catalog.sell_refund.append(data.sell_refund)
		catalog.rebuild_fraction.append(data.rebuild_fraction)
		var levels: Array = data.get("levels", [])
		var lv: Dictionary = _LEVEL_DEFAULTS.merged(data, true)
		lv.erase("levels")
		var table: Array = [lv]
		for entry: Dictionary in levels:
			lv = lv.merged(entry, true)
			table.append(lv)
		catalog.max_level.append(table.size())
		catalog.level_stats.append(table)
	return catalog


## Index of a tower id, or -1 if unknown.
func type_of(id: String) -> int:
	return Array(ids).find(id)
