# 043 — Perf: M3 re-bench and report
- Status: todo
- Milestone: M3
- Depends on: 036, 040, 041
- PR:

## Goal
Measure the M3 build against the budgets and re-check the known maze worst case (D-124).

## Context
- `docs/02_TECH_ARCHITECTURE.md` 4 and 6 (bench), `reports/perf_m2.md`, D-124 (`pc_maze_churn` re-checked at every milestone bench), D-080 (Deck estimate).

## Acceptance criteria
- New scenario(s) with M3 towers (every kind, upgraded, relationships active, auras) on the maze with combat on and cards picked; existing scenarios rerun; median of 3 runs.
- `reports/perf_m3.md` with the table against M2, Deck estimates and any trigger from `reports/perf_m1.md` section 6; `02_TECH_ARCHITECTURE.md` 4 updated.
- Any scenario over 8 ms per tick beyond noise is flagged for the owner (no silent tuning).
- Headless tests green twice; data validator green; docs in the same PR.

## Plan

## Questions

## Review log
