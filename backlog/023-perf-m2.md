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

## Acceptance criteria
- Bench scenarios include combat (towers attacking, deaths, spawns).
- If any budget fails, apply the cheap optimisations first; report before/after.
- `reports/perf_m2.md` and the 02 section 4 table updated.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
