class_name EnemyMovement
extends RefCounted
## Enemy movement split in two passes (D-107): steer() picks a direction and the
## remaining gap to the stop point, advance() moves along it and sets the state.
## Task 024 replaces only steer() with the flow field; advance() stays.

## Per enemy, refilled each tick by steer(). Corpses (hp <= 0) are skipped.
var dir_x: PackedFloat32Array = PackedFloat32Array()
var dir_z: PackedFloat32Array = PackedFloat32Array()
var gap: PackedFloat32Array = PackedFloat32Array()
## Per type: distance from the Guardian centre at which the enemy stops and attacks.
var stop_dist: PackedFloat32Array = PackedFloat32Array()


## stop = contact_radius + radius + attack_range (range between body edges; 0 = melee).
func set_stop(catalog: EnemyCatalog, contact_radius: float) -> void:
	stop_dist.resize(catalog.radius.size())
	for t in stop_dist.size():
		stop_dist[t] = contact_radius + catalog.radius[t] + catalog.attack_range[t]


## Straight line to the Guardian at (0, 0).
func steer(enemies: SimEnemies) -> void:
	var n := enemies.count()
	dir_x.resize(n)
	dir_z.resize(n)
	gap.resize(n)
	var xs := enemies.pos_x
	var zs := enemies.pos_z
	var hp := enemies.hp
	var ty := enemies.type_id
	for i in n:
		if hp[i] <= 0.0:
			continue
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


## Moves each live enemy along its steer direction by min(speed * dt, gap).
## State is re-evaluated every tick: ATTACKING once the gap is closed, else MOVING.
func advance(enemies: SimEnemies, type_speed: PackedFloat32Array, dt: float) -> void:
	var hp := enemies.hp
	var ty := enemies.type_id
	var st := enemies.state
	var xs := enemies.pos_x
	var zs := enemies.pos_z
	for i in enemies.count():
		if hp[i] <= 0.0:
			continue
		var g := gap[i]
		if g <= 0.0:
			st[i] = SimEnemies.State.ATTACKING
			continue
		var step := type_speed[ty[i]] * dt
		if g <= step:
			step = g
			st[i] = SimEnemies.State.ATTACKING
		else:
			st[i] = SimEnemies.State.MOVING
		xs[i] += dir_x[i] * step
		zs[i] += dir_z[i] * step
