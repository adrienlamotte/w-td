# M1 perf report: budgets, Steam Deck estimate, 3D billboard go/no-go

Task 009. Date: 2026-10-08. Commit measured: `8af7b96`. Data: `perf_2026-10-08_r1.json`, `_r2`, `_r3` (the three runs used), `_r4` (an extra check run, see Method), `perf_2026-10-08.json` (the 008 run, for comparison).

## Summary (for the owner)

**Verdict: GO for the 3D billboard + MultiMesh view (D-089, PROPOSED).** On PC, the typical and stress budgets pass with room to spare. On the Steam Deck the result is an **estimate** (no Deck, D-080): every Deck scenario stays above 40 FPS, even with the pessimistic factor. The time is spent in the sim, not in the view.

The numbers that matter (median of 3 runs):

| | Value | Budget | |
|---|---|---|---|
| PC typical (3000 enemies, 50 towers), 1%-low FPS / frame p99 | 125 FPS / 6.8 ms | >= 60 FPS / <= 16.7 ms | PASS |
| PC stress (300 towers), sim step per tick | 6.6 ms | <= 8 ms | PASS |
| PC piled worst case, sim step per tick | 8.6 ms | <= 8 ms | FAIL by ~8% (placeholder worst case, see below) |
| View cost per frame on PC (fill + render CPU + GPU) | <= 0.87 ms | - | ~10% of a tick frame |
| Deck estimate, worst tick frame, pessimistic (`deck_piled`) | 19.2 ms (~52 FPS) | <= 25 ms (40 FPS) | within 40-60 FPS (estimate) |

What it means:
- GDScript is fast enough for M1 on PC. The only miss is the "everyone piled at the Guardian" case, which is partly made by M1 placeholders (no Guardian contact radius, nobody dies). M2 changes that case anyway.
- About 90% of a tick frame is the sim step, and 60-79% of the step is enemy separation. A pure 2D view would save less than 1 ms per frame, so the 2D fallback buys nothing.
- No optimisation and no GDExtension are needed now. The cheap GDScript wins below are listed for an M2 task.
- The Deck numbers are an estimate from public benchmarks. A real Deck run is still required (by M6, D-080).

## 1. Setup and method

| | |
|---|---|
| Machine | Intel Core i7-13700K (24 threads), NVIDIA GeForce RTX 5070 Ti (Vulkan 1.4.351), Windows 10.0.26200 (Windows 11) |
| Engine | Godot 4.7.2-stable (official), Forward+, **release export** (`release: true`) |
| Display | 2560x1440 window, vsync off (`vsync_mode: 0`), no FPS cap (`max_fps: 0`), both recorded in each JSON |
| Run | `scripts\bench.ps1` (D-088): per scenario a warm-up (5 s, 20 s for the piled cases), then 20 s measured, about 600 sim ticks at 30 Hz |
| Statistic | 3 runs; each metric is the **median of the 3 runs**, with the min-max range in brackets |
| Deck proxy | `render_scale` 0.5 at 2560x1440 = 1280x720 3D pixels |

Reading the numbers: average FPS above ~1000 is noise (frames under 1 ms). The report reasons from milliseconds (sim step, phases, fill, render CPU, GPU, frame p99) and from 1%-low FPS. Average FPS appears only as context.

**Noise in these runs.** The machine was not fully quiet. In run 2, both piled scenarios ran capped at 144.9 FPS (frames of 6.9 ms, only 2899 frames). That is a display-rate cap from outside the game (probably the window lost focus or was covered), since vsync was off in the file. Run 3 had stalls (`pc_typical` 1%-low 89, `deck_piled` p99 10.5 ms). An extra run 4 had a stall in `deck_typical` (1%-low 92) but clean piled cases (`deck_piled` p99 4.2 ms, 1%-low 204). Effects:
- The sim step and phase times are stable across all 4 runs (within ~7%). Every budget verdict rests on them.
- Frame p99 and 1%-low pick up external stalls. The medians are used as planned. Where a stall moves a verdict, it is said below.

