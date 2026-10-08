# 002 — Sim: enemy arrays, spawning and chasing the Guardian
- Status: todo
- Milestone: M1
- Depends on: -
- PR: -

## Goal
Store enemies in the sim as packed arrays and move them straight toward the Guardian at (0, 0) every 30 Hz tick.

## Context
- `02_TECH_ARCHITECTURE.md` 3, 3a (SoA arrays, determinism, per-concern RNG), D-038
- `01_GAME_DESIGN.md` section 2: enemies path straight toward the Guardian
- Enemy data: `game/data/enemies/enemy_swarmer_01.json` (placeholder numbers)

## Acceptance criteria
- Enemy state lives in `PackedFloat32Array` / `PackedInt32Array` (pos_x, pos_z, hp, type_id, state, anim_frame) that grow dynamically; no Node, no per-enemy object.
- Enemy stats (speed, radius) come from the data file, not code.
- A spawn API places enemies on a ring around the Guardian at positions drawn from the seeded spawn RNG (the benchmark and tests need it; the real spawn curve is M2).
- Each tick moves every enemy toward (0, 0) at its speed x SIM_DT; enemies stop at the Guardian (no damage yet).
- Removing an enemy is O(1) (swap-remove).
- Headless tests: movement per tick, spawn count, and the determinism test extended so `state_hash()` covers the enemy arrays (same seed = same hash, different seed = different hash) after 1800 ticks with 1000 enemies.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan

## Questions

## Review log
