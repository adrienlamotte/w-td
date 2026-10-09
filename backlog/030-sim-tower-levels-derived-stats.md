# 030 — Sim: tower levels, UPGRADE_TOWER and derived tower stats
- Status: done
- Milestone: M3
- Depends on: 029
- PR: #38

## Goal
Placed towers have a level (1-4) bought per tower with gold, and every tower's effective stats come from packed derived arrays that are recomputed only when the layout or a modifier changes. This is the base that perks, meta nodes, synergies and auras plug into.

## Context
- `docs/10_M3_CONTENT.md` 3.2 (levels, `UPGRADE_TOWER{tower_uid}`, upgrade gold adds to `paid`, rebuild keeps the level, level values absolute), 3.3 (derived stats, dirty flag, recompute once in the next PATH phase), 2.5 (modifier rule: multipliers of one stat add up; cooldown clamp at 50% of the level value and at least 1 tick).
- D-134 (levels 2-3 gold, level 4 needs the signature card), D-137 (per placed tower), D-113 (sell refund, rebuild fraction), D-105 (no building while paused), D-121 (UI verdicts come from the sim query the command uses), D-124 (maze tick budget).
- `docs/02_TECH_ARCHITECTURE.md` 3a: Towers, Tower attacks, tower building. Data shape from task 029 (`levels`, `needs_card`).

## Acceptance criteria
- `UPGRADE_TOWER{tower_uid}`: only while RUNNING and not paused (and not drafting once 033 lands); refused on a husk, at max level, without gold, or for level 4 without its unlock; price = the next level's `cost`; `paid` grows; `TOWER_UPGRADED` (a = uid, value = level). A read-only `check_upgrade` (reason + price) that the command itself uses, for the UI.
- Per-tower `level` (hashed) and derived arrays (damage, cooldown ticks, range, max HP and the per-kind fields) read by targeting and attacks instead of catalog lookups. A modifier store (`stat`, `op`, `target`, per the 2.5 vocabulary) feeds the recompute; nothing fills it in this task except tests.
- Recompute on place, sell, rebuild, upgrade, husk and modifier change, once in the next PATH phase; max HP rise adds the difference, a fall clamps HP; never per tick.
- Tests: upgrade rules and refusals, sell and rebuild with upgrade gold, derived stats per level, modifier sum and clamps, determinism. `scripts\bench.ps1`: `pc_maze`, `pc_maze_combat`, `pc_combat_stress` within noise of `reports/perf_m2.md` (D-124); numbers in the PR.
- Headless tests green twice; data validator green; docs (`02_TECH_ARCHITECTURE.md` 3a) and a PROPOSED decision in the same PR.

## Plan
Decision ID: **D-144** (PROPOSED, the rules below). About 300 lines of code plus about 200 of tests; no data or schema change (029 shipped `levels` and `needs_card`). Everything is `sim/` except the tests. The input/UI side (R / d-pad up, hints, D-141) is task 038; it calls `TowerUpgrade.check` read-only.

