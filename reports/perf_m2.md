# M2 perf report: separation order, combat scenarios, gate

Task 023. Date: 2026-10-09. Commit measured: `8940257`. Data: `perf_2026-10-09_r1.json`, `_r2`, `_r3` (the three final runs). The "before" column is one run at `87c9411` (code identical to `6103121`, after 026), not committed.

## Summary (for the owner)

**Gate: NOT MET, by 0.12 ms.** `pc_maze` passes (7.55 ms per tick), `pc_maze_churn` misses (8.12 ms, budget 8 ms, +1.5%). Step A (D-123) took 0.5-1.0 ms off the maze scenarios and 0.2-0.7 ms off the M1 scenarios (separation -15 to -20%); the step B micro-optimisations gave nothing measurable and were dropped. Per the plan (step C) no GDExtension is added here; the lead dev puts the next step to the owner.

| | Before | After (median of 3 [range]) | Budget | |
|---|---|---|---|---|
| `pc_maze`, step per tick | 8.38 ms | 7.55 ms [7.27-7.95] | <= 8 ms | PASS (one run at 7.95) |
| `pc_maze_churn`, step per tick | 9.13 ms | 8.12 ms [7.98-8.16] | <= 8 ms | **FAIL** (+0.12 ms) |
| M1 scenarios, step per tick | 2.54-6.01 ms | 2.17-5.32 ms | no regression | PASS (all faster) |
| Combat scenarios, step per tick | - | 2.46-7.04 ms | <= 8 ms | PASS |
| Deck estimate, worst tick frame, pessimistic (`deck_maze`) | - | 15.6 ms | <= 25 ms | within 60 FPS (estimate) |

What it means:
- No `perf_m1.md` section 6 GDExtension trigger fired: `pc_typical` 4.45 ms and `pc_stress` 5.32 ms are under 8 ms with combat, and the pessimistic Deck tick frame is 15.6 ms (under 25 ms). The only miss is the 024 churn worst case (a field recompute always in flight), by 1.5%.
- Separation is still the top phase (60% of the maze step). Its remaining cost is the work per overlapping pair (about 7 pairs per enemy in the maze corridors), which a same-rule GDScript loop cannot shrink further.

## 1. Method

Same as `perf_m1.md` section 1 (D-088): i7-13700K + RTX 5070 Ti, Windows 11, Godot 4.7.2-stable release export, 2560x1440, vsync off, no FPS cap, 5 s warm-up (20 s piled) then 20 s measured per scenario. One release bench before any change, one after step A, one after each step B change, three at the end (median per metric). The bench window was kept focused; run-to-run noise on the step is about +-0.4 ms on the maze scenarios (see the ranges), so a single run cannot resolve gains under ~0.3 ms.

## 2. Before / after (step per tick and phases, ms)

Separation column: before / after. Other phases: after (medians).

| scenario | step before | step after (median [range]) | separation | movement | grid | targeting | path | attacks | frame p99 | 1%-low FPS |
|---|---|---|---|---|---|---|---|---|---|---|
| `pc_typical` | 5.06 | 4.45 [4.44-4.87] | 3.61 / 2.98 | 0.56 | 0.72 | 0.14 | 0.00 | 0.00 | 6.32 | 141 |
| `pc_stress` | 6.01 | 5.32 [5.30-5.58] | 3.79 / 3.12 | 0.58 | 0.75 | 0.85 | 0.00 | 0.00 | 7.94 | 110 |
| `deck_typical` | 2.54 | 2.17 [2.16-2.26] | 1.41 / 1.12 | 0.29 | 0.59 | 0.16 | 0.00 | 0.00 | 4.78 | 203 |
| `deck_stress` | 2.69 | 2.48 [2.48-2.52] | 1.32 / 1.12 | 0.29 | 0.59 | 0.47 | 0.00 | 0.00 | 4.76 | 207 |
| `pc_piled` | 5.89 | 5.25 [5.04-5.29] | 4.08 / 3.46 | 0.39 | 0.76 | 0.60 | 0.00 | 0.00 | 7.34 | 121 |
| `deck_piled` | 3.01 | 2.78 [2.72-2.79] | 1.71 / 1.48 | 0.19 | 0.59 | 0.49 | 0.00 | 0.00 | 4.79 | 200 |
| `pc_maze` | 8.38 | 7.55 [7.27-7.95] | 5.67 / 4.76 | 1.32 | 0.75 | 0.68 | 0.01 | 0.00 | 9.74 | 95 |
| `deck_maze` | 4.83 | 4.31 [4.02-4.32] | 2.56 / 2.09 | 0.70 | 0.62 | 0.87 | 0.01 | 0.00 | 5.68 | 155 |
| `pc_maze_churn` | 9.13 | 8.12 [7.98-8.16] | 5.68 / 4.65 | 1.28 | 0.73 | 0.66 | 0.75 | 0.00 | 10.24 | 91 |

