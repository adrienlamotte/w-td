extends GutTest


func test_summary_of_one_slow_frame_in_a_hundred() -> void:
	var f := PackedInt64Array()
	for i in 99:
		f.append(10000)
	f.append(50000)
	var s := BenchStats.summarize(f)
	assert_eq(s.frames, 100)
	assert_almost_eq(s.frame_ms_avg, 10.4, 1e-6)
	assert_almost_eq(s.avg_fps, 100.0 / 1.04, 1e-3)
	assert_almost_eq(s.low1_fps, 20.0, 1e-6)
	assert_almost_eq(s.frame_ms_p99, 10.0, 1e-6)
	assert_almost_eq(s.frame_ms_max, 50.0, 1e-6)


func test_single_frame() -> void:
	var s := BenchStats.summarize(PackedInt64Array([20000]))
	assert_eq(s.frames, 1)
	assert_almost_eq(s.low1_fps, 50.0, 1e-6)
	assert_almost_eq(s.frame_ms_p99, 20.0, 1e-6)
