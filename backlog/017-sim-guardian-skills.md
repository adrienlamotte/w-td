# 017 — Sim: Guardian skills (Area blast, Shield)
- Status: todo
- Milestone: M2
- Depends on: 014
- PR: -

## Goal
The two M2 Guardian skills, triggered by UseSkill.

## Context
- D-044 (Area blast ~12 s, Shield ~25 s, no auto-attack; Heal later)
- From 014's plan (D-107): Area blast damages through `SimWorld.damage_enemy`; the Shield absorbs inside `SimWorld._hit_guardian` (the only path for damage to the Guardian; `GUARDIAN_HIT` value = damage after shield).

## Acceptance criteria
- Area blast damages enemies in a ring from data; Shield absorbs damage to the Guardian for a data amount and duration.
- Cooldowns; UseSkill during cooldown is rejected; SkillUsed events.
- Tests per skill.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
