# 004 — Sim: enemy crowd behaviour
- Status: todo
- Milestone: M1
- Depends on: 003
- PR: -

## Goal
Apply soft separation (D-079) so the horde reads well and the benchmark has a realistic per-tick cost.

## Context
- D-079 (Q-41): soft separation; enemies push each other apart a little and may still overlap slightly under pressure; strength and radius are placeholder values in data
- `01_GAME_DESIGN.md` 2.3: the horde must stay readable

## Acceptance criteria
- Soft separation as in D-079, tunable from data, uses the spatial hash, and stays deterministic.
- Tests: the chosen behaviour is covered (for example two overlapping enemies separate over a few ticks); determinism test still green.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan

## Questions

## Review log
