# 021 — UI: run flow, pause, win and lose screens
- Status: done
- Milestone: M2
- Depends on: 014, 020, 027
- PR: #31

## Goal
A complete loop from start to end: start screen, run, pause menu, win/lose screens, restart.

## Context
- `06_ROADMAP.md` M2 (win/lose screens), D-046 (slow-time-while-placing accessibility option)

## Acceptance criteria
- Start screen → run → pause menu (resume, restart, quit) → win or lose screen with time survived → restart.
- Slow-time-while-placing toggle as an accessibility option.
- Works fully with gamepad and with mouse/keyboard.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-125** (PROPOSED: run flow rules below). View and input only; no sim change (StartRun, Pause, WON/LOST and `clock` already exist, D-100, D-107). Session-only settings (saves are M3).

### Rules (D-125 PROPOSED)
- **Flow:** `main.tscn` stays the main scene (the `--bench` redirect stays in `game_view._ready`). The world starts IDLE behind a **start screen** overlay (title, Start run, Slow time while placing toggle, Quit game). Start run -> `game_view.start_run()` queues `StartRun(seed, "run_m2")`; the seed comes from a view-local `RandomNumberGenerator` with `randomize()` (never global `randi()`) and is printed to the log for repro. **Restart** and **Main menu** reload the scene (`get_tree().reload_current_scene()`): a fresh `SimWorld` and fresh views, no reset code. `RunFlow.autostart = true` before a Restart makes the new scene start a run at once instead of showing the start screen.
- **Pause menu:** shown while `run_state == RUNNING and paused`: title (`hud.paused`, moved from the HUD label, which is deleted), Resume, Restart, Slow time toggle, Main menu. Resume, and `ui_cancel` (Esc / B) while the menu is shown, queue `Pause(false)` through a new `PlayerInput.set_paused(on)`; the menu calls `set_input_as_handled()` so Esc does not also reach `PlayerInput` (the menu is after `PlayerInput` in the tree, so it gets `_unhandled_input` first). Start / P keep toggling through `PlayerInput` as today. Pausing clears the selection and closes the radial (like `build_cancel`), so nothing is half-placed while paused (D-105).
- **Pause gate:** `PlayerInput` queues `Pause` only while `run_state == RUNNING` (no pausing behind the start or end screen). The sim rule is unchanged.
- **End screen:** shown while `run_state` is WON or LOST: title `flow.won` / `flow.lost`, `flow.time_survived` "Time survived: {time}" with `Hud.mmss` of `world.clock * SIM_DT` (whole seconds, floor), Restart, Main menu. The sim already freezes on WON/LOST.
- **Slow time while placing (D-046 accessibility option):** `RunFlow.slow_time_placing` (static var, default **off**, session only: it survives the scene reload, not a restart of the game). While on, `PlayerInput.is_placing()` and `PlayerInput.can_build(world)`, `game_view._process` calls `driver.advance(delta * slow_time_scale)` instead of `driver.advance(delta)`. `slow_time_scale` (placeholder 0.5) is in `data/ui/ui_default.json`. **Determinism:** only the rate at which whole ticks run changes; every tick is the same `SIM_DT` step with the same content, and commands are still stamped with `world.tick`, so a replay is identical. Do not use `Engine.time_scale` (it would slow the camera and input too). Camera pan, the radial and the ghost keep real time (unscaled frame `delta`); fx lifetimes are view seconds and stay real time (accepted, placeholder look).
- **Navigation:** menus use Godot GUI focus (`ui_up/down/accept/cancel`; check the default bindings cover d-pad, left stick, A, Enter and arrows in `project.godot`, add any missing gamepad event there) and the mouse. Each menu calls `grab_focus()` on its first button when it becomes visible. Menu buttons keep `mouse_filter = STOP` (they are not HUD); the build bar keeps `FOCUS_NONE`, so focus never lands on it. All labels and buttons follow the theme (font >= 32).

