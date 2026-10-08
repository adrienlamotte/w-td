extends GutTest


func test_enemy_strip() -> void:
	var img := PlaceholderArt.enemy_strip(PlaceholderArt.type_color(0), 8, 64)
	assert_eq(img.get_size(), Vector2i(8 * 64, 64))
	assert_eq(img.get_pixel(0, 0).a, 0.0, "corner transparent")
	assert_gt(img.get_pixel(32, 40).a, 0.5, "body opaque")
	assert_ne(img.get_region(Rect2i(0, 0, 64, 64)).get_data(),
		img.get_region(Rect2i(64, 0, 64, 64)).get_data(), "frames differ")


func test_tower_image() -> void:
	var img := PlaceholderArt.tower_image(Color.RED, 64)
	assert_eq(img.get_size(), Vector2i(64, 64))
	assert_eq(img.get_pixel(0, 0).a, 0.0)
	assert_false(img.is_invisible())
