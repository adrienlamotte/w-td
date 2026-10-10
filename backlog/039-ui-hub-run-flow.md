# 039 — UI: hub screen and M3 run flow
- Status: done
- Milestone: M3
- Depends on: 035
- Labels: needs-human:playtest
- PR: #48

## Goal
Between runs the player sees her hearts, buys meta nodes, sees the roster and picks the Guardian to rescue from the offer; the end screen shows the hearts earned and returns to the hub.

## Context
- `docs/01_GAME_DESIGN.md` 7 (hub: meta currency, permanent upgrades, roster; outfits and bond come later), 3 (Guardian offer, win unlock).
- `docs/10_M3_CONTENT.md` 6 (hearts, tree), D-050, D-023, D-125 (run flow, reload for restart), D-121 (every number from the meta rules of 035), `docs/09_CONTROLS.md` Menus.
- Q-68 safe to assume ★ A (all 6 rescued: offer all 6 again).

## Acceptance criteria
- Flow: start screen -> hub -> Guardian pick -> run -> end screen (hearts earned, unlock shown on a win) -> hub. "Main menu" from the pause menu abandons with loss hearts (6.1).
- Hub: hearts; 12 nodes in 3 branches with cost and bought / locked / affordable state, buy; roster (starters, rescued, locked); mouse, keyboard and gamepad (GUI focus).
- The run starts with the `START_RUN` config built from the profile (035).
- Headless view tests (the offer shown matches the rule, a buy updates the profile, abandon grants hearts).
- Headless tests green twice; data validator green; docs (`02_TECH_ARCHITECTURE.md` 2, `09_CONTROLS.md` Menus) in the same PR.

## Plan
Decision ID: **D-154** (PROPOSED, rules below; it applies the owner answers D-155, D-157, D-158, D-160, D-161). About 375 lines of code (GDScript and scenes) plus about 230 of tests; game data: new `strings.csv` keys only, no schema change. Everything is `view/` except two small read-only helpers and the D-158 line in `sim/`, one return value and the small settings file in `save/`. If the PR runs past ~420 lines, split rule 9 (settings) out into its own task rather than trimming tests. Every number the screens show comes from 035's rules (D-121): `MetaProfile.offer`, `check_buy`, `hearts_for`, `record_run`, `start_command`.

### Rules (D-154)
1. **Screens** (all CanvasLayer overlays in `main.tscn`, the world IDLE behind them, D-125): start screen (Play, Slow time, Quit) -> **hub** -> a rescue button starts the run -> pause menu / draft / end screen -> hub. Which screen shows after a scene reload is `RunFlow.screen` (`START` or `HUB`, static, session only); `RunFlow.autostart` becomes `RunFlow.restart_waifu` ("" = none).
2. **Hub** (`view/ui/hub.tscn`): loads the profile when it opens (`ProfileStore.load_profile(cat, RunFlow.profile_dir)`) and shows: hearts; the offer as one button per `profile.offer(cat)` id ("Rescue {name}", plus "Best {m:ss}" from `best_sec` of her Guardian when > 0); the 12 nodes in one column per `branch` (columns in sorted branch order: economy, guardian, towers; nodes in id order), each a button with name, description, cost and a state line from `check_buy` (OK "{cost} hearts", NO_HEARTS "{cost} hearts" greyed, LOCKED "Needs {name}", OWNED "Bought"); the roster (starters, then the guardians in offer order) with "Starter", "Rescued" or "Locked" from `MetaProfile.roster_state`; a Back button (and `ui_cancel`) to the start screen. Rivals are not listed (none in data; tiers are M5).
3. **Buy:** a node button calls `profile.buy(cat, id)`; on OK the profile is saved at once (`ProfileStore.save_profile`, `10_M3_CONTENT.md` 7) and the hub refreshes; any other verdict changes nothing. Buttons stay focusable whatever their state, so gamepad navigation never skips a column.
4. **Rescue:** a rescue button queues `profile.start_command(cat, world.tick, seed, "run_m3", waifu)` with a view-local random seed printed to the log (as D-125). **The M3 game runs `run_m3`** (the starters Pip and Mallow are buildable from the start, `10_M3_CONTENT.md` 2.1); `run_m2` stays the M2 fixture for the bench and the M2 bot.
5. **Run end:** the end screen (not `game_view`) writes the run once, on the first refresh that sees WON or LOST (`ProfileStore.record_run_end(world, RunFlow.profile_dir)`, now returning `{hearts, unlocked}`), and shows "+{n} hearts" and, on a win with a new unlock, "{name} joins your towers!". One button, Continue -> hub (Restart is removed from the end screen: after a win her Guardian is no longer offered). The 035 hook in `game_view` goes away; with `demo == false` (bench) the end screen is never set up, so nothing is written.
6. **Abandon (D-155):** the pause menu "Main menu" becomes "Abandon run": a confirm panel "Abandon run? You keep {n} hearts." with `n = MetaProfile.hearts_for(run, false, clock)`, Cancel focused by default (Cancel and `ui_cancel` close it); Abandon records the run as a loss at the time reached (`record_run_end`, the run still RUNNING) and reloads to the hub. **Restart** in the pause menu uses the same confirm, records the same loss, and reloads with `restart_waifu` = the waifu of the run's Guardian, who is still offered (owner check below).
7. **Unreadable profile (D-161, task 035):** when `ProfileStore.last_error` is not empty the hub first shows a one-panel notice ("Your profile could not be read; it was kept as profile.bad.json and a new one was started.") with OK focused; OK clears `last_error`.
8. **Save folder:** `RunFlow.save_dir` (static, default `user://`) for the profile and the settings, so tests use a scratch folder.
9. **Settings (D-157):** `user://settings.json` = `{"schema_version": 1, "slow_time_placing": bool}`, toggles only. `SettingsStore.load_into_run_flow(dir)` runs in `game_view._ready` (every scene load, so the file is the one truth): missing file, unreadable JSON, not a Dictionary, a newer version or a wrong type = the defaults (off), with a `push_warning` for the unreadable cases and no notice (nothing of value is lost); unknown keys are ignored. Each toggle of Slow time (start screen and pause menu) sets `RunFlow.slow_time_placing` and calls `SettingsStore.save(dir)` at once: a plain write, not the profile's tmp + rename (a torn write loses one toggle, which loads as the default). Nothing reads it in `sim/`; the bench and tests that never call `save` never write it.
10. **No hearts before the first wave (D-158):** `MetaProfile.hearts_for(run, won, clock)` returns 0 when `not won and clock < run.first_wave_tick` (the tick the wave spawner starts wave 0); unchanged after that. `record_run` still counts the run and the loss and still updates `best_sec` (D-160: longest time survived). The abandon confirm shows the same value ("You keep 0 hearts" in the first seconds).

