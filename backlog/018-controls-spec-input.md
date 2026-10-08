# 018 — Controls spec and input layer (mouse and gamepad)
- Status: todo
- Milestone: M2
- Depends on: 012
- PR: -

## Goal
Write the controls spec and map keyboard, mouse and gamepad to sim commands and camera actions. Gamepad is first-class.

## Context
- D-041 (camera, gamepad: right stick pan, bumpers zoom, button recentre), D-046 (gamepad building: hold for radial menu, centre cursor, A place, B cancel, skills on triggers, slow-time option)
- `01_GAME_DESIGN.md` 9: no feature may need the mouse only

## Acceptance criteria
- `docs/09_CONTROLS.md`: full mapping for keyboard/mouse and gamepad, marked PROPOSED for the owner to approve at CP-M2.
- `game/input/` maps devices to commands; the view and sim never read devices directly.
- Gamepad camera controls added; centre-of-screen placement cursor for gamepad.
- Tests for the mapping layer where possible headless.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
