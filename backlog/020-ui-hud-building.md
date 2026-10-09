# 020 — UI: HUD, sim queries for the UI, localisation, real run in the main scene
- Status: review
- Milestone: M2
- Depends on: 015, 017, 018
- PR: #26

## Goal
Everything the player needs to play: HUD and building with mouse and gamepad.

## Context
- D-040, D-042, D-046 (radial menu), D-039 (2560x1440, readable at 1280x800)
- Text as localisation keys (D-063)

## Acceptance criteria
- HUD: Guardian HP, gold, run clock, wave/break indicator, skill cooldowns.
- Build menu, radial menu, placement ghost, sell and rebuild: split to task 027. This task adds the read-only sim queries they use and starts a real run in the main scene.
- Readable at 1280x800; all strings are localisation keys.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
**Split** (one PR each): this task = sim read queries for the UI, the localisation mechanism, the UI theme, the HUD, and a real run in the main scene. The build bar, gamepad radial menu, placement ghost and sell/rebuild hints move to **027** (depends on 020). Decision ID: **D-121** (PROPOSED). 027 reserves D-122.

### Rules (D-121 PROPOSED)
- **The view never re-implements a rule.** Every number or verdict the UI shows comes from a read-only sim query, and the command path uses the same function, so the UI and the sim cannot disagree:
  - `TowerBuilding.check_place(w, type, x, z) -> TowerBuilding.Check` (`reason`, snapped centre `x, z`, `footprint` cells, `price`). Reasons, in today's check order: `OK, NOT_OFFERED, OCCUPIED` (a tower or husk there, or outside the grid), `OUT_OF_RADIUS` (`dist + radius > build_radius`), `TOO_CLOSE` (inside the Guardian contact radius), `NO_GOLD`. `place()` becomes `check_place` + commit; behaviour unchanged (the RUNNING/not-paused gate stays in `SimWorld._apply`).
  - `TowerBuilding.price(w, type)` (rising price, husks count, D-113), `rebuild_price(w, t)`, `sell_refund(w, t)` (0 for a husk); `place/rebuild/sell` use them.
  - `WaveSpawner.timeline(clock, run) -> Vector3i(wave, in_break, ticks_left)`: `wave` 0-based (-1 before `first_wave_tick`), `in_break` 1 during a break and before the first wave, `ticks_left` until the next wave start or break start. Same arithmetic as `step()` (D-106); `step()` may call it if that keeps it shorter, otherwise leave `step()` alone.
