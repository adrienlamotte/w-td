extends GutTest
## Hub (D-154 rules 2-4, 7): offer, meta tree buy, roster, bad-profile notice.

const HUB := preload("res://view/ui/hub.tscn")
const DIR := "user://test_hub/"

var world: SimWorld
var hub: Hub
var cat: MetaCatalog = MetaCatalog.load_dir()


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	RunFlow.save_dir = DIR
	world = SimWorld.new(1)
	hub = HUB.instantiate()
	add_child_autofree(hub)
	hub.setup(world)


func after_each() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)
	RunFlow.save_dir = "user://"
	ProfileStore.last_error = ""


func _save(unlocked: Array, hearts: int, nodes: Array = []) -> void:
	var p := MetaProfile.fresh(cat)
	p.unlocked = PackedStringArray(unlocked)
	p.hearts = hearts
	p.meta_nodes = PackedStringArray(nodes)
	ProfileStore.save_profile(p, DIR)


func _offer_names() -> Array:
	return hub.get_node("Panel/Box/Offer").get_children().map(func(c: Node) -> String: return c.name)


func _node(id: String) -> Button:
	return hub.get_node("Panel/Box/Tree/%s/%s" % [cat.branch[id], id])


func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(DIR + ProfileStore.FILE)


func test_offer_matches_the_rule() -> void:
	hub.open()
	assert_eq(_offer_names(), ["waifu_cinder", "waifu_bastia", "waifu_clover"])
	assert_true(hub.get_node("Panel/Box/Offer/waifu_cinder").has_focus(), "first rescue focused")
	_save(["waifu_cinder"], 0)
	hub.open()
	assert_eq(_offer_names(), ["waifu_bastia", "waifu_clover", "waifu_hymn"])
	_save(Array(cat.offer_order), 0)
	hub.open()
	assert_eq(_offer_names(), Array(cat.offer_order), "all 6 rescued: all 6 offered (Q-68)")


func test_rescue_starts_run_m3_with_the_profile() -> void:
	_save([], 0, ["meta_gold_1"])
	hub.open()
	(hub.get_node("Panel/Box/Offer/waifu_bastia") as Button).pressed.emit()
	assert_false(hub.visible)
	world.step()
	assert_eq(world.run.id, "run_m3")
	assert_eq(world.run.guardian_id, "guardian_bastia")
	assert_eq(world.gold, 250, "meta_gold_1 applied")


func test_buy_saves_and_refreshes() -> void:
	_save([], 60)
	hub.open()
	assert_string_contains(_node("meta_gold_1").text, tr("hub.node.cost").format({"cost": 60}))
	_node("meta_gold_1").pressed.emit()
	var p := ProfileStore.load_profile(cat, DIR)
	assert_eq(p.hearts, 0)
	assert_eq(p.meta_nodes, PackedStringArray(["meta_gold_1"]))
	assert_string_contains(_node("meta_gold_1").text, tr("hub.node.owned"))
	assert_string_contains((hub.get_node("Panel/Box/Hearts") as Label).text, "0")


func test_refused_buys_change_nothing() -> void:
	_save([], 100)
	hub.open()
	var before := _bytes()
	assert_string_contains(_node("meta_gold_2").text,
			tr("hub.node.locked").format({"name": tr("meta.gold_1.name")}))
	_node("meta_gold_2").pressed.emit()
	assert_eq(_bytes(), before, "LOCKED")
	_save([], 10)
	before = _bytes()
	hub.open()
	_node("meta_gold_1").pressed.emit()
	assert_eq(_bytes(), before, "NO_HEARTS")
	assert_eq(_node("meta_gold_1").focus_mode, Control.FOCUS_ALL, "still focusable")


func test_roster() -> void:
	_save(["waifu_cinder"], 0)
	hub.open()
	var roster := hub.get_node("Panel/Box/Tree/Roster")
	assert_string_contains((roster.get_node("waifu_pip") as Label).text, tr("hub.roster.starter"))
	assert_string_contains((roster.get_node("waifu_cinder") as Label).text, tr("hub.roster.rescued"))
	assert_string_contains((roster.get_node("waifu_bastia") as Label).text, tr("hub.roster.locked"))
	assert_eq(hub.get_node("Panel/Box/Tree").get_child_count(), 4, "3 branches + roster")


func test_bad_profile_notice() -> void:
	var f := FileAccess.open(DIR + ProfileStore.FILE, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	hub.open()
	var notice: Panel = hub.get_node("Notice")
	assert_true(notice.visible)
	assert_true(hub.get_node("Notice/Box/OK").has_focus())
	(hub.get_node("Notice/Box/OK") as Button).pressed.emit()
	assert_false(notice.visible)
	assert_eq(ProfileStore.last_error, "")
	assert_true(FileAccess.file_exists(DIR + ProfileStore.BAD))


func test_back_and_keys() -> void:
	watch_signals(hub)
	hub.open()
	(hub.get_node("Panel/Box/Back") as Button).pressed.emit()
	assert_signal_emitted(hub, "back_pressed")
	for c: Control in hub.find_children("*", "Control", true, false):
		if c is Label or c is Button:
			assert_gte(c.get_theme_font_size("font_size"), 32, "%s font size" % c.name)
	for k: String in ["hub.title", "hub.hearts", "hub.rescue", "hub.best", "hub.back", "hub.branch.economy",
			"hub.branch.guardian", "hub.branch.towers", "hub.node.cost", "hub.node.locked", "hub.node.owned",
			"hub.roster", "hub.roster.starter", "hub.roster.rescued", "hub.roster.locked",
			"hub.notice.bad_profile", "hub.notice.ok"]:
		assert_ne(tr(k), k, k)
