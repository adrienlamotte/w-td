# 040 — View: placeholder feedback for M3 towers, skills and relationships
- Status: todo
- Milestone: M3
- Depends on: 032, 034
- Labels: needs-human:art
- PR:

## Goal
The playtest can read what happens: tower looks per kind, active relationships, aura and repair, marks, thorns and the 6 signature skills, all with placeholder art.

## Context
- D-120 (looks from `data/render`, `FxPool` from sim events, no Node per enemy or effect), `docs/02_TECH_ARCHITECTURE.md` 2.
- Events and state from 031-034: `TOWER_REPAIRED`, thorns as `ENEMY_HIT`, `SKILL_USED`, `guard_until`, `bounty_until`, `haste_until`, the mark arrays.

## Acceptance criteria
- Distinct placeholder looks per kind (wall, aura, repair, mark, slow_area) in render data; a marker on towers with an active relationship; aura radius ring; repair beam; marked enemies tinted; one effect per signature skill (ring, tint or disc from state); all cosmetic.
- No per-enemy Node; `scripts\bench.ps1` shows no view fill regression.
- Headless tests for the new `FxPool` mappings.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan

## Questions

## Review log
