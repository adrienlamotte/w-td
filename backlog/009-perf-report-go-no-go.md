# 009 — Perf report, Steam Deck result and the 3D billboard go/no-go
- Status: planned
- Milestone: M1
- Depends on: 008
- PR: -

## Goal
Measure the budgets, record the Steam Deck result (or an estimate with a note), and write the go/no-go on the 3D billboard approach versus the pure 2D fallback.

## Context
- Roadmap M1 'done when'; `02_TECH_ARCHITECTURE.md` 4; D-019 (2.5D, PROPOSED until M1); Q-32; D-080 (no Deck: estimate from PC numbers, method recorded); D-075 (the Deck runs the Windows build through Proton)

## Acceptance criteria
- `reports/perf_m1.md`: PC results against the budgets, Steam Deck results (or an estimate with its method), bottlenecks found.
- `02_TECH_ARCHITECTURE.md` section 4 updated with measured numbers.
- A PROPOSED decision in `DECISIONS.md`: go or no-go for 3D billboards (D-019), with the evidence; the owner confirms at the checkpoint.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Mostly a measuring and writing task: two tiny code/data changes, three bench runs, one report, docs. Next free decision ID: D-089 (D-088 is the last).

Code and data (small):
1. `game/data/bench/bench_m1.json` (data): add a sixth scenario `{"name": "deck_piled", "enemies": 1500, "towers": 150, "piled": true, "warmup_sec": 20, "zoom": 1, "render_scale": 0.5}`. The Deck worst case is otherwise unmeasured; scaling `pc_piled` by enemy count is not valid (separation cost depends on density, not only count).
2. `game/view/bench/bench.gd` (view): record the method in `_machine()`: `"vsync_mode": DisplayServer.window_get_vsync_mode()` and `"max_fps": Engine.max_fps` (proves uncapped in the file itself, found in the 008 review).

Measurements:
3. Run `scripts\bench.ps1` three times on a quiet machine (no other heavy apps). After each run rename the output to `reports/perf_<date>_r1.json`, `_r2`, `_r3` (commit all three, ~6 KB each; delete nothing from 008, `perf_2026-10-08.json` stays as the 008 record). For every metric use the **median of the three runs** and give the min-max range. Average FPS above ~1000 is noise (008 review: deck_typical 1347 vs 2250 between runs): reason from ms (step, phases, fill, render CPU, GPU, frame avg and p99) and 1%-low FPS, show average FPS only as context.

`reports/perf_m1.md` (new, the owner reads it at CP-M1; plain sections, tables, no padding):
4. **Setup and method**: machine block from the JSON, release export, vsync off / uncapped, 2560x1440, warm-up, 20 s measure, 600 ticks, 3 runs median; link D-088 and the JSON files.
5. **PC vs budgets** (02 section 4), one table, a PASS/FAIL column per line:
   - 60 FPS at 3000 + 50 (`pc_typical`) and the 300-tower stress (`pc_stress`): judge on 1%-low FPS >= 60 and frame p99 <= 16.7 ms.
   - Sim per tick <= 8 ms (30 Hz tick) for typical, stress and piled; and the "under 4 ms per frame" form = `step_ms_avg * ticks_per_sec / 60` (the amortised cost at 60 FPS).
   - Expected from the 008 numbers: everything passes except `pc_piled` at about 8.5-8.7 ms/tick (slightly over 8). Say so plainly, and why it is a worst case partly made by placeholders (004 review log: no Guardian contact radius, `AT_GUARDIAN` enemies pile at the centre at ~8x overlap density; M2 adds the contact radius and deaths).
