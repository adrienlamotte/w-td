class_name EnemyCatalog
extends RefCounted
## Enemy types loaded from data. type_id = index in this catalog, sorted by id
## so the order is deterministic (02_TECH_ARCHITECTURE.md 3a, D-081).

var ids: PackedStringArray = PackedStringArray()
var name_key: PackedStringArray = PackedStringArray()
var speed: PackedFloat32Array = PackedFloat32Array()
var radius: PackedFloat32Array = PackedFloat32Array()
var hp: PackedFloat32Array = PackedFloat32Array()
var separation_strength: PackedFloat32Array = PackedFloat32Array()
## Damage per hit, melee or ranged.
var damage: PackedFloat32Array = PackedFloat32Array()
## 0 = melee (attacks at contact).
var attack_range: PackedFloat32Array = PackedFloat32Array()
## In ticks.
var attack_cooldown: PackedInt32Array = PackedInt32Array()
## Gold dropped on death (amount) and its chance, from the first drops entry
## (gold is the only drop type, D-094).
var gold: PackedInt32Array = PackedInt32Array()
var gold_chance: PackedFloat32Array = PackedFloat32Array()
## 1 for archetype miniboss or boss.
var is_boss: PackedByteArray = PackedByteArray()
## Largest radius over the horde (non-boss) types only: it sizes the spatial grid
## cell and the separation scan, so a boss must not grow it (D-099; bosses get
## their own separation pass in task 013).
var max_radius: float = 0.0


static func load_dir(path: String = "res://data/enemies") -> EnemyCatalog:
	var catalog := EnemyCatalog.new()
	for data in DataFiles.read_dir(path):
		var boss: bool = data.archetype in ["miniboss", "boss"]
		var drop: Dictionary = data.drops[0] if data.drops.size() > 0 else {"amount": 0, "chance": 0.0}
		catalog.ids.append(data.id)
		catalog.name_key.append(data.name_key)
		catalog.speed.append(data.speed)
		catalog.radius.append(data.radius)
		catalog.hp.append(data.hp)
		catalog.separation_strength.append(data.separation_strength)
		catalog.damage.append(data.damage)
		catalog.attack_range.append(data.attack_range)
		catalog.attack_cooldown.append(DataFiles.ticks(data.attack_cooldown_sec))
		catalog.gold.append(int(drop.amount))
		catalog.gold_chance.append(drop.chance)
		catalog.is_boss.append(1 if boss else 0)
		if not boss:
			catalog.max_radius = maxf(catalog.max_radius, data.radius)
	return catalog


## type_id of an enemy id, or -1 if unknown.
func type_of(id: String) -> int:
	return Array(ids).find(id)