The lead dev's baseline (plan, same commit range) was 8.28 / 9.96 ms for `pc_maze` / `pc_maze_churn`; this machine's "before" run gave 8.38 / 9.13 ms.

### Steps tried

| Step | Change | Bench result (maze scenarios) | Kept |
|---|---|---|---|
| A (D-123) | Separation in cell order with a half box over cell-ordered copies of x, z, radius | separation 5.67 -> 4.55-4.60 ms; `pc_maze` 8.38 -> 7.29, `pc_maze_churn` 9.13 -> 7.96 | Yes |
| A, extra | Locals for the push/blocked arrays and the hoisted visitor state in the overlap block | separation 4.58-4.96 ms (noise) | No |
| B1 | `EnemyMovement`: push-out merged into `advance`, `FlowField` constants hoisted in `steer` | movement 1.27 -> 1.25-1.39 ms (noise) | No |
| B2 | `_fill_keys`: one read per array per enemy, local key array, hoisted `INF` | separation 4.61-5.11 ms (noise) | No |
| B3 | `SpatialGrid.rebuild`: prefix sum limited to the used cell range | Not attempted: the per-enemy min/max tracking costs about as many operations as the shorter prefix sum saves (the maze horde spans ~70% of the grid rows) | - |

Why step A gave -15 to -20% and not the 2x the plan expected: it halves the candidates and the reads per candidate, but the work per overlapping pair (key compare, state reads, sqrt, four push updates) is unchanged, and in the maze that is about 7 pairs per enemy. The headless debug cost test (`test_separation_cost_3000_piled`) went from about 12.6 ms (the figure in `02_TECH_ARCHITECTURE.md` 3a) to 9.3 ms on this machine.

## 3. Combat scenarios

New in this task (`combat: true`, see `02_TECH_ARCHITECTURE.md` section 6): a RUNNING `run_m2` with no wave spawns, real towers that fire, deaths refilled every frame. The refill's grid safety-net rebuild is outside the phase timers by design; wave spawning itself is not exercised (a few spawns per tick).

| scenario | towers built | deaths / s | step (median [range]) | separation | movement | targeting | attacks | frame p99 | 1%-low FPS |
|---|---|---|---|---|---|---|---|---|---|
| `pc_combat` 3000 | 50 | 25.6 | 4.83 [4.80-5.16] | 2.68 | 1.13 | 0.11 | 0.14 | 6.82 | 136 |
| `pc_combat_stress` 3000 | 300 | 268 | 5.03 [4.95-5.29] | 2.09 | 1.19 | 0.72 | 0.21 | 8.40 | 106 |
| `deck_combat` 1500 | 50 | 24.1 | 2.46 [2.46-2.67] | 1.07 | 0.58 | 0.12 | 0.08 | 4.77 | 206 |
| `deck_combat_stress` 1500 | 150 | 96.3 | 2.60 [2.58-2.61] | 0.95 | 0.58 | 0.35 | 0.10 | 4.81 | 202 |
| `pc_maze_combat` 3000 | 219 (maze) | 170 | 7.04 [6.66-7.35] | 3.57 | 1.25 | 1.21 | 0.18 | 10.54 | 88 |
| `pc_walled` 3000 | 48 (one ring at r = 8) | 48.3 | 6.76 [6.54-7.26] | 2.78 | 2.92 | 0.11 | 0.15 | 9.76 | 93 |

