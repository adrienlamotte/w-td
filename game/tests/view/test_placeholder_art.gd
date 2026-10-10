extends GutTest

const ENEMY_SHAPES := ["blob", "brute", "ranged", "crown"]
const TOWER_SHAPES := ["single", "splash", "slow", "husk", "bare", "wall", "aura", "repair", "mark", "slow_area"]


func test_enemy_strip() -> void:
	var img := PlaceholderArt.enemy_strip(Color.GREEN, 8, 64)
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


func test_shapes_are_visible_and_differ() -> void:
	var seen := {}
	for shape: String in ENEMY_SHAPES:
		var img := PlaceholderArt.enemy_strip(Color.GREEN, 2, 64, shape)
		assert_false(img.is_invisible(), shape)
		seen[img.get_data()] = true
	for shape: String in TOWER_SHAPES:
		var img := PlaceholderArt.tower_image(Color.GREEN, 64, shape)
		assert_false(img.is_invisible(), shape)
		seen[img.get_data()] = true
	assert_eq(seen.size(), ENEMY_SHAPES.size() + TOWER_SHAPES.size(), "every shape differs")
