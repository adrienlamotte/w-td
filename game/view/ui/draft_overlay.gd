class_name DraftOverlay
extends CanvasLayer
## Level-up draft (D-153, 10_M3_CONTENT.md 1): shown while a draft is open and not paused,
## one button per slot of world.draft.draft. A pick queues PICK_CARD once; the buttons stay
## disabled until the next draft (told apart by the picks taken). No skip, no cancel.

var world: SimWorld
# Picks taken when the shown draft opened; -1 = none shown yet.
var _shown: int = -1
var _picked: bool = false

@onready var _title: Label = $Panel/Box/Title
@onready var _cards: Array[Node] = $Panel/Box/Cards.get_children()


func _ready() -> void:
	visible = false
	for s in _cards.size():
		(_cards[s] as Button).pressed.connect(pick.bind(s))


func setup(w: SimWorld) -> void:
	world = w
	_shown = -1
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var show := PlayerInput.in_draft(world)
	var fresh := show and not visible
	visible = show
	if not show:
		return
	var taken := 0
	for n in world.draft.picks:
		taken += n
	if taken != _shown:
		_shown = taken
		_fill()
		fresh = true
	if fresh:
		(_cards[0] as Button).grab_focus()


func pick(slot: int) -> void:
	if _picked or not PlayerInput.in_draft(world):
		return
	_picked = true
	world.queue(SimCommand.pick_card(world.tick, slot))
	for b: Button in _cards:
		b.disabled = true


func _fill() -> void:
	var d := world.draft
	var cat := world.cards
	_picked = false
	_title.text = tr("draft.title").format({"level": d.level - d.pending + 1})
	for s in _cards.size():
		var b: Button = _cards[s]
		b.disabled = false
		var c := d.draft[s]
		b.text = "%s\n%s\n\n%s" % [tr(cat.name_key[c]),
				tr("draft.type." + CardCatalog.TYPE_NAMES[cat.type[c]]), tr(cat.desc_key[c])]
