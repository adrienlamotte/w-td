# 023 — Performance with combat: optimise and re-bench
- Status: done
- Milestone: M2
- Depends on: 013, 016, 024, 026
- PR: #29

## Goal
Keep the budgets with the M2 load: apply the cheap GDScript optimisations listed in the M1 report if needed and re-run the benchmark with combat.

## Context
- Cosmetic cleanup to include: lost line breaks (tabs mid-line) in `game/sim/spatial_grid.gd` line 41 and `game/tests/sim/test_wave_spawner.gd` line 106 (found in the 025 and 020 reviews).
- `reports/perf_m1.md` (cheap optimisations, GDExtension triggers), D-088 (bench method)
- `02_TECH_ARCHITECTURE.md` 4 budgets
- Baseline after 011/012 (lead-dev bench, 2026-10-09, no combat yet): step 6.4 / 7.9 / 10.5 ms on pc typical / stress / piled, up from 5.7 / 6.6 / 8.7 ms at M1, most likely the larger horde cell (1.4 -> 1.6, brute radius 0.4, D-099). `pc_stress` is already near the 8 ms budget before combat.
- **Maze separation density (from 024, priority after 026):** 024's release bench (lead dev, 2026-10-09) gives step `pc_maze` 8.27-8.41 ms (separation 5.6-5.7, movement 1.2-1.3, path 0) and `pc_maze_churn` 9.56-10.11 ms (separation 5.9-6.0, path 0.78), over the 8 ms budget. The pathing is within its own budget; the cost is the M1 separation loop under corridor density: about 7.4 overlapping neighbours per enemy in the maze vs 2.0 in `pc_typical`. Candidate fixes (lead dev's call in the plan): skip pairs of two stopped enemies, a cheaper path for `QUEUED` enemies (e.g. half-rate separation), or a GDExtension separation loop (M1 report triggers). Do not change the bench maze density or enemy counts (owner decision).
- From 024/026 plans: 024 adds the `pc_maze`, `deck_maze` and `pc_maze_churn` bench scenarios (maze of 3 rings, sliced flow-field recompute, `path` phase) and reports them; this task adds combat to them (towers fire only while RUNNING, so the IDLE bench needs a run or a combat switch) and a walled-in worst case (a full ring with 3000 enemies attacking it, 026).

## Acceptance criteria
- `pc_maze` and `pc_maze_churn` run under 8 ms per tick (step, release bench) with the maze, density and enemy counts of 024 unchanged; the M1 scenarios do not regress; before/after phase breakdown in the PR.
- Bench scenarios include combat (towers attacking, deaths, spawns).
- If any budget fails, apply the cheap optimisations first; report before/after.
- `reports/perf_m2.md` and the 02 section 4 table updated.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-123** (separation iteration order). One PR: about 250 lines of code, plus data, tests and the report.

### Baseline (lead dev, release bench, 2026-10-09, after 026, commit 6103121; ms per tick)
| scenario | step | separation | movement | grid | targeting | path |
|---|---|---|---|---|---|---|
| pc_typical | 5.35 | 3.81 | 0.59 | 0.75 | 0.15 | 0 |
| pc_stress | 5.83 | 3.66 | 0.57 | 0.72 | 0.83 | 0 |
| pc_piled | 5.48 | 3.78 | 0.37 | 0.72 | 0.57 | 0 |
| deck_typical / stress / piled | 2.43 / 2.82 / 3.21 | 1.34 / 1.37 / 1.83 | | | | |
| pc_maze | 8.28 | 5.59 | 1.27 | 0.72 | 0.66 | 0 |
| deck_maze | 4.39 | 2.31 | 0.65 | 0.59 | 0.81 | 0 |
| pc_maze_churn | 9.96 | 6.16 | 1.42 | 0.78 | 0.73 | 0.83 |

Target: `pc_maze_churn` needs about -2 ms, so separation must go from about 6 to 4 ms or less. Why it costs: per enemy the horde loop scans the cell box of reach `r_i + max_radius` (0.35 + 0.4 with 0.8 cells: about 8 cells, about 25 candidates in the maze), **half of the candidates are thrown away by `j <= i`**, and every kept candidate costs 6 indexed reads (`cell_items[k]`, `xs[j]`, `zs[j]`, `types[j]`, `radius[tj]`, plus the compare).