Reading:
- Combat itself is cheap: tower attacks 0.1-0.2 ms, deaths 0.03-0.05 ms. With the Guardian contact radius the crowd at the Guardian is less dense, so combat scenarios cost less separation than their non-combat twins; movement doubles (~1.2 ms) because RUNNING enemies steer against the run's flow field.
- `pc_maze_combat` is cheaper than `pc_maze` (deaths thin the corridors) but targeting doubles (219 firing towers in a dense horde).
- `pc_walled` (the 026 worst case): movement 2.9 ms is the walled-in steer (`_attack_wall` per walled enemy every tick). Under budget, but the most expensive movement phase measured; the first place to look if walled-in hordes grow.

## 4. Steam Deck estimate (D-080; method and factors from `perf_m1.md` section 4)

**An estimate, not a measurement.** `k_cpu` 2.2 expected / 2.74 pessimistic, `k_gpu` ~61. `non_tick_cpu_ms` is the median over the three runs.

| Scenario | k_cpu | Tick frame: formula / p99 cross-check -> kept | Tick-frame FPS | Est. avg FPS (CPU side, GPU cap) | GPU per frame (vs 25 ms) |
|---|---|---|---|---|---|
| `deck_typical` | 2.2 / 2.74 | 7.15 / 10.52 -> **10.5 ms**; 8.90 / 13.10 -> **13.1 ms** | 95 / 76 | 240 | 4.2 ms |
| `deck_stress` | 2.2 / 2.74 | 7.94 / 10.47 -> **10.5 ms**; 9.89 / 13.04 -> **13.0 ms** | 96 / 77 | 246 | 4.1 ms |
| `deck_piled` | 2.2 / 2.74 | 8.91 / 10.53 -> **10.5 ms**; 11.09 / 13.11 -> **13.1 ms** | 95 / 76 | 207 | 4.8 ms |
| `deck_maze` | 2.2 / 2.74 | 12.08 / 12.51 -> **12.5 ms**; 15.04 / 15.58 -> **15.6 ms** | 80 / 64 | 197 | 5.1 ms |
| `deck_combat` | 2.2 / 2.74 | 7.94 / 10.49 -> **10.5 ms**; 9.89 / 13.06 -> **13.1 ms** | 95 / 77 | 216 | 4.6 ms |
| `deck_combat_stress` | 2.2 / 2.74 | 8.90 / 10.58 -> **10.6 ms**; 11.08 / 13.18 -> **13.2 ms** | 94 / 76 | 198-218 | 4.6 ms |

Every Deck scenario stays at 60+ FPS even with the pessimistic factor. Note: the p99 of the `deck_*` scenarios is about 4.8 ms whatever the load (M1: 2.5-3.0 ms for typical/stress), so the p99 cross-check sets most kept numbers; the per-frame view work added in M2 (019 effects, 020 HUD) is the likely cause, not the sim. Worth a look when the view is profiled, not a budget issue.

## 5. GDExtension triggers (`perf_m1.md` section 6), stated plainly for the owner

| Trigger | Measured | Fired? |
|---|---|---|
| `pc_typical` or `pc_stress` step > 8 ms per tick after M2 combat | 4.45 / 5.32 ms (combat twins 4.83 / 5.03 ms) | No |
| Pessimistic Deck tick frame > 25 ms | 15.6 ms worst (`deck_maze`) | No |
| A real Deck run with a 1%-low under 40 FPS | no Deck run yet | - |

None fired. The task's own gate (`pc_maze_churn` <= 8 ms) is missed by 0.12 ms (1.5%). Options for the lead dev to put to the owner (not decided here): accept the churn worst case as within noise of the budget, a GDExtension separation loop (D-018), a threaded GDScript separation, or a rule change such as skipping pairs of two stopped enemies (excluded from this task by the plan).
