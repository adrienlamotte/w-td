# 036 — Save: suspend save and resume
- Status: review
- Milestone: M3
- Depends on: 032, 033, 034, 035, 039, 045
- PR: #51

## Goal
A run survives closing the game: a snapshot at card and wave boundaries, and Resume or Abandon on the next launch.

## Context
- `docs/10_M3_CONTENT.md` 7 (written when a draft opens and at `WAVE_STARTED`, never mid-wave; full sim state with RNG states, command queue and clock, plus `state_hash()` checked on load; a snapshot, not a replay; derived grids and fields rebuilt; deleted at run end; abandon = loss, hearts per 6.1).
- D-053, `docs/02_TECH_ARCHITECTURE.md` 7.
- D-156: closing the app mid-wave rewinds to the last suspend save (card or wave boundary); a run is resumable only from a suspend save. Settings are not part of it: 039 saves them in `user://settings.json` (D-157) and fixes the `09_CONTROLS.md` line.
- D-165 (replaces D-158): a loss or abandon before 60 s of run time (`hearts_min_sec`) gives 0 hearts; discarding a suspended run is an abandon (`10_M3_CONTENT.md` 6.1). D-166: such runs still count in `runs` and `losses`.

## Acceptance criteria
- Snapshot write and read of every hashed world field; load rebuilds derived state (spatial grid, build grid, flow field, uid index, derived tower stats) and checks `state_hash()` against the saved one; a mismatch or unreadable file is reported and the run counts as abandoned, never silently resumed.
- A resumed run continues identically: run N ticks with a save in the middle, reload, continue, same hash as an uninterrupted run (once with a draft open, once at a wave start).
- Start screen: Resume / Abandon when a suspend file exists; Abandon grants loss hearts.
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan
Decision: **D-167** (PROPOSED, add the row in this PR). Reading of D-053, D-156, D-165, D-166 and `10_M3_CONTENT.md` 7; no new design. Target size: about 380 changed lines (tests included), no data files.

### Key technical facts (read before coding)
- The flow field is time-sliced (`FlowField.CELLS_PER_TICK` = 4000; the `run_m3` grid is about 96 x 96 cells, so one recompute spans several ticks) and keeps the old published arrays while it runs. A field rebuilt in full on load only equals the live one when the live one is **settled**: not `busy()` and computed for the current `BuildGrid.version` (a tower death in ATTACKS bumps the version after PATH). So a save is only written when the field is settled (rule 2). This is the one place where "rebuilt on load" could silently diverge; the determinism tests below must place towers shortly before each save point.
- JSON numbers are doubles. Write with `JSON.stringify(d, "\t", false, true)` (full precision: float32 and float64 round-trip exactly). Ints above 2^53 do not: the three RNG `state` values go as strings (`str()` / `String.to_int()`). Restore an RNG by setting `state` only (the PCG increment is the engine default; never set `seed` after `state`).
- Non-hashed state that changes the future and must be saved: the command queue `_queue`, `towers.footprint`, the RNG states, the run-scope caches (`xp_mult`, `kill_gold_mult`, `max_build_radius`, `rebuild_mult`, `detour_mult`) and `paused`. Everything else not hashed is per-tick scratch (separation, movement `dir_x` / `dir_z` / `gap`, attack `_hits`, events) or derived (below).
- `TowerStats.recompute` is idempotent only when `towers.stats_dirty` is false (it clears and re-appends the `layout` modifier entries; with a pending change it would reorder the store and move HP). When dirty, the next PATH phase recomputes before anything reads the links, as in the live run.

