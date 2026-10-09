# 015 — Sim: placing, selling, tower HP, husks and blocking
- Status: done
- Milestone: M2
- Depends on: 014
- PR: #21

## Goal
Building in real time and during breaks: placement on the fine grid inside the build radius, costs that grow per copy, selling, tower HP, enemies attacking towers that block their path, husks.

## Context
- D-040 (fine grid, no cap, sell partial refund, no move), D-042 (radius ~20, cost growth per copy), D-043 (tower HP, husk rebuilt for a fraction, no repair), D-101 to D-105 (maze, full walls allowed, walkable husks, no building while paused)
- M1 SimTowers (D-085) grows into the full tower arrays
- From 011 review (maze, D-101): tower data has a circular `radius` (0.5) but no footprint in grid cells, and `run_m2.grid_step` is 0.5, so blocking is undefined. 015's plan must define which build-grid cells a tower occupies: either derive cells from `radius` and `grid_step`, or replace `radius` with an explicit footprint in cells (towers schema v2). Placement snaps to `grid_step` from RunData; 024 paths over the same grid.

## Acceptance criteria
- PlaceTower snaps to the grid, checks the radius, free cell and gold, applies cost growth per copy; SellTower refunds the data fraction.
- Towers occupy grid cells and are solid for pathing (the path itself is task 024); towers have HP.
- A dead tower leaves a walkable husk (D-104) that can be rebuilt for the data fraction of the cost.
- No placement while paused (D-105).
- Tests for each rule, including 300 towers still placeable.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-109** (D-110 is reserved by 017). No schema change: the footprint comes from the existing tower `radius` and the run's `grid_step`. Scope: enemies attacking towers (the Goal's "towers that block their path") is task 024 (D-103); 015 gives it `damage_tower()`, the husk rule and the solid cells.

Open questions added (none blocks this task; each has a ★ placeholder that is safe to assume, written into the rules below and named in D-109): **Q-54** gap narrower than an enemy's body, e.g. a boss through a one-cell gap (affects 024 only); **Q-55** placing or rebuilding where enemies stand; **Q-56** husk economy (copies, selling a husk, rebuild price base).

