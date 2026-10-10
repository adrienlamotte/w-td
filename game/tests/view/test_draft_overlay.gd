extends GutTest
## Draft overlay (D-153): shows the sim's cards, a pick queues one PICK_CARD, focus, pause.

const SCENE := preload("res://view/ui/draft_overlay.tscn")

var world: SimWorld
var overlay: DraftOverlay


func before_each() -> void:
	world = SimWorld.new(1)
	world.queue(SimCommand.start_run(0, 7, "run_m3"))
	world.step()
	world.run.first_wave_tick = 1 << 30  # no spawns
	overlay = SCENE.instantiate()
	add_child_autofree(overlay)
	overlay.setup(world)


func _button(s: int) -> Button:
	return overlay.get_node("Panel/Box/Cards").get_child(s)


func _level_up(xp: float) -> void:
	world.draft.xp = xp
	world.step()
	overlay.refresh()


func _step() -> void:
	world.step()
	overlay.refresh()


func test_hidden_without_draft() -> void:
	assert_false(overlay.visible)
	overlay.setup(null)
	assert_false(overlay.visible)


func test_shows_the_sim_cards() -> void:
	_level_up(30.0)
	assert_true(overlay.visible)
	var d := world.draft
	var cat := world.cards
	for s in CardDraft.SLOTS:
		var t := _button(s).text
		var c := d.draft[s]
		assert_string_contains(t, tr(cat.name_key[c]))
		assert_string_contains(t, tr("draft.type." + CardCatalog.TYPE_NAMES[cat.type[c]]))
		assert_string_contains(t, tr(cat.desc_key[c]))
		assert_ne(tr(cat.name_key[c]), cat.name_key[c], "translated")
	assert_eq((overlay.get_node("Panel/Box/Title") as Label).text, "Level 2!")
	assert_true(_button(0).has_focus())


func test_pick_queues_once() -> void:
	_level_up(30.0)
	var c := world.draft.draft[2]
	_button(2).pressed.emit()
	_button(1).pressed.emit()
	assert_eq(world._queue.size(), 1)
	assert_eq(world._queue[0].type, SimCommand.Type.PICK_CARD)
	assert_eq(world._queue[0].slot, 2)
	assert_true(_button(0).disabled)
	_step()
	assert_eq(world.draft.picks[c], 1, "the next step picks draft[2]")
	assert_false(overlay.visible)


func test_next_draft_refreshes_and_refocuses() -> void:
	_level_up(90.0)  # levels 2 and 3
	assert_eq(world.draft.pending, 2)
	_button(1).grab_focus()
	_button(0).pressed.emit()
	_step()
	assert_true(overlay.visible, "the second draft")
	assert_false(_button(0).disabled)
	assert_true(_button(0).has_focus())
	assert_eq((overlay.get_node("Panel/Box/Title") as Label).text, "Level 3!")
	_button(1).pressed.emit()
	assert_eq(world._queue.size(), 1)
	assert_eq(world._queue[0].slot, 1)


func test_hidden_while_paused() -> void:
	_level_up(30.0)
	world.queue(SimCommand.pause(world.tick, true))
	_step()
	assert_false(overlay.visible)
	_button(0).pressed.emit()
	assert_eq(world._queue.size(), 0, "no pick while paused")
	world.queue(SimCommand.pause(world.tick, false))
	_step()
	assert_true(overlay.visible)
	assert_true(_button(0).has_focus())


func test_readable() -> void:
	_level_up(30.0)
	for c: Control in overlay.find_children("*", "Control", true, false):
		if c is Label or c is Button:
			assert_gte(c.get_theme_font_size("font_size"), 32, "%s font size" % c.name)
