# 005 — Sim: placeholder tower arrays with targeting queries
- Status: planned
- Milestone: M1
- Depends on: 003
- PR: -

## Goal
Add the tower arrays and a per-tick nearest-enemy query per tower, so the benchmark carries the tower load (50 typical, 300 stress, D-042). No attacks yet (M2).

## Context
- `02_TECH_ARCHITECTURE.md` 3a: tower arrays pos_x, pos_z, hp, waifu_id, level, cooldown; arrays grow dynamically, no cap (D-040, D-042)

## Acceptance criteria
- Towers are packed arrays that grow dynamically; one call adds a tower (the full command queue is M2).
- Every tick each tower looks up its nearest enemy in range via the spatial hash and stores the target index; no damage.
- Tests: the target is the nearest enemy; 300 towers can be added.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Tick order and phase timing are fixed for 004 and 005 together in `02_TECH_ARCHITECTURE.md` 3a "Tick order" (D-083, PROPOSED). 005 is phase (4): targeting after the single grid rebuild, so every target is exact for this tick's positions. 004 may land before or after; see "Shared with 004".

Scope: only what the benchmark and M1 need. Tower arrays in M1: `pos_x`, `pos_z`, `attack_range`, `target`. `hp`, `waifu_id`, `level`, `cooldown` (3a) are added when M2 uses them, same rule as `target_id` for enemies (D-081). The tower range is a parameter of `add` for now (no tower or waifu data exists yet; benchmark and tests pass it); M2 replaces it with a lookup in waifu data. No data file, no schema change.

Files:
1. `sim` (new): `game/sim/sim_towers.gd`, `class_name SimTowers extends RefCounted`. Packed arrays `pos_x`, `pos_z`, `attack_range` (`PackedFloat32Array`), `target` (`PackedInt32Array`, -1 = none). `count()`, `add(x, z, p_range) -> int` (appends to every array, `target` -1; arrays grow, no cap, D-040/D-042), `retarget(grid: SpatialGrid, xs: PackedFloat32Array, zs: PackedFloat32Array) -> void`: `target[t] = grid.nearest(pos_x[t], pos_z[t], attack_range[t], xs, zs)` for each tower in index order. `target` is an enemy index, valid within this tick only (D-081). No removal yet (sell is M2). About 35 lines.
2. `sim`: `game/sim/sim_world.gd`: `var towers := SimTowers.new()`; adding a tower is one call, `world.towers.add(x, z, range)`; `step()` calls `towers.retarget(...)` as phase TARGETING (shape below); `state_hash()` adds `towers.pos_x, towers.pos_z, towers.attack_range, towers.target`.
3. Docs: `02_TECH_ARCHITECTURE.md` 3a: replace the tower part of the "Entity arrays" bullet with the M1 set above and a "Towers (D-085)" bullet (arrays, `add`, per-tick nearest target via `SpatialGrid.nearest`, target valid one tick, range a parameter until M2). `DECISIONS.md`: D-085 PROPOSED (minimal M1 tower arrays, target recomputed every tick after the grid rebuild, range passed to `add` until waifu data exists). D-084 is reserved for 004.

Shared with 004 (`step()` target shape; whichever task lands first adds the shared parts, the second only adds its own lines):
```
enum Phase { SEPARATE, MOVE, GRID, TARGETING }
var phase_usec: PackedInt64Array  # size 4, indexed by Phase; diagnostics, not in state_hash()

func step() -> void:
	if _grid_count != enemies.count():   # safety net (3a)
		_rebuild_grid()
	_t = Time.get_ticks_usec()
	separation.apply(enemies, grid, catalog)          # 004
	_lap(Phase.SEPARATE)
	enemies.chase_guardian(catalog.speed, catalog.radius, SIM_DT)
	_lap(Phase.MOVE)
	_rebuild_grid()                                    # sets _grid_count
	_lap(Phase.GRID)
	towers.retarget(grid, enemies.pos_x, enemies.pos_z)  # 005
	_lap(Phase.TARGETING)
	tick += 1
```
`_lap(p)` stores `now - _t` in `phase_usec[p]` and resets `_t`. A phase not yet implemented reads 0.

Tests (`game/tests/sim/test_sim_towers.gd`):
- nearest: a `SimWorld` with about 200 enemies from `spawn_ring` and about 20 towers spread over the build radius (seeded RNG in the test); after a few steps, every `target[t]` equals a brute-force nearest over the enemy positions within `attack_range` (lowest index on ties, -1 if none);
- out of range: a tower with no enemy within range has target -1; an enemy moving into range is picked up on the next step;
- growth: 300 towers can be added (`count() == 300`, every array size 300), and one step with 3000 enemies runs; `gut.p` the TARGETING phase time from `phase_usec` and copy it into the PR;
- determinism: add 50 towers to both runs in `test_determinism.gd` (same positions and range) so tower targets are in the hash; keep it green.
- `test_sim_world.gd`: after one step, `phase_usec.size() == 4`.

Performance: 300 `nearest` calls per tick. The expensive case is a tower with no enemy in range: `nearest` scans every ring up to `range / cell_size` (about 169 cells at range 8 and cell 1.4). Report the TARGETING time for 300 towers spread on the build radius (20) with 3000 enemies; 008 measures it properly. No optimisation in this task (keeping a still-valid target, or retargeting every N ticks, changes targeting rules: M2 design).

Order: `SimTowers` + unit tests, `step()` and `state_hash()` wiring, determinism update, docs, `scripts\test.ps1` twice, `scripts\validate.ps1`.
Size: about 50 lines of code, about 80 of tests. One PR.

## Questions

## Review log
