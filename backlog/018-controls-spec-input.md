# 018 — Controls spec and input layer (mouse and gamepad)
- Status: review
- Milestone: M2
- Depends on: 012
- PR: #24

## Goal
Write the controls spec and map keyboard, mouse and gamepad to sim commands and camera actions. Gamepad is first-class.

## Context
- D-041 (camera, gamepad: right stick pan, bumpers zoom, button recentre), D-046 (gamepad building: hold for radial menu, centre cursor, A place, B cancel, skills on triggers, slow-time option)
- `01_GAME_DESIGN.md` 9: no feature may need the mouse only

## Acceptance criteria
- `docs/09_CONTROLS.md`: full mapping for keyboard/mouse and gamepad, marked PROPOSED for the owner to approve at CP-M2.
- `game/input/` maps devices to commands; the view and sim never read devices directly.
- Gamepad camera controls added; centre-of-screen placement cursor for gamepad.
- Tests for the mapping layer where possible headless.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-119** (PROPOSED: bindings home and the input layer contract). The mapping itself is the controls spec, PROPOSED for CP-M2 (M2.md human gate). No data or schema change; no sim change (`USE_SKILL` already exists, 017 makes it act).

### Where the bindings live (D-119)
Default bindings stay in Godot's **InputMap in `project.godot`**, where `cam_pan_*` / `cam_zoom_*` already are; no JSON bindings file. Why:
- Rule 4 is about game content (waifus, enemies, towers, cards...). Bindings are engine/player configuration; `project.godot` is already a diffable text data file.
- InputMap natively handles keys, mouse buttons, joypad buttons and axes, per-action deadzones and `is_action_*` / `get_vector`; a JSON file would need a loader, a schema and a re-implementation of all that.
- Later runtime rebinding (not M2) edits InputMap through its API and saves the overrides to the user settings; Steam Input (GodotSteam, later) maps the Deck onto the same actions.
- The spec (`docs/09_CONTROLS.md`) lists every action; a headless test checks every project action has a keyboard/mouse **and** a gamepad binding (except the listed device-specific ones), which enforces "no mouse-only feature".
Tunables stay in data: pan speed, edge-scroll margin in `data/camera` (unchanged); stick deadzone in the action (0.2, placeholder).

