# 032 — Sim: relationship synergies, Hymn's aura and Poppy's repair
- Status: todo
- Milestone: M3
- Depends on: 031
- PR:

## Goal
Relationship bonuses (the game's hook, D-057) and the two neighbour-based kinds (`aura`, `repair`) are computed in the derived-stats recompute, so their per-tick cost stays near zero.

## Context
- `docs/10_M3_CONTENT.md` 5.1-5.2 (active rule, distance window centre to centre, the Guardian measured from her body edge, one partner is enough, different relationships add up, Guardian-side bonus once per relationship), 3.1 (`aura`: the strongest Hymn in reach applies, no stacking; `repair`: lowest HP fraction in range every `cooldown`, else the Guardian if in range, level 4 two targets), 3.3 (pair scan through build-grid cells within the largest reach, neighbour list for repair).
- D-132 (the Guardian counts as a placed waifu), D-135 (repair), D-136 (rivals 2-6 units), D-128 (the maze must pay off).
- Rival rows (Vexa, Gilda) are supported by the format but have no files in M3.

## Acceptance criteria
- Synergy catalog loaded from `data/synergies`; each tower's active relationships and bonuses folded into its derived stats; Guardian-side bonuses (shield absorb, skill cooldown, skill power) written to the modifier store for 034.
- `aura`: Hymn never fires; towers whose centre is within `aura_radius` get her damage and cooldown bonus, strongest Hymn only.
- `repair`: on its cooldown only, heals the live tower in range with the lowest HP fraction below 100% (husks excluded; `heal_targets` at level 4), else the Guardian if in range for `guardian_heal` (capped at max HP); `TOWER_REPAIRED` (a = uid or -1, value = HP).
- Husks and bare towers never count as partners; place, sell, husk, rebuild and upgrade re-evaluate. The pair scan runs per change, never per tick.
- Tests: each 5.2 row, window edges (rivals 2-6), no stacking per partner, the Guardian as a partner, aura strongest-only, repair targeting and Guardian fallback, determinism; recompute time of a 300-tower layout measured in a headless test. `scripts\bench.ps1` maze and combat scenarios within noise (D-124).
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan

## Questions

## Review log
