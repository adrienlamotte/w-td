# Controls spec

Status: **DECIDED** (approved at CP-M2, D-129). Implements D-041 (camera) and D-046 (gamepad building); input layer and bindings home: D-119. Rule: no feature may need the mouse only (`01_GAME_DESIGN.md` 9).

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
| `tower_upgrade` | R (tower under the mouse) | d-pad up (tower under the cursor) | UpgradeTower of the tower under the cursor; the sim refuses a husk, max level, a locked level or short gold (D-141, D-151) |
| `skill_1` / `skill_2` | Q / E | LT / RT | UseSkill of the Guardian's skill 1 / 2 (D-046); a trigger fires once per pull |
| `pause` | Esc (nothing selected), P | Start (Menu) | Pause toggle, only while a run is running (D-125); pausing clears the selection and closes the radial |

All stick and trigger deadzones are 0.2 (placeholder).

## Cursor and device mode
- **Mouse mode:** the cursor is the ground point under the mouse. Edge scroll is on.
- **Gamepad mode:** the cursor is the screen centre, which is the camera focus (the world moves under it). No edge scroll.
- The mode follows the last device used: mouse motion or button -> mouse; joypad button, or a stick/trigger past the deadzone -> gamepad. Keys do not switch it.

## Rules
- Building actions (`build_menu`, `build_slot_*`, `build_place`, `tower_sell`, `tower_upgrade`) do nothing unless a run is running and not paused (D-105). Camera, skills and pause always pass (the sim gates skills, D-110).
- Esc cancels first: with a tower selected or the menu open it only cancels; otherwise it pauses.

## Build UI (D-122, task 027)
- **Build bar** (bottom centre, all devices): one button per run tower with name, current price and hotkey `[1]..[3]`. A click selects like the slot key; the selected button stays pressed. Greyed but clickable when gold is short (the ghost then says why); disabled unless a run is running and not paused. The buttons take no GUI focus (the gamepad uses the radial).
- **Radial menu** (gamepad): shown while `build_menu` is held, centred on the screen; one slice per run tower, slice 0 centred at the top, then clockwise; each shows name and price, greyed when not affordable; the slice under the left stick is highlighted. Release on a slice selects its tower; release with the stick in the centre (under `radial_deadzone`) keeps the current selection.
- **Placement ghost:** with a tower selected, a flat box of the tower footprint at the snapped position under the cursor plus its attack range ring, green when the placement is valid, red otherwise. A label next to the cursor shows the price, or why it cannot be built (occupied, too far from the Guardian, too close to the Guardian, not enough gold, not in this run). Verdict, position and price come from the sim's `check_place`.
- **Hints** (nothing selected): on a tower, "{sell key}: sell (+refund)"; on a husk, "{place key}: rebuild (price)" and "{sell key}: sell (+0)". On a live tower that can level up (waifu towers; not the M2 towers), an upgrade line comes first, from the sim's `TowerUpgrade.check`: "{upgrade key}: upgrade to Lv n (price)", or "{upgrade key}: upgrade (price), not enough gold", "Lv 4 needs her signature card", "Max level"; a husk shows no upgrade line. The key names follow the device mode (Left click / A, X / X, R / D-pad up) (D-151).
- **Level labels:** "Lv n" above every tower (live or husk) that can level up, at `level_label_height` (`data/ui`) above the tower (D-151).
- The cursor label sits next to the mouse in mouse mode and under the screen centre in gamepad mode.

## Menus (D-125, task 021)
- **Screens:** start screen (Start run, Slow time while placing, Quit game) -> run -> pause menu (Resume, Restart, Slow time while placing, Main menu) -> win or lose screen (time survived, Restart, Main menu). Restart and Main menu reload the scene; Restart starts a new run at once.
- **Navigation:** Godot GUI focus. Up/down arrows, d-pad or left stick move between buttons; Enter, Space or A press; the mouse clicks. Each menu focuses its first button when it opens. The build bar never takes focus.
- **Pause:** Start / P toggle the pause as before; while the pause menu is shown, Esc or B (`ui_cancel`) resumes. No pause outside a running run (start and end screens).
- **Slow time while placing** (accessibility option, D-046): off by default, kept for the session only (saved settings are M3). While on, the game runs at `slow_time_scale` (placeholder 0.5, `data/ui`) whenever a tower is selected or the radial is open and building is possible. Camera, cursor, radial and ghost keep real time.

## Later (not in this spec's code)
- Runtime rebinding (edits the InputMap and saves overrides to the user settings) and Steam Input (maps the Deck onto the same actions): later milestones.
