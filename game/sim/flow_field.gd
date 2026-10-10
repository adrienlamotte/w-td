class_name FlowField
extends RefCounted
## Flow field toward the Guardian over the build grid (D-115), same cells and indexing as
## BuildGrid. Per cell: `dist` octile path cost to the goal, `dir` step toward it, `hit`
## first tower on the straight line to the Guardian, `escape` nearest free cell.
## Recomputed only when BuildGrid.version changes, into working arrays, at most `budget`
## units of work per update(); one computation in flight, a change during it is picked up
## by the next one. Derived from the tower arrays: not in state_hash().

const INF: int = 1 << 30
const NO_DIR: int = 255
## Work units per tick (one cell reset, settled cell, hit cell or escape cell). Placeholder,
## set from the pc_maze_churn release bench so the PATH phase stays under ~1.5 ms per tick.
const CELLS_PER_TICK: int = 4000
## Budget that finishes a computation in one update().
const FULL: int = 1 << 30
## Unit step of dir 0..7: E, W, S, N, SE, SW, NE, NW (E = +x, S = +z).
const DIR_X := [1.0, -1.0, 0.0, 0.0, 0.70710678, -0.70710678, 0.70710678, -0.70710678]
const DIR_Z := [0.0, 0.0, 1.0, -1.0, 0.70710678, 0.70710678, -0.70710678, -0.70710678]

enum Stage { IDLE, CELLS, DIAL, HIT, ESCAPE }

var grid: BuildGrid
var size: int = 0
var step: float = 0.5
## Published arrays, swapped in when a computation ends. INF = solid or unreachable,
## NO_DIR = no step, hit -1 = clear line.
var dist: PackedInt32Array = PackedInt32Array()
var dir: PackedByteArray = PackedByteArray()
var hit: PackedInt32Array = PackedInt32Array()
var escape: PackedInt32Array = PackedInt32Array()
## Completed computations. Diagnostics for tests, not state.
var recomputes: int = 0

var _geo: FlowGeometry
var _dist: PackedInt32Array = PackedInt32Array()
var _dir: PackedByteArray = PackedByteArray()
var _hit: PackedInt32Array = PackedInt32Array()
var _esc: PackedInt32Array = PackedInt32Array()
var _solid: PackedByteArray = PackedByteArray()
var _version: int = -1
var _stage: Stage = Stage.IDLE
var _pos: int = 0
var _cur: int = 0
var _pending: int = 0
## Dial buckets: 4 blocks of n cells (a bucket never holds a cell twice), and their lengths.
var _bq: PackedInt32Array = PackedInt32Array()
var _blen: PackedInt32Array = PackedInt32Array([0, 0, 0, 0])
## Escape BFS queue (free border cells, then solid cells; each at most once).
var _eq: PackedInt32Array = PackedInt32Array()
var _elen: int = 0


func _init(p_grid: BuildGrid, contact_radius: float) -> void:
	grid = p_grid
	size = grid.size
	step = grid.step
	var n := size * size
	dist.resize(n)
	hit.resize(n)
	escape.resize(n)
	_dist.resize(n)
	_hit.resize(n)
	_esc.resize(n)
	_eq.resize(n)
	dir.resize(n)
	_dir.resize(n)
	_bq.resize(4 * n)
	dist.fill(INF)
	dir.fill(NO_DIR)
	hit.fill(-1)
	for c in n:
		escape[c] = c
	_geo = FlowGeometry.new(size, step, maxf(contact_radius, step))


## Starts a computation if the layout changed and none is running, then works on the
## running one for at most `budget` units; swaps the result in when it ends.
func update(budget: int) -> void:
	if _stage == Stage.IDLE:
		if grid.version == _version:
			return
		_start()
	var w := 0
	while w < budget and _stage != Stage.IDLE:
		match _stage:
			Stage.CELLS:
				w += _cells(budget - w)
			Stage.DIAL:
				w += _dial(budget - w)
			Stage.HIT:
				w += _hits(budget - w)
			Stage.ESCAPE:
				w += _escape(budget - w)


## True while a computation is in flight.
func busy() -> bool:
	return _stage != Stage.IDLE


## True when no computation runs and the published arrays match the grid's layout: a field
## rebuilt in full from the grid equals this one (suspend save, D-167).
func settled() -> bool:
	return _stage == Stage.IDLE and _version == grid.version


func _start() -> void:
	_solid = grid.solid.duplicate()
	_version = grid.version
	_dist.fill(INF)
	_dir.fill(NO_DIR)
	_blen.fill(0)
	_pending = 0
	_elen = 0
	_pos = 0
	_cur = 0
	_stage = Stage.CELLS


# Goal cells into bucket 0, escape seeds (free cells with a solid 4-neighbour), index order.
func _cells(budget: int) -> int:
	var s := _solid
	var goal := _geo.goal
	var n := s.size()
	var w := 0
	while _pos < n and w < budget:
		var c := _pos
		_pos += 1
		w += 1
		if s[c]:
			_esc[c] = -1
			continue
		_esc[c] = c
		if goal[c]:
			_dist[c] = 0
			_bq[_blen[0]] = c
			_blen[0] += 1
			_pending += 1
		var i := c % size
		if (i > 0 and s[c - 1]) or (i < size - 1 and s[c + 1]) or (c >= size and s[c - size]) \
				or (c + size < n and s[c + size]):
			_eq[_elen] = c
			_elen += 1
	if _pos == n:
		_stage = Stage.DIAL
		_pos = 0
	return w


