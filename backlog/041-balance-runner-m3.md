# 041 — Balance: M3 headless runner and first balance report
- Status: todo
- Milestone: M3
- Depends on: 032, 033, 034, 035, 045
- Labels: needs-human:balance
- PR:

## Goal
The full balance runner: bots that build, upgrade and pick cards, a maze strategy against a spread strategy, profile presets, and the first M3 balance report.

## Context
- `docs/02_TECH_ARCHITECTURE.md` 6 (M2 bot, D-126: deterministic sim clients that only queue commands and use read-only queries; `scripts\balance.ps1`), `docs/04_AGENT_WORKFLOW.md` 5 (nightly balance routine, `reports/balance_<date>.md`).
- D-128 (the maze must pay off: the report shows maze vs spread), `docs/10_M3_CONTENT.md`.
- Q-69 (numeric targets) blocks only the tuning task 042; this task reports the numbers.

## Acceptance criteria
- Bots `passive`, `spread`, `maze` (a corridor layout with walls and relationship pairs along the walls); each picks cards by a fixed deterministic priority, buys upgrades and rebuilds husks.
- Profile presets: `fresh` (nothing rescued, no meta) and `full` (all 6 rescued, whole tree), with each Guardian of the offer.
- `reports/balance_<date>.md`: win rate, death and win times, per-minute curves (as M2) plus level, cards picked, upgrades, active relationships and damage per tower kind; a maze vs spread summary line.
- `scripts\balance.ps1` runs it; a smoke test runs one short run headless.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan

## Questions

## Review log
