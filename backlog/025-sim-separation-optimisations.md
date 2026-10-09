# 025 — Sim: cheap separation and targeting optimisations (priority)
- Status: todo
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

## Questions

## Review log
