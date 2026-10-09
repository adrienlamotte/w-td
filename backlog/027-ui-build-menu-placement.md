# 027 — UI: build menu, radial menu, placement ghost, sell and rebuild
- Status: review
- Milestone: M2
- Depends on: 018, 020
- PR: #30

## Goal
Building with mouse and gamepad: build bar with costs, gamepad radial menu, placement ghost snapped to the grid with valid/invalid feedback, sell and rebuild husk interactions. Split from 020.

## Context
- D-040, D-042 (rising price), D-046 (radial menu), D-105 (no building while paused), D-109/D-113 (placement, husks, prices), D-119 (input layer), D-121 (sim queries, localisation, theme; task 020)
- `docs/09_CONTROLS.md` (actions, cursor and device mode)

## Acceptance criteria
- Build bar with one button per run tower: name, current price, hotkey; mouse click and keys 1-3 select; greyed when not affordable.
- Gamepad radial menu while `build_menu` is held; release selects the slice under the left stick.
- Placement ghost snapped to the grid at the cursor (mouse or screen centre), green when valid, red with a reason text when not; verdict, snapped position and price only from `TowerBuilding.check_place`.
- Hover/cursor on a tower: sell hint with the refund; on a husk: rebuild hint with the price (both from the sim queries).
- Nothing to build while paused or without a running run (D-105).
- Readable at 1280x800; all strings are localisation keys.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-122** (PROPOSED: build UI rules below). View only; no sim change (020 added the queries). Commands still go only through `PlayerInput` (018).

### Rules (D-122 PROPOSED)
- **Build bar** (mouse/keyboard, also visible on gamepad): bottom centre of the HUD, one button per `run.tower_types` slot: name (`name_key`), price `TowerBuilding.price()`, hotkey `1/2/3`. Click -> `PlayerInput.select_tower(id)` (same as the key). The selected slot is highlighted. A button is greyed (still clickable, so the ghost shows "not enough gold") when `gold < price`; the whole bar is disabled when not RUNNING or paused. `focus_mode = NONE` on the buttons (gamepad uses the radial, not GUI focus, so `ui_*` never fights 018's actions).
- **Radial menu** (gamepad, D-046): shown while `PlayerInput.menu_open`, centred on the screen; `n = run.tower_types.size()` slices, slice 0 centred at the top, clockwise; each shows name and price, greyed when not affordable; the slice under `menu_dir` is highlighted. `slice(dir, n, deadzone) -> int` (static): -1 when `dir.length() < deadzone` (release in the centre = no change). On `build_menu_closed(dir)`: a slice selects its tower; -1 keeps the selection.
- **Placement ghost:** while `selected_tower != ""`, RUNNING and not paused: `check_place(world, type, cursor.x, cursor.y)` once per frame; a flat box of `footprint * grid_step` per side at the snapped centre, plus the attack range ring; colour valid / invalid from data. When invalid, a cursor label shows the reason key (`build.reason.occupied`, `.out_of_radius`, `.too_close`, `.no_gold`, `.not_offered`); when valid, the price.
- **Hints** (no tower selected): cursor on a live tower (`PlayerInput.tower_uid_at`) -> `build.hint.sell` "{key}: sell (+{gold})" with `sell_refund`; on a husk -> `build.hint.rebuild` "{key}: rebuild ({gold})" with `rebuild_price` plus the sell hint (clears it, +0). `{key}` is the action glyph for the current device mode (`input.kbm.*` / `input.pad.*` keys, e.g. "Left click" / "A", "X" / "X").
- The cursor label sits at the screen projection of the cursor point (mouse mode: next to the mouse; gamepad: under the screen centre).

### Files
1. `view` (new) `game/view/ui/build_bar.gd` (+ nodes in `hud.tscn`), `class_name BuildBar extends HBoxContainer`: `setup(world, input)`, refresh on change of gold, copies, selection, run state. About 70.
2. `view` (new) `game/view/ui/radial_menu.gd`, `class_name RadialMenu extends Control`: `_draw()` slices with `draw_colored_polygon` + labels; static `slice()`; connects `build_menu_closed`. About 70.
3. `view` (new) `game/view/placement_ghost.gd`, `class_name PlacementGhost extends Node3D` (child of `Main`): box `MeshInstance3D` + range ring (`TorusMesh` or a flat ring mesh), unshaded materials; `update()` per frame; static `hint(world, input) -> Dictionary` (`key`, `values`) shared with the cursor label so it is testable without rendering. About 80.
4. `view` `game/view/ui/hud.gd` / `hud.tscn`: the bar, the radial and a cursor `Label` (positioned by `Camera3D.unproject_position`). About +20.
5. `view` `game/view/game_view.gd`, `main.tscn`: `PlacementGhost` node, setup calls. +5.
6. `data` (new) `game/data/ui/ui_default.json` + `tools/schemas/ui.schema.json`: `ghost_valid_color`, `ghost_invalid_color` ([r, g, b, a] in 0..1), `ghost_height`, `range_ring_width`, `radial_radius_px`, `radial_deadzone`, `cursor_label_offset_px`. All placeholders. (Separate from `render_default.json`, which 019 changes.)
7. `data` `game/loc/strings.csv`: the `build.*` and `input.*` keys.

### Tests
- `tests/view/test_radial_menu.gd`: `slice()`: up -> 0, clockwise order for n = 3 and 4, boundaries, under deadzone -> -1; a `build_menu_closed` with a slice direction selects that tower, centre release keeps the previous selection.
- `tests/view/test_build_bar.gd` (world + StartRun `run_m2`): one button per run tower with the `price()` text; after a placed tower the price text rises; pressing a button sets `input.selected_tower`; greyed when gold is short; disabled when paused and before StartRun.
- `tests/view/test_placement_ghost.gd`: with a tower selected on a free spot -> visible, valid colour, position = `check_place` centre (not the raw cursor); on an occupied cell / beyond the radius / without gold -> invalid colour and the matching reason key; hidden with nothing selected, when paused, and before StartRun; `hint()` on a live tower gives the sell key with `sell_refund`, on a husk the rebuild key with `rebuild_price`, in mouse and gamepad modes.
- Every new Label/Button has font size >= 32 (the HUD test walks the whole HUD, so it covers the bar and the radial); every new key translates.
- `scripts\test.ps1` twice, `scripts\validate.ps1`; run the game, build with mouse and keys (gamepad if one is plugged in, else say so in the PR).

### Performance
Per frame: one `check_place` (O(footprint cells)), one `tower_uid_at`, a few label updates on change; the radial redraws only while open. Nothing per tick.

### Docs (same PR)
- `09_CONTROLS.md`: the build bar, radial slice layout and release-in-centre rule, ghost and hints (still PROPOSED for CP-M2).
- `02_TECH_ARCHITECTURE.md` UI bullet: ghost and hints go through `check_place`, `price`, `sell_refund`, `rebuild_price` only.
- `DECISIONS.md`: **D-122 PROPOSED**. needs-human:playtest at CP-M2 (building feel with mouse and gamepad).

### Order
1. Data file + schema. 2. Radial `slice()` and the radial menu, tests. 3. Build bar, tests. 4. Ghost + hints + cursor label, tests. 5. Run the game, docs, D-122; tests twice, validator.

Size: about 250 lines of code (+ about 30 of data/schema), about 180 of tests. One PR. Out of scope: slow-time-while-placing option and pause menu (021), device-specific glyph art (later), rebinding.

## Questions

## Review log
