class_name FlowGeometry
extends RefCounted
## Static per-cell geometry of a FlowField (D-115), built once per grid.
## Cell (i, j) has its centre at ((2i - S + 1), (2j - S + 1)) * step / 2.

## 1 = goal cell (centre within the goal radius of the Guardian), whatever its solid flag.
var goal: PackedByteArray = PackedByteArray()
## Cells sorted by the integer key (2i - S + 1)^2 + (2j - S + 1)^2, then index.
var order: PackedInt32Array = PackedInt32Array()
## Cell holding centre - step * centre / |centre| (one of the 8 neighbours, always earlier
## in `order`); -1 for goal cells.
var pred: PackedInt32Array = PackedInt32Array()
## When the step to pred is diagonal: the two orthogonal cells it passes (x first, then z);
## -1 otherwise.
var pa: PackedInt32Array = PackedInt32Array()
var pb: PackedInt32Array = PackedInt32Array()


func _init(size: int, step: float, goal_radius: float) -> void:
	var n := size * size
	goal.resize(n)
	order.resize(n)
	pred.resize(n)
	pa.resize(n)
	pb.resize(n)
	pa.fill(-1)
	pb.fill(-1)
	# Counting sort by key, stable in index order.
	var start := PackedInt32Array()
	start.resize(2 * (size - 1) * (size - 1) + 2)
	for c in n:
		start[_key(c, size) + 1] += 1
	for k in range(1, start.size()):
		start[k] += start[k - 1]
	var r2 := goal_radius * goal_radius
	var half := size / 2.0
	for c in n:
		var k := _key(c, size)
		order[start[k]] = c
		start[k] += 1
		var i := c % size
		var j := c / size
		var x := (i - half + 0.5) * step
		var z := (j - half + 0.5) * step
		var d2 := x * x + z * z
		if d2 <= r2:
			goal[c] = 1
			pred[c] = -1
			continue
		var d := sqrt(d2)
		var pi := floori((x - step * x / d) / step + half)
		var pj := floori((z - step * z / d) / step + half)
		pred[c] = pj * size + pi
		if pi != i and pj != j:
			pa[c] = j * size + pi
			pb[c] = pj * size + i


static func _key(c: int, size: int) -> int:
	var a := 2 * (c % size) - size + 1
	var b := 2 * (c / size) - size + 1
	return a * a + b * b
