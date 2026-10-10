class_name Hub
extends CanvasLayer
## Hub between runs (D-154 rules 2-4, 7): hearts, the Guardian offer, the meta tree, the
## roster. Every number comes from MetaProfile (D-121); the buttons are rebuilt only on
## open and after a buy, never per frame.

signal back_pressed

const STATE_KEYS := {MetaProfile.Roster.STARTER: "hub.roster.starter",
	MetaProfile.Roster.RESCUED: "hub.roster.rescued", MetaProfile.Roster.LOCKED: "hub.roster.locked"}

var world: SimWorld
var cat: MetaCatalog = MetaCatalog.load_dir()
var profile: MetaProfile

@onready var _hearts: Label = $Panel/Box/Hearts
@onready var _offer: HBoxContainer = $Panel/Box/Offer
@onready var _tree: HBoxContainer = $Panel/Box/Tree
@onready var _notice: Panel = $Notice
@onready var _ok: Button = $Notice/Box/OK


func _ready() -> void:
	visible = false
	$Panel/Box/Back.pressed.connect(back_pressed.emit)
	_ok.pressed.connect(close_notice)


func setup(w: SimWorld) -> void:
	world = w


## Loads the profile and shows the hub; the bad-profile notice first if the load hit one (D-161).
func open() -> void:
	profile = ProfileStore.load_profile(cat, RunFlow.save_dir)
	_rebuild("")
	visible = true
	_notice.visible = ProfileStore.last_error != ""
	if _notice.visible:
		_ok.grab_focus()
	else:
		(_offer.get_child(0) as Button).grab_focus()


func close_notice() -> void:
	ProfileStore.last_error = ""
	_notice.visible = false
	(_offer.get_child(0) as Button).grab_focus()


func rescue(waifu: String) -> void:
	if RunFlow.start_rescue(world, profile, cat, waifu):
		visible = false


func buy(id: String) -> void:
	if profile.buy(cat, id) != MetaProfile.Buy.OK:
		return
	ProfileStore.save_profile(profile, RunFlow.save_dir)
	_rebuild(id)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _notice.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


# `focus_id`: the node button to focus after a buy rebuilt the tree ("" = none).
func _rebuild(focus_id: String) -> void:
	_hearts.text = tr("hub.hearts").format({"n": profile.hearts})
	_clear(_offer)
	for w in profile.offer(cat):
		var text := tr("hub.rescue").format({"name": tr(cat.waifu_name_key[w])})
		var best: int = profile.best_sec.get(cat.guardian_of[w], 0)
		if best > 0:
			text += "\n" + tr("hub.best").format({"time": Hud.mmss(best)})
		var b := _button(_offer, w, text)
		b.pressed.connect(rescue.bind(w))
	_clear(_tree)
	var branches: Array = cat.branch.values()
	branches.sort()
	for br: String in branches:
		if _tree.has_node(br):
			continue
		_column(br, "hub.branch." + br)
	for id in cat.ids:  # sorted ids: nodes in id order
		var b := _button(_tree.get_node(cat.branch[id]), id, _node_text(id))
		b.modulate.a = 1.0 if profile.check_buy(cat, id) in [MetaProfile.Buy.OK, MetaProfile.Buy.OWNED] else 0.5
		b.pressed.connect(buy.bind(id))
		if id == focus_id:
			b.grab_focus.call_deferred()
	var roster := _column("Roster", "hub.roster")
	for w: String in Array(cat.starters) + Array(cat.offer_order):
		var l := Label.new()
		l.name = w
		l.text = "%s: %s" % [tr(cat.waifu_name_key[w]), tr(STATE_KEYS[profile.roster_state(cat, w)])]
		roster.add_child(l)


func _node_text(id: String) -> String:
	var state := ""
	match profile.check_buy(cat, id):
		MetaProfile.Buy.OWNED:
			state = tr("hub.node.owned")
		MetaProfile.Buy.LOCKED:
			var names := PackedStringArray()
			for r: String in cat.requires[id]:
				if not profile.meta_nodes.has(r):
					names.append(tr(cat.name_key[r]))
			state = tr("hub.node.locked").format({"name": ", ".join(names)})
		_:
			state = tr("hub.node.cost").format({"cost": cat.cost[id]})
	return "%s\n%s\n%s" % [tr(cat.name_key[id]), tr(cat.desc_key[id]), state]


func _column(node_name: String, title_key: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.name = node_name
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = title_key
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	_tree.add_child(col)
	return col


func _button(parent: Node, node_name: String, text: String) -> Button:
	var b := Button.new()
	b.name = node_name
	b.text = text
	b.focus_mode = Control.FOCUS_ALL  # every state stays focusable: the gamepad never skips one
	parent.add_child(b)
	return b


# Remove first so the new nodes can take the same names this frame.
func _clear(box: Node) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()