### Rules (D-167)
1. **Snapshot** (`user://suspend.json`, atomic like the profile): `schema_version` 1, a header (`run_id`, `guardian_id`, `run_seed`, `clock`), then the sim state and `state_hash`. Any other `schema_version` is unreadable (no migration for a suspend save: it lives one run).
2. **When written:** a boundary (a draft opened in this step: a `LEVEL_UP` or `CARD_PICKED` event with `draft.drafting` true after the step; or a `WAVE_STARTED` event) marks a save pending. The pending save is written at the end of the first step, at or after the boundary, where the run is `RUNNING` and the flow field is settled; a later boundary replaces it. In practice this is the boundary tick itself; only a layout change in the last few ticks before it delays the write by a few ticks (a draft opened with an unsettled field is saved right after the pick). Never written once the run is WON or LOST, never by the bench or the balance bot (only `game_view` in demo mode installs the saver).
3. **Deleted at run end:** `ProfileStore.record_run_end` deletes it (the one path every run end takes: end screen, pause Restart / Abandon run, start-screen Abandon run).
4. **Start screen:** when `suspend.json` exists, Play is replaced by **Resume** and **Abandon run**. Abandon run opens the same confirm as the pause menu (`flow.abandon_confirm` with the loss hearts at the saved clock, Cancel focused, D-155 pattern), then records the run as a loss at the saved clock (0 hearts under `hearts_min_sec`, D-165; counted in runs and losses, D-166), deletes the file and shows Play.
5. **Resume:** restores the snapshot into the fresh `game_view.world` and hides the start screen; the views poll the world, so nothing else is needed.
6. **Failure** (unparsable, wrong version, unknown run or Guardian id, wrong types, `state_hash` mismatch): never resumed. The file is renamed `suspend.bad.json` (replacing an older one), `SuspendStore.last_error` is set, and the scene reloads to the start screen, which shows a notice (`flow.suspend_failed`). If the header was readable, the run is recorded as an abandon at the saved clock (rule 4); if not even the header is, there is nothing to attribute and no run is recorded.

