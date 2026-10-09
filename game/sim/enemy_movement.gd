class_name EnemyMovement
extends RefCounted
## Enemy movement split in two passes (D-107): steer() picks a direction and the
## remaining gap to the stop point, advance() moves along it and sets the state.
## With a FlowField, steer() routes around towers (D-115); push_out() keeps enemies out of them.

## Gap of an enemy with no clear line to the Guardian: it keeps walking (D-115, D-118).
const BLOCKED_GAP: float = 1e9

## Per enemy, refilled each tick by steer(). Corpses (hp <= 0) are skipped.
var dir_x: PackedFloat32Array = PackedFloat32Array()
var dir_z: PackedFloat32Array = PackedFloat32Array()
var gap: PackedFloat32Array = PackedFloat32Array()
## Per type: distance from the Guardian centre at which the enemy stops and attacks.
var stop_dist: PackedFloat32Array = PackedFloat32Array()
# Per type, copied by set_stop() for the walled-in stop (D-116).
var _radius: PackedFloat32Array = PackedFloat32Array()
var _range: PackedFloat32Array = PackedFloat32Array()


## stop = contact_radius + radius + attack_range (range between body edges; 0 = melee).
func set_stop(catalog: EnemyCatalog, contact_radius: float) -> void:
	stop_dist.resize(catalog.radius.size())
	_radius = catalog.radius
	_range = catalog.attack_range
	for t in stop_dist.size():
		stop_dist[t] = contact_radius + catalog.radius[t] + catalog.attack_range[t]


## Straight line to the Guardian at (0, 0); with a field, the D-115 cases: outside the
## grid or with a clear line, straight; else the field step, and BLOCKED_GAP so it never
## stops to attack through a tower (D-118). Walled in (no path), it heads for the first
## live tower on its line and stops at its range from it (D-116, needs build and towers);
## sets enemies.target_id (tower uid, or -1 = the Guardian).
func steer(enemies: SimEnemies, field: FlowField = null, build: BuildGrid = null,
		towers: SimTowers = null, tower_catalog: TowerCatalog = null) -> void:
	var n := enemies.count()
	dir_x.resize(n)
	dir_z.resize(n)
	gap.resize(n)
	var xs := enemies.pos_x
	var zs := enemies.pos_z
	var hp := enemies.hp
	var ty := enemies.type_id
	var tgt := enemies.target_id
	var size := 0
	var half := 0.0
	var fstep := 1.0
	var fdist := PackedInt32Array()
	var fdir := PackedByteArray()
	var fhit := PackedInt32Array()
	var fesc := PackedInt32Array()
	if field:
		size = field.size
		half = size / 2.0
		fstep = field.step
		fdist = field.dist
		fdir = field.dir
		fhit = field.hit
		fesc = field.escape
	for i in n:
		if hp[i] <= 0.0:
			continue
		tgt[i] = -1
		var x := xs[i]
		var z := zs[i]
		var d := sqrt(x * x + z * z)
		if d < 1e-6:
			dir_x[i] = 0.0
			dir_z[i] = 0.0
		else:
			dir_x[i] = -x / d
			dir_z[i] = -z / d
		gap[i] = d - stop_dist[ty[i]]
		if size == 0:
			continue
		var ci := floori(x / fstep + half)
		var cj := floori(z / fstep + half)
		if ci < 0 or cj < 0 or ci >= size or cj >= size:
			continue
		var c := fesc[cj * size + ci]  # inside a tower: its nearest free cell
		if fhit[c] < 0:
			continue
		gap[i] = BLOCKED_GAP
		if fdist[c] < FlowField.INF:
			var k := fdir[c]
			dir_x[i] = FlowField.DIR_X[k]
			dir_z[i] = FlowField.DIR_Z[k]
		elif towers:
			_attack_wall(i, fhit[c], enemies, build, towers, tower_catalog)


# Walled in (D-116): toward the tower holding cell h, gap to its range from the tower body.
# Sold, husk or unknown (the field lags a few ticks): keep the straight chase, BLOCKED_GAP.
func _attack_wall(i: int, h: int, enemies: SimEnemies, build: BuildGrid, towers: SimTowers,
		tower_catalog: TowerCatalog) -> void:
	var u := build.owner[h]
	if u < 0 or u >= towers.uid_index.size():
		return
	var t := towers.uid_index[u]
	if t < 0 or towers.husk[t]:
		return
	var dx := towers.pos_x[t] - enemies.pos_x[i]
	var dz := towers.pos_z[t] - enemies.pos_z[i]
	var d := sqrt(dx * dx + dz * dz)
	if d > 1e-6:
		dir_x[i] = dx / d
		dir_z[i] = dz / d
	var e := enemies.type_id[i]
	gap[i] = d - (tower_catalog.radius[towers.type_id[t]] + _radius[e] + _range[e])
	enemies.target_id[i] = u


## D-112: a live enemy whose cell is solid and known as such by the field is clamped
## into the square of the cell's escape (1e-4 inside). Runs after advance().
func push_out(enemies: SimEnemies, build: BuildGrid, field: FlowField) -> void:
	var size := field.size
	var half := size / 2.0
	var fstep := field.step
	var solid := build.solid
	var fesc := field.escape
	var xs := enemies.pos_x
	var zs := enemies.pos_z
	var hp := enemies.hp
	for i in enemies.count():
		if hp[i] <= 0.0:
			continue
		var ci := floori(xs[i] / fstep + half)
		var cj := floori(zs[i] / fstep + half)
		if ci < 0 or cj < 0 or ci >= size or cj >= size:
			continue
		var c := cj * size + ci
		var e := fesc[c]
		if solid[c] == 0 or e == c or e < 0:
			continue
		var x0 := (e % size - half) * fstep
		var z0 := (e / size - half) * fstep
		xs[i] = clampf(xs[i], x0 + 1e-4, x0 + fstep - 1e-4)
		zs[i] = clampf(zs[i], z0 + 1e-4, z0 + fstep - 1e-4)


## Moves each live enemy along its steer direction by min(speed * dt * slow, gap); slow
## is slow_factor while slow_ticks > 0, counted down here once per tick (D-114).
## State is re-evaluated every tick: ATTACKING once the gap is closed, QUEUED (no move)
## when blocked (EnemySeparation.blocked, same tick), else MOVING.
func advance(enemies: SimEnemies, type_speed: PackedFloat32Array, dt: float,
		blocked: PackedByteArray) -> void:
	var hp := enemies.hp
	var ty := enemies.type_id
	var st := enemies.state
	var xs := enemies.pos_x
	var zs := enemies.pos_z
	var sf := enemies.slow_factor
	var sn := enemies.slow_ticks
	for i in enemies.count():
		if hp[i] <= 0.0:
			continue
		var g := gap[i]
		if g <= 0.0:
			st[i] = SimEnemies.State.ATTACKING
		elif blocked[i] != 0:
			st[i] = SimEnemies.State.QUEUED
		else:
			var step := type_speed[ty[i]] * dt
			if sn[i] > 0:
				step *= sf[i]
			if g <= step:
				step = g
				st[i] = SimEnemies.State.ATTACKING
			else:
				st[i] = SimEnemies.State.MOVING
			xs[i] += dir_x[i] * step
			zs[i] += dir_z[i] * step
		# A slow counts down once per MOVE phase, moving or not (D-114).
		if sn[i] > 0:
			sn[i] -= 1
			if sn[i] == 0:
				sf[i] = 1.0
