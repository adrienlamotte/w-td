extends GutTest


func test_config_has_three_zooms_and_valid_default() -> void:
	var c := IsoCamera.load_config()
	assert_eq(c.zoom_sizes.size(), 3)
	assert_between(int(c.default_zoom), 0, 2)


func test_clamp_focus() -> void:
	var c := IsoCamera.load_config()
	var max_r: float = c.bounds_radius + c.bounds_margin
	assert_almost_eq(IsoCamera.clamp_focus(Vector2(1000, -500), max_r).length(), max_r, 1e-3)
	assert_eq(IsoCamera.clamp_focus(Vector2(3, -4), max_r), Vector2(3, -4))


func test_step_zoom_clamps() -> void:
	assert_eq(IsoCamera.step_zoom(0, -1, 3), 0)
	assert_eq(IsoCamera.step_zoom(2, 1, 3), 2)
	assert_eq(IsoCamera.step_zoom(1, 1, 3), 2)


func test_edge_dir() -> void:
	var vp := Vector2(2560, 1440)
	assert_eq(IsoCamera.edge_dir(Vector2(5, 720), vp, 24), Vector2(-1, 0))
	assert_eq(IsoCamera.edge_dir(Vector2(1280, 720), vp, 24), Vector2.ZERO)
	assert_eq(IsoCamera.edge_dir(Vector2(2558, 2), vp, 24), Vector2(1, -1))
