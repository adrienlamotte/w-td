# 031 — Sim: tower kinds wall, mark and slow_area
- Status: review
- Milestone: M3
- Depends on: 030
- PR: #39

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
Decision ID: **D-145** (PROPOSED, rules below). About 150 lines of code plus about 150 of tests; no data or schema change (029 shipped `thorns`, `mark_sec`, `mark_gold`, `splash_radius`, `slow_*` on Bastia, Clover and Tansy). Everything is `sim/` except the tests. Order in the milestone: first of 031 -> 034 -> 033 -> 045 (docs/plans/M3.md).

### Rules (D-145)
1. **Towers that never shoot enemies skip targeting.** `TowerStats` writes `attack_range = 0` for the kinds `wall`, `aura` and `repair`; `SimTowers.retarget` sets `target = -1` without a grid query when `husk[t]` or `attack_range[t] <= 0`. So Bastia (and later Hymn) cost nothing in TARGETING and never fire; 032 reads Poppy's heal range from her level table, not from `attack_range`.
2. **Thorns.** In `SimWorld._enemy_attacks`, walled-in branch (D-116): after `damage_tower(k, dmg)`, if `towers.thorns[k] > 0` the attacker takes `damage_enemy(i, thorns[k])` (a normal `ENEMY_HIT`). Every hit that lands counts, the lethal one too (the tower was hit). Not reduced or changed by anything else in M3.
3. **Mark.** `mark` fires like `single` (one target, `damage_enemy`), then marks the target: an existing mark is active while `clock < mark_until[i]`; an expired mark counts as none. New values: `mark_gold[i] = max(active gold, tower mark_gold)`, `mark_until[i] = max(active until, clock + tower mark_ticks)` (the two maxima are independent: higher gold wins, longer expiry wins, no stacking). In DEATHS, a dying enemy with `clock < mark_until[i]` adds `mark_gold[i]` to its gold, independent of the base `gold_chance` roll, after the base gold (033 multiplies only the base by `kill_gold`), and the sum is the `ENEMY_DIED` value.
4. **slow_area.** Same `query_radius` as `splash` around the target; every enemy hit takes `damage_enemy` then `apply_slow` (D-117) with the tower's derived `slow_factor` and `slow_ticks`, in query order.
5. **Derived fields.** `thorns`, `mark_gold` and `mark_ticks` (from `mark_sec`) are per-tower derived arrays from the level table, like `splash_radius` (030). No card modifies them; 032 adds the synergy bonuses (`thorns` +3, `mark_gold` +1) to the same derive step.

### Files
1. `sim` `game/sim/tower_catalog.gd` (+2): `_LEVEL_DEFAULTS` gains `thorns` 0, `mark_sec` 0, `mark_gold` 0. Remove the stale "M3 kinds are loaded but not simulated" line.
2. `sim` `game/sim/sim_towers.gd` (+15): derived `thorns` (float), `mark_gold` (int), `mark_ticks` (int) through `add()` (0) and `remove()`; `retarget` skips `attack_range <= 0` (rule 1).
3. `sim` `game/sim/tower_stats.gd` (+8): `_derive` writes the three fields; `attack_range = 0` for `WALL`, `AURA`, `REPAIR` (read the kind from `w.tower_catalog.attack`).
4. `sim` `game/sim/sim_enemies.gd` (+8): `mark_gold: PackedInt32Array`, `mark_until: PackedInt32Array` (absolute run clock tick), 0 at `add()`, through `remove()`.
5. `sim` `game/sim/tower_attacks.gd` (+20): `MARK` branch (damage then `_mark(w, target, t)`), `SLOW_AREA` branch (rule 4). `WALL`, `AURA`, `REPAIR` never reach the match (target -1).
6. `sim` `game/sim/sim_world.gd` (+12): thorns in `_enemy_attacks` (rule 2); mark gold in `_deaths` (rule 3); `state_hash()` adds `enemies.mark_gold`, `enemies.mark_until`, `towers.thorns`, `towers.mark_gold`, `towers.mark_ticks`. Also fix the 030 nit: the `PLACE_TOWER, ..., UPGRADE_TOWER:` match pattern has stray tabs mid-line; put `SimCommand.Type.UPGRADE_TOWER` on a proper continuation line (or one line).

### Tests (headless)
- `game/tests/sim/test_tower_kinds.gd` (new): wall never targets (target -1 with an enemy in reach), never fires (no `TOWER_FIRED`); thorns: a walled-in enemy hitting a Bastia takes 3 (L1) and 6 (L3) per hit, a normal `ENEMY_HIT`, the lethal hit too (reuse the walled-in setup of `test_walled_in.gd`); mark: shot marks for `DataFiles.ticks(4)`, kill while marked adds 2 gold to `ENEMY_DIED` value (enemy with `gold_chance` 0 or forced, so the base roll does not hide it), kill after expiry adds nothing, a higher-gold mark replaces gold but keeps the longer expiry, swap-remove moves the marks; slow_area: every enemy in `splash_radius` of the target is damaged and slowed (D-117: stronger factor wins), one outside is not.
- `test_sim_enemies.gd` / `test_sim_towers.gd`: the new arrays in their `remove()` checks.
- `test_determinism.gd`: a replay with Bastia, Clover and Tansy built (`add_built`) on `run_m2` in a walled-in layout, same `state_hash` twice.
- Release bench `scripts/bench.ps1`: `pc_maze`, `pc_maze_combat`, `pc_combat_stress` within noise of `reports/perf_m2.md` (D-124); table in the PR. Expected neutral: the bench builds M2 towers only; the per-enemy cost is two more array swaps in `remove()`.

### Perf
No new per-tick loop: thorns is one call inside the existing walled-in hit, mark is one write per shot and one compare per death, slow_area reuses the splash query. Walls get cheaper (no grid query).

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: tower attacks (kinds `wall`, `mark`, `slow_area`, rule 1), enemy arrays (`mark_gold`, `mark_until`), tower derived arrays (`thorns`, `mark_gold`, `mark_ticks`), walled-in attacks (thorns), deaths (mark gold in the `ENEMY_DIED` value).
- `DECISIONS.md`: D-145 PROPOSED (rules 1-5).

### Order
1. Catalog defaults, derived arrays, rule 1 (existing suites green). 2. Thorns. 3. Mark arrays, mark shot, mark gold. 4. slow_area. 5. Tests, determinism, bench, docs, D-145; `scripts/test.ps1` twice, `scripts/validate.ps1`.

## Questions

## Review log
