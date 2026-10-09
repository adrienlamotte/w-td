# 016 — Sim: the 3 tower attacks
- Status: todo
- Milestone: M2
- Depends on: 015
- PR: -

## Goal
The three M2 tower types fight: ranged single target, splash, slow.

## Context
- D-045, D-098 (instant hit)
- Targeting from M1 (nearest in range, D-085)
- From 014's plan (D-107): all damage goes through `SimWorld.damage_enemy(i, amount)`; tower attacks run in the ATTACKS phase before the enemy attacks; a tower skips a target with `hp <= 0` (killed earlier in the same phase; corpses are removed in the next tick's DEATHS phase).

## Acceptance criteria
- Each type attacks on its cooldown with instant hits: single target damage; splash damage around the target; slow applies a timed speed reduction (does not stack beyond the data rule).
- EnemyHit and EnemyDied events; slow affects movement in the tick order.
- Tests per type; determinism.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
