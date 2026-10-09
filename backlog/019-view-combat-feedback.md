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
- From 012's plan: `world.events` (SimEvents, SoA) is cleared at the start of every `step()`; the driver runs up to 5 steps per frame, so read events after each step.
- From 016/026 plans: tower shots come as `TOWER_FIRED` (a = tower uid, x, z = target position, value = tower type); enemy hits on towers as `TOWER_HIT` (a = tower uid, x, z = attacker position, value = damage); Guardian hits as `GUARDIAN_HIT` (source position). Tower `hp`/`husk` and enemy `slow_ticks` are readable arrays.

## Acceptance criteria
- Placeholder visuals distinct per enemy type; bosses visibly bigger; tower types distinct; husks visible.
- Hit flash, death effect, shot lines, coin flight, blast ring and shield effects, all driven by sim events; no Node per enemy.
- The removal jump is fixed.
- Benchmark still runs.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