### Step A: separation in cell order, half box (D-123 PROPOSED; `sim` `game/sim/enemy_separation.gd`)
Same rule (D-079, D-084, D-106, D-107 queue flag), same pairs, new visit order:
- At the start of `apply()`, copy positions and radii into cell order: `_sx[p] = xs[cell_items[p]]`, `_sz[p]`, `_sr[p] = radius[types[cell_items[p]]]` (one pass; packed arrays kept between ticks, no allocation once sized).
- Loop over `p` in cell order (visitor `i = cell_items[p]`; bosses skipped as now). Box as now, but rows **below** the visitor's row are skipped, the visitor's own row starts at `p + 1`, rows above are scanned in full. Every overlapping pair is still visited exactly once (both boxes contain it, since `r_i + r_j <= r + max_radius`), with no `j <= i` test.
- The inner loop reads only `_sx[q]`, `_sz[q]`, `_sr[q]`; `j = cell_items[q]`, `types[j]`, `is_boss`, `_key`, `st` and `strength` are read only for an overlapping pair (about 7 per enemy, not 25).
- Pushes still accumulate in index space (`_push_x[i]`, `_push_x[j]`), so the boss pass and the capped apply pass are unchanged.
- Coincident rule kept: coincident enemies share a cell and a cell's slice is in ascending index order, so the visitor is always the lower index (`-x`). Covered by a test.
- Floats are summed in another order: positions differ in the last bits, still deterministic (as D-108). No test holds a golden hash.
Expected: about half the candidates and half the reads per candidate, so separation about 2x faster. **Bench A alone** before anything else.

### Step B, only if a gate scenario is still >= 8 ms after A (behaviour-preserving; bench each, keep only what helps)
- `EnemyMovement` (1.3-1.4 ms in the maze): merge `push_out` into the loop after `advance`, sharing the cell computation; hoist per-type lookups.
- `EnemySeparation._fill_keys`: compute the cell once per enemy, avoid repeated array lookups.
- `SpatialGrid.rebuild` (0.7 ms): micro-optimise the counting sort only where the result stays identical (keep the clamp).
No rule change in this task (for example: no skipping pushes between stopped enemies, no half-rate separation for `QUEUED`).

### Step C, if A + B still miss the gate: stop and report, no GDExtension in this task
Open the PR anyway with the bench and the report (the combat scenarios and the measured gains are worth merging). Say in the PR and in `reports/perf_m2.md` which scenario misses and by how much, and mark the gate criterion as not met. The lead dev then puts the GDExtension (D-018, `perf_m1.md` section 6 triggers) or a threaded GDScript separation to the owner in `OPEN_QUESTIONS.md`; it is not decided here.

### Combat in the bench (`view` `game/view/bench/bench_scenario.gd`, `game/view/bench/bench.gd`; `data` `game/data/bench/bench_m1.json`; `tools` `tools/schemas/bench.schema.json`)
The nine existing scenarios stay **exactly** as they are (the gate and the M1 comparison). New scenarios with `combat: true`:

| name | enemies | towers | layout | recycle | render_scale |
|---|---|---|---|---|---|
| `pc_combat` | 3000 | 50 | sunflower, real towers | yes | 1.0 |
| `pc_combat_stress` | 3000 | 300 | sunflower, real towers | yes | 1.0 |
| `deck_combat` | 1500 | 50 | sunflower, real towers | yes | 0.5 |
| `deck_combat_stress` | 1500 | 150 | sunflower, real towers | yes | 0.5 |
| `pc_maze_combat` | 3000 | 0 | the 024 maze, firing | yes | 1.0 |
| `pc_walled` | 3000 | 0 | one full ring at `walled_ring` (8), no gap, unkillable | no (`piled: true`) | 1.0 |

