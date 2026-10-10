# 037 — UI: level-up draft, XP bar and card-unlocked towers in the build bar
- Status: done
- Milestone: M3
- Depends on: 033
- Labels: needs-human:playtest
- PR: #44

## Goal
The player sees XP and level, picks one of 3 cards when the draft opens (mouse, keyboard and gamepad), and towers unlocked by cards appear in the build bar and the radial.

## Context
- `docs/10_M3_CONTENT.md` 1 (the draft freezes the run like a pause; pause allowed during a draft; no skip), 2 (card text from `name_key` / `desc_key`).
- `docs/09_CONTROLS.md` Menus (GUI focus) and Build UI; D-121 (cards and eligibility come from the sim), D-122, D-039 (font sizes).
- Up to 8 buildable towers per run: the build bar and radial grow, slot keys go from 1-3 to 1-8 (`09_CONTROLS.md` updated, PROPOSED).

## Acceptance criteria
- Draft overlay (CanvasLayer) shown while drafting: 3 cards with name, type and description, the first focused; a pick queues `PICK_CARD`; mouse, keyboard and gamepad; nothing else takes input meanwhile except pause.
- HUD: level and XP bar from sim state, text rebuilt on change only.
- Build bar and radial show the run's current buildable towers; slot keys 1-8.
- Headless view tests (overlay shows the sim's cards, a pick queues the right slot, the build bar grows); no font under 32 px at base.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan
Decision ID: **D-153** (PROPOSED, rules below). About 190 lines of code (GDScript and scene) plus about 200 of tests; no game data or schema change, new localisation keys only. All `view/` and `input/` except two read-only additions in `sim/` (card text keys, XP bar progress) so the view never re-derives a rule (D-121). Replaces the game-view stopgap of 033 (auto-pick of slot 0); the balance bot and the bench keep theirs.

### Rules (D-153)
1. **Draft overlay** (`DraftOverlay`, a CanvasLayer in `main.tscn` after `PauseMenu`): visible while the run is RUNNING, `world.draft.drafting` and not paused. A title "Level {level}!" and 3 card buttons in a row, one per `world.draft.draft` slot, each showing the card name (`name_key`), its type (`draft.type.<type>` key) and its description (`desc_key`), word-wrapped. On opening (and on returning from the pause menu) the first card takes GUI focus.
2. **A pick** (click, Enter / Space or A on the focused card) queues `PICK_CARD(world.tick, slot)` once, then the 3 buttons are disabled until the draft changes. The overlay tells drafts apart by the number of picks taken (sum of `world.draft.picks`): when it changes, the next draft (several level-ups queue, D-147) is shown with fresh text and focus. So a double click never picks blind in the next draft. No skip, no cancel: `ui_cancel` does nothing in the overlay (D-051).
3. **Input during a draft:** `PlayerInput.handle` only updates the device mode and passes `pause` (Esc, P, Start); camera pan (polled in `_process`), zoom, recentre, skills and building actions are ignored, and an open radial closes without selecting. The tower selection is kept for after the pick. Pausing hides the overlay and shows the pause menu (the draft stays open in the sim, D-147); resuming shows it again.
4. **HUD level and XP:** under the HP bar, a "Lv {level}" label and an XP bar. The bar fill is `CardDraft.level_progress(run)` (new read-only sim query: `(xp - previous threshold) / (xp_next - previous threshold)`, clamped to 0-1, previous threshold = `xp_next - (xp_base + xp_step * (level - 1))`). The label text is rebuilt only when the level changes.
5. **Build bar and radial** list `world.tower_types` (the buildable list, D-147: starters plus card unlocks, up to 8 per run) and rebuild their buttons or slices when the run or that list's size changes. The build bar becomes a 4-column grid (8 towers = 2 rows), so it stays clear of the skill panels at the bottom right at 1920 x 1080 and 1280 x 800.
6. **Slot keys 1-8:** actions `build_slot_1..8` on keys 1-8 (physical keys), each selecting the run's tower at that position in `world.tower_types`; hotkey labels `[1]..[8]`. Gamepad unchanged (radial, now up to 8 slices).

### Files
1. `sim` `game/sim/card_catalog.gd` (+4): `name_key`, `desc_key` per card (data, no rule).
2. `sim` `game/sim/card_draft.gd` (+6): `level_progress(run) -> float` (rule 4), read-only.
3. `view` `game/view/ui/draft_overlay.tscn` + `draft_overlay.gd` (new, ~75 + scene): rules 1-2. Buttons use the project theme (36 px default, nothing below 32 px), `autowrap_mode` on, a fixed minimum card size in the scene; `setup(world, input)`.
4. `view` `game/view/main.tscn`, `game/view/game_view.gd` (~6): add the overlay, `setup` it in demo mode, remove the slot-0 stopgap.
5. `input` `game/input/player_input.gd` (~15): rule 3 (a static `in_draft(w)` next to `can_build`), rule 6 (`for slot in 8`, `world.tower_types`).
6. `view` `game/view/ui/hud.tscn`, `hud.gd` (~15): rule 4.
7. `view` `game/view/ui/build_bar.gd` + `hud.tscn` (~10): rule 5 (`GridContainer`, `columns = 4`; read `world.tower_types`).
8. `view` `game/view/ui/radial_menu.gd` (~6): rule 5.
9. `game/project.godot`: `build_slot_4..8` actions (keys 4-8).
10. `game/loc/strings.csv`: `draft.title` ("Level {level}!"), `draft.type.new_tower` ("New waifu"), `draft.type.signature` ("Signature"), `draft.type.skill` ("Guardian skill"), `draft.type.perk` ("Perk"), `draft.type.filler` ("Bonus"), `hud.level` ("Lv {level}"). Placeholder wording.

### Tests (headless)
- `game/tests/view/test_draft_overlay.gd` (new): a `run_m3` world brought to a draft (set `draft.xp` to the threshold, step); the overlay is visible with 3 buttons whose text contains `tr(name_key)`, the type text and `tr(desc_key)` of `world.draft.draft[s]`; the first button has focus; pressing button 2 queues exactly one `PICK_CARD` with slot 2 (the next step picks `draft[2]`), a second press before the step queues nothing; with two pending level-ups the second draft is shown and refocused after the first pick; hidden while paused, shown again after resume; every Label and Button font size >= 32 at base.
- `game/tests/input/test_player_input.gd`: during a draft, a skill key, a slot key and `build_place` queue nothing and the camera does not pan; `pause` still queues `PAUSE`; `build_slot_8` selects the 8th buildable tower (a world with 8 unlocked types).
- `game/tests/view/test_build_bar.gd`, `test_radial_menu.gd`: after `card_tower_cinder` is applied the bar has 3 buttons and the radial 3 slices; with 8 types, 8 buttons labelled `[1]..[8]` in a 4-column grid; existing assertions switch from `run.tower_types` to `world.tower_types`.
- `game/tests/view/test_hud.gd`: "Lv 1" and an empty bar at start; after XP is added the bar fill matches `level_progress`; the level label changes on a level-up.
- `game/tests/sim/test_card_draft.gd`: `level_progress` at 0, mid-level and right after a level-up.
- One frame capture of a draft at 1920 x 1080 from the game's own viewport (`get_viewport().get_texture().get_image()`), saved outside the repo, linked in the PR description only (not committed): cards readable, build bar clear of the skill panels.
- Perf: view only, text rebuilt on change; no sim per-tick work. No bench run needed.

### Docs (same PR)
- `09_CONTROLS.md`: mapping `build_slot_1..8` (1-8); Rules (during a draft only pause passes); Build UI (hotkeys `[1]..[8]`, 4-column bar, radial up to 8 slices); Menus (the draft overlay: focus, pick, no skip, pause).
- `02_TECH_ARCHITECTURE.md` 2 (UI and HUD: draft overlay, Lv and XP bar, build bar and radial read `world.tower_types`); 3a (drop "the build UI still reads `run.tower_types` until task 037" and the game-view stopgap mention).
- `DECISIONS.md`: D-153 PROPOSED (rules 1-6).

### Order
1. Sim read-only additions and their test. 2. Build bar, radial and slot keys on `world.tower_types` (tests). 3. HUD Lv and XP bar. 4. Draft overlay, input gate, remove the stopgap (tests). 5. Frame capture, docs, D-153; `scripts/test.ps1` twice, `scripts/validate.ps1`.

## Questions
- None blocking. The card-type labels and the overlay layout are placeholder wording and layout for the playtest (`needs-human:playtest`).

## Review log
- 2026-10-10 lead-dev: approved and squash-merged PR #44 into m3/dev. All criteria met, matches plan D-153; test.ps1 322/322 GUT + 24 Python green, validate.ps1 0 errors (run in a worktree). Owner: playtest the draft overlay layout and card-type wording (needs-human:playtest).
