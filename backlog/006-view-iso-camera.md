# 006 — View: isometric camera, ground plane and tick interpolation
- Status: todo
- Milestone: M1
- Depends on: 002
- PR: -

## Goal
Show the sim in a 3D scene with an orthographic isometric-style camera over a flat ground plane, interpolating positions between sim ticks, with the PC camera controls from D-041.

## Context
- `02_TECH_ARCHITECTURE.md` 2 (2.5D, orthographic iso camera, movable camera), 3a (the view interpolates between ticks)
- D-039 base resolution 2560x1440; D-041 camera controls

## Acceptance criteria
- A view scene drives the sim with a fixed-step accumulator (one `step()` per 1/30 s) and interpolates between the previous and current tick for rendering.
- Orthographic camera; its angle, distance and the 3 zoom levels are tunable values in a data or resource file (the final angle is judged at the checkpoint).
- PC controls: WASD/arrows pan, edge scroll, mouse wheel switches between the 3 zoom levels; the camera is limited to the build radius (about 20 units, D-042) plus a margin. Gamepad camera is M2.
- Placeholder ground plane and a Guardian marker at (0, 0). No game rules in view code.
- The game opens on this scene (`scripts\run.ps1`).
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan

## Questions

## Review log
