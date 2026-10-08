# 003 — Sim: uniform spatial hash grid
- Status: todo
- Milestone: M1
- Depends on: 002
- PR: -

## Goal
Add the uniform spatial hash grid used for all spatial queries, rebuilt every tick.

## Context
- `02_TECH_ARCHITECTURE.md` 3, 3a: cell size = largest enemy collision diameter x 2 (start 2.0 units), rebuilt each tick

## Acceptance criteria
- Grid rebuilt from the enemy arrays every tick, using packed arrays (no Dictionary per cell, no allocation per tick after warm-up).
- Queries: enemies within a radius of a point; nearest enemy to a point within a max range.
- Results are deterministic (ordered by enemy index).
- Tests: query results match a brute-force scan on a seeded random layout; rebuild after enemies move.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan

## Questions

## Review log
