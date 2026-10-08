# 008 — Benchmark scene and perf report command
- Status: review
- Milestone: M1
- Depends on: 004, 005, 007
- PR: #12

## Goal
A fixed, seeded benchmark scenario that outputs FPS and frame-time numbers as JSON, runnable with one command.

## Context
- `02_TECH_ARCHITECTURE.md` 4 (budgets), 6 (perf benchmark scene)
- D-042 stress cases; `04_AGENT_WORKFLOW.md` 5 (`/reports/perf_<date>.json`)
- From 007: `SimWorld.recycle_radius` (respawn arrived enemies on a ring) and `HordeRenderer.last_fill_usec` (view fill cost per frame)

## Acceptance criteria
- Scenarios: PC typical (3000 enemies + 50 towers), PC stress (3000 + 300 towers), Deck typical (1500 + 50), Deck stress (1500 + 150).
- Enemies must keep moving for the whole measurement (for example respawn on the ring any enemy that reaches the Guardian, or a larger ring); otherwise they stop after about 280 ticks and the per-tick cost is understated (found in 002).
- Each runs a fixed number of seconds after warm-up and records average and 1%-low FPS, frame time, and sim step time per tick (ms).
- Per-phase sim timings (ms/tick, from `SimWorld.phase_usec`: separation, movement, grid rebuild, targeting) are reported for every scenario, measured in a release export, plus a "piled at the Guardian" worst case (3000 enemies allowed to pile up, no respawn) next to the moving-crowd cases (task 004 measured separation at ~34-45 ms/tick piled vs ~10 ms spread in headless debug).
- Targeting cost uses a realistic enemy layout around the towers: in the tower scenarios, part of the crowd walks through the tower field (towers spread over the build radius, enemies crossing it on their way to the Guardian), not only enemies outside every tower's range. Task 005 found dense cells among towers cost more than empty rings (headless debug, 300 towers / 3000 enemies: ~4-6 ms none in range vs ~10-12 ms packed among towers); report targeting ms/tick for both the moving-crowd and piled cases.
- Output: `reports/perf_<date>.json` with the machine description (CPU, GPU, OS, Godot version).
- One command `scripts\bench.ps1` (state whether it runs the exported build or the editor binary), and the Commands section of `CLAUDE.md` updated.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Design:
- **Release export, one scene.** The benchmark is a scene, `game/view/bench/bench.tscn` (root `Node`, script `bench.gd`), shipped in the normal export (`export_filter="all_resources"`) and started by passing its path to the exported exe: `build\windows\WTD.exe res://view/bench/bench.tscn -- --out=<abs path> --commit=<sha>`. A release template runs GDScript without debug checks, which is what the budgets are about. Check first that the exported exe honours the scene argument; if it does not, fall back to a user arg `--bench` read in `game_view.gd` `_ready` that calls `get_tree().change_scene_to_file(...)` (one line), and say which one in the PR.
- **Scenarios (data).** `game/data/bench/bench_m1.json`, schema `tools/schemas/bench.schema.json` (validator picks it by folder name), `additionalProperties: false` at both levels. Top level: `schema_version` (1), `id` (`^bench_[a-z0-9_]+$`), `seed` (1), `enemy_type` (`enemy_swarmer_01`), `measure_sec` (20), `build_radius` (20, D-042), `tower_range` (6, placeholder like the demo), `spawn_rings` (6), `spawn_ring_min` (24), `spawn_ring_max` (44), `recycle_radius` (40), `scenarios` (array, min 1). Each scenario: `name` (`^[a-z0-9_]+$`), `enemies`, `towers` (integers >= 0), `piled` (bool: no recycle), `warmup_sec` (> 0), `zoom` (index into the camera `zoom_sizes`), `render_scale` (0 < x <= 1). The five scenarios:

  | name | enemies | towers | piled | warmup_sec | zoom | render_scale |
  |---|---|---|---|---|---|---|
  | pc_typical | 3000 | 50 | false | 5 | 1 | 1.0 |
  | pc_stress | 3000 | 300 | false | 5 | 2 | 1.0 |
  | deck_typical | 1500 | 50 | false | 5 | 1 | 0.5 |
  | deck_stress | 1500 | 150 | false | 5 | 2 | 0.5 |
  | pc_piled | 3000 | 300 | true | 20 | 1 | 1.0 |

  Moving cases: enemies spawn on 6 rings from 24 to 44 and recycle at 40, so they keep moving for the whole run, and every one of them walks straight through the tower field (towers fill the build radius 20) on its way in: about half the crowd is inside the tower field at any time, which is the realistic targeting layout. Piled case: same spawn, `recycle_radius` 0, warm-up 20 s (44 units at speed 3.2 is about 14 s), so the 3000 enemies have piled at the Guardian, among the inner towers, before measuring. `render_scale` 0.5 sets `Viewport.scaling_3d_scale` for the Deck cases: 3D renders at about 1280x720 (close to the Deck's 1280x800 pixel count) without resizing the window.
- **Scenario setup** `game/view/bench/bench_scenario.gd` (static funcs, `RefCounted`, no Node, testable headless): `apply(world: SimWorld, cfg: Dictionary, sc: Dictionary) -> void` spawns `sc.enemies` of `cfg.enemy_type` over the rings (same loop as the demo in `game_view.gd`, remainder on the last ring so the count is exact), sets `world.recycle_radius` to 0 if `piled` else `cfg.recycle_radius`, and adds `sc.towers` towers with `cfg.tower_range` on a sunflower spiral filling the build radius: tower t at radius `build_radius * sqrt((t + 0.5) / towers)`, angle `t * 2.39996` (golden angle). Only the sim's existing test/benchmark APIs (`spawn_ring`, `towers.add`, `recycle_radius`), no rule.
- **Stats** `game/view/bench/bench_stats.gd` (static, `RefCounted`): `summarize(frame_usec: PackedInt64Array) -> Dictionary` with `frames`, `avg_fps` (frames / total time), `low1_fps` (1e6 / mean of the slowest 1% of frames, at least one frame), `frame_ms_avg`, `frame_ms_p99` (sorted, index `ceili(0.99 * n) - 1`), `frame_ms_max`.
- **Sim timing hook (sim, 3 lines).** `SimDriver` may run 0-5 steps per frame, so the last-step `phase_usec` alone is not enough. Add `SimWorld.phase_usec_sum: PackedInt64Array` (4 zeros), incremented in `_lap` next to `phase_usec`; diagnostics only, not in `state_hash()`, the caller resets it. Per-tick averages = sum / ticks run (`world.tick` delta).
- **Runner** `game/view/bench/bench.gd` (view, `extends Node`):
  - `_ready`: read user args (`OS.get_cmdline_user_args()`: `--out=`, `--commit=`; default out `user://perf_<YYYY-MM-DD>.json`), load the bench JSON, `DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)`, `Engine.max_fps = 0`, `RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)`.
  - Per scenario, in order: instance `res://view/main.tscn`; before adding it, set `view.demo = false`, `view.world = SimWorld.new(cfg.seed)`, `view.driver = SimDriver.new(view.world)` and call `BenchScenario.apply(...)`; add it; then `rig.set_process(false)` and `rig.set_process_unhandled_input(false)` (no pan from the mouse or keys during a run) and `rig.set_zoom(sc.zoom)`; set `get_viewport().scaling_3d_scale`. Warm up `warmup_sec`, then reset the sums and measure for `measure_sec` (wall time from `Time.get_ticks_usec()`); each frame record the frame time (usec since the previous frame) and add `HordeRenderer.last_fill_usec`, `Performance.TIME_PROCESS`, `RenderingServer.viewport_get_measured_render_time_cpu/gpu`. At the end, read `phase_usec_sum` and the ticks run, compute `mean_speed` (mean of `|pos - prev| / SIM_DT` over the enemies, from `driver.prev_x/z`: proves the crowd moves, near 0 when piled) and free the instance. A small state machine in `_process` (warm-up, measure, next) is enough.
  - After the last scenario write the JSON (`JSON.stringify(report, "  ")`), print a one-line summary per scenario to stdout, `get_tree().quit(0)` (1 if the file cannot be written).
- **Report** `reports/perf_<YYYY-MM-DD>.json`:
  - `machine`: `OS.get_name()`, `OS.get_version()`, `OS.get_processor_name()`, `OS.get_processor_count()`, `RenderingServer.get_video_adapter_name()`, `get_video_adapter_vendor()`, `get_video_adapter_api_version()`, rendering method, `Engine.get_version_info().string`, `release` (`not OS.is_debug_build()`), window size, `commit`, date and time.
  - `scenarios[]`: the scenario's own fields, plus `render_size` (3D render pixels), the frame stats from `BenchStats`, `sim` {`ticks`, `ticks_per_sec` (shows dropped time when the frame rate falls under 6 FPS), `step_ms_avg`, `phase_ms_avg` {`separation`, `movement`, `grid`, `targeting`}}, `view` {`fill_ms_avg`}, `cpu_gpu` {`process_ms_avg` (whole `_process`, includes sim and fill), `render_cpu_ms_avg`, `gpu_ms_avg`}, `mean_speed`.
  - The `cpu_gpu` split is what 009 needs for the Deck estimate (D-080): CPU-side and GPU-side times can be scaled separately by the Deck's CPU and GPU ratios. Skipped: a separate capped-FPS run; add it only if 009 cannot work from the split.
- **Command** `scripts/bench.ps1` (tools): dot-source `_common.ps1`, run `scripts\export.ps1` (always: the bench must measure the current code), then `Start-Process -Wait` the exported `build\windows\WTD.exe` with the scene path, `--resolution 2560x1440` and the user args (`--out` = absolute `reports\perf_<date>.json`, `--commit` = `git rev-parse --short HEAD`); fail if the exit code is not 0 or the file is missing; print the path. If Windows clamps the window below 2560x1440 on a 1440p monitor, use `--fullscreen` instead; the JSON records the real size either way. About 2.5 minutes.
- `game/view/game_view.gd`: `var demo: bool = true`; the demo setup in `_ready` runs only when `demo` (the bench sets its own scenario). `game/view/iso_camera.gd`: rename `_set_zoom` to `set_zoom` (public, used by the bench).

Files:
1. `game/data/bench/bench_m1.json` (data, new), `tools/schemas/bench.schema.json` (tools, new), `tools/tests/test_validate_data.py` (tools, change).
2. `game/sim/sim_world.gd` (sim, change): `phase_usec_sum`.
3. `game/view/bench/bench_scenario.gd`, `bench_stats.gd`, `bench.gd`, `bench.tscn` (view, new).
4. `game/view/game_view.gd`, `game/view/iso_camera.gd` (view, change).
5. `scripts/bench.ps1` (tools, new).
6. `reports/perf_<date>.json` from the PR's own run (committed: 009 reads it).
7. Docs: `CLAUDE.md` Commands ("Perf benchmark: `scripts\bench.ps1`, exports and runs the release build, writes `reports/perf_<date>.json`, about 2.5 min"); `02_TECH_ARCHITECTURE.md` 6 (perf benchmark as built: scenarios in `data/bench`, release export, metrics and their definitions) and 3a (`phase_usec_sum`); D-088 (PROPOSED) in `DECISIONS.md`: benchmark method (release export, five scenarios including the piled worst case, `render_scale` 0.5 as the Deck pixel proxy, 1%-low definition, CPU/GPU split for the Deck estimate). Section 4 numbers are 009's job.

Tests (headless, GUT):
- `game/tests/view/test_bench_stats.gd`: 99 frames of 10 000 usec + 1 of 50 000 give `frames` 100, `frame_ms_avg` 10.4, `low1_fps` 20, `frame_ms_p99` 10, `frame_ms_max` 50; a single frame does not crash.
- `game/tests/view/test_bench_scenario.gd`: with the config from the real `bench_m1.json` and small scenario counts set in the test: enemy count exact (including a count not divisible by the rings), tower count, every tower within `build_radius`, `recycle_radius` 0 when piled and `cfg.recycle_radius` otherwise; a moving scenario with 300 enemies / 20 towers stepped 300 ticks keeps the count, has at least one tower with a target and at least one enemy inside the build radius (the crowd crosses the tower field).
- `game/tests/sim/test_sim_world.gd`: after 3 steps, `phase_usec_sum` has 4 entries and each is >= the matching `phase_usec`.
- `tools/tests`: the validator accepts `bench_m1.json` and rejects a scenario with an extra field.
- The bench itself needs a GPU, so it is not in the headless suite: the PR states the `scripts\bench.ps1` run (machine and the 5 summary lines) and commits its JSON.

Performance notes:
- The runner adds per frame a few appends and 3 RenderingServer reads; negligible next to the fill. The only growing allocation is the frame-time list (about 3000 entries per scenario at 150 FPS).
- Vsync off and `max_fps` 0, otherwise every case reads 60 FPS on a 60 Hz monitor. Frame time is about max(CPU, GPU), so the split tells which side bounds each case.
- Piled separation in release is the number to watch (task 004: about 40 ms/tick in headless debug). The report only measures it; optimisation is 009's call.

Order: data + schema + validator test; `phase_usec_sum` + test; `bench_stats` + test; `bench_scenario` + test; `game_view` `demo` flag and `set_zoom`; `bench.gd`/`bench.tscn`, run first from the editor binary (`--path game res://view/bench/bench.tscn`); `scripts\bench.ps1` against the export (check the scene argument); commit the JSON; docs and D-088; `scripts\test.ps1` twice; `scripts\validate.ps1`.
Size: about 300-350 lines of code and tests plus data, one PR.

## Questions

## Review log