### Files
1. `sim` `game/sim/meta_catalog.gd` (+8): `branch`, `name_key`, `desc_key` per node; `waifu_name_key` per waifu; `starters` (status `starter`, id order). Load time only.
2. `sim` `game/sim/meta_profile.gd` (+10): `enum Roster { STARTER, RESCUED, LOCKED }`, `roster_state(cat, waifu_id)`; rule 10 in `hearts_for` (2 lines). No tick code changes, so no hash or determinism impact.
2b. `save` `game/save/settings_store.gd` (new, ~35): `FILE := "settings.json"`, `load_into_run_flow(dir)`, `save(dir)` (rule 9).
3. `save` `game/save/profile_store.gd` (+4): `record_run_end` returns `{"hearts": int, "unlocked": String}` ("" = no new unlock); update `test_profile_store.gd`.
4. `view` `game/view/run_flow.gd` (+20): `enum Screen { START, HUB }`, `screen`, `restart_waifu`, `save_dir`; the header comment drops "session-only"; `start_rescue(world, profile, cat, waifu)` (seed, log line, queue; returns false when `start_command` is null).
5. `view` `game/view/ui/hub.gd` + `hub.tscn` (new, ~140 + ~90): rules 2, 3, 4, 7; buttons built in code from `MetaCatalog`, rebuilt only on open and after a buy; signal `back_pressed`.
6. `view` `game/view/ui/start_screen.gd` / `.tscn` (~7): Start run -> Play, emits `start_pressed` (game_view opens the hub); the Slow time toggle also saves (rule 9).
7. `view` `game/view/ui/pause_menu.gd` / `.tscn` (+37): rule 6, a confirm panel (Label, Cancel, Abandon) inside the menu; signals `abandon_confirmed`, `restart_confirmed` after the record; the Slow time toggle also saves (rule 9).
8. `view` `game/view/ui/end_screen.gd` / `.tscn` (+20): rule 5; Hearts and Unlock labels, Continue button.
9. `view` `game/view/game_view.gd` (~27 changed): `_ready` loads the settings (rule 9), then picks the screen from `RunFlow` (restart_waifu -> load the profile and `start_rescue`; HUB -> hub; else start screen); `RUN_ID` and the old `start_run` go; the 035 `_recorded` hook moves to the end screen.
10. `view` `game/view/main.tscn`: Hub instance after StartScreen.
11. `data` `game/loc/strings.csv`: `flow.play`, `flow.abandon`, `flow.abandon_confirm`, `flow.cancel`, `flow.continue`, `flow.hearts_earned`, `flow.unlocked`, `hub.title`, `hub.hearts`, `hub.rescue`, `hub.best`, `hub.back`, `hub.branch.economy|guardian|towers`, `hub.node.cost`, `hub.node.locked`, `hub.node.owned`, `hub.roster`, `hub.roster.starter|rescued|locked`, `hub.notice.bad_profile`, `hub.notice.ok`.

