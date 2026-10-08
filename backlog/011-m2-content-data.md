# 011 — Data: M2 content definitions and schemas
- Status: todo
- Milestone: M2
- Depends on: -
- PR: -

## Goal
Define all M2 content as data with schemas, so later tasks only read it: enemies, towers, Guardian, run timeline and economy.

## Context
- `01_GAME_DESIGN.md` 3, 4, 6, 8
- D-042 (build radius ~20, cost grows per copy), D-043 (tower HP, husks), D-044 (Guardian skills), D-045 (3 tower types), D-047 (boss at 15:00), D-093 (60 s waves), D-095 (swarmer, brute, ranged + bosses), D-097 (mini-bosses 5:00 and 10:00)
- `02_TECH_ARCHITECTURE.md` 3b, 5 (data + JSON Schema, localisation keys, schema_version)

## Acceptance criteria
- Enemy files for swarmer, brute, ranged, 2 mini-bosses and the final boss: hp, speed, radius, contact damage, attack range and cooldown (ranged), gold drop, separation strength, name as a localisation key.
- Tower files for the 3 M2 types (ranged single target, splash, slow): cost, cost growth per extra copy, hp, range, damage, cooldown, splash radius, slow amount and duration, sell refund fraction, husk rebuild fraction.
- Guardian file: hp, contact radius, the 2 skills (Area blast ~12 s cooldown, Shield ~25 s cooldown) with their numbers.
- Run file: wave length 60 s, break 15-20 s, spawn curve per wave (counts and enemy mix), mini-boss times 5:00 and 10:00, final boss 15:00, starting gold, build radius, placement grid step.
- Every number is a placeholder and says so; sim catalogs load them; the validator checks them (schemas, references between files).
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
