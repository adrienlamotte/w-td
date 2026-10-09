# 034 — Sim: Guardians and signature skills
- Status: todo
- Milestone: M3
- Depends on: 030
- PR:

## Goal
The run's Guardian comes from `StartRun` (`guardian_id`) and has her signature skill plus the shared Shield. The 6 signature skill kinds work, and skill modifiers (cards, synergy Guardian bonuses, meta) apply.

## Context
- `docs/10_M3_CONTENT.md` 4.1 (kinds `area_blast`, `guard`, `bounty`, `haste`, `snare`, `rebuild`; a cast works once in COMMANDS; timed effects store an absolute `until` tick checked where code already runs; `power_stats`; rounding), 2.3 (`card_skill_sig_power`, `card_skill_sig_quick`, `card_skill_shield_plus`, `card_skill_mending`), 5.1 (Guardian-side synergy bonuses), 8 (`START_RUN` gains `guardian_id`; the run file drops `guardian`).
- D-133, D-139 (signature skills), D-110 (cooldowns on the run clock, Shield), D-044 (Heal as an upgrade), D-117 (Tangle uses the slow rule).
- `skill_area_blast` and `guardian_placeholder_01` stay for the M2 tests and the bench.

## Acceptance criteria
- `START_RUN{run_seed, run_id, guardian_id}`; the placeholder Guardian stays usable by tests and the bench.
- Each signature kind as specified; `guard_until`, `bounty_until`, `haste_until` hashed; Big Finish and Tangle one linear scan per cast; Emergency Rebuild restores every husk.
- Skill modifiers: signature power multiplies `power_stats` (integer stats rounded down), signature and all-skill cooldown multipliers (clamp at 50%), Shield absorb and duration, Mending heal on a Shield cast, Guardian max HP.
- Tests per kind and per modifier, timed effects expire on the run clock (frozen while paused), determinism. `scripts\bench.ps1` maze and combat scenarios within noise (D-124).
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan

## Questions

## Review log