### Tests (headless)
- `game/tests/view/test_hub.gd` (new, scratch `user://test_hub/` removed in `after_each`, `RunFlow` statics reset): offer buttons = `offer()` at 0 rescued (Cinder, Bastia, Clover), Cinder rescued (Bastia, Clover, Hymn), all 6 (6 buttons); pressing Bastia's button queues a StartRun that, after one step, has `run.id == "run_m3"`, `guardian_id == "guardian_bastia"` and the bought nodes applied (gold 250 with `meta_gold_1`); buying `meta_gold_1` with 60 hearts leaves 0 hearts and the node in the file, and the button shows Bought; `meta_gold_2` LOCKED and a NO_HEARTS buy leave the file bytes unchanged; roster: Pip Starter, Cinder Rescued, Bastia Locked; the notice shows when `last_error` is set and OK clears it; the first rescue button has focus on open.
- `game/tests/view/test_menus.gd` (extend): Abandon at clock 13 500 on a `run_m3` / `guardian_cinder` world shows "40" in the confirm text, Cancel focused, Cancel writes nothing; Abandon writes hearts 40 and losses 1 and sets `RunFlow.screen = HUB`; the Restart confirm writes the loss and sets `restart_waifu = "waifu_cinder"`; end screen on WON: file hearts 100, Cinder unlocked, labels show +100 and her name; refreshing twice records once; LOST shows no unlock line.
- `test_profile_store.gd`: the new return value.
- `test_meta_profile.gd` (update + extend, D-158): `hearts_for(run, false, first_wave_tick - 1)` = 0, `hearts_for(run, false, first_wave_tick)` = the 6.1 value (30 + rounding), 13 500 still 40, a win at clock 0 still 100; `record_run` at clock 0 adds 0 hearts but runs 1, losses 1. The old "clock 0 = 30" assertion becomes 0.
- `game/tests/save/test_settings_store.gd` (new, scratch folder): missing file = off; save on, load = on; garbage JSON, a list, `schema_version` 2 and `"slow_time_placing": "yes"` each load as off; an unknown key is ignored. In `test_menus.gd`: toggling Slow time on the start screen writes the file.
- In `test_menus.gd`, the abandon confirm before the first wave (clock 0) shows "0" and records 0 hearts with losses 1.
- No sim rule change, so no new determinism test. Perf: nothing per tick (the hub shows only while IDLE; its text is rebuilt on open and after a buy).

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 2 (the Run flow paragraph and the "Main scene" sentence: hub, `run_m3`, `RunFlow.screen`, the end screen records the run) and 7 (the run-end write moves to the end screen).
- `09_CONTROLS.md` Menus: the new screen list, hub navigation (GUI focus across the offer row, the three columns and the roster; `ui_cancel` = Back), the abandon confirm (Cancel focused); the Slow time line: "kept for the session only (saved settings are M3)" becomes "saved in `settings.json` (D-157)".
- `02_TECH_ARCHITECTURE.md` 7: `hearts_for` gains the D-158 clause; the settings file (rule 9) next to the profile.
- `DECISIONS.md`: D-154 PROPOSED (rules 1-10). Rows D-125, D-155..D-162 are not edited (append-only).

### Order
1. `MetaCatalog` fields, `roster_state`, the D-158 line, the `record_run_end` return value and their tests; `SettingsStore` and its test. 2. `RunFlow`, hub scene and script, `test_hub.gd`. 3. Pause confirm, end screen, start screen, `game_view`, `main.tscn`, `test_menus.gd`. 4. Strings, docs, D-154; `scripts/test.ps1` twice, `scripts/validate.ps1`; one manual run (`scripts\run.ps1`) through start -> hub -> run -> abandon -> hub for the PR note.

## Questions
Answered by the owner (commit d10b41a): Q-72 -> D-155 (confirm, Cancel default, then the hub: rule 6 as planned), Q-70 -> D-157 (settings file: rule 9), Q-76 -> D-158 (rule 10), Q-73 -> D-161 (rule 7 as planned), Q-78 -> D-160 (`best_sec` as 035 built it). Still open, non-blocking (the plan's readings, an owner check at review):
- Restart in the pause menu counts as an abandon (loss hearts recorded, 0 before the first wave) and starts a new run with the same Guardian (rule 6).
- The end screen keeps one button, Continue to the hub (Restart and Main menu removed there) (rule 5).
- A loss or abandon before the first wave still counts in `runs` and `losses` (rule 10; D-158 only speaks of hearts).
- For 036: D-156 (closing mid-wave rewinds to the last suspend save) is noted in 036's Context; the Resume / Abandon choice will sit on the start screen or the hub of this task.

## Review log
- 2026-10-10 lead-dev: approved, PR #48 squash-merged into m3/dev. All criteria met; D-165 (hearts_min_sec 60, replaces D-158) and D-166 applied; D-154 PROPOSED. Tests 378/378 green twice on the branch, 388/388 after merging m3/dev (040), validator green. Code ~480 lines, over the ~420 split line but one cohesive flow; settings (36 lines) not split out. Resolved a docs-only conflict in 02_TECH_ARCHITECTURE 2 (040 + 039 Main scene sentence). Nit for later: test_record_run_before_the_first_wave keeps its D-158 name. Needs the owner playtest (start -> hub -> run -> abandon / win -> hub).
