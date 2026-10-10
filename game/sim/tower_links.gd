class_name TowerLinks
extends RefCounted
## Neighbour-based tower stats (D-150), run inside TowerStats.recompute only (per change, never
## per tick): relationship bonuses (10_M3_CONTENT.md 5), the Guardian side as `guardian` layout
## entries, Hymn's aura and Poppy's repair lists. Pair scan through a tower SpatialGrid.
## ponytail: full pass per change; an incremental update around the changed tower if a big
## layout's recompute ever shows in a frame.

const _CELL := 6.0  # the largest max_distance (rivals, D-136)
const _N := 10  # TowerStats.MODDED.size()
const _RANGE := 0
const _DAMAGE := 1
const _COOLDOWN := 2
const _AURA_RADIUS := 7

## Extra (add, mult) sums per tower index, _N per tower in TowerStats.MODDED order; empty when
## no live tower has a waifu, an aura or a repair kind (M2 runs, the bench).
var extra: PackedVector2Array = PackedVector2Array()
## Repair neighbour lists, CSR by tower index (live towers in range, herself included,
## ascending index). Valid until the next recompute.
var heal_first: PackedInt32Array = PackedInt32Array()
var heal_count: PackedInt32Array = PackedInt32Array()
var heal_list: PackedInt32Array = PackedInt32Array()
var _grid: SpatialGrid = null
var _near: PackedInt32Array = PackedInt32Array()
var _aura_of: PackedInt32Array = PackedInt32Array()
var _waifu: PackedInt32Array = PackedInt32Array()
## Per tower index: aura_damage, aura_cooldown of a live Hymn, else -1.
var _ad: PackedFloat32Array = PackedFloat32Array()
var _ac: PackedFloat32Array = PackedFloat32Array()


## `cache`: the store sums per tower type (TowerStats), filled for every built type.
func compute(w: SimWorld, cache: Array) -> void:
	var towers := w.towers
	var n := towers.count()
	w.modifiers.clear_layout()
	w.guardian_syn_mask = 0
	towers.syn_mask.fill(0)
	extra.clear()
	heal_first.resize(n)
	heal_count.resize(n)
	heal_count.fill(0)
	heal_list.clear()
	if not _any(w):
		return
	extra.resize(n * _N)
	extra.fill(Vector2.ZERO)
	var half := w.max_build_radius + 1.0
	if _grid == null or _grid.half_extent != half:
		_grid = SpatialGrid.new(_CELL, half)
	_grid.rebuild(towers.pos_x, towers.pos_z)
	_relationships(w)
	_aura(w, cache)
	_repair_lists(w, cache)


static func live(towers: SimTowers, t: int) -> bool:
	return towers.type_id[t] >= 0 and not towers.husk[t]


func _any(w: SimWorld) -> bool:
	var towers := w.towers
	for t in towers.count():
		if live(towers, t):
			var type := towers.type_id[t]
			var kind := w.tower_catalog.attack[type]
			if w.synergies.waifu_of_tower[type] >= 0 or kind == TowerCatalog.Attack.AURA \
					or kind == TowerCatalog.Attack.REPAIR:
				return true
	return false


