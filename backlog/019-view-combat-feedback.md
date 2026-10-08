# 019 — View: combat feedback and enemy/tower visuals
- Status: todo
- Milestone: M2
- Depends on: 016, 017
- PR: -

## Goal
Make combat readable: hits, deaths, shots, coins, skills, husks, and distinct placeholder looks per enemy and tower type.

## Context
- D-098 (shot effect is visual only), D-094 (coins fly to the Guardian), D-087 (MultiMesh rendering)
- M1 known gap: a removed enemy's slot can jump for one frame (fix it here)

## Acceptance criteria
- Placeholder visuals distinct per enemy type; bosses visibly bigger; tower types distinct; husks visible.
- Hit flash, death effect, shot lines, coin flight, blast ring and shield effects, all driven by sim events; no Node per enemy.
- The removal jump is fixed.
- Benchmark still runs.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