6. **Where the time goes**: per-phase table (separation, movement, grid, targeting, fill, render CPU, GPU) for every scenario; shares of the tick-frame cost. Facts already visible: separation is 65-75% of the step; targeting grows with towers (0.19 ms at 50, 1.1-1.4 ms at 300); fill <= 0.6 ms/frame; render CPU ~0.03 ms; GPU <= 0.24 ms; frames are CPU-bound and the 1%-lows are the frames on which a sim tick runs on the main thread (frame time ~ step time).
7. **Steam Deck estimate (D-080)**, method stated so a reader can redo it:
   - CPU factor `k_cpu` = single-thread performance i7-13700K / Steam Deck APU (Zen 2, 4c/8t, 2.4-3.5 GHz). Sources: at least two public single-thread benchmarks (for example PassMark CPU single-thread, Geekbench 6 single-core browser medians, or a CPU review that tests both), plus Valve's Steam Deck tech specs page for clocks. Use WebSearch/WebFetch; cite each source with URL and retrieval date in the report. If the web is not reachable, use clocks x IPC reasoning, mark every number "unverified" and say so in the PR. Give a range (expected 2.3-3x from benchmarks) and use a **pessimistic factor = top of the range + 15%** (GDScript is an interpreter: branchy, memory-latency bound, so it may scale worse than synthetic benchmarks; the Deck also shares a 15 W budget between CPU and GPU). Proton: the sim and fill are native x86 code under Proton and Godot uses Vulkan natively, so no factor; one sentence on this (D-075).
   - GPU factor `k_gpu` = the worse of FP32 TFLOPS ratio and memory bandwidth ratio, RTX 5070 Ti vs Deck (about 1.6 TFLOPS, 88 GB/s LPDDR5; TechPowerUp GPU database and Valve specs, cited), times the pixel ratio 1280x800 / 1280x720 = 1.11, times a safety factor 2 (tiny GPU loads do not scale linearly; fixed Forward+ overhead).
   - Per Deck scenario (`deck_typical`, `deck_stress`, `deck_piled`), with the expected and pessimistic factors:
     - tick frame (worst frames) ~ `k_cpu * (step_ms_avg + non_tick_cpu_ms)`, where `non_tick_cpu_ms = (frame_ms_avg * frames - step_ms_avg * ticks) / frames` (the PC is CPU-bound, so frame time ~ CPU time); compare with 25 ms (40 FPS) and 16.7 ms (60 FPS). Also show `k_cpu * frame_ms_p99` as a cross-check and keep the worse of the two.
     - other frames ~ `max(k_cpu * non_tick_cpu_ms, k_gpu * gpu_ms_avg)`; estimated average FPS (CPU side) from the one-second budget `30 * k_cpu * step_ms_avg + fps * k_cpu * non_tick_cpu_ms = 1000`, i.e. `fps = (1000 - 30 * k_cpu * step_ms_avg) / (k_cpu * non_tick_cpu_ms)`, capped by the GPU side `1000 / (k_gpu * gpu_ms_avg)`.
     - GPU headroom: `k_gpu * gpu_ms_avg` vs 25 ms.
   - Verdict per scenario: within 40-60 FPS / under 40 FPS, for expected and pessimistic. State the uncertainty plainly (estimate, not a measurement; a real Deck run is still required by M6, D-080).
8. **Optimisations already logged** (do not implement any in this task): from the 004 review log, cell size `2 * max_radius` (~40% fewer separation candidates, a D-082 change) and hoisting `catalog.max_radius` / `cell_coord` out of the inner loop; from the 005 review log, precomputing each tower's cell and ring bounds at `add`, a tighter per-cell distance bound, inlining the scan in `retarget`. For each: target phase, expected gain (rough), whether it changes a decision or a rule. Then say whether any is needed now: needed only if a PC typical/stress budget fails or the pessimistic Deck tick frame is over 25 ms; otherwise recommend them as an M2 task when combat adds per-tick work.
9. **Recommendation for the owner (not a decision): GDExtension escape hatch (02 section 1)**: now or later, with the evidence. Expected answer from the 008 numbers: later; give measurable triggers, for example PC `pc_typical` step > 8 ms/tick after M2 combat, or the pessimistic Deck tick frame > 25 ms, or a real Deck run under 40 FPS 1%-low, and only after the cheap GDScript wins above are measured. Mention the cheaper alternative for the 1%-lows (running the sim step off the main thread) as an option to evaluate, not a plan.
10. **Go/no-go on 3D billboards (D-019)**: evidence = GPU <= 0.24 ms, render CPU ~0.03 ms and fill <= 0.6 ms per frame on PC, the Deck GPU estimate with headroom, and the fact that the cost is in the sim, which the view choice does not touch (a pure 2D view would save at most the view part). Expected: GO.

Docs:
11. `docs/02_TECH_ARCHITECTURE.md` section 4: keep the target table, add a "Measured in M1 (task 009)" table (scenario, 1%-low FPS, frame p99, step ms/tick, top phase, Deck estimate expected/pessimistic tick frame) with a link to `reports/perf_m1.md`; replace "Numbers are initial guesses; M1 spike will measure" with what was measured and that the Deck line is an estimate (D-080). Keep the section **[P]** (owner confirms at CP-M1). Section 6 (benchmark): add `deck_piled` and the two recorded fields. Section 1: one line pointing to the triggers in the report.
12. `docs/DECISIONS.md`: D-089 | date | Go: keep the 3D billboard + MultiMesh view (D-019); the 2D fallback is not needed on the M1 evidence | PROPOSED | Task 009, `reports/perf_m1.md`; the owner confirms at CP-M1, then D-019 becomes DECIDED. Do not change D-019's status yourself. If the evidence says no-go, write that instead.
13. `docs/OPEN_QUESTIONS.md` Q-32: one line, "Estimated in `reports/perf_m1.md` (D-080); real Deck run pending, by M6".
14. `docs/plans/M1.md` Risks: replace the GDScript risk line with the measured result in one sentence and a pointer to the report.

Tests: no new system. The existing tests cover the change: `test_bench_scenario.gd` and the validator test load the real `bench_m1.json`, so the new scenario is validated. `scripts\test.ps1` twice, `scripts\validate.ps1`.

Order: 1-2, `scripts\test.ps1` + `scripts\validate.ps1`; 3 (three bench runs, ~3 min each); medians in a scratch table; the source lookup for 7; write the report 4-10; docs 11-14; tests twice, validator; PR to `m1/dev`. In the PR body: the PC verdict table, the Deck expected/pessimistic tick frames, the D-089 verdict, the GDExtension recommendation, and "needs the owner: CP-M1 confirms D-089 and reads `reports/perf_m1.md`".

Size: ~3 lines of code, 1 line of data, the rest is report and docs. One PR.

## Questions

## Review log