# Rules 2, 3 and 5: one partner in the window is enough; the Guardian (body edge) while RUNNING.
func _relationships(w: SimWorld) -> void:
	var towers := w.towers
	var syn := w.synergies
	var px := towers.pos_x
	var pz := towers.pos_z
	var running := w.run_state == SimWorld.RunState.RUNNING
	var gw := syn.waifu_of_guardian(w.run.guardian_id) if running else -1
	var contact := w.run.guardian_contact_radius if running else 0.0
	var gmask := 0
	var n := towers.count()
	_waifu.resize(n)
	for t in n:
		_waifu[t] = syn.waifu_of_tower[towers.type_id[t]] if live(towers, t) else -1
	for t in n:
		var a := _waifu[t]
		if a < 0 or syn.waifu_reach[a] <= 0.0:
			continue
		var mask := 0
		_grid.query_radius(px[t], pz[t], syn.waifu_reach[a], px, pz, _near)
		for j in _near:
			var b := _waifu[j]
			if b < 0 or j == t:
				continue
			var rules := syn.rules_for(a, b)
			if rules.is_empty():
				continue
			var d := Vector2(px[j] - px[t], pz[j] - pz[t]).length()
			for r in rules:
				if d >= syn.min_d[r] and d <= syn.max_d[r]:
					mask |= 1 << r
		if gw >= 0:
			var d := Vector2(px[t], pz[t]).length() - contact
			for r in syn.rules_for(a, gw):
				if d >= syn.min_d[r] and d <= syn.max_d[r]:
					mask |= 1 << r
					gmask |= 1 << r
		towers.syn_mask[t] = mask
		for r in syn.rule_ids.size():
			if mask & (1 << r):
				var s := syn.side_of(r, a)
				_add(t, syn.side_stat[s][r], syn.side_op[s][r], syn.side_value[s][r])
	w.guardian_syn_mask = gmask
	for r in syn.rule_ids.size():
		if gmask & (1 << r):  # written directly: never sets stats_dirty again
			w.modifiers.add(syn.guardian_stat[r], syn.guardian_op[r], syn.guardian_value[r], "guardian", true)


# Rule 6: the strongest Hymn in reach applies to every other live tower, Hymns excluded.
func _aura(w: SimWorld, cache: Array) -> void:
	var towers := w.towers
	var kind := w.tower_catalog.attack
	var n := towers.count()
	_aura_of.resize(n)
	_aura_of.fill(-1)
	_ad.resize(n)
	_ad.fill(-1.0)
	_ac.resize(n)
	for h in n:
		if live(towers, h) and kind[towers.type_id[h]] == TowerCatalog.Attack.AURA:
			var lv := _lv(w, h)
			_ad[h] = lv.aura_damage
			_ac[h] = lv.aura_cooldown
	for h in n:
		if _ad[h] < 0.0:
			continue
		var r := TowerStats.value(_lv(w, h).aura_radius, cache[towers.type_id[h]][_AURA_RADIUS] + extra[h * _N + _AURA_RADIUS])
		_grid.query_radius(towers.pos_x[h], towers.pos_z[h], r, towers.pos_x, towers.pos_z, _near)
		for o in _near:
			if _ad[o] >= 0.0 or not live(towers, o):  # Hymns never get an aura
				continue
			var b := _aura_of[o]
			# Higher aura_damage, then higher aura_cooldown, then lower uid.
			if b < 0 or _ad[h] > _ad[b] or (_ad[h] == _ad[b] and (_ac[h] > _ac[b] 					or (_ac[h] == _ac[b] and towers.uid[h] < towers.uid[b]))):
				_aura_of[o] = h
	for o in n:
		var h := _aura_of[o]
		if h >= 0:
			_add(o, _DAMAGE, SimModifiers.Op.MULT, _ad[h])
			_add(o, _COOLDOWN, SimModifiers.Op.MULT, -_ac[h])


# Rule 7: each Poppy's live towers in her derived range, herself included.
func _repair_lists(w: SimWorld, cache: Array) -> void:
	var towers := w.towers
	var kind := w.tower_catalog.attack
	for p in towers.count():
		heal_first[p] = heal_list.size()
		if not live(towers, p) or kind[towers.type_id[p]] != TowerCatalog.Attack.REPAIR:
			continue
		var r := TowerStats.value(_lv(w, p).range, cache[towers.type_id[p]][_RANGE] + extra[p * _N + _RANGE])
		_grid.query_radius(towers.pos_x[p], towers.pos_z[p], r, towers.pos_x, towers.pos_z, _near)
		for o in _near:
			if live(towers, o):
				heal_list.append(o)
		heal_count[p] = heal_list.size() - heal_first[p]


func _add(t: int, stat: int, op: int, v: float) -> void:
	extra[t * _N + stat] += Vector2(v, 0.0) if op == SimModifiers.Op.ADD else Vector2(0.0, v)


static func _lv(w: SimWorld, t: int) -> Dictionary:
	return w.tower_catalog.level_stats[w.towers.type_id[t]][w.towers.level[t] - 1]
