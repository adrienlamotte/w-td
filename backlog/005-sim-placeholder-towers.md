# 005 — Sim: placeholder tower arrays with targeting queries
- Status: todo
- Milestone: M1
- Depends on: 003
- PR: -

## Goal
Add the tower arrays and a per-tick nearest-enemy query per tower, so the benchmark carries the tower load (50 typical, 300 stress, D-042). No attacks yet (M2).

## Context
- `02_TECH_ARCHITECTURE.md` 3a: tower arrays pos_x, pos_z, hp, waifu_id, level, cooldown; arrays grow dynamically, no cap (D-040, D-042)

## Acceptance criteria
- Towers are packed arrays that grow dynamically; one call adds a tower (the full command queue is M2).
- Every tick each tower looks up its nearest enemy in range via the spatial hash and stores the target index; no damage.
- Tests: the target is the nearest enemy; 300 towers can be added.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan

## Questions

## Review log
