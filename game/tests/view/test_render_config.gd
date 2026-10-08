extends GutTest
## Sprite heights on screen at 2560x1440 and the default zoom (03_ART_PIPELINE.md 3, D-087).
## An orthographic Camera3D keeps height: 1 world unit = 1440 / size px.


func _px(height_key: String) -> float:
	var render: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HordeRenderer.CONFIG_PATH))
	var cam := IsoCamera.load_config()
	return float(render[height_key]) * 1440.0 / float(cam.zoom_sizes[cam.default_zoom])


func test_enemy_height_on_screen() -> void:
	assert_between(_px("enemy_sprite_height"), 85.0, 130.0)


func test_tower_height_on_screen() -> void:
	assert_between(_px("tower_sprite_height"), 215.0, 265.0)
