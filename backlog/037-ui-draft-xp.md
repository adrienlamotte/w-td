# 037 — UI: level-up draft, XP bar and card-unlocked towers in the build bar
- Status: todo
- Milestone: M3
- Depends on: 033
- Labels: needs-human:playtest
- PR:

## Goal
The player sees XP and level, picks one of 3 cards when the draft opens (mouse, keyboard and gamepad), and towers unlocked by cards appear in the build bar and the radial.

## Context
- `docs/10_M3_CONTENT.md` 1 (the draft freezes the run like a pause; pause allowed during a draft; no skip), 2 (card text from `name_key` / `desc_key`).
- `docs/09_CONTROLS.md` Menus (GUI focus) and Build UI; D-121 (cards and eligibility come from the sim), D-122, D-039 (font sizes).
- Up to 8 buildable towers per run: the build bar and radial grow, slot keys go from 1-3 to 1-8 (`09_CONTROLS.md` updated, PROPOSED).

## Acceptance criteria
- Draft overlay (CanvasLayer) shown while drafting: 3 cards with name, type and description, the first focused; a pick queues `PICK_CARD`; mouse, keyboard and gamepad; nothing else takes input meanwhile except pause.
- HUD: level and XP bar from sim state, text rebuilt on change only.
- Build bar and radial show the run's current buildable towers; slot keys 1-8.
- Headless view tests (overlay shows the sim's cards, a pick queues the right slot, the build bar grows); no font under 32 px at base.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan

## Questions

## Review log
