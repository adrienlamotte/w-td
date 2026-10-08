class_name BenchStats
extends RefCounted
## Frame-time summary for the perf benchmark (task 008, D-088). No Node, testable headless.


## frame_usec: one wall-clock frame time per frame, in usec. Needs at least one frame.
## low1_fps = 1e6 / mean of the slowest 1% of frames (at least one frame).
static func summarize(frame_usec: PackedInt64Array) -> Dictionary:
	var sorted := frame_usec.duplicate()
	sorted.sort()
	var n := sorted.size()
	var total := 0
	for f in sorted:
		total += f
	var n_low := maxi(1, n / 100)
	var low := 0
	for i in range(n - n_low, n):
		low += sorted[i]
	return {
		"frames": n,
		"avg_fps": n * 1e6 / total,
		"low1_fps": n_low * 1e6 / low,
		"frame_ms_avg": total / 1000.0 / n,
		"frame_ms_p99": sorted[ceili(0.99 * n) - 1] / 1000.0,
		"frame_ms_max": sorted[n - 1] / 1000.0,
	}
