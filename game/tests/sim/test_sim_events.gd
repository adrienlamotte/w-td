extends GutTest


func test_push_past_capacity_keeps_every_value() -> void:
	var ev := SimEvents.new()
	var n := ev.kind.size() * 3 + 1
	for i in n:
		ev.push(SimEvents.Kind.ENEMY_HIT, i, i * 0.5, -i, i * 2.0)
	assert_eq(ev.count, n)
	for i in n:
		assert_eq(ev.kind[i], SimEvents.Kind.ENEMY_HIT)
		assert_eq(ev.a[i], i)
		assert_almost_eq(ev.x[i], i * 0.5, 1e-4)
		assert_almost_eq(ev.z[i], float(-i), 1e-4)
		assert_almost_eq(ev.value[i], i * 2.0, 1e-4)


func test_clear_resets_count_keeps_capacity() -> void:
	var ev := SimEvents.new()
	for i in 200:
		ev.push(SimEvents.Kind.ENEMY_DIED, i, 0.0, 0.0, 1.0)
	var cap := ev.kind.size()
	ev.clear()
	assert_eq(ev.count, 0)
	assert_eq(ev.kind.size(), cap)
	assert_eq(ev.value.size(), cap)
