# 025 — Sim: cheap separation and targeting optimisations (priority)
- Status: planned
- Milestone: M2
- Depends on: -
- PR: -

## Goal
Recover per-tick headroom before combat and the maze land. The sim step is already 15-20% slower than in M1 (PC stress 7.9 ms against the 8 ms budget, measured during the 012 review), most likely because the brute's radius grew the grid cell from 1.4 to 1.6. Apply the cheap GDScript optimisations already identified in M1, measure before and after.

## Context
- `reports/perf_m1.md` (cheap optimisations section; GDExtension triggers), review logs of `backlog/004-sim-enemy-separation.md` and `backlog/005-sim-placeholder-towers.md` (hoist `max_radius` and `cell_coord` out of the inner loop, smaller grid cell, precompute tower cells, tighter per-cell bound, inline the scan)
- Baseline in `backlog/023-perf-m2.md` Context (PC typical 6.4, stress 7.9, piled 10.5 ms per tick)
- D-082 (grid cell size rule), D-083 (tick order), D-084 (separation rule): behaviour must not change, only cost; if the cell size rule changes, record it as a new PROPOSED decision
- Bosses are kept out of the cell size (011 plan); keep it that way

## Acceptance criteria
- Separation and targeting results are unchanged (existing tests and determinism hash expectations stay green; add an equivalence test if the algorithm changes).
- `scripts\bench.ps1` before/after table in the PR (release export); the goal is PC stress back under about 6.5 ms per tick.
- No GDExtension (not triggered); GDScript only.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Order: **025 before 014** (014 now depends on 025). Pure cost work: no data, schema or rule change. Decision ID **D-108**, used only if step 3 is kept (cell size). Where the bench time goes today (release, 013 review): `pc_stress` step 7.61 ms = separation 5.39 + grid 0.72 + targeting 1.21 + movement 0.28. Separation is the target; targeting must not get worse.

### Steps (each one measured, each one keeps the suite green)
1. **Separation, bit-exact** (`sim` `game/sim/enemy_separation.gd`): copy `catalog.max_radius`, `grid.half_extent`, `grid.cell_size`, `grid.dim - 1` into locals before the loop and replace the 4 `grid.cell_coord()` calls per enemy with the same expression inline (`clampi(floori((v + he) / cs), 0, dmax)`, same operand order so the result is bit-identical). Same inlining in `SpatialGrid.rebuild()` (2 calls per enemy, GRID phase). `_apply_bosses` is cold: leave it.
2. **Targeting, exact** (`sim` `game/sim/spatial_grid.gd`, `nearest()`): locals for `cell_start` / `cell_items` / `dim`, and scan each ring's top and bottom rows as one contiguous range (cells `gx0..gx1` of one row are contiguous in `cell_items`), side cells one by one as now. The result is unchanged: the best (smallest `d2`, lowest index on ties) does not depend on visit order, and the ring early-out rule is unchanged. Do not inline into `SimTowers.retarget` and do not cache tower cells (300 calls are not the cost; skip unless the bench says otherwise).
3. **Cell size `2 * max_radius`** (`sim` `game/sim/sim_world.gd` line `SpatialGrid.new(4.0 * ...)`, D-082 change): scan reach `r_i + max_radius <= 2 * max_radius` = one cell, so each enemy reads 2-3 cells per axis of 0.8 instead of 1-2 of 1.6, about 40% fewer pair candidates (`reports/perf_m1.md` 5). Not bit-exact: pairs are summed in another order, so positions differ in the last float bits (still deterministic). Costs to watch: grid rebuild (dim 80 -> 160, the prefix sum loops 25600 cells instead of 6400) and `nearest` (twice the rings for the same range). **Gate:** keep step 3 only if the release bench shows a net gain on `pc_stress` step (separation + grid + targeting together) and `pc_typical` does not get worse; otherwise revert it, say so in the PR, and D-108 is not used. If kept and `nearest` got slower, the allowed fix is a row-span scan: rows outward from the point's row, each row one contiguous range limited to the x-span that can still beat `best_d2` (plus a small margin so ties on the boundary are never skipped), stop when a row's minimum z-gap squared exceeds `best_d2`; exact by the same order argument.

Not in scope: GDExtension, threads, retarget-every-N (design), changing the push cap or any D-084 rule.

### Tests
- `test_enemy_separation.gd`: `test_matches_reference` (write it **first**, against the current code): a test-local O(n^2) reference of the D-084 rule (pairs i < j, Jacobi buffers, coincident rule, per-enemy cap), 400 enemies at seeded random positions in a 10 x 10 square, mixed swarmer/brute/ranged plus one boss and one coincident pair; one `apply` on each copy; every position equal within 1e-4. It must pass after every step.
- `test_spatial_grid.gd`: `test_nearest_ties_on_lattice`: enemies on an integer lattice (many equal distances) and 200 queries at lattice points and half-points with ranges 1..8, `nearest` equal to `_brute_nearest` every time. If step 3 is kept, `test_sim_world_grid_matches_enemies` asserts `2.0 * max_radius`.
- Existing determinism, separation, tower-target and grid brute-force tests stay green unchanged (no test pins a hash value).
- Headless timings in the PR: `test_separation_cost_3000_piled` and `test_print_timings` before/after (3 runs each).

### Performance and measurement
- Release bench (`scriptsench.ps1`, GPU) before any change, after steps 1+2, and after step 3: one table per run in the PR, all 6 scenarios, step + separation + grid + targeting. Goal `pc_stress` step <= about 6.5 ms. If steps 1-3 do not reach it, report the gap: do not add more optimisations in this task (023 picks it up with combat).
- No allocation added in the hot loops.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a spatial hash bullet: cell size (if step 3 kept) and the `nearest` row-range scan; separation bullet: replace the M1 cost numbers with the new headless and release ones.
- `DECISIONS.md` (only if step 3 kept): **D-108 PROPOSED**: grid cell size = `2 * max horde radius` (largest horde collision diameter), replacing the cell-size part of D-082, for cost only; the rest of D-082 stands.
- `reports/perf_m1.md` section 5: one line per row saying done in 025 (or measured and dropped).

### Order
1. `test_matches_reference` + lattice test, green on the current code; bench "before" (or reuse the 013 table if the machine is unchanged and quiet). 2. Step 1, step 2; headless timings; bench. 3. Step 3; bench; apply the gate. 4. Docs; `scripts	est.ps1` twice, `scriptsalidate.ps1`.

Size: about 60-100 changed lines of code, about 80 of tests. One PR.

## Questions

## Review log