# Dial's algorithm, costs 2 (orthogonal) and 3 (diagonal), 4 cyclic buckets, lazy deletion.
# A diagonal step needs both orthogonal cells free (no corner cutting). Neighbours unrolled.
func _dial(budget: int) -> int:
	var s := _solid
	var dd := _dist
	var dr := _dir
	var q := _bq
	var bl := _blen
	var n := s.size()
	var sm1 := size - 1
	var w := 0
	while w < budget:
		var b := _cur & 3
		if _pos >= bl[b]:
			bl[b] = 0
			_pos = 0
			if _pending == 0:
				_stage = Stage.HIT
				return w
			_cur += 1
			continue
		var u := q[b * n + _pos]
		_pos += 1
		_pending -= 1
		w += 1
		if dd[u] != _cur:
			continue
		var i := u % size
		var e := i < sm1 and s[u + 1] == 0
		var wf := i > 0 and s[u - 1] == 0
		var so := u + size < n and s[u + size] == 0
		var no := u >= size and s[u - size] == 0
		var c2 := _cur + 2
		var b2 := c2 & 3
		var o2 := b2 * n
		var c3 := _cur + 3
		var b3 := c3 & 3
		var o3 := b3 * n
		var v := 0
		if e and c2 < dd[u + 1]:
			v = u + 1
			dd[v] = c2; dr[v] = 1; q[o2 + bl[b2]] = v; bl[b2] += 1; _pending += 1
		if wf and c2 < dd[u - 1]:
			v = u - 1
			dd[v] = c2; dr[v] = 0; q[o2 + bl[b2]] = v; bl[b2] += 1; _pending += 1
		if so and c2 < dd[u + size]:
			v = u + size
			dd[v] = c2; dr[v] = 3; q[o2 + bl[b2]] = v; bl[b2] += 1; _pending += 1
		if no and c2 < dd[u - size]:
			v = u - size
			dd[v] = c2; dr[v] = 2; q[o2 + bl[b2]] = v; bl[b2] += 1; _pending += 1
		if e and so and s[u + size + 1] == 0 and c3 < dd[u + size + 1]:
			v = u + size + 1
			dd[v] = c3; dr[v] = 7; q[o3 + bl[b3]] = v; bl[b3] += 1; _pending += 1
		if wf and so and s[u + size - 1] == 0 and c3 < dd[u + size - 1]:
			v = u + size - 1
			dd[v] = c3; dr[v] = 6; q[o3 + bl[b3]] = v; bl[b3] += 1; _pending += 1
		if e and no and s[u - size + 1] == 0 and c3 < dd[u - size + 1]:
			v = u - size + 1
			dd[v] = c3; dr[v] = 5; q[o3 + bl[b3]] = v; bl[b3] += 1; _pending += 1
		if wf and no and s[u - size - 1] == 0 and c3 < dd[u - size - 1]:
			v = u - size - 1
			dd[v] = c3; dr[v] = 4; q[o3 + bl[b3]] = v; bl[b3] += 1; _pending += 1
	return w


# First solid cell on the line to the Guardian, cells by distance (pred is always earlier).
func _hits(budget: int) -> int:
	var s := _solid
	var h := _hit
	var order := _geo.order
	var pred := _geo.pred
	var pa := _geo.pa
	var pb := _geo.pb
	var n := s.size()
	var w := 0
	while _pos < n and w < budget:
		var c := order[_pos]
		_pos += 1
		w += 1
		var p := pred[c]
		if s[c]:
			h[c] = c
		elif p < 0:
			h[c] = -1
		elif pa[c] >= 0 and s[pa[c]]:
			h[c] = pa[c]
		elif pa[c] >= 0 and s[pb[c]]:
			h[c] = pb[c]
		else:
			h[c] = h[p]
	if _pos == n:
		_stage = Stage.ESCAPE
		_pos = 0
	return w


# 4-neighbour BFS from the free border cells into the solid ones: nearest free cell.
func _escape(budget: int) -> int:
	var s := _solid
	var es := _esc
	var q := _eq
	var n := s.size()
	var w := 0
	while _pos < _elen and w < budget:
		var u := q[_pos]
		_pos += 1
		w += 1
		var e := es[u]
		var i := u % size
		if i < size - 1 and s[u + 1] and es[u + 1] == -1:
			es[u + 1] = e; q[_elen] = u + 1; _elen += 1
		if i > 0 and s[u - 1] and es[u - 1] == -1:
			es[u - 1] = e; q[_elen] = u - 1; _elen += 1
		if u + size < n and s[u + size] and es[u + size] == -1:
			es[u + size] = e; q[_elen] = u + size; _elen += 1
		if u >= size and s[u - size] and es[u - size] == -1:
			es[u - size] = e; q[_elen] = u - size; _elen += 1
	if _pos == _elen:
		_swap()
	return w


func _swap() -> void:
	var t32 := dist
	dist = _dist
	_dist = t32
	var t8 := dir
	dir = _dir
	_dir = t8
	t32 = hit
	hit = _hit
	_hit = t32
	t32 = escape
	escape = _esc
	_esc = t32
	_stage = Stage.IDLE
	recomputes += 1
