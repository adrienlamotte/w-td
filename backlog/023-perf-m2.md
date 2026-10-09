# 023 — Performance with combat: optimise and re-bench
- Status: todo
- Milestone: M2
- Depends on: 013, 016, 024, 026
- PR: -

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

## Questions

## Review log
