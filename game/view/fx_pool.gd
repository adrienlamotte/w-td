class_name FxPool
extends RefCounted
## Combat effects as SoA, spawned from sim events, aged in view seconds (D-120). No Node,
## testable headless; FxLayer draws them. Capped at fx.max_effects: new ones are dropped when full.
## The Guardian stands at the origin (D-107).

enum Kind { PUFF, COIN, SHOT, SPARK, RING }

## Effect start (x0, z0) and end (x1, z1); a RING keeps its radius in x1.
var kind: PackedInt32Array = PackedInt32Array()
var x0: PackedFloat32Array = PackedFloat32Array()
var z0: PackedFloat32Array = PackedFloat32Array()
var x1: PackedFloat32Array = PackedFloat32Array()
var z1: PackedFloat32Array = PackedFloat32Array()
var age: PackedFloat32Array = PackedFloat32Array()
var life: PackedFloat32Array = PackedFloat32Array()
var color: PackedColorArray = PackedColorArray()
## Disc diameter, or ribbon/ring width.
var size: PackedFloat32Array = PackedFloat32Array()
## View seconds of Guardian flash left.
var guardian_flash: float = 0.0
var fx: Dictionary
var max_effects: int
var _enemy_color: PackedColorArray = PackedColorArray()
var _enemy_size: PackedFloat32Array = PackedFloat32Array()
var _tower_color: PackedColorArray = PackedColorArray()
var _coin_color: Color
var _spark_color: Color
var _ring_color: Color


func _init(cfg: Dictionary, world: SimWorld) -> void:
	fx = cfg.fx
	max_effects = int(fx.max_effects)
	for t in world.catalog.ids.size():
		var look := HordeRenderer.enemy_look(cfg, world.catalog, t)
		_enemy_color.append(HordeRenderer.rgb(look.color))
		_enemy_size.append(float(fx.death_size) * float(look.height_scale))
	for type in world.tower_catalog.ids.size():
		_tower_color.append(HordeRenderer.rgb(HordeRenderer.tower_look(cfg, world.tower_catalog, type).color))
	_coin_color = HordeRenderer.rgb(fx.coin_color)
	_spark_color = HordeRenderer.rgb(fx.spark_color)
	_ring_color = HordeRenderer.rgb(fx.ring_color)


func count() -> int:
	return kind.size()


## Reads the events of the last step(); call after every step (they are cleared at the next).
func read_events(world: SimWorld) -> void:
	var ev := world.events
	for e in ev.count:
		var k := ev.kind[e]
		var a := ev.a[e]
		var x := ev.x[e]
		var z := ev.z[e]
		if k == SimEvents.Kind.ENEMY_DIED:
			add(Kind.PUFF, x, z, x, z, float(fx.death_sec), _enemy_color[a], _enemy_size[a])
			if ev.value[e] > 0.0:  # gold is already counted: the coin is cosmetic (D-094)
				add(Kind.COIN, x, z, 0.0, 0.0, float(fx.coin_sec), _coin_color, float(fx.coin_size))
		elif k == SimEvents.Kind.TOWER_FIRED:
			var t := world.towers.uid.find(a)
			if t >= 0:
				add(Kind.SHOT, world.towers.pos_x[t], world.towers.pos_z[t], x, z, float(fx.shot_sec),
					_tower_color[int(ev.value[e])], float(fx.shot_width))
		elif k == SimEvents.Kind.GUARDIAN_HIT:
			guardian_flash = float(fx.flash_sec)
			if world.catalog.attack_range[a] > 0.0:
				add(Kind.SHOT, x, z, 0.0, 0.0, float(fx.shot_sec), _enemy_color[a], float(fx.shot_width))
		elif k == SimEvents.Kind.SKILL_USED:
			if world.run.skill_kind[a] == RunData.Skill.AREA_BLAST:
				add(Kind.RING, 0.0, 0.0, world.run.skill_radius[a], 0.0, float(fx.ring_sec),
					_ring_color, float(fx.ring_width))
		elif k == SimEvents.Kind.TOWER_HIT:
			var t := world.towers.uid.find(a)
			if t >= 0:
				add(Kind.SPARK, world.towers.pos_x[t], world.towers.pos_z[t], 0.0, 0.0,
					float(fx.spark_sec), _spark_color, float(fx.spark_size))
		# ENEMY_HIT spawns nothing: the hit flash covers it; one blast can hit thousands.


func add(p_kind: Kind, p_x0: float, p_z0: float, p_x1: float, p_z1: float, p_life: float,
		p_color: Color, p_size: float) -> void:
	if kind.size() >= max_effects:
		return
	kind.append(p_kind)
	x0.append(p_x0)
	z0.append(p_z0)
	x1.append(p_x1)
	z1.append(p_z1)
	age.append(0.0)
	life.append(p_life)
	color.append(p_color)
	size.append(p_size)


## Ages every effect and swap-removes the expired ones.
func advance(delta: float) -> void:
	guardian_flash = maxf(0.0, guardian_flash - delta)
	for i in range(kind.size() - 1, -1, -1):
		age[i] += delta
		if age[i] >= life[i]:
			_remove(i)


## Fraction of the lifetime elapsed, in [0, 1).
func progress(i: int) -> float:
	return age[i] / life[i]


func _remove(i: int) -> void:
	var last := kind.size() - 1
	kind[i] = kind[last]
	x0[i] = x0[last]
	z0[i] = z0[last]
	x1[i] = x1[last]
	z1[i] = z1[last]
	age[i] = age[last]
	life[i] = life[last]
	color[i] = color[last]
	size[i] = size[last]
	kind.resize(last)
	x0.resize(last)
	z0.resize(last)
	x1.resize(last)
	z1.resize(last)
	age.resize(last)
	life.resize(last)
	color.resize(last)
	size.resize(last)