- **Localisation (D-063):** Godot translations from a CSV: `game/loc/strings.csv`, columns `keys,en` (French is a new column later), imported by Godot (commit `strings.csv.import`; the generated `*.translation` files are gitignored; test/run/export scripts import first), listed in `project.godot` `[internationalization] locale/translations`. Controls auto-translate a key set as `text`; text with values uses `tr(key).format({"value": v})` with `{name}` placeholders in the CSV. Keys are lowercase dotted (`hud.gold`, same pattern as the data `name_key`). English text is placeholder. The validator checks every `*_key` value in `game/data` exists in the CSV.
- **Readability (D-039):** one project theme `game/view/ui/ui_theme.tres` set as `gui/theme/custom` (021 inherits it). Stretch is `canvas_items` from 2560x1440, so 1280x800 is a 0.5 scale: no font below **32 px at base** (16 px on the Deck). Default font size 36 (placeholder). HUD margins 48 px base, anchored to the corners; bottom centre left free for 027's build bar.
- **Main scene runs a real run** (placeholder until 021's start screen): `game_view` queues `SimCommand.start_run(0, RUN_SEED, "run_m2")`; the M1 demo horde (`_setup_demo`, `DEMO_*`, `spawn_ring`, recycle, bare towers) leaves the main scene; `demo = false` (bench) still skips it. No scripted towers: the player builds with 018's keys and clicks (1-3 + left click; on gamepad, A rebuilds/places once 027's radial selects). **Coordination with 019:** if 019 merged first, keep its `StartRun` and delete its scripted tower list; if 020 merges first, 019 skips its main-scene item (note added to 019's plan).

### HUD (view: reads sim state each frame, writes none)
`game/view/ui/hud.tscn` + `hud.gd` (`class_name Hud extends CanvasLayer`), child of `Main`; `setup(world: SimWorld)` from `game_view._ready`. All HUD controls `mouse_filter = IGNORE` (clicks reach the world).
- Top left: Guardian HP bar (`ProgressBar`, `world.guardian_hp / world.run.guardian_hp`) and `"{hp} / {max}"` (ceil).
- Top centre: run clock `m:ss` from `world.clock / TICK_RATE`; under it the wave or break line from `timeline()`: `hud.wave` "Wave {n}" (1-based) or `hud.break` "Break {time}" with the countdown.
- Top right: gold (`hud.gold` "Gold {value}").
- Bottom right: one panel per skill slot: skill name (`run.skill_name_key`), hint `hud.hint.skill_1/2` ("Q / LT", "E / RT"; device-aware glyphs later), state `hud.ready` or the seconds left, a cooldown bar.
- Paused: a centred `hud.paused` label (021 replaces it with the pause menu).
- Before StartRun (`world.run == null`, bench): hidden.
- Statics for tests: `clock_text(ticks) -> String` (`m:ss`), `seconds_left(ready_at, clock) -> int` (ceil, 0 when ready).
- Sets a label only when its value changed (no per-frame string churn).

### Files
1. `sim` `game/sim/tower_building.gd`: `Reason` enum, inner `class Check`, `check_place`, `price`, `rebuild_price`, `sell_refund`; `place/sell/rebuild` use them. About +35 net.
2. `sim` `game/sim/wave_spawner.gd`: `timeline()`. About +15.
3. `sim` `game/sim/run_data.gd`: `skill_name_key: PackedStringArray` from the skill file. +2.
4. `view` (new) `game/view/ui/hud.tscn`, `hud.gd` (about 110 lines), `ui_theme.tres`.
5. `view` `game/view/game_view.gd`, `main.tscn`: StartRun, demo horde removed, `Hud` node + setup. About -15 net.
6. `data` (new) `game/loc/strings.csv` (+ `.import`): HUD keys, the 12 existing data `name_key`s (placeholder English names), `hud.paused`. `.gitignore`: `game/loc/*.translation`. `project.godot`: `[internationalization]` and `gui/theme/custom`.
7. `tools` `tools/validate_data.py`: collect `*_key` string values, report the ones missing from `game/loc/strings.csv`. About +15.
8. Scripts: check `scripts\run.ps1` and `scripts\export.ps1` run `--import` first (as `test.ps1` does); add it where missing so a fresh clone gets the translation.

### Tests
- `tests/sim/test_tower_building.gd`: `check_place` returns each reason in its case (not offered, occupied by a tower, by a husk, outside the grid, out of radius, too close, no gold) and OK otherwise; in every case `place()` is accepted iff `OK` (gold, towers and grid unchanged on a reject); OK's snapped `x, z` equal the placed tower's position and `price` equals the gold taken; `price` rises per copy with husks counted; `rebuild_price` and `sell_refund` equal what the commands charge and refund (husk refund 0). Determinism/replay tests stay green unchanged (pure refactor).
- `tests/sim/test_wave_spawner.gd`: over the first two wave periods `timeline()` agrees with `WAVE_STARTED` (wave index; `in_break` flips at `wave_ticks`; `ticks_left` reaches 0 at each switch); with `first_wave_tick > 0` it gives wave -1 before it.
- `tests/view/test_hud.gd`: world + StartRun `run_m2`, Hud instanced with `add_child_autofree`: gold, HP, clock (`0:01` after 30 steps), wave label in a wave and break label after `wave_ticks`; UseSkill then a step -> that slot shows seconds, the other shows ready; paused label visible after Pause; HUD hidden with no run; `clock_text`/`seconds_left` edge cases; every Label/Button under the HUD has `get_theme_font_size("font_size") >= 32`; every HUD key and every catalog `name_key` translates (`tr(k) != k`), which also proves the CSV loads headless.
- `tools/tests/test_validate_data.py`: a `name_key` missing from the CSV is reported; the real data passes.
- `scripts\test.ps1` twice, `scripts\validate.ps1`; run the game once at 1280x800 (`--resolution 1280x800`) and look at the HUD (screenshot in the PR if possible).

### Performance
HUD: a few reads and compares per frame, text rebuilt on change only. Queries are O(footprint cells); here they run on commands only (027 calls `check_place` once per frame). Nothing per tick; `state_hash()` unchanged.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md`: UI bullet (HUD reads sim state; UI verdicts and prices only through the sim queries above; project theme and the 32 px rule; localisation mechanism and the validator check; main scene starts `run_m2`). The building bullet in 3a names `check_place` as the single placement rule. Line 95 (localisation keys): point at `game/loc/strings.csv`.
- `DECISIONS.md`: **D-121 PROPOSED** (the rules above). HUD look and readability: needs-human:playtest at CP-M2.

### Order
1. Sim queries + tests (refactor `place/sell/rebuild` onto them, suite green). 2. `timeline()`, `skill_name_key`, tests. 3. Localisation CSV, project settings, validator check + Python test. 4. Theme, HUD, tests. 5. Main scene run; run the game at 1280x800. 6. Docs, D-121; `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 200 lines of code (+ CSV, theme, config), about 200 of tests. One PR. Out of scope (027): build bar, radial menu, placement ghost, sell/rebuild hints. (021): pause menu, start/end screens.

## Questions

## Review log