## 2. PC vs budgets (`02_TECH_ARCHITECTURE.md` section 4)

| Budget line | Scenario | Measured (median [range]) | Limit | Result |
|---|---|---|---|---|
| 60 FPS, ~3000 enemies + 50 towers | `pc_typical` | 1%-low 124.7 FPS [89.4-133.0]; p99 6.75 ms [6.70-9.04] | 1%-low >= 60, p99 <= 16.7 ms | PASS |
| 60 FPS, stress 300 towers | `pc_stress` | 1%-low 111.8 FPS [105.6-112.8]; p99 7.61 ms [7.56-7.89] | 1%-low >= 60, p99 <= 16.7 ms | PASS |
| Sim step per tick | `pc_typical` | 5.67 ms [5.67-6.08] | <= 8 ms | PASS |
| Sim step per tick | `pc_stress` | 6.56 ms [6.55-6.61] | <= 8 ms | PASS |
| Sim step per tick | `pc_piled` | 8.65 ms [8.53-8.77] | <= 8 ms | **FAIL** (+8%) |
| Sim per frame at 60 FPS (`step * ticks_per_sec / 60`) | `pc_typical` | 2.84 ms [2.83-3.04] | < 4 ms | PASS |
| Sim per frame at 60 FPS | `pc_stress` | 3.28 ms [3.28-3.30] | < 4 ms | PASS |
| Sim per frame at 60 FPS | `pc_piled` | 4.32 ms [4.27-4.39] | < 4 ms | **FAIL** (+8%) |

Context: average FPS 1294 [794-1366] typical, 1178 [1069-1180] stress, 903 [145-1000] piled. `pc_piled` still holds a 1%-low of 90.1 FPS [80.3-92.3] and p99 10.2 ms, so the frame rate is not at risk on PC. Only the per-tick sim budget is exceeded.

**Why `pc_piled` misses, and why it is partly a placeholder.** All 3000 enemies stand still at the Guardian (mean speed 0.10). In M1 the Guardian has no contact radius and nobody dies, so enemies in the `AT_GUARDIAN` state pile at the centre at about 8x overlap density (~166 separation candidates per enemy; 004 review log). Separation then costs 6.46 ms per tick instead of 4.47 ms. M2 adds the contact radius and deaths, which lower that density. The case is kept as the worst-case benchmark, but its 8% miss is not a reason to change the view or the language now.

The numbers match the 008 run (`perf_2026-10-08.json`: step 5.78 / 6.78 / 8.48 ms for typical / stress / piled).

## 3. Where the time goes

Per-tick sim phases (ms per tick) and per-frame view costs (ms per frame), medians:

| Scenario | Separation | Movement | Grid | Targeting | **Step** | Fill | Render CPU | GPU | Other CPU per frame* | Frame p99 |
|---|---|---|---|---|---|---|---|---|---|---|
| `pc_typical` 3000/50 | 4.47 | 0.27 | 0.74 | 0.19 | **5.67** | 0.48 | 0.032 | 0.172 | 0.64 | 6.75 |
| `pc_stress` 3000/300 | 4.44 | 0.27 | 0.74 | 1.11 | **6.56** | 0.55 | 0.030 | 0.156 | 0.68 | 7.61 |
| `pc_piled` 3000/300 | 6.46 | 0.03 | 0.74 | 1.42 | **8.65** | 0.60 | 0.034 | 0.238 | 0.82 | 10.20 |
| `deck_typical` 1500/50 | 1.63 | 0.14 | 0.44 | 0.18 | **2.39** | 0.25 | 0.028 | 0.062 | 0.40 | 2.49 |
| `deck_stress` 1500/150 | 1.66 | 0.14 | 0.44 | 0.53 | **2.77** | 0.29 | 0.029 | 0.060 | 0.42 | 2.97 |
| `deck_piled` 1500/150 | 2.69 | 0.02 | 0.45 | 0.87 | **4.03** | 0.32 | 0.041 | 0.080 | 1.12 | 7.00 |