### Rules (D-144)
1. **Level tables.** A level inherits every stat of the level below and overrides the ones its `levels` entry lists (values absolute, 3.2): Pip L4 = damage 10, range 7, cooldown 0.35. Max level = 1 + `levels.size()` (the M2 `tower_*_01` files: 1, so they can never be upgraded).
2. **Derived value** of a stat for a tower = `(level value + sum of add) * (1 + sum of mult)` over the modifiers whose target matches (`all_towers` or `tower:<its id>`); multipliers add up (2.5). Cooldown: `ticks = max(1, ceili(level_ticks * 0.5), roundi(level_ticks * (1 + mult)))` (clamp at 50% of the level value and 1 tick). Derived in this task: `range`, `damage`, `cooldown`, `hp` (max HP) and the per-kind fields the attacks read today (`splash_radius`, `slow_factor`, `slow_sec`). 031 and 032 add their kind fields (thorns, mark, aura, heal) to the same function; price, refund, rebuild, kill gold, XP and detour stats are read by the tasks that apply them (033, 035).
3. **Modifier store** (`SimModifiers`): flat entries `{stat, op, value, target}` exactly as the 2.5 effect object, so 033 (cards) and 035 (meta) push card and node effects as they are, unfiltered; nothing fills it in this task except tests. Adding an entry sets the towers' dirty flag. Hashed.
4. **Level 4 unlock** = the store holds an entry `{stat: "unlock_level", value >= 4, target: "tower:<id>"}` (the signature card's own effect, 029), so `TowerUpgrade` never needs to know about picked cards. `needs_card` stays the data link for the UI and the draft.
5. **UPGRADE_TOWER{tower_uid}** (appended to `SimCommand.Type`): gate in `SimWorld._apply` with the other building commands (RUNNING and not paused, D-105; 033 adds "not drafting"). `TowerUpgrade.check(w, uid) -> Check{reason, price, level}`, reasons in check order `OK, NO_TOWER, HUSK, MAX_LEVEL, LOCKED, NO_GOLD` (D-121: the command calls `check` and commits only on OK). Commit: `gold -= price`, `paid += price` (so sell and rebuild follow, D-113), `level += 1`, dirty, `TOWER_UPGRADED` (appended to `SimEvents.Kind`; a = uid, x, z = tower position, value = new level). Price = the next level's `cost`, never grows with copies (3.2).
6. **Recompute.** `towers.stats_dirty` is set on place, sell, rebuild, upgrade, husk (`TowerBuilding.damage` lethal hit) and modifier change. `SimWorld.step()` runs `TowerStats.recompute(self)` at the end of the PATH phase when dirty (same tick as the command, before targeting; never per tick otherwise), and clears the flag. Per built tower: new max HP; a live tower whose max rises gains the difference, a fall clamps `hp`; husks keep `hp` 0. A newly built tower (`add_built`) gets its stats at once through `TowerStats.apply(w, t)` with `hp = max_hp`, so the arrays are never stale for tests and the bench; it also sets dirty for neighbour effects (032). Rebuild restores `hp = max_hp[t]` and keeps the level.

### Files
1. `sim` `game/sim/tower_catalog.gd` (+20): `max_level: PackedInt32Array`; `level_stats: Array` (per type, an Array of resolved Dictionaries, index level - 1; keys as in data: `range, damage, cooldown_sec, hp, splash_radius, slow_factor, slow_sec, cost, needs_card` and the 029 kind fields, so 031/032 only read more keys). Level 1 = the top-level stats with the current defaults (range/damage/cooldown 0, slow 1). The existing per-type arrays stay (level 1; the placement ghost and the build bar read them).
2. `sim` `game/sim/sim_modifiers.gd` (new, ~35): packed `stat`, `op` (0 add, 1 mult), `value`, `target`; `add(stat, op, value, target)`; `sums(stat, tower_id) -> Vector2(add, mult)`; `unlocked_level(tower_id) -> int`; `hash_parts() -> Array`.
3. `sim` `game/sim/tower_stats.gd` (new, ~70): `apply(w, t)`, `recompute(w)`. Perf: recompute first caches the modifier sums per (type, stat) (types x stats x entries, about 11 x 7 x 30), then one pass over the towers; about towers x 7 float ops per change. No Dictionary walk per tick.
4. `sim` `game/sim/tower_upgrade.gd` (new, ~55): `Reason`, `Check`, `check(w, uid)`, `upgrade(w, uid)`.
5. `sim` `game/sim/sim_towers.gd` (+35): per-tower `level` (1 at `add`), derived `damage`, `reload` (cooldown ticks; `cooldown` stays the countdown), `max_hp`, `splash_radius`, `slow_factor`, `slow_ticks` (bare-tower defaults: 0, 0, 1, 0, 1, 0), all through `add()` and `remove()`; `stats_dirty: bool`. `attack_range` becomes a derived array (still set at `add`).
6. `sim` `game/sim/tower_attacks.gd` (~8 changed): read `towers.damage[t]`, `reload[t]`, `splash_radius[t]`, `slow_factor[t]`, `slow_ticks[t]` instead of the catalog (the `attack` kind stays per type).
7. `sim` `game/sim/tower_building.gd` (~10): `add_built` sets level 1 and calls `TowerStats.apply`; `rebuild` uses `max_hp[t]`; place, sell, rebuild and the lethal `damage` set `stats_dirty`.
8. `sim` `game/sim/sim_world.gd` (+15): `var modifiers := SimModifiers.new()` (reset at StartRun); the UPGRADE_TOWER branch; recompute call in `step()` after `_path()`; `state_hash()` adds `towers.level`, the derived arrays and `modifiers.hash_parts()`.
9. `sim` `game/sim/sim_command.gd`, `game/sim/sim_events.gd` (+8): `UPGRADE_TOWER` + `upgrade_tower(tick, uid)`; `TOWER_UPGRADED`.

### Tests (headless)
- `game/tests/sim/test_tower_upgrade.gd` (new): Pip L1->L2->L3 with gold (price = `cost`, `paid` grows, event payload); refusals with no change and no event: unknown uid, husk, max level (an M2 tower at 1; Pip at 3 without unlock = LOCKED, at 4 = MAX_LEVEL), no gold, paused, IDLE; with an `unlock_level` 4 modifier Pip reaches L4; `check` gives the same verdict and price the command applies; sell after upgrade refunds `floori(paid * 0.5)`; rebuild costs `floori(paid * 0.3)`, keeps the level, restores `max_hp`.
- `game/tests/sim/test_tower_stats.gd` (new): resolved level tables (Pip L4 keeps damage 10 / range 7, cooldown `DataFiles.ticks(0.35)`; Bastia hp 400/600/800/1200); upgrade of a damaged Bastia adds 200 HP; two `damage` mult 0.1 on `all_towers` give x1.2 (not 1.21); add before mult; a `tower:` target touches only that type; cooldown clamp (mult -0.9 -> 50%, a 1-tick floor); a max HP fall clamps `hp`; no recompute when nothing changed (flag stays false across steps; derived arrays unchanged).
- `test_determinism.gd`: one replay with place + upgrade + sell commands, same `state_hash` twice. Existing `test_tower_attacks.gd` / `test_tower_building.gd` stay green unchanged (level 1 values = catalog values); `test_sim_towers.gd` gains the new arrays in its `remove()` check.
- Release bench `scripts\bench.ps1`: `pc_maze`, `pc_maze_combat`, `pc_combat_stress` within noise of `reports/perf_m2.md` (D-124); table in the PR. Expected neutral: attacks read a per-tower array instead of a per-type one, and the recompute only runs on a change.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: command list (`UPGRADE_TOWER`, `TowerUpgrade.check` and its reasons), events table (`TOWER_UPGRADED`), tower arrays (`level`, derived arrays, `stats_dirty`), a short "Derived tower stats (D-144)" bullet (rules 1-6), tick order (recompute at the end of PATH), Tower attacks reading the derived arrays.
- `DECISIONS.md`: D-144 PROPOSED (rules 1-6).

### Order
1. Catalog level tables + test. 2. `SimModifiers`, `TowerStats`, the new tower arrays; attacks read derived arrays; existing suites green. 3. `UPGRADE_TOWER`, `TowerUpgrade`, event, dirty flags; upgrade tests; determinism. 4. Bench, docs, D-144; `scripts\test.ps1` twice, `scripts\validate.ps1`.

## Questions

## Review log
- 2026-10-09 lead-dev: approved and merged PR #38 (squash). Matches the plan and D-144; scripts/test.ps1 green twice on the branch merged with m3/dev incl. the 044 hygiene test (263 GUT + 24 Python), validate 0 errors; bench in the PR within the M2 range. Accepted choices: cooldown `add` modifiers in seconds converted to ticks before the multiplier; HP clamped only on a max-HP fall. Nit carried to 031: stray tabs inside the UPGRADE_TOWER match pattern in `SimWorld._apply` (put it on a proper continuation line).
