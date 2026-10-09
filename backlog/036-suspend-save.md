# 036 — Save: suspend save and resume
- Status: todo
- Milestone: M3
- Depends on: 032, 033, 034, 035, 039
- PR:

## Goal
A run survives closing the game: a snapshot at card and wave boundaries, and Resume or Abandon on the next launch.

## Context
- `docs/10_M3_CONTENT.md` 7 (written when a draft opens and at `WAVE_STARTED`, never mid-wave; full sim state with RNG states, command queue and clock, plus `state_hash()` checked on load; a snapshot, not a replay; derived grids and fields rebuilt; deleted at run end; abandon = loss, hearts per 6.1).
- D-053, `docs/02_TECH_ARCHITECTURE.md` 7.
- Settings stay session-only (`10_M3_CONTENT.md` 7): fix the "saved settings are M3" line in `docs/09_CONTROLS.md`.

## Acceptance criteria
- Snapshot write and read of every hashed world field; load rebuilds derived state (spatial grid, build grid, flow field, uid index, derived tower stats) and checks `state_hash()` against the saved one; a mismatch or unreadable file is reported and the run counts as abandoned, never silently resumed.
- A resumed run continues identically: run N ticks with a save in the middle, reload, continue, same hash as an uninterrupted run (once with a draft open, once at a wave start).
- Start screen: Resume / Abandon when a suspend file exists; Abandon grants loss hearts.
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan

## Questions

## Review log
