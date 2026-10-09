# 023 — Performance with combat: optimise and re-bench
- Status: todo
- Milestone: M2
- Depends on: 013, 016, 024
- PR: -

## Goal
Keep the budgets with the M2 load: apply the cheap GDScript optimisations listed in the M1 report if needed and re-run the benchmark with combat.

## Context
- `reports/perf_m1.md` (cheap optimisations, GDExtension triggers), D-088 (bench method)
- `02_TECH_ARCHITECTURE.md` 4 budgets
- Baseline after 011/012 (lead-dev bench, 2026-10-09, no combat yet): step 6.4 / 7.9 / 10.5 ms on pc typical / stress / piled, up from 5.7 / 6.6 / 8.7 ms at M1, most likely the larger horde cell (1.4 -> 1.6, brute radius 0.4, D-099). `pc_stress` is already near the 8 ms budget before combat.

## Acceptance criteria
- Bench scenarios include combat (towers attacking, deaths, spawns).
- If any budget fails, apply the cheap optimisations first; report before/after.
- `reports/perf_m2.md` and the 02 section 4 table updated.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
