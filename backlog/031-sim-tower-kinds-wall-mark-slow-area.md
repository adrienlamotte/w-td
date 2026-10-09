# 031 — Sim: tower kinds wall, mark and slow_area
- Status: todo
- Milestone: M3
- Depends on: 030
- PR:

## Goal
Bastia (`wall`, with thorns), Clover (`mark`) and Tansy (`slow_area`) work in the sim.

## Context
- `docs/10_M3_CONTENT.md` 3.1 (rules), 3.3 (cost: walls skip targeting; `slow_area` one `query_radius` per shot; mark arrays `mark_gold` / `mark_until` as absolute ticks, swapped in `remove()`, read once in DEATHS; thorns one `damage_enemy` inside the walled-in attack).
- D-114 (tower attacks), D-116 (walled-in attacks), D-117 (slow rule), D-107 (`damage_enemy`, DEATHS gold).
- `tax` (Gilda) is out of M3 scope: rivals come with the tiers (D-131).

## Acceptance criteria
- `wall`: never targets or fires; a walled-in enemy hitting her takes her derived `thorns` (levels and synergies apply) through `damage_enemy` (a normal `ENEMY_HIT`).
- `mark`: a `single` shot that marks the target for `mark_sec`; a marked enemy dying from any source drops `mark_gold` extra (higher gold wins, longer expiry wins, no stacking), included in the `ENEMY_DIED` value.
- `slow_area`: the `splash` query; every enemy hit is also slowed by the D-117 rule.
- New enemy arrays hashed; tests per kind; determinism. `scripts\bench.ps1` maze and combat scenarios within noise (D-124).
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan

## Questions

## Review log
