# 026 — Sim: walled-in enemies attack the blocking tower
- Status: planned
- Milestone: M2
- Depends on: 024
- PR: -

## Goal
When the player walls the Guardian in (allowed, D-102), enemies with no path take the straight path and attack the tower that blocks it until a gap opens (D-103). Split out of 024 by the lead dev.

## Context
- D-043 (the straight-path attack rule, now the walled-in fallback), D-102, D-103, D-104 (husks walkable), D-107 (enemy attacks, cooldown, `ATTACKING`), D-109 (`damage_tower`, husks), D-111
- 024 (D-115): `FlowField` publishes `dist` (`INF` = no path), `hit` (first solid cell on the straight line from a cell to the Guardian, -1 = clear) and `escape`; steer case 5 (walled in) is a straight chase that this task replaces. A layout change reaches the field within a few ticks (sliced recompute).
- As built in 024 (checked by the lead dev after merge): `EnemyMovement.steer(enemies, field)` takes the field only (this task adds `build`, `towers`, `tower_catalog`); `c` is already the escape cell; any blocked line (`hit[c] >= 0`) sets `gap = BLOCKED_GAP` (1e9), so no enemy hits the Guardian through a tower (D-118). The walled-in branch below overrides `gap` only when it targets a live tower; its fallbacks (sold, husk, missing) keep `BLOCKED_GAP`, never the Guardian gap. `SimWorld._path()` is the PATH phase where the uid lookup is refreshed. `TowerBuilding.add_built` can lay out the test rings.
- `02_TECH_ARCHITECTURE.md` 3a (Combat, Enemy movement, Pathing)

## Acceptance criteria
- Walled-in enemies (no path) head for the first tower on their straight line to the Guardian, stop at their attack range from it and hit it through `damage_tower` on their cooldown; the Guardian is not hit by them.
- When a gap opens (the tower dies and becomes a walkable husk, or is sold), they path through it to the Guardian.
- Ranged enemies stop at their range from the tower.
- Determinism kept; tests for a full ring, a ranged attacker, a husk gap, a sold gap, an enclosed pocket.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-116**. No data or schema change.

### Rules (D-116 PROPOSED)
- **Attack target**: new enemy array `target_id` (tower uid, -1 = the Guardian), set by steer every tick, swapped in `remove`, hashed.
- **Uid lookup**: `SimTowers.uid_index` (`PackedInt32Array` of size `next_tower_uid`, -1 = none), refreshed in the PATH phase every tick when a build grid exists (O(towers + uids)). Tower indices only move on sell (COMMANDS, before PATH) and husks stay in place, so the lookup is valid until the end of the tick.
- **Steer, walled in** (024 case 5: `dist[c] == INF`, `c` = the enemy's cell after `escape`): `h = hit[c]`. If `h == -1`, or `build.owner[h] == -1` (sold since the field was computed), or that tower is missing or a husk: straight to the Guardian with `gap = BLOCKED_GAP` (024), `target_id = -1` (the field catches up in a few ticks). Else with `t = uid_index[owner[h]]`: direction toward the tower centre, `gap = |p - tower| - (tower radius + enemy radius + attack_range)` (tower `radius` from the tower catalog, the D-107 body-edge convention), `target_id = owner[h]`. Every other case sets `target_id = -1`. Outside the grid enemies keep the straight chase until they enter it.
- **Enemy attacks** (D-107 loop, unchanged cooldown rule): an `ATTACKING` enemy with `target_id >= 0` hits that tower: if it exists and is not a husk, push `TOWER_HIT` (new event, appended: a = tower uid, x, z = attacker position, value = damage) then `damage_tower(t, damage)` (at 0 HP: husk, `TOWER_DIED`, `version` bump, D-109), and reset the cooldown; otherwise no hit and the cooldown stays 0 (it re-steers next tick). `target_id == -1`: the Guardian, as now.
- **Gap opening**: a husk or a sold tower frees its cells, bumps `version`, and the field (024) gives those enemies a finite `dist` within its latency; they then path through the gap with `target_id = -1`.
- Queue key (024): walled-in enemies are `1e6 + d`, so the crowd at a wall queues radially.

### Files
1. `sim` `game/sim/sim_enemies.gd`: `target_id` (-1 in `add`, swapped in `remove`). +4 lines.
2. `sim` `game/sim/sim_towers.gd`: `uid_index`, `refresh_uid_index(next_uid)`. +10 lines.
3. `sim` `game/sim/enemy_movement.gd`: steer case 5 (needs `towers`, `tower_catalog`, `build`). About +25 lines.
4. `sim` `game/sim/sim_world.gd`: refresh the lookup in PATH; `_enemy_attacks` tower branch; `state_hash()` adds `enemies.target_id`. About +15 lines.
5. `sim` `game/sim/sim_events.gd`: `Kind.TOWER_HIT` appended.

### Tests (`game/tests/sim/test_walled_in.gd`; StartRun `run_m2`, gold set, towers by PlaceTower, `guardian_hp` raised, enemies by `enemies.add`)
- Full ring at radius 6, a swarmer outside: it becomes `ATTACKING` with `target_id` = a ring tower on its line to the Guardian; that tower loses `damage` per `attack_cooldown` ticks (`TOWER_HIT` events), the Guardian takes nothing.
- Ranged enemy outside the ring: stops at about `tower radius + radius + attack_range` from its target tower and damages it.
- Husk gap: the attacked tower dies (`TOWER_DIED`, husk); within the field latency the enemy has `target_id == -1`, walks through the husk cells and hits the Guardian.
- Sold gap: same with SellTower on the targeted tower; an enemy whose target was sold does not hit anything in the tick after the sale.
- Pocket: an enemy inside a closed square of towers that does not contain the Guardian attacks one of the square's towers.
- `target_id` follows its enemy through a DEATHS swap-remove.
- Determinism: two-seed hash test with a full ring broken by the horde.

### Performance
Only walled-in enemies pay: one lookup and one `sqrt` in steer; the attack is one lookup. `uid_index` refresh is a few hundred writes per tick. Negligible; 023 benches the walled-in worst case (a full ring with 3000 enemies on it).

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: entity arrays add enemy `target_id`; events table adds `TOWER_HIT`; Pathing/Enemy movement: the walled-in case; Combat: enemy attacks may hit a tower.
- `DECISIONS.md`: **D-116 PROPOSED**.

### Order
1. Arrays and lookup. 2. Steer case 5, tests. 3. Attack branch and `TOWER_HIT`, tests. 4. Gaps, pocket, determinism. 5. Docs, D-116; `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 60 lines of code, about 180 of tests. One PR.

## Questions

## Review log
