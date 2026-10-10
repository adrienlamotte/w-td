# 038 — UI: tower upgrade controls, hints and level display
- Status: review
- Milestone: M3
- Depends on: 030
- Labels: needs-human:playtest
- PR: #42

## Goal
The player can upgrade a placed tower with mouse/keyboard and with the gamepad, and sees its level and the next price, or why it cannot be upgraded.

## Context
- D-141 (owner, 2026-10-09) answers Q-67.
- `docs/10_M3_CONTENT.md` 3.2 (per placed tower, gold, level 4 needs the signature card), D-134, D-137.
- `docs/09_CONTROLS.md` has no upgrade binding (Q-67); D-121 (verdict and price from the sim's `check_upgrade`), D-122 (hints).

## Acceptance criteria
- The input chosen in Q-67 queues `UPGRADE_TOWER` for the tower under the cursor, only when building is allowed.
- The hint shows the upgrade price or the refusal reason (max level, needs the card, not enough gold); each tower's level is visible on the field.
- Tests for the input mapping and the hint text; `09_CONTROLS.md` updated.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan
Decision ID: **D-151** (PROPOSED, the UI details below; D-141 already fixes the binding). About 150 lines of code plus about 110 of tests; one data field pair and loc strings. `input/` and `view/` only: no sim change, every verdict and price comes from `TowerUpgrade.check` (030, D-121).

### Rules (D-151)
1. **Action `tower_upgrade`** (D-141): R (physical key) and d-pad up (`JOY_BUTTON_DPAD_UP`). Under `PlayerInput.can_build` (like `tower_sell`): queues `UPGRADE_TOWER(uid)` for the tower (live or husk) owning the cell under the cursor; nothing under the cursor = nothing queued; the sim refuses a husk, max level, locked or no gold. Works with or without a tower selected for placement (like sell). If 033 is merged by then and `can_build` does not yet check the draft, add `and not w.draft.drafting` there (the single gate the UI shares).
2. **Hint** (`PlacementGhost.hint`, nothing selected, on a tower whose type has `max_level > 1`; M2 `tower_*_01` towers get no upgrade line): one line from `TowerUpgrade.check` before the sell line: OK -> `upgrade.hint` "{key}: upgrade to Lv {level} ({gold})"; NO_GOLD -> `upgrade.reason.no_gold` "{key}: upgrade ({gold}), not enough gold"; LOCKED -> `upgrade.reason.locked` "Lv {level} needs her signature card"; MAX_LEVEL -> `upgrade.reason.max_level` "Max level"; HUSK -> no line (the rebuild line already shows). Key glyph by device mode: `input.kbm.tower_upgrade` "R", `input.pad.tower_upgrade` "D-pad up".
3. **Level on the field:** a label "Lv {level}" (`tower.level`) above every tower (live or husk) whose type has `max_level > 1`, at the screen projection of the tower position raised by `level_label_height` (world units, `data/ui`), theme font (36, never below 32 px). Text is rebuilt only when that tower's level changes; positions follow the camera every frame. A Label pool in the HUD, no Node in the sim, no per-enemy node.

### Files
1. `input` `game/project.godot` (+4): `tower_upgrade` action (physical keycode 82, joypad button 11, deadzone 0.2).
2. `input` `game/input/player_input.gd` (+5): `tower_upgrade` branch in `_build` next to `tower_sell`.
3. `view` `game/view/placement_ghost.gd` (+20): `UPGRADE_KEYS` (Reason -> loc key) and the upgrade line in `hint()` (rule 2).
4. `view` `game/view/ui/tower_levels.gd` (new, ~45, `TowerLevels`, Control, `mouse_filter = IGNORE`): `setup(world, camera)`; `_process` grows/shrinks a Label pool to the qualifying towers, sets text on level change, positions via `Camera3D.unproject_position`; static `labels(world) -> Array[Dictionary]` (`{uid, level, x, z}` for qualifying towers) so the logic is testable without a camera.
5. `view` `game/view/ui/hud.tscn` + `hud.gd` (+4): a `TowerLevels` node under `Root` (before `Cursor`, so the hint label draws on top), set up from `Hud.setup` with the camera the cursor label already uses.
6. `data` `game/data/ui/ui_default.json` + `tools/schemas/ui.schema.json`: `level_label_height` (number > 0, placeholder 1.6; required).
7. `data` `game/loc/strings.csv` (+7): `upgrade.hint`, `upgrade.reason.no_gold`, `upgrade.reason.locked`, `upgrade.reason.max_level`, `tower.level`, `input.kbm.tower_upgrade`, `input.pad.tower_upgrade`.

### Tests (headless)
- `game/tests/input/test_player_input.gd`: `tower_upgrade` added to `ACTIONS` (the both-devices test then checks R and the d-pad); new `test_upgrade`: R (keyboard) and d-pad up (pad, cursor = focus) on a placed tower queue one `UPGRADE_TOWER` with its uid; nothing under the cursor, paused, or IDLE queue nothing.
- `game/tests/view/test_placement_ghost.gd`: new `test_upgrade_hints` with a Pip added through `TowerBuilding.add_built` on `run_m2` (as `test_tower_upgrade.gd`): OK line (level 2, price 40, before the sell line), pad glyph, NO_GOLD with gold 0, LOCKED at level 3, MAX_LEVEL at 4 with an `unlock_level` 4 modifier, no upgrade line on an M2 tower or on a husk; `text()` gives "R: upgrade to Lv 2 (40)". The existing `test_sell_and_rebuild_hints` stays unchanged (M2 towers).
- `game/tests/view/test_tower_levels.gd` (new): `labels()` lists a Pip with level 1 then 2 after an upgrade, keeps a husk Pip, skips M2 towers; the node's pool size follows the tower count and a label text changes only when the level does.
- No sim change: determinism and replay suites unchanged; no bench needed (towers are tens, one unproject each per frame).

### Docs (same PR)
- `09_CONTROLS.md`: mapping row `tower_upgrade` (R / d-pad up, UpgradeTower of the tower under the cursor), the building-actions list in Rules, the Hints bullet (upgrade line and reasons) and a level-label bullet in Build UI.
- `02_TECH_ARCHITECTURE.md` 2 (UI and HUD): `TowerUpgrade.check` among the read-only queries, the upgrade hint, `TowerLevels`.
- `DECISIONS.md`: D-151 PROPOSED (rules 1-3).

### Order
1. Action + input branch + input tests. 2. Hint lines + strings + hint tests. 3. `TowerLevels`, data field, schema, HUD wiring, tests. 4. Docs, D-151; `scripts/test.ps1` twice, `scripts/validate.ps1`.

Playtest note: the main scene still runs `run_m2` (M2 towers, max level 1), so in game nothing is upgradeable until a run with waifu towers is playable (`run_m3` from 033, main scene switch in 039). The needs-human:playtest label is checked at CP-M3.

## Questions
- None blocking. For the owner (no answer needed to proceed): the upgrade UI can only be tried in game once 039 starts runs with waifu towers; the label shows "Lv 1" too (all levels visible, per the acceptance criteria), only on towers that can level up.

## Review log
