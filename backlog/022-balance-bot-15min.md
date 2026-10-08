# 022 — Headless bot run: a 15-minute run is playable
- Status: todo
- Milestone: M2
- Depends on: 013, 016, 017
- PR: -

## Goal
Prove the M2 run works end to end without a human: a simple scripted bot builds towers and uses skills; tune placeholder data so a run can be both won and lost.

## Context
- `06_ROADMAP.md` M2 'done when' (a full 15-minute run is playable start to finish)
- `02_TECH_ARCHITECTURE.md` 6 (balance runner proper is M3)

## Acceptance criteria
- A headless command runs N seeded runs with 2-3 simple bot strategies and writes `reports/balance_m2.md` (win rate, time of death, gold curve).
- Placeholder numbers tuned so a decent strategy usually wins and a passive one loses; changes stay in data.
- Marked needs-human:balance; the owner reviews at CP-M2.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
