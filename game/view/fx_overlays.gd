class_name FxOverlays
extends RefCounted
## State overlays (D-163), rebuilt from the world every frame by read_state, never accumulated:
## a LINK disc above every live tower with an active relationship, a RING of radius `reach`
## around every live aura tower, the bounty ring at the Guardian while Clearance Sale lasts.
## Empty while no run. No Node, testable headless; FxLayer draws them.

enum Kind { LINK, RING }

const MAX_OVERLAYS: int = 512

var kind: PackedInt32Array = PackedInt32Array()
var x: PackedFloat32Array = PackedFloat32Array()
var z: PackedFloat32Array = PackedFloat32Array()
## Ring radius (0 for a LINK).
var r: PackedFloat32Array = PackedFloat32Array()
## Disc diameter or ring width.
var size: PackedFloat32Array = PackedFloat32Array()
var color: PackedColorArray = PackedColorArray()
var fx: Dictionary
var _link_color: Color
var _aura_color: Color
var _bounty_color: Color


func _init(cfg: Dictionary) -> void:
	fx = cfg.fx
	_link_color = HordeRenderer.rgb(fx.link_color)
	_aura_color = HordeRenderer.rgb(fx.aura_color)
	_bounty_color = HordeRenderer.rgb(fx.bounty_color)


func count() -> int:
	return kind.size()


func read_state(world: SimWorld) -> void:
	kind.resize(0)
	x.resize(0)
	z.resize(0)
	r.resize(0)
	size.resize(0)
	color.resize(0)
	if world.run == null:
		return
	var towers := world.towers
	var attack := world.tower_catalog.attack
	for t in towers.count():
		var type := towers.type_id[t]
		if type < 0 or towers.husk[t]:
			continue
		if towers.syn_mask[t] != 0:
			_add(Kind.LINK, towers.pos_x[t], towers.pos_z[t], 0.0, float(fx.link_size), _link_color)
		if attack[type] == TowerCatalog.Attack.AURA:
			_add(Kind.RING, towers.pos_x[t], towers.pos_z[t], towers.reach[t], float(fx.aura_width), _aura_color)
	if world.clock < world.skills.bounty_until:
		_add(Kind.RING, 0.0, 0.0, float(fx.bounty_radius), float(fx.bounty_width), _bounty_color)


func _add(k: Kind, p_x: float, p_z: float, p_r: float, p_size: float, c: Color) -> void:
	if kind.size() >= MAX_OVERLAYS:
		return
	kind.append(k)
	x.append(p_x)
	z.append(p_z)
	r.append(p_r)
	size.append(p_size)
	color.append(c)
