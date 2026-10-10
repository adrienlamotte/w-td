class_name PlayerInput
extends Node
## The only code that reads devices (D-119, docs/09_CONTROLS.md). Turns InputMap actions
## into camera intents on IsoCamera and SimCommands through world.queue(); never changes
## sim state directly. Bindings live in the InputMap (project.godot).

## Emitted when the gamepad radial menu closes; 020 picks the slice from dir.
signal build_menu_closed(dir: Vector2)

## Joypad axis travel that switches to gamepad mode (same as the action deadzones).
const DEADZONE: float = 0.2

var world: SimWorld
var camera: IsoCamera
## Last device used: true = gamepad (cursor at screen centre), false = mouse.
var gamepad: bool = false
## Ground point (x, z) the building actions aim at.
var cursor: Vector2 = Vector2.ZERO
## data/towers id to place, "" = none.
var selected_tower: String = ""
var menu_open: bool = false
var menu_dir: Vector2 = Vector2.ZERO
# Trigger actions held, so an analog trigger fires once per pull, not per motion event.
var _held: Dictionary = {}


## Ground point (x, z) where a ray hits y = 0.
static func ground_point(origin: Vector3, dir: Vector3) -> Vector2:
	if is_zero_approx(dir.y):
		return Vector2(origin.x, origin.z)
	var p := origin + dir * (-origin.y / dir.y)
	return Vector2(p.x, p.z)


## Uid of the tower (live or husk) owning the build cell at p, -1 if none.
static func tower_uid_at(w: SimWorld, p: Vector2) -> int:
	if w.build == null:
		return -1
	var b := w.build
	var i := b.first_cell(p.x, 1)
	var j := b.first_cell(p.y, 1)
	if i < 0 or j < 0 or i >= b.size or j >= b.size:
		return -1
	return b.owner[j * b.size + i]


## Pan direction from the mouse near a viewport edge, in screen axes (x right, y down).
static func edge_dir(mouse: Vector2, viewport: Vector2, margin: float) -> Vector2:
	var d := Vector2.ZERO
	if mouse.x < margin: d.x = -1.0
	elif mouse.x > viewport.x - margin: d.x = 1.0
	if mouse.y < margin: d.y = -1.0
	elif mouse.y > viewport.y - margin: d.y = 1.0
	return d


func select_tower(id: String) -> void:
	selected_tower = id


func is_placing() -> bool:
	return selected_tower != "" or menu_open


## Queues Pause(on); pausing also drops the selection so nothing is half-placed (D-125).
func set_paused(on: bool) -> void:
	world.queue(SimCommand.pause(world.tick, on))
	if on:
		_cancel_build()


func _cancel_build() -> void:
	selected_tower = ""
	menu_open = false


func _unhandled_input(event: InputEvent) -> void:
	handle(event)


func handle(event: InputEvent) -> void:
	_update_mode(event)
	if in_draft(world):  # only pause passes; the draft overlay takes the rest (D-153)
		menu_open = false
		if _pressed(event, &"pause"):
			set_paused(true)
		return
	if menu_open and event.is_action_released(&"build_menu"):
		menu_open = false
		build_menu_closed.emit(menu_dir)
	if _pressed(event, &"cam_zoom_in"):
		camera.zoom_step(-1)
	elif _pressed(event, &"cam_zoom_out"):
		camera.zoom_step(1)
	elif _pressed(event, &"cam_recentre"):
		camera.recentre()
	elif _pressed(event, &"build_cancel") and is_placing():
		_cancel_build()
	elif _pressed(event, &"pause"):
		if world.run_state == SimWorld.RunState.RUNNING:
			set_paused(not world.paused)
	elif _pressed(event, &"skill_1"):
		_use_skill(0)
	elif _pressed(event, &"skill_2"):
		_use_skill(1)
	elif can_build(world):
		_build(event)


func _build(event: InputEvent) -> void:
	for slot in 8:
		if _pressed(event, StringName("build_slot_%d" % (slot + 1))):
			if slot < world.tower_types.size():
				selected_tower = world.tower_catalog.ids[world.tower_types[slot]]
			return
	if _pressed(event, &"build_menu"):
		menu_open = true
	elif _pressed(event, &"build_place"):
		var uid := tower_uid_at(world, cursor)
		var t := world.towers.uid.find(uid) if uid >= 0 else -1
		if t >= 0 and world.towers.husk[t]:
			world.queue(SimCommand.rebuild_tower(world.tick, uid))
		elif selected_tower != "":
			world.queue(SimCommand.place_tower(world.tick, selected_tower, cursor.x, cursor.y))
	elif _pressed(event, &"tower_sell"):
		var uid := tower_uid_at(world, cursor)
		if uid >= 0:
			world.queue(SimCommand.sell_tower(world.tick, uid))
	elif _pressed(event, &"tower_upgrade"):
		var uid := tower_uid_at(world, cursor)
		if uid >= 0:  # the sim refuses a husk, max level, locked or no gold (D-151)
			world.queue(SimCommand.upgrade_tower(world.tick, uid))


func _process(delta: float) -> void:
	if in_draft(world):
		return
	var dir := Input.get_vector(&"cam_pan_left", &"cam_pan_right", &"cam_pan_up", &"cam_pan_down")
	var stick := Input.get_vector(&"menu_left", &"menu_right", &"menu_up", &"menu_down")
	if menu_open:
		menu_dir = stick
	else:
		dir += stick
	if not gamepad:
		var vp := get_viewport()
		var mouse := vp.get_mouse_position()
		var size := vp.get_visible_rect().size
		if get_window().has_focus() and Rect2(Vector2.ZERO, size).has_point(mouse):
			dir += edge_dir(mouse, size, camera.config.edge_scroll_px)
	camera.pan(dir, delta)
	_update_cursor()


func _update_cursor() -> void:
	if gamepad:
		cursor = camera.focus()
		return
	var cam: Camera3D = camera.get_node("Camera3D")
	var mouse := get_viewport().get_mouse_position()
	cursor = ground_point(cam.project_ray_origin(mouse), cam.project_ray_normal(mouse))


# Keys do not switch the mode.
func _update_mode(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		gamepad = false
	elif event is InputEventJoypadButton or \
			(event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > DEADZONE):
		gamepad = true
		cursor = camera.focus()


## Building is possible: a run is RUNNING, not paused (D-105) and no card draft is open (D-147). The build UI uses it too.
static func can_build(w: SimWorld) -> bool:
	return w != null and w.run_state == SimWorld.RunState.RUNNING and not w.paused and not w.draft.drafting


## A card draft is open on screen: RUNNING, not paused, drafting (D-153).
static func in_draft(w: SimWorld) -> bool:
	return w != null and w.run_state == SimWorld.RunState.RUNNING and not w.paused and w.draft.drafting


func _use_skill(slot: int) -> void:
	if world.run != null and slot < world.run.skill_ids.size():
		world.queue(SimCommand.use_skill(world.tick, world.run.skill_ids[slot]))


# Press edge of an action; an analog axis counts once until it falls back under its deadzone.
func _pressed(event: InputEvent, action: StringName) -> bool:
	if not event is InputEventJoypadMotion:
		return event.is_action_pressed(action)
	if not event.is_action(action):
		return false
	var was: bool = _held.get(action, false)
	_held[action] = event.is_action_pressed(action)
	return _held[action] and not was
