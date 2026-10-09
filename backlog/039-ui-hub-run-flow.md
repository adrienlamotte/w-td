# 039 — UI: hub screen and M3 run flow
- Status: todo
- Milestone: M3
- Depends on: 035
- Labels: needs-human:playtest
- PR:

## Goal
Between runs the player sees her hearts, buys meta nodes, sees the roster and picks the Guardian to rescue from the offer; the end screen shows the hearts earned and returns to the hub.

## Context
- `docs/01_GAME_DESIGN.md` 7 (hub: meta currency, permanent upgrades, roster; outfits and bond come later), 3 (Guardian offer, win unlock).
- `docs/10_M3_CONTENT.md` 6 (hearts, tree), D-050, D-023, D-125 (run flow, reload for restart), D-121 (every number from the meta rules of 035), `docs/09_CONTROLS.md` Menus.
- Q-68 safe to assume ★ A (all 6 rescued: offer all 6 again).

## Acceptance criteria
- Flow: start screen -> hub -> Guardian pick -> run -> end screen (hearts earned, unlock shown on a win) -> hub. "Main menu" from the pause menu abandons with loss hearts (6.1).
- Hub: hearts; 12 nodes in 3 branches with cost and bought / locked / affordable state, buy; roster (starters, rescued, locked); mouse, keyboard and gamepad (GUI focus).
- The run starts with the `START_RUN` config built from the profile (035).
- Headless view tests (the offer shown matches the rule, a buy updates the profile, abandon grants hearts).
- Headless tests green twice; data validator green; docs (`02_TECH_ARCHITECTURE.md` 2, `09_CONTROLS.md` Menus) in the same PR.

## Plan

## Questions

## Review log
