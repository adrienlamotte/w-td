# 038 — UI: tower upgrade controls, hints and level display
- Status: blocked
- Milestone: M3
- Depends on: 030
- Blocked on: Q-67
- Labels: needs-human:playtest
- PR:

## Goal
The player can upgrade a placed tower with mouse/keyboard and with the gamepad, and sees its level and the next price, or why it cannot be upgraded.

## Context
- `docs/10_M3_CONTENT.md` 3.2 (per placed tower, gold, level 4 needs the signature card), D-134, D-137.
- `docs/09_CONTROLS.md` has no upgrade binding (Q-67); D-121 (verdict and price from the sim's `check_upgrade`), D-122 (hints).

## Acceptance criteria
- The input chosen in Q-67 queues `UPGRADE_TOWER` for the tower under the cursor, only when building is allowed.
- The hint shows the upgrade price or the refusal reason (max level, needs the card, not enough gold); each tower's level is visible on the field.
- Tests for the input mapping and the hint text; `09_CONTROLS.md` updated.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan

## Questions

## Review log
