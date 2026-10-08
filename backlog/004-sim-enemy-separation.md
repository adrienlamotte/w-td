# 004 — Sim: enemy crowd behaviour
- Status: blocked
- Milestone: M1
- Depends on: 003
- PR: -
- Blocked on: Q-41

## Goal
Apply the crowd behaviour the owner chooses (Q-41) so the horde reads well and the benchmark has a realistic per-tick cost.

## Context
- Q-41 (blocked until answered)
- `01_GAME_DESIGN.md` 2.3: the horde must stay readable

## Acceptance criteria
- Behaviour matches the Q-41 answer, uses the spatial hash, and stays deterministic.
- Tests: the chosen behaviour is covered (for example two overlapping enemies separate over a few ticks); determinism test still green.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan

## Questions

## Review log