\* `non_tick_cpu_ms = (frame_ms_avg * frames - step_ms_avg * ticks) / frames`: the average frame time left after the sim steps (fill, render submission, engine overhead). For `deck_piled` the median (1.12, range 0.48-6.07) is inflated by the capped run 2 and the stalls in run 3; the clean run 1 gives 0.48.

Findings:
- **Separation is 60-79% of the step** (79% typical, 68% stress, 75% piled, 60-68% on the Deck scenarios). It is the hot loop.
- **Targeting grows with towers:** 0.19 ms at 50 towers, 1.11 ms at 300, 1.42 ms at 300 in the dense piled case.
- **View costs are small:** fill <= 0.60 ms per frame, render CPU ~0.03 ms, GPU <= 0.24 ms (at 2560x1440).
- **Frames are CPU-bound, and the 1%-lows are the tick frames.** The sim step runs on the main thread inside one frame, 30 times per second. A tick frame takes about step + other CPU (typical: 5.67 + 0.64 = 6.3 ms vs p99 6.75 ms). The sim is about 90% of a tick frame. The other frames are under 1 ms.

## 4. Steam Deck estimate (D-080)

**This is an estimate, not a measurement.** No Deck was available (D-080). A real Deck run is still required, by M6 at the latest.

Proton (D-075): the Deck runs the Windows build through Proton. The sim and fill are native x86-64 code (the Godot interpreter and engine), not emulated, and Godot uses Vulkan, which Proton passes through. So no Proton factor is applied.

### 4.1 Factors

**CPU factor `k_cpu`** = single-thread performance of the i7-13700K / Steam Deck APU (Zen 2, 4c/8t, 2.4-3.5 GHz).

| Source (retrieved 2026-10-08) | i7-13700K | Steam Deck APU | Ratio |
|---|---|---|---|
| PassMark single-thread rating: https://www.cpubenchmark.net/cpu.php?cpu=Intel+Core+i7-13700K&id=5060 and https://www.cpubenchmark.net/cpu.php?id=6154 (AMD Custom APU 0932, the OLED Deck APU: same Zen 2 4c/8t at 2.4-3.5 GHz, 27 samples; no PassMark entry was found for the LCD APU 0405) | 4325 | 2201 | 1.97 |
| Geekbench 6 single-core, 13700K: https://www.cpu-monkey.com/en/benchmark-intel_core_i7_13700k-geekbench_6_single_core; Deck LCD APU 0405: https://laptopmedia.com/processor/valve-steam-deck-amd-custom-apu-0405/ (database value) | 2787 | 1348 | 2.07 |
| Geekbench 6 single-core, one Deck result under Windows 11: https://browser.geekbench.com/v6/cpu/1029250 | 2787 | 1173 | 2.38 |
| Clocks: Valve Steam Deck tech specs, https://www.steamdeck.com/en/tech ("Zen 2 4c/8t, 2.4-3.5GHz") | | | |

Caveat: the Geekbench values were read from search-engine excerpts of these pages. A direct fetch returned HTTP 403, so they are not verified against the page itself. The PassMark values and the Valve specs were read from the pages.

- Range from the benchmarks: **1.97-2.38**.
- **Expected `k_cpu` = 2.2** (middle of the range).
- **Pessimistic `k_cpu` = 2.38 x 1.15 = 2.74** (top of the range + 15%). Reasons for the margin: GDScript is an interpreter (branchy, memory-latency bound), so it may scale worse than synthetic benchmarks, and the Deck shares a 15 W budget between CPU and GPU.
- Sensitivity: the plan expected 2.3-3x before the lookup. Results are also shown at 3.0 x 1.15 = **3.45**, to show the margin if the public numbers flatter the Deck.