### Rules (D-109 PROPOSED)
- **Build grid** (`BuildGrid`, created at StartRun from `run.build_radius` and `run.grid_step`): a square of `S = 2 * ceili(build_radius / step)` cells per side centred on the Guardian (80 x 80 for `run_m2`). Cell `(i, j)` covers x in `[(i - S/2) * step, (i - S/2 + 1) * step)`, same for z with `j`; flat index `j * S + i`. Per cell: `owner` (tower uid, -1 = free; a husk keeps its cells) and `solid` (1 = live tower; husks are walkable, D-104). `version` is incremented on every change of `solid`, so 024 recomputes its path data only then. Derived from the tower arrays, not in `state_hash()`. Size fixed for the run (the radius only grows with M3 cards or meta; resize then).
- **Footprint**: a tower covers a square of `n = ceili(2 * radius / step - 1e-4)` cells per side (`n >= 1`): radius 0.5, step 0.5 gives 2 x 2 cells = 1 x 1 unit. Snap: first cell `i0 = roundi(x / step + S/2 - n / 2.0)` (same for z), centre `(i0 + n / 2.0 - S/2) * step`; works for odd and even `n`.
- **Corridors vs enemy size**: a gap of `k` free cells is `k * step` wide (one cell = 0.5 units; bodies: swarmer 0.7, brute 0.8, mini-boss 1.6, boss 2.0). How a gap narrower than an enemy is treated is **Q-54** (024); placeholder ★ A: pathing treats every enemy as a point (any free cell is passable, one shared path field), bodies overlap tower edges in tight gaps. Nothing in 015 depends on the answer.
- **PlaceTower{tower_id, x, z}** applies only while RUNNING and not paused (D-105; IDLE has no run, WON/LOST is frozen); otherwise ignored, no event. Rejected (ignored, no event, gold unchanged) unless all hold: `tower_id` is in `run.tower_types`; the footprint is inside the grid; the snapped centre is inside the build radius (`dist + radius <= build_radius`) and off the Guardian (`dist >= guardian_contact_radius + radius`); every footprint cell has `owner == -1` (a husk's cells are taken); `gold >= price`, `price = cost + cost_per_copy * copies` with `copies` = towers of that type in the arrays (husks included, Q-56 ★). Then `gold -= price`, uid = `_next_uid` (starts at 0, +1 per placement, never reused), the tower is appended with full HP and `paid = price`, its cells get `owner = uid`, `solid = 1`, `version += 1`, push `TOWER_PLACED` (a = uid, snapped centre, value = tower type). Enemies on the footprint are not checked (Q-55 ★: allowed; 024 moves enemies out of solid cells).
- **SellTower{tower_uid}**: same gate; unknown uid ignored. Refund `floori(paid * sell_refund)` for a live tower, 0 for a husk (Q-56 ★: selling a husk just clears it). Cells freed (`owner = -1`, `solid = 0`, `version += 1` if it was solid), tower swap-removed (uids stay stable; a tower is found with `uid.find()`), push `TOWER_SOLD` (new event kind: a = uid, position, value = refund).
- **RebuildTower{tower_uid}** (new command, D-100's list grows by one): same gate; only on a husk; price `floori(paid * rebuild_fraction)` (Q-56 ★: fraction of the price paid); rejected if `gold < price`. Then full HP, not a husk, cells `solid = 1`, `version += 1`, push `TOWER_PLACED` (same uid; the view revives the tower). `paid` unchanged.
- **Tower HP**: `hp` from the tower catalog at placement. `SimWorld.damage_tower(t, amount)` is the single entry point for damage to towers (024 calls it): ignored on a husk; `hp -= amount`; at `hp <= 0`: `hp = 0`, husk, cells `solid = 0` (owner kept), `target = -1`, `version += 1`, push `TOWER_DIED` (a = uid, position). Immediate: husks stay in the arrays, so no deferred phase.
- **Targeting**: husks get `target = -1` and are skipped by `retarget` (016 never fires from a husk).
- **Bench/demo API kept**: `towers.add(x, z, range)` still appends a bare tower (type -1, uid -1, hp 1, not on the build grid), so the M1 demo, the bench and the existing determinism tests are unchanged.

### Files
1. `sim` (new) `game/sim/build_grid.gd`, `class_name BuildGrid extends RefCounted`: `step, size, owner: PackedInt32Array, solid: PackedByteArray, version: int`; `_init(build_radius, step)`; `static footprint(radius, step) -> int`; `first_cell(v, n) -> int`; `cell_centre(i0, n) -> float`; `is_free(i0, j0, n) -> bool` (false if a cell is out of the grid or owned); `fill(i0, j0, n, uid, solid)` (bumps `version` when `solid` changes). About 60 lines.
2. `sim` `game/sim/sim_towers.gd`: arrays `uid, type_id, paid, cell_i, cell_j, footprint: PackedInt32Array`, `hp: PackedFloat32Array`, `husk: PackedByteArray`; `add()` appends defaults to all and returns the index (the world fills the fields); `remove(t)` swap-removes through every array (like `SimEnemies.remove`); `copies(type) -> int`; `retarget` skips husks. About +45 lines.
3. `sim` `game/sim/sim_command.gd`: `Type.REBUILD_TOWER`, `static rebuild_tower(tick, uid)`. About +6 lines.
4. `sim` `game/sim/sim_events.gd`: `Kind.TOWER_SOLD`, appended at the end of the enum.
5. `sim` `game/sim/sim_world.gd`: `build: BuildGrid` (null before StartRun), `_next_uid`; StartRun creates `build`; `_apply` routes PLACE/SELL/REBUILD to `_place_tower`, `_sell_tower`, `_rebuild_tower` behind one gate (`run_state == RUNNING and not paused`); `damage_tower()`; `state_hash()` adds `_next_uid` and the tower arrays `uid, type_id, hp, husk, paid, cell_i, cell_j`. About +90 lines. If `sim_world.gd` passes about 300 lines, put the three handlers and `damage_tower` in `sim/tower_building.gd` (static funcs taking the world), same public API.

### Tests (`game/tests/sim/`)
- `test_build_grid.gd`: footprint 2 for (radius 0.5, step 0.5), 1 for (0.2, 0.5), 3 for (0.7, 0.5); snap for even and odd `n` (x 1.3: centre 1.5 for n = 2, 1.25 for n = 1); `is_free` false out of the grid and on owned cells; `fill` sets owner/solid and bumps `version` only when `solid` changes; `size == 80` for `run_m2`.
- `test_tower_building.gd` (StartRun `run_m2`, then commands; set `world.gold` directly where a test needs more):
  - place: snapped centre, `TOWER_PLACED` (uid 0, centre, type), gold minus `cost`, footprint cells owned and solid, `version` bumped, hp = catalog hp;
  - rejections, each leaving gold and towers unchanged with no event: outside the radius, on the Guardian, overlapping a tower by one cell, not enough gold, tower id not in the run, while paused, before StartRun, after the run is LOST;
  - cost growth: the second copy costs `cost + cost_per_copy`, another type still its base `cost`; after selling a copy the price drops back;
  - sell: refund `floori(paid * sell_refund)`, cells free and not solid, `TOWER_SOLD`; unknown uid ignored; selling the first of three towers keeps the others' uids, positions and cells (swap-remove);
  - damage and husk: `damage_tower` lowers hp; lethal hit gives a husk, `TOWER_DIED`, cells owned but not solid, `version` bumped, `target == -1` with an enemy in range, further damage ignored; placing on a husk's cells rejected; selling a husk refunds 0 and frees its cells;
  - rebuild: price `floori(paid * rebuild_fraction)`, hp back to full, solid again, `TOWER_PLACED` with the same uid; rejected on a live tower, without enough gold, while paused;
  - 300 towers: huge gold, place on a 1.5-unit lattice inside the radius until 300 are placed (no rejection expected), count 300, uids distinct, `4 * 300` solid cells.
- Determinism: `test_replay.gd` already sends PlaceTower and SellTower(uid 0), which now really place and sell. Add a two-world hash test in `test_tower_building.gd` with place, sell, a `damage_tower` kill and a rebuild (seed 7 equal, seed 8 different).

### Performance
No per-tick cost except one husk check per tower in `retarget`. A command costs O(towers) (`uid.find`, `copies`), 300 at most: negligible. The grid is 6400 cells. 024 reads `solid` and `version` and recomputes only on change.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: commands add `REBUILD_TOWER{tower_uid}` and the PlaceTower/SellTower/RebuildTower rules; events table adds `TOWER_SOLD` (a = uid, position, value = refund) and notes that `TOWER_PLACED` is also pushed on rebuild; entity arrays: the tower arrays; the "Towers (D-085)" and "Build area" bullets describe `BuildGrid` (cells, footprint, snap, `solid`, `version`), tower HP, husks and `damage_tower`.
- `DECISIONS.md`: **D-109 PROPOSED** (the rules above; the Q-54/Q-55/Q-56 ★ defaults named as placeholders).

### Order
1. `BuildGrid` and its tests. 2. Tower arrays, `remove`, husk skip in retarget. 3. PlaceTower with every rejection and cost growth. 4. SellTower, `TOWER_SOLD`. 5. `damage_tower`, husks, RebuildTower. 6. Hash, 300 towers, determinism. 7. Docs, D-109; `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 200 lines of code, about 250 of tests. One PR.

## Questions

## Review log
- 2026-10-09 lead-dev: approved and squash-merged PR #21. Re-ran `scripts\test.ps1` (125/125) and `scripts\validate.ps1` (0 errors). Matches the plan and D-109; uses D-111/D-112/D-113. Accepted deviation: `SimWorld.next_tower_uid` is public (was `_next_uid`) because the handlers live in `TowerBuilding` static funcs. Release bench step: pc_typical 5.11, pc_stress 5.70, pc_piled 5.46 ms.
