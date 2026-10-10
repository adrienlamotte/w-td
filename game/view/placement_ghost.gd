class_name PlacementGhost
extends Node3D
## Placement ghost and cursor hints (D-122). Verdict, snapped centre and price come only from
## TowerBuilding.check_place; sell and rebuild numbers from sell_refund and rebuild_price,
## upgrade line from TowerUpgrade.check (D-151).
## One check_place per frame; the HUD cursor label shows `hints`.

const CONFIG_PATH := "res://data/ui/ui_default.json"
const REASON_KEYS := {
	TowerBuilding.Reason.NOT_OFFERED: "build.reason.not_offered",
	TowerBuilding.Reason.OCCUPIED: "build.reason.occupied",
	TowerBuilding.Reason.OUT_OF_RADIUS: "build.reason.out_of_radius",
	TowerBuilding.Reason.TOO_CLOSE: "build.reason.too_close",
	TowerBuilding.Reason.NO_GOLD: "build.reason.no_gold",
}
## Upgrade line per TowerUpgrade.check verdict (D-151); HUSK and NO_TOWER show no line.
const UPGRADE_KEYS := {
	TowerUpgrade.Reason.OK: "upgrade.hint",
	TowerUpgrade.Reason.NO_GOLD: "upgrade.reason.no_gold",
	TowerUpgrade.Reason.LOCKED: "upgrade.reason.locked",
	TowerUpgrade.Reason.MAX_LEVEL: "upgrade.reason.max_level",
}

var world: SimWorld
var input: PlayerInput
var config: Dictionary
var material := StandardMaterial3D.new()
## Last verdict (null when nothing is being placed) and the cursor hints built from it.
var check: TowerBuilding.Check
var hints: Array[Dictionary] = []
var _box := MeshInstance3D.new()
var _ring := MeshInstance3D.new()
var _ring_type: int = -1


static func load_config() -> Dictionary:
	return DataFiles.read_file(CONFIG_PATH)


## Cursor hint lines as {key, values}; values.key is an action glyph key (input.kbm/pad.*).
## c: the frame's check_place result; computed here when null and a tower is selected.
static func hint(w: SimWorld, p_input: PlayerInput, c: TowerBuilding.Check = null) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not PlayerInput.can_build(w):
		return out
	var glyph := "input.pad." if p_input.gamepad else "input.kbm."
	if p_input.selected_tower != "":
		if c == null:
			c = TowerBuilding.check_place(w, p_input.selected_tower, p_input.cursor.x, p_input.cursor.y)
		var key: String = "build.cost" if c.reason == TowerBuilding.Reason.OK else REASON_KEYS[c.reason]
		out.append({"key": key, "values": {"gold": c.price}})
		return out
	var uid := PlayerInput.tower_uid_at(w, p_input.cursor)
	var t := w.towers.uid.find(uid) if uid >= 0 else -1
	if t < 0:
		return out
	if w.towers.husk[t]:
		out.append({"key": "build.hint.rebuild",
			"values": {"key": glyph + "build_place", "gold": TowerBuilding.rebuild_price(w, t)}})
	elif w.tower_catalog.max_level[w.towers.type_id[t]] > 1:
		var u := TowerUpgrade.check(w, uid)
		out.append({"key": UPGRADE_KEYS[u.reason],
			"values": {"key": glyph + "tower_upgrade", "gold": u.price, "level": u.level}})
	out.append({"key": "build.hint.sell",
		"values": {"key": glyph + "tower_sell", "gold": TowerBuilding.sell_refund(w, t)}})
	return out


## Translated text of hint lines, one per line.
static func text(lines: Array[Dictionary]) -> String:
	var parts := PackedStringArray()
	for h in lines:
		var values: Dictionary = h.values.duplicate()
		if values.has("key"):
			values.key = TranslationServer.translate(values.key)
		parts.append(TranslationServer.translate(h.key).format(values))
	return "\n".join(parts)


func setup(w: SimWorld, p_input: PlayerInput) -> void:
	world = w
	input = p_input
	config = load_config()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_box.mesh = BoxMesh.new()
	_box.material_override = material
	_ring.material_override = material
	add_child(_box)
	add_child(_ring)
	update()


func _process(_delta: float) -> void:
	update()


func update() -> void:
	check = null
	if input.selected_tower != "" and PlayerInput.can_build(world):
		check = TowerBuilding.check_place(world, input.selected_tower, input.cursor.x, input.cursor.y)
	hints = hint(world, input, check)
	visible = check != null and check.footprint > 0  # NOT_OFFERED has no footprint
	if not visible:
		return
	var ok := check.reason == TowerBuilding.Reason.OK
	var rgba: Array = config.ghost_valid_color if ok else config.ghost_invalid_color
	material.albedo_color = Color(rgba[0], rgba[1], rgba[2], rgba[3])
	position = Vector3(check.x, 0.0, check.z)
	var side := check.footprint * world.build.step
	var h := float(config.ghost_height)
	_box.scale = Vector3(side, h, side)
	_box.position.y = h / 2.0
	if _ring_type != check.type:
		_ring_type = check.type
		var r := world.tower_catalog.attack_range[check.type]
		var half := float(config.range_ring_width) / 2.0
		var torus := TorusMesh.new()
		torus.inner_radius = r - half
		torus.outer_radius = r + half
		_ring.mesh = torus
