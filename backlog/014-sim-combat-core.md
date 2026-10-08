# 014 — Sim: enemy HP and death, Guardian HP, gold, win and lose
- Status: todo
- Milestone: M2
- Depends on: 011, 012
- PR: -

## Goal
Make the run winnable and losable: damage, deaths, Guardian contact, ranged enemies, automatic gold.

## Context
- D-043 (enemies attack what blocks their straight path, else the Guardian), D-094 (gold on death), D-098 (instant hit), D-047 (win by killing the final boss)
- M1 placeholder to replace: enemies stopped at their own radius (no Guardian contact radius)

## Acceptance criteria
- Enemies have HP; deaths remove them with events and add gold immediately (D-094).
- Guardian has HP and a contact radius from data; melee enemies stop at contact and attack on a cooldown.
- Ranged enemies stop at their attack range from their target and hit instantly on a cooldown (D-098).
- Lose when Guardian HP reaches 0; win when the final boss dies; RunEnded event.
- Tests for each rule; determinism with combat.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