### Input layer contract (D-119)
`game/input/player_input.gd` is the only code that reads devices (`Input`, `InputEvent`). The view (`IsoCamera`, 020's HUD) gets intents or reads its state; the sim gets `SimCommand`s through `world.queue()`. It never changes sim state directly.

### Mapping (the content of `docs/09_CONTROLS.md`, PROPOSED; Xbox layout = Steam Deck A/B/X/Y positions)
| Action (InputMap) | Keyboard / mouse | Gamepad | Effect |
|---|---|---|---|
| `cam_pan_up/down/left/right` | W/S/A/D, arrows; edge scroll (mouse mode only) | right stick | pan (D-041) |
| `menu_up/down/left/right` | - | left stick | radial slice direction while `build_menu` is held; otherwise pans like the right stick |
| `cam_zoom_in` / `cam_zoom_out` | wheel up / down | RB / LB | zoom step (D-041) |
| `cam_recentre` | Space | R3 (right stick click) | focus back on the Guardian (D-041) |
| `build_menu` | - (mouse/keyboard use 020's build bar and the slot keys) | Y, hold | radial menu open while held; release selects (D-046) |
| `build_slot_1..3` | 1 / 2 / 3 | - (radial) | select `run.tower_types[i]` |
| `build_place` | left click | A | on a husk: RebuildTower; on a free spot with a tower selected: PlaceTower at the cursor; the selection stays (place several) |
| `build_cancel` | right click; Esc while something is selected | B | clear selection / close menu (D-046) |
| `tower_sell` | X (tower under the mouse) | X (tower under the cursor) | SellTower (live or husk) |
| `skill_1` / `skill_2` | Q / E | LT / RT | UseSkill(`run.skill_ids[i]`) (D-046) |
| `pause` | Esc (nothing selected), P | Start (Menu) | Pause toggle; 021 adds the pause menu on top |
Cursor: mouse mode = ground point under the mouse; gamepad mode = screen centre = the camera focus (the rig sits at its focus on the ground, D-041). The mode follows the last device used (mouse motion/button -> mouse; joypad button or axis past the deadzone -> gamepad); keys do not switch it. Edge scroll only in mouse mode. Snapping and the placement ghost are 020 (the sim snaps anyway). The radial slice from a direction is 020. The slow-time-while-placing option (D-046) is 021; it reads `is_placing()`.

### Rules in `PlayerInput`
- Building actions (`build_menu`, `build_slot_*`, `build_place`, `tower_sell`) are dropped unless `world.run_state == RUNNING` and not `world.paused` (D-105; the sim also rejects them, this keeps the menu from opening and no useless command is queued). Camera, `skill_*` (sim gates, 017) and `pause` always pass.
- Esc priority: if something is selected or the menu is open, `build_cancel` handles it and `pause` does not fire.
- Every command is `SimCommand.<type>(world.tick, ...)` then `world.queue()`; pause toggles `not world.paused`.

### Files
1. `input` (new) `game/input/player_input.gd`, `class_name PlayerInput extends Node`, about 130 lines:
   - `world: SimWorld`, `camera: IsoCamera` (set by `game_view.gd`); state: `gamepad: bool`, `cursor: Vector2` (ground x, z), `selected_tower: String` ("" = none), `menu_open: bool`, `menu_dir: Vector2`; `signal build_menu_closed(dir: Vector2)` for 020; `select_tower(id)` (020's menus call it), `is_placing() -> bool`.
   - `_unhandled_input(event)` -> `handle(event)` (public so tests feed real `InputEventKey` / `InputEventMouseButton` / `InputEventJoypadButton` / `InputEventJoypadMotion` through the real InputMap).
   - `_process(delta)`: pan vector (`cam_pan_*` + `menu_*` when the menu is closed + edge scroll in mouse mode) -> `camera.pan(dir, delta)`; `menu_dir` while open; cursor update.
   - statics moved/added: `edge_dir()` (moved from `IsoCamera`), `ground_point(origin: Vector3, dir: Vector3) -> Vector2` (ray to y = 0); `tower_uid_at(world, p: Vector2) -> int` via `BuildGrid.first_cell(v, 1)` and `owner` (-1 outside the grid or with no run).
2. `view` `game/view/iso_camera.gd`: no more device reads. `_process` body becomes `pan(dir: Vector2, delta: float)`; `_unhandled_input` becomes `zoom_step(dir: int)`; add `recentre()` (instant, position 0) and `focus() -> Vector2`. `edge_dir` leaves. About net 0 lines.
3. `view` `game/view/main.tscn` + `game/view/game_view.gd`: add a `PlayerInput` node and wire `world`, `camera` in `_ready`. +6 lines.
4. `view` `game/view/bench/bench.gd`: disable the `PlayerInput` node (`process_mode = DISABLED`) instead of the rig's process/input (the rig no longer reads input). 2 lines.
5. config `game/project.godot`: the new actions (deadzone 0.2), joypad events added to `cam_pan_*` (right stick) and `cam_zoom_*` (bumpers). About 80 config lines (not code).
6. Tests `game/tests/view/test_iso_camera.gd`: `edge_dir` test moves to the new input test file.

### Tests (`game/tests/input/test_player_input.gd`; a `SimWorld` with StartRun `run_m2`, an `IsoCamera` built with its `Camera3D` child, both added with `add_child_autofree`)
- Bindings: every non-`ui_*` InputMap action has at least one keyboard/mouse event and one joypad event, except the explicit lists `PAD_ONLY = menu_*, build_menu` and `KEY_ONLY = build_slot_*` (each with the alternative named in a comment); the expected action names are a const list in the test, kept equal to the spec's table.
- Gamepad, RUNNING: joypad A with `selected_tower` set -> one queued PLACE_TOWER at `camera.focus()`; joypad A on a husk's cell -> REBUILD_TOWER with its uid; X on a tower -> SELL_TOWER; LT / RT -> USE_SKILL with `run.skill_ids[0]` / `[1]`; Start -> PAUSE(true), again -> PAUSE(false) after a step; B clears the selection and queues nothing; Y press opens the menu, release emits `build_menu_closed` and closes it.
- Keyboard/mouse: key 2 selects `run.tower_types[1]`'s id; in mouse mode, a left click places at `cursor` (set directly; `ground_point` is tested alone); Esc with a selection cancels and does not pause; Esc with nothing selected pauses.
- D-105: paused, or IDLE (no StartRun): A, X, 1 and Y queue nothing and the menu stays closed; camera and pause still work.
- Device mode: a joypad motion past the deadzone sets `gamepad` and `cursor == camera.focus()`; a mouse motion clears it.
- Statics: `ground_point` on a known ray; `tower_uid_at` inside, outside, no run; `edge_dir` (moved).
- Camera: `zoom_step` clamps, `recentre` sets the focus to 0 (the existing static tests stay).
- No determinism test: no sim change. Commands queued by input go through `queue()`, which the replay tests already cover.

### Performance
Per frame: a few `Input.get_vector` calls and one ray-plane hit; per event: a handful of `is_action_pressed` checks. Negligible; nothing per tick.

### Docs (same PR)
- New `docs/09_CONTROLS.md`: the table above, the cursor and device-mode rules, the building gates (D-105), what is 020/021, "PROPOSED, approved at CP-M2"; notes: rebinding and Steam Input later; Deck glyphs follow the Xbox layout.
- `02_TECH_ARCHITECTURE.md`: Camera rig bullet (no device reads; `pan/zoom_step/recentre`; actions listed in `09_CONTROLS.md`); a short "Input layer" bullet (contract and bindings home, D-119).
- `01_GAME_DESIGN.md` 9: link the spec. `CLAUDE.md` doc map and `00_INDEX.md`: add `09_CONTROLS.md`.
- `DECISIONS.md`: **D-119 PROPOSED** (bindings in InputMap with the test, `PlayerInput` as the only device reader, building actions dropped when not RUNNING or paused, cursor/mode rules); the mapping table is the spec's, approved at CP-M2.

### Order
1. `IsoCamera` API (`pan`, `zoom_step`, `recentre`, `focus`), move `edge_dir`; camera tests. 2. InputMap actions in `project.godot`; bindings test. 3. `PlayerInput` (device mode, cursor, camera intents), wire into `main.tscn` / `game_view.gd`, disable in the bench. 4. Commands and gates, tests. 5. Spec and docs, D-119; `scripts\test.ps1` twice, `scripts\validate.ps1`; run the game once with a gamepad if one is plugged in (else say so in the PR).

Size: about 150 lines of code (plus about 80 lines of `project.godot` config and about 170 of tests). One PR. Out of scope: radial menu drawing and slice choice, ghost, HUD (020); pause menu, slow-time option (021); rebinding UI.

## Questions

## Review log