**GPU factor `k_gpu`** = the worse of the two ratios, x the pixel ratio, x a safety factor 2:
- FP32: RTX 5070 Ti 43.9 TFLOPS (https://www.club386.com/nvidia-geforce-rtx-5070-ti-release-date-specs-price-and-performance) / Deck 1.6 TFLOPS (https://www.steamdeck.com/en/tech) = **27.4**.
- Memory bandwidth: 896 GB/s (same club386 page) / 88 GB/s (Deck LCD, LPDDR5 5500 MT/s; the OLED's 6400 MT/s quad 32-bit is 102 GB/s per the Valve page) = 10.2.
- Worse ratio 27.4 x pixel ratio 1280x800 / 1280x720 = 1.11 x safety factor 2 (tiny GPU loads do not scale linearly; fixed Forward+ overhead) = **`k_gpu` ~ 61**.

### 4.2 Formulas (from the medians of the `deck_*` scenarios, measured at 1280x720 3D pixels)

- Tick frame ~ `k_cpu * (step_ms_avg + non_tick_cpu_ms)`; cross-check `k_cpu * frame_ms_p99`; keep the worse of the two.
- Other frames ~ `max(k_cpu * non_tick_cpu_ms, k_gpu * gpu_ms_avg)`.
- Average FPS (CPU side) from the one-second budget: `fps = (1000 - 30 * k_cpu * step_ms_avg) / (k_cpu * non_tick_cpu_ms)`, capped by the GPU side `1000 / (k_gpu * gpu_ms_avg)`.
- GPU headroom: `k_gpu * gpu_ms_avg` vs 25 ms.

### 4.3 Results

| Scenario | k_cpu | Tick frame: formula / p99 cross-check -> kept | Tick-frame FPS | Other frames | Est. avg FPS (CPU side, GPU cap) | GPU per frame (vs 25 ms) | Verdict |
|---|---|---|---|---|---|---|---|
| `deck_typical` 1500/50 | 2.2 expected | 6.13 / 5.49 -> **6.1 ms** | 163 | 3.8 ms (GPU) | 263 (961, cap 263) | 3.8 ms | 60+ FPS |
| | 2.74 pessimistic | 7.63 / 6.83 -> **7.6 ms** | 131 | 3.8 ms | 263 (736, cap 263) | 3.8 ms | 60+ FPS |
| | 3.45 sensitivity | **9.6 ms** | 104 | 3.8 ms | 263 | 3.8 ms | 60+ FPS |
| `deck_stress` 1500/150 | 2.2 expected | 7.03 / 6.52 -> **7.0 ms** | 142 | 3.7 ms (GPU) | 272 (875, cap 272) | 3.7 ms | 60+ FPS |
| | 2.74 pessimistic | 8.75 / 8.12 -> **8.8 ms** | 114 | 3.7 ms | 272 (664, cap 272) | 3.7 ms | 60+ FPS |
| | 3.45 sensitivity | **11.0 ms** | 91 | 3.7 ms | 272 | 3.7 ms | 60+ FPS |
| `deck_piled` 1500/150 | 2.2 expected | 11.32 / 15.40 -> **15.4 ms** | 65 | 4.9 ms (GPU) | 204 (298, cap 204) | 4.9 ms | 60+ FPS |
| | 2.74 pessimistic | 14.10 / 19.18 -> **19.2 ms** | 52 | 4.9 ms | 204 (218, cap 204) | 4.9 ms | **40-60 FPS** |
| | 3.45 sensitivity | **24.2 ms** | 41 | 4.9 ms | 151 | 4.9 ms | 40-60 FPS (at the limit) |

Reading:
- **Typical and stress:** the worst frames stay under 16.7 ms (60 FPS) even with the pessimistic factor, with headroom for M2 combat.
- **`deck_piled`** is the tight case. The p99 cross-check sets its number, and that p99 (7.0 ms median) is inflated by the noisy runs. With the clean p99 of runs 1 and 4 (4.24-4.32 ms), the pessimistic tick frame is 2.74 x 4.32 = 11.8 ms. With the worst noisy p99 (10.5 ms, run 3), it is 28.8 ms (under 40 FPS), but that run had external stalls. On the median, which the plan uses: **40-60 FPS, pessimistic.**
- **GPU:** 3.7-4.9 ms of 25 ms even with `k_gpu` ~ 61. The GPU is not the risk. The Deck would normally run vsynced at 60 Hz (or 40 Hz in the Deck's frame limiter), so the "other frames" are not a concern.
- Uncertainty: single-thread benchmarks are not GDScript, the Deck's sustained clocks under a 15 W shared budget are not modelled, and Proton is assumed to add nothing measurable. The pessimistic and sensitivity columns cover part of this, not all of it.

## 5. Optimisations already logged (none implemented here; status after task 025 in the last column)

| Optimisation | Source | Target phase | Expected gain (rough) | Changes a decision or a rule? | Task 025 |
|---|---|---|---|---|---|
| Grid cell size `2 * max_radius` | 004 review log | separation | ~40% fewer pair candidates; maybe -1 to -2 ms per tick at 3000 | Yes: changes D-082 (cell size); no game rule | Done (D-108): release `pc_stress` step 6.2 -> 5.3 ms |
| Hoist `catalog.max_radius` and `cell_coord` out of the inner loop | 004 review log | separation, grid | a few % of separation | No | Done (inlined `cell_coord`); with the `nearest` row ranges, release `pc_stress` step 7.6 -> 6.2 ms |
| Precompute each tower's cell and clamped ring bounds at `add` (towers do not move) | 005 review log | targeting | some of 1.1-1.4 ms at 300 towers | No | Dropped: 300 calls are not the cost |
| Tighter per-cell distance bound instead of `(k - 1) * cell_size` | 005 review log | targeting | skips packed far cells; most useful in dense cases (piled) | No (same result: nearest in range, lowest index on ties) | Not done; `nearest` now scans each ring's edge rows as one range instead |
| Inline the scan in `retarget` (drop 300 calls per tick) | 005 review log | targeting | call overhead, ~10-20% of targeting | No | Dropped: not the cost |

**Needed now?** No. The rule was: needed only if a PC typical/stress budget fails or the pessimistic Deck tick frame is over 25 ms. Neither happens (PC typical/stress pass; pessimistic Deck worst 19.2 ms). The only miss is `pc_piled` (+8%), a placeholder-shaped worst case. **Recommendation:** one M2 task that measures these wins when combat adds per-tick work (damage, deaths, projectiles). It should start with the cell size, since separation is most of the step.

## 6. Recommendation for the owner: GDExtension escape hatch (`02_TECH_ARCHITECTURE.md` section 1)

This is a recommendation, not a decision. **Later, not now.** GDScript meets the PC typical/stress budgets with ~1.4-2.3 ms per tick to spare, and the Deck estimate stays above 40 FPS.

Measurable triggers to revisit (any one, and only after the cheap GDScript wins in section 5 are measured):
- PC `pc_typical` or `pc_stress` step > 8 ms per tick after M2 combat is in.
- The pessimistic Deck tick frame (method above) > 25 ms.
- A real Deck run with a 1%-low under 40 FPS.

A cheaper option for the 1%-lows: run the sim step off the main thread (the view already interpolates between ticks, D-086), so a tick no longer stalls one frame. This would remove the tick-frame spike without changing the language. It is an option to evaluate, not a plan.

## 7. Go/no-go: 3D billboards (D-019) vs pure 2D

**GO: keep the 3D billboard + MultiMesh view.** Evidence:
- On PC at 2560x1440 with 3000 enemies: GPU <= 0.24 ms, render CPU ~0.03 ms and MultiMesh fill <= 0.60 ms per frame. The whole view is under 0.9 ms per frame, about 10% of a tick frame.
- Deck estimate: GPU 3.7-4.9 ms of a 25 ms frame with a deliberately harsh factor (~61x).
- The cost is in the sim (step 2.4-8.7 ms per tick, 60-79% of it separation). The view choice does not touch the sim. A pure 2D view could save at most the view part (< 1 ms per frame on PC) and would not fix the only miss (`pc_piled`, a sim cost).

Recorded as D-089 (PROPOSED). The owner confirms at CP-M1; then D-019 becomes DECIDED.