### Files
- `sim/sim_snapshot.gd` (new, **sim**, about 120 lines): `SimSnapshot.capture(w) -> Dictionary` and `restore(w, d) -> String` ("" = OK, else the reason). No file access. Per object (`SimEnemies`, `SimTowers`, `SimModifiers`, `GuardianSkills`, `CardDraft` minus `rng`): every script variable from `get_property_list()` (`PROPERTY_USAGE_SCRIPT_VARIABLE`), restored with `type_convert(value, typeof(current))` after checking the JSON type (Array for packed arrays, number, bool, String), so a field added later is saved without touching this file. SimWorld scalars and the queue (`SimCommand` fields as a dict, `type` as int) are an explicit list. It may read `w._spawn_rng`, `w._loot_rng`, `w._queue` (documented as SimWorld's snapshot friend). Restore order: header -> `w.run = RunData.load_id(...)` (ids checked to exist in `data/runs` and `data/guardians` first) and `w.clock` (so a later failure can still be recorded as an abandon) -> `movement.set_stop(catalog, run.guardian_contact_radius)` -> state -> derived: `build = BuildGrid.new(max_build_radius, run.grid_step)` filled from every built tower (`fill(cell_i, cell_j, footprint, uid, 0 if husk else 1)`), `field = FlowField.new(build, run.guardian_contact_radius)` + `update(FULL)`, `_rebuild_grid()`, `towers.refresh_uid_index(next_tower_uid)`, `TowerStats.recompute(w)` only if not `stats_dirty` -> compare `state_hash()` with the saved one.
- `sim/sim_world.gd` (**sim**, about 6 lines): `var run_seed: int` set at START_RUN (not hashed; for the header and repro logs). `_rebuild_grid` stays as is (the snapshot is its friend).
- `sim/flow_field.gd` (**sim**, 3 lines): `settled() -> bool` = `_stage == Stage.IDLE and _version == grid.version`.
- `save/suspend_store.gd` (new, **save**, about 90 lines): `SuspendStore` static `exists(dir)`, `save(world, dir)`, `load_into(world, dir) -> bool` (sets `last_error`, renames to `suspend.bad.json` on failure), `delete(dir)`, `header(dir) -> Dictionary` (for the Abandon confirm hearts). Atomic write: move the temp-and-rename body of `ProfileStore.save_profile` into `ProfileStore.write_atomic(path, text) -> Error` and use it from both.
- `save/suspend_saver.gd` (new, **save**, about 30 lines): `SuspendSaver` (RefCounted) with `dir` and `on_step(world)` implementing rule 2 (one `pending` flag).
- `save/profile_store.gd` (**save**): `write_atomic`; `record_run_end` calls `SuspendStore.delete(dir)`.
- `view/game_view.gd` (**view**, about 25 lines): demo mode creates a `SuspendSaver` on `RunFlow.save_dir`; `driver.on_step` calls `$FxLayer.on_step` then the saver (one lambda). Resume: `SuspendStore.load_into(world, RunFlow.save_dir)`; OK -> hide the start screen; failure -> `record_run_end` if `world.run` is set, `RunFlow.screen = START`, `reload()`. Abandon run (after the confirm): restore into the world the same way (or the failure path), `record_run_end`, reload to the start screen.
- `view/ui/start_screen.gd` + `start_screen.tscn` (**view**, about 45 lines): `Resume`, `Abandon` and a `Confirm` box (Text, Cancel, Abandon) and a `Notice` label; `resume_pressed` / `abandon_confirmed` signals; on every show: Play hidden and Resume / Abandon run shown when `SuspendStore.exists`, notice shown while `SuspendStore.last_error != ""` (cleared when dismissed, like the hub notice). Hearts in the confirm: `MetaProfile.hearts_for` with a `RunData` loaded from the header (0 if the header is unreadable).
- `loc/strings.csv` (**data**): `flow.suspend_failed` ("Your suspended run could not be restored. It counts as abandoned."). Reuse `flow.resume`, `flow.abandon`, `flow.abandon_confirm`, `flow.cancel`.
- `tests/sim/test_meta_profile.gd`: rename `test_record_run_before_the_first_wave` to `test_record_run_before_hearts_min_sec` (039 review nit, D-165).
- Docs: `docs/02_TECH_ARCHITECTURE.md` 7 (a "Suspend save (D-167, task 036)" paragraph: classes, rules 1-6, the settled-field condition); `docs/10_M3_CONTENT.md` 7 (one clause: written at the first tick at or after the boundary with a settled path field, in practice the boundary itself; the start screen shows Resume / Abandon run instead of Play); `docs/DECISIONS.md` D-167 PROPOSED; `docs/09_CONTROLS.md` only if it lists start-screen buttons.

### Tests (headless)
- `tests/sim/test_sim_snapshot.gd` (new): a helper builds a `run_m3` world with a Guardian, places several towers, upgrades one, uses a skill. (a) **Draft case:** step until `draft.drafting` (raise `draft.xp` the same way in both worlds if a natural level-up takes too long), with a tower placed a few ticks before so the field has recomputed; capture -> `JSON.stringify` (full precision) -> parse -> restore into `SimWorld.new(999)` (another seed: proves the RNG states come from the file); hash equal; `field.dist` and `field.dir` equal to the live world's; queue the same `PICK_CARD` in both, step 600 ticks, hashes equal. (b) **Wave case:** the same at the first `WAVE_STARTED` with a settled field, 600 ticks after, equal (enemies alive; a husk if one tower can be made to fall). (c) A queued future command survives the round trip. (d) Restore fails with a reason (not a crash) on: wrong `schema_version`, unknown `run_id`, a packed array replaced by a string, `gold` edited (hash mismatch).
- `tests/save/test_suspend_store.gd` (new, scratch `dir`): save/load round trip through the file; garbage file -> false, `last_error` set, `suspend.bad.json` exists, `suspend.json` gone; `record_run_end` deletes `suspend.json`; `SuspendSaver`: a `WAVE_STARTED` step writes the file, a mid-wave step does not rewrite it, an unsettled field at the boundary defers the write to the first settled step, a WON or LOST world never writes.
- `tests/view/test_menus.gd` (or a new `test_start_screen.gd`): with a suspend file, Play hidden and Resume / Abandon run shown; Abandon run -> confirm (Cancel focused) -> confirm records a loss in the scratch profile (hearts = `hearts_for` at the saved clock), the file is gone, Play shown; with `last_error` set the notice shows.
- Determinism: no rule changes (only `run_seed` and `settled()`), so `test_determinism` and `test_replay` stay as they are; the snapshot tests above are the new determinism checks. Run the suite twice.

### Performance
- A save runs on the main thread at a wave start (a draft is frozen anyway): `JSON.stringify` of all enemy and tower arrays. Print the save time for a 2000-enemy world in `test_suspend_store` (`gut.p`); budget about 10 ms. If it is over, say so in the PR (043 re-benches). `ponytail:` comment on the save call: synchronous write; move the stringify and write to a `WorkerThreadPool` task, with the dict captured on the main thread, if 043 shows a wave-start hitch.
- Nothing per tick: the saver's per-step check is one scan of the last step's events and two bools. The bench and the balance bot never install it.

### Order of steps
1. `FlowField.settled()`, `SimWorld.run_seed`; `SimSnapshot` + `test_sim_snapshot.gd` (draft and wave cases green before any I/O).
2. `ProfileStore.write_atomic`, `SuspendStore`, `SuspendSaver`, the delete in `record_run_end`; `test_suspend_store.gd`.
3. Start screen, `game_view` wiring, loc key; view test.
4. Test rename (nit), docs, D-167 row; `scripts\test.ps1` twice, `scripts\validate.ps1`; play once by hand: start a rescue, wait for wave 2, close the window mid-wave, relaunch, Resume (back at the wave 2 start); repeat and Abandon run.

## Questions

## Review log