- Combat setup (BenchScenario, harness only, like `spawn_ring`): queue `SimCommand.start_run(0, seed, cfg.combat_run)` (`run_m2`) and run one `world.step()` before the layout, so the world is RUNNING with the run's `BuildGrid`; then the overrides `test_walled_in.gd` already uses: no wave spawns (`first_wave_tick = 1 << 30`, no bosses) and a huge `guardian_hp`, so the run never ends. `_maze()` reuses `world.build` when it exists (`run_m2` has the same radius 20 and step 0.5; a test checks it).
- Real towers: at the sunflower positions, `TowerBuilding.add_built` with `run.tower_types` in turn; taken cells are skipped, so the report records the real count (`towers_built`).
- `pc_walled`: ring towers every 0.25 units of arc (as `test_walled_in`), `hp` set huge so the ring holds for the whole run (the 026 worst case: the horde stays walled in and attacks).
- Deaths and spawns: towers kill enemies (DEATHS swap-remove); a static `BenchScenario.refill(world, cfg, sc)` tops the count back up with `spawn_ring(type, missing, spawn_ring_max)`, called by `bench.gd` each frame (as `_churn`). The refill triggers the safety-net grid rebuild, which is outside the phase timers by design; say so in the report. Per scenario the report adds `deaths_per_sec` (from `ENEMY_DIED` events read after each step through the driver) and `towers_built`. Wave spawning itself is not exercised (its cost is a few spawns per tick; say so).
- Schema: new optional top-level `combat_run` (run id pattern) and `walled_ring` (number); per scenario optional `combat` and `walled` booleans. Validator green.
- Combat scenarios are measured against the same 8 ms step budget and reported. The **gate** of this task is `pc_maze` and `pc_maze_churn` (024's maze and counts unchanged); a combat scenario that misses after A/B goes into the step C report, not into more code here.

### Cosmetic (Context)
- `game/sim/spatial_grid.gd` line 41 and `game/tests/sim/test_wave_spawner.gd` line 106: break the line where the stray tabs are (the expression continues on the next line). No behaviour change.

### Tests
- New `game/tests/sim/test_separation_order.gd`: random crowds (fixed seed; swarmers, brutes, two bosses, some coincident pairs, some enemies outside the grid square), `EnemySeparation.apply` against a brute-force O(n^2) reference over all pairs written in the test (same pair rule): positions equal within 1e-5, `blocked` identical; a coincident pair sends the lower index to `-x`.
- Existing separation, queue, maze, walled-in and determinism tests stay green unchanged.
- `game/tests/view/test_bench_scenario.gd`: a combat scenario is RUNNING, its towers fire within N ticks (`TOWER_FIRED`), enemies die and `refill` restores the count; `pc_walled` keeps its ring alive and its enemies have `target_id >= 0` after N ticks; a combat maze reuses the run's build grid.

### Performance method
- Release bench (`scripts\bench.ps1`) once at the start (before, this machine), after A, after each kept B change, and three times at the end (median, as M1).
- `reports/perf_m2.md`: method, before/after per scenario with the phase breakdown, the combat scenarios with `deaths_per_sec`, the Deck estimate for the `deck_*` scenarios with the `perf_m1.md` section 4 formulas, the gate verdict, and whether any `perf_m1.md` section 6 GDExtension trigger fired (stated plainly, as input for the owner). Commit the three final JSON runs as `reports/perf_<date>_rN.json`, as M1 did.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a Enemy separation: cell-order half-box iteration (D-123) and the new cost; section 4: M2 rows (gate, combat, Deck estimate); section 6 bench paragraph: combat scenarios, `combat_run`, `walled_ring`, refill, `deaths_per_sec`, `towers_built`.
- `DECISIONS.md`: **D-123 PROPOSED**: the horde separation loop visits each pair once in cell order with a half box over cell-ordered copies of positions and radii; same rule, last-bit float differences, deterministic.

### Order
1. Cosmetic line breaks; one release bench (before).
2. Step A + `test_separation_order.gd`; `scripts\test.ps1`; bench.
3. Step B only if needed, one change at a time, bench each.
4. Combat scenarios (data, schema, BenchScenario, `bench.gd` refill and counters) + tests.
5. Bench three times; `reports/perf_m2.md`, docs, D-123; `scripts\test.ps1` twice, `scripts\validate.ps1`.
6. If the gate misses: step C (PR with the report, flagged).

## Questions

## Review log
- 2026-10-09 lead dev: PR #29 approved and merged (squash) into `m2/dev`. Tests 215/215 and validator green on the branch. Code checked: the half box covers every pair once (the lower cell-order visitor scans the other's cell; own row from `p + 1`, rows above in full), key tie and coincident rules match the old `i < j` loop, bosses sorted back into index order; `test_separation_order.gd` is a real brute-force reference. Combat harness stays in `view/bench` using sim test APIs, as planned. `reports/perf_m2.md` is honest and clear. Acceptance criterion "`pc_maze` and `pc_maze_churn` < 8 ms" **not met** (step C, as planned): 7.55 / 8.12 ms median of 3; a lead-dev rerun gave 8.03 / 8.06 ms, so both gate scenarios sit on the 8 ms line within noise (+-0.4 ms). Merged because the gap is a budget decision, not a defect: put to the owner as Q-59. The flat `deck_*` frame p99 of about 4.8 ms (M1 2.5-3.0) is a CP-M2 note, not a task: it does not threaten any budget (pessimistic Deck tick frame 15.6 ms vs 25 ms) and belongs with view profiling.