### Files
1. `view` (new) `game/view/run_flow.gd`, `class_name RunFlow extends RefCounted`: `static var autostart: bool`, `static var slow_time_placing: bool`, `static func time_scale(on: bool, placing: bool, can_build: bool, slow: float) -> float`. About 15.
2. `view` (new) `game/view/ui/start_screen.tscn` + `start_screen.gd` (`StartScreen extends CanvasLayer`): opaque panel, title `flow.title`, buttons `flow.start`, `flow.quit`, `CheckButton` `flow.slow_time` bound to `RunFlow.slow_time_placing`; signals `start_pressed`, `quit_pressed`. About 35.
3. `view` (new) `game/view/ui/pause_menu.tscn` + `pause_menu.gd` (`PauseMenu extends CanvasLayer`): `setup(world, input)`, visibility from the world each frame, the toggle, `ui_cancel` -> resume; signals `restart_pressed`, `main_menu_pressed`. About 50.
4. `view` (new) `game/view/ui/end_screen.tscn` + `end_screen.gd` (`EndScreen extends CanvasLayer`): `setup(world)`, title and time rebuilt when the state changes; signals `restart_pressed`, `main_menu_pressed`. About 40.
5. `view` `game/view/game_view.gd` + `main.tscn`: the three overlays (after `PlayerInput` and `Hud`), `start_run()`, `restart()` / `main_menu()` (set `RunFlow.autostart`, reload), autostart or show the start screen when `demo`; all three hidden when `demo == false` (bench); scaled `advance`. About +35.
6. `input` `game/input/player_input.gd`: `set_paused(on)`, Pause only while RUNNING, clear selection and radial on pause. About +10.
7. `view` `game/view/ui/hud.gd` / `hud.tscn`: delete the `Paused` label. About -5.
8. `data` `game/data/ui/ui_default.json` + `tools/schemas/ui.schema.json`: `slow_time_scale` (number, `exclusiveMinimum` 0, `maximum` 1; placeholder 0.5).
9. `data` `game/loc/strings.csv`: `flow.title`, `flow.start`, `flow.quit`, `flow.resume`, `flow.restart`, `flow.main_menu`, `flow.slow_time`, `flow.won`, `flow.lost`, `flow.time_survived`.

### Tests
- `tests/view/test_run_flow.gd`: `time_scale()` truth table (off -> 1; on, placing and can build -> slow; on but not placing, or paused -> 1). **Determinism:** two worlds with the same seed and the same commands at the same ticks, one driven by `SimDriver.advance` at full delta, the other with some deltas scaled by 0.5, give the same `state_hash()` once both reach the same tick.
- `tests/view/test_menus.gd` (world + StartRun `run_m2`, `PlayerInput` with an `IsoCamera` like `test_hud.gd`): pause menu hidden while running, shown after `Pause(true)` + step, hidden before StartRun and on WON/LOST; Resume queues `Pause(false)` (not paused after a step); a `ui_cancel` event while shown resumes; pausing clears `selected_tower` and `menu_open`; `PlayerInput` ignores `pause` while IDLE and while WON/LOST. End screen hidden while running, shown with `flow.lost` when the Guardian falls (as the 014 tests force it) and `flow.won` on WON; time text = `mmss` of the clock. Start screen toggle writes `RunFlow.slow_time_placing` (reset in `after_each`). Buttons emit their signals. Every Label/Button in the three overlays has font >= 32; every `flow.*` key translates; each overlay gives focus to its first button when shown.
- `test_hud.gd`: drop the `Paused` assertions (moved to the pause menu test).
- `scripts\test.ps1` twice, `scripts\validate.ps1`; run the game: start, pause/resume (Esc, P), restart from the pause menu, lose (or force a loss), restart from the end screen, main menu, quit; mouse and keyboard; gamepad if one is plugged in, else say so in the PR.

### Performance
Nothing per tick. Overlays read two sim fields per frame and rebuild text only on change.

### Docs (same PR)
- `09_CONTROLS.md`: a "Menus" section (navigation, Esc/B resumes, Start/P toggles, pausing clears the selection, no pause outside a run); remove the 021 line from "Later".
- `02_TECH_ARCHITECTURE.md` UI bullet: run flow, scene reload as the restart, `RunFlow` session settings, slow time scales only the driver delta (determinism note).
- `DECISIONS.md`: **D-125 PROPOSED**. needs-human:playtest at CP-M2 (flow and slow-time feel; default off and 0.5 are placeholders).

### Order
1. `RunFlow`, `time_scale` and the driver scaling in `game_view`, determinism test. 2. `PlayerInput` changes, tests. 3. Pause menu (HUD label removed), tests. 4. End screen, tests. 5. Start screen, autostart and reload in `game_view`, tests. 6. Data/schema/strings, docs, D-125; run the game; tests twice, validator.

Size: about 200 lines of code (+ scenes, data, strings), about 170 of tests. One PR. Out of scope: saved settings (M3), hub and Guardian pick (M3), audio/volume options, rebinding, end-of-run rewards (M3).

## Questions

## Review log
- 2026-10-09 lead-dev: PR #31 approved and squash-merged into m2/dev. All criteria met, matches the plan (D-125 PROPOSED). Reviewer ran test.ps1 (241 GUT + 14 Python green) and validate.ps1 (0 errors). Out-of-plan change accepted: gamepad A/B added to `ui_accept`/`ui_cancel` in project.godot (engine defaults lack them; checked at runtime that Enter/KP Enter/Space/Esc are kept and d-pad + left stick are already in `ui_up/down`); no conflict with 018 bindings, the pause menu consumes `ui_cancel` only while shown. project.godot is LF, no control chars. Hidden menus release focus (checked). needs-human:playtest at CP-M2 (flow, slow-time feel, real gamepad).
