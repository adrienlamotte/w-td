# Controls spec

Status: **PROPOSED**, for the owner to approve at CP-M2. Implements D-041 (camera) and D-046 (gamepad building); input layer and bindings home: D-119. Rule: no feature may need the mouse only (`01_GAME_DESIGN.md` 9).

## Mapping
Gamepad names use the Xbox layout, which matches the Steam Deck A/B/X/Y positions (Deck glyphs follow it).

| Action (InputMap) | Keyboard / mouse | Gamepad | Effect |
|---|---|---|---|
| `cam_pan_up/down/left/right` | W/S/A/D, arrows; edge scroll (mouse mode only) | right stick | pan (D-041) |
| `menu_up/down/left/right` | - | left stick | radial slice direction while `build_menu` is held; otherwise pans like the right stick |
| `cam_zoom_in` / `cam_zoom_out` | wheel up / down | RB / LB | zoom step (D-041) |
| `cam_recentre` | Space | R3 (right stick click) | focus back on the Guardian (D-041) |
| `build_menu` | - (mouse/keyboard use the build bar and the slot keys) | Y, hold | radial menu open while held; release selects (D-046) |
| `build_slot_1..3` | 1 / 2 / 3 | - (radial) | select the run's tower 1..3 |
| `build_place` | left click | A | on a husk: RebuildTower; on a free spot with a tower selected: PlaceTower at the cursor; the selection stays (place several) |
| `build_cancel` | right click; Esc while something is selected | B | clear selection / close menu (D-046) |
| `tower_sell` | X (tower under the mouse) | X (tower under the cursor) | SellTower (live or husk) |
| `skill_1` / `skill_2` | Q / E | LT / RT | UseSkill of the Guardian's skill 1 / 2 (D-046); a trigger fires once per pull |
| `pause` | Esc (nothing selected), P | Start (Menu) | Pause toggle; 021 adds the pause menu on top |

All stick and trigger deadzones are 0.2 (placeholder).

## Cursor and device mode
- **Mouse mode:** the cursor is the ground point under the mouse. Edge scroll is on.
- **Gamepad mode:** the cursor is the screen centre, which is the camera focus (the world moves under it). No edge scroll.
- The mode follows the last device used: mouse motion or button -> mouse; joypad button, or a stick/trigger past the deadzone -> gamepad. Keys do not switch it.

## Rules
- Building actions (`build_menu`, `build_slot_*`, `build_place`, `tower_sell`) do nothing unless a run is running and not paused (D-105). Camera, skills and pause always pass (the sim gates skills, D-110).
- Esc cancels first: with a tower selected or the menu open it only cancels; otherwise it pauses.

## Build UI (D-122, task 027)
- **Build bar** (bottom centre, all devices): one button per run tower with name, current price and hotkey `[1]..[3]`. A click selects like the slot key; the selected button stays pressed. Greyed but clickable when gold is short (the ghost then says why); disabled unless a run is running and not paused. The buttons take no GUI focus (the gamepad uses the radial).
- **Radial menu** (gamepad): shown while `build_menu` is held, centred on the screen; one slice per run tower, slice 0 centred at the top, then clockwise; each shows name and price, greyed when not affordable; the slice under the left stick is highlighted. Release on a slice selects its tower; release with the stick in the centre (under `radial_deadzone`) keeps the current selection.
- **Placement ghost:** with a tower selected, a flat box of the tower footprint at the snapped position under the cursor plus its attack range ring, green when the placement is valid, red otherwise. A label next to the cursor shows the price, or why it cannot be built (occupied, too far from the Guardian, too close to the Guardian, not enough gold, not in this run). Verdict, position and price come from the sim's `check_place`.
- **Hints** (nothing selected): on a tower, "{sell key}: sell (+refund)"; on a husk, "{place key}: rebuild (price)" and "{sell key}: sell (+0)". The key names follow the device mode (Left click / A, X / X).
- The cursor label sits next to the mouse in mouse mode and under the screen centre in gamepad mode.

## Later (not in this spec's code)
- Pause menu and the slow-time-while-placing accessibility option (D-046): task 021.
- Runtime rebinding (edits the InputMap and saves overrides to the user settings) and Steam Input (maps the Deck onto the same actions): later milestones.
