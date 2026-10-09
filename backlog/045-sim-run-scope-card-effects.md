# 045 — Sim: run-scope card effects (build radius, rebuild price, detour damage)
- Status: planned
- Milestone: M3
- Depends on: 033
- PR:

## Goal
The three card effects that change existing sim rules work: `perk_expand` grows the build radius, `perk_masonry` halves the rebuild price, `perk_maze` adds damage to enemies that are detouring. Split out of 033 to keep both PRs reviewable; 033 already puts these entries in the modifier store.

## Context
- `docs/10_M3_CONTENT.md` 2.4 (`perk_expand`: the build grid is allocated at StartRun for the largest reachable radius, placement checks the current one; `perk_maze`: `hit[c] != -1` in the flow field, one cell lookup per tower hit, only when the perk is held; `perk_masonry` rebuild price -50%), 2.5 (effect vocabulary), 3.3 (cost).
- D-109 (build grid), D-113 (rebuild price), D-115 (flow field `hit`), D-124 (maze tick budget), D-144 (modifier store), D-147 (card effects).

## Acceptance criteria
- `build_radius` (target `run`): the current radius = run radius + the sum of `build_radius` add entries; placement (`check_place`) uses it; the build grid is sized at StartRun for the largest reachable radius, so a pick never reallocates the grid or the flow field.
- `rebuild_price` (target `run`): the rebuild price = `floori(paid * rebuild_fraction * (1 + mult))`, at least 0; `check` and the command agree (D-121).
- `detour_damage` (target `all_towers`): a tower hit on an enemy whose cell has `field.hit[c] != -1` deals `damage * (1 + mult)`; no lookup when the sum is 0.
- Tests per effect, determinism; `scripts\bench.ps1` maze and combat scenarios within noise (D-124).
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan
Decision ID: **D-148** (PROPOSED, rules below). About 80 lines of code plus about 120 of tests; no data or schema change. All `sim/` except the tests. Last of the order 031 -> 034 -> 033 -> 045 (docs/plans/M3.md).

### Rules (D-148)
1. **Reachable radius.** At StartRun, `max_build_radius` = run `build_radius` + the `build_radius` add entries already in the store (none until 035's meta effects) + for every card whose effects add `build_radius`, `max_picks` x value (`perk_expand`: 2 x 3 = 6). The `BuildGrid` is created with it (88 to 112 cells per side for `run_m2`: a longer first flow-field computation, not a higher per-tick cost, `CELLS_PER_TICK` caps it). Hashed `build_radius` (current) = run radius + store adds, updated in the 030 recompute when dirty; `check_place` reads `w.build_radius`, and `FlowField` / spawns are unchanged.
2. **Rebuild price.** `TowerBuilding.rebuild_price` = `maxi(0, floori(paid * rebuild_fraction * (1 + m)))`, `m` = sum of `rebuild_price` mult on `run`, cached in the recompute.
3. **Detour damage.** Cached `detour_mult` (sum of `detour_damage` mult on `all_towers`). In `TowerAttacks.fire`, when `detour_mult != 0` and `w.field` exists, every `damage_enemy` from a tower checks `field.hit[build.cell_of(x, z)] != -1` for the hit enemy (cells outside the grid count as no detour) and multiplies the damage by `1 + detour_mult`. Skills and thorns are not tower shots: unchanged.

### Files
1. `sim` `game/sim/sim_world.gd` (+15): `max_build_radius`, `build_radius`, `rebuild_mult`, `detour_mult` (caches next to `TowerStats.recompute`); StartRun sizes `BuildGrid` with `max_build_radius`; `state_hash()` adds `build_radius`.
2. `sim` `game/sim/card_catalog.gd` (+5): `max_build_radius_bonus` summed at load (rule 1).
3. `sim` `game/sim/tower_building.gd` (~4): `check_place` radius, `rebuild_price` (rule 2).
4. `sim` `game/sim/tower_attacks.gd` (+15): a `_hit(w, i, dmg)` helper used by every branch, applying rule 3.

### Tests (headless)
- `game/tests/sim/test_run_effects.gd` (new): grid size for `run_m2` (112 x 112), placement at radius 21 refused, then OK after one `perk_expand` pick (and 26 after two, 27 refused); rebuild price halves with `perk_masonry` (`check` = command); `perk_maze` adds 20% to a hit on an enemy standing in a detour cell (a wall forcing `hit != -1`) and nothing on a clear line; no effect without the perk.
- Fix the M2 tests that assert the 88 x 88 grid (they now get 112), with a comment.
- `test_determinism.gd`: replay on `run_m3` with `perk_expand` and `perk_maze` picked, same `state_hash` twice.
- Release bench `scripts/bench.ps1`: `pc_maze`, `pc_maze_combat`, `pc_combat_stress` within noise of `reports/perf_m2.md` (D-124); table in the PR. Expected neutral: the bench does not hold `perk_maze`; the `detour_mult != 0` check is one compare per shot.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: build area (max and current radius), rebuild price, tower attacks (detour damage); D-148 PROPOSED in `DECISIONS.md`.

### Order
1. Build radius and grid sizing, fix the grid-size tests. 2. Rebuild price. 3. Detour damage. 4. Tests, bench, docs, D-148; `scripts/test.ps1` twice, `scripts/validate.ps1`.

## Questions

## Review log
