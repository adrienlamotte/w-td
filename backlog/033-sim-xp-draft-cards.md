# 033 — Sim: XP, level-up draft and card effects
- Status: todo
- Milestone: M3
- Depends on: 030
- PR:

## Goal
Kills give XP; a level-up freezes the run and offers 3 cards; `PICK_CARD` applies one. Card effects feed the modifier store (030), unlock towers and level 4, and change the run-scope stats.

## Context
- `docs/10_M3_CONTENT.md` 1 (XP in DEATHS times the XP multiplier, float total, curve `xp_base + xp_step * (L - 1)`, `LEVEL_UP` then `drafting` frozen like a pause, draw with the `cards` RNG: weighted type then a uniform card, filler `card_purse`, queued level-ups, pause allowed during a draft), 2 (card pool, eligibility, `max_picks`), 2.4 (`perk_maze` via `hit[c] != -1`; `perk_expand`: build grid allocated for the largest reachable radius), 2.5 (effect vocabulary).
- D-051 (cards never give a tower for free; no reroll, banish or skip), D-134 (the signature card unlocks level 4), `docs/02_TECH_ARCHITECTURE.md` 3a (per-concern RNG `hash([seed, "cards"])`, commands, events).
- Skill-scope effects (`skill_power`, `skill_cooldown`, `shield_*`) are stored here and consumed by 034.

## Acceptance criteria
- XP, level, the open draft (3 card indices), `drafting` and picked counts live in the world and are hashed. `LEVEL_UP` (a = level), `CARD_PICKED` (a = card index). While drafting nothing moves and building, upgrades and skills are refused; `PICK_CARD{slot}` closes it; a queued draft opens right after.
- Eligibility from the run's buildable towers and the unlocked waifus given at StartRun (a new `START_RUN` field; empty = nothing rescued, so the M2 tests are unchanged).
- Effects: `unlock_tower`, `unlock_level`, `gold`, `kill_gold` (rounded down per kill, before mark gold), `xp`, `build_radius`, `rebuild_price`, `detour_damage`, and the tower stats through the modifier store.
- Tests: XP thresholds, several level-ups in one tick, draw weights and determinism (same seed, same cards), filler slots, `max_picks`, each effect, the frozen state, replay from `(seed, commands)` with picks. `scripts\bench.ps1` maze and combat scenarios within noise (D-124).
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan

## Questions

## Review log
