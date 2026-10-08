# 004 — Sim: enemy crowd behaviour
- Status: review
- Milestone: M1
- Depends on: 003
- PR: #8

## Goal
Apply soft separation (D-079) so the horde reads well and the benchmark has a realistic per-tick cost.

## Context
- D-079 (Q-41): soft separation; enemies push each other apart a little and may still overlap slightly under pressure; strength and radius are placeholder values in data
- `01_GAME_DESIGN.md` 2.3: the horde must stay readable

## Acceptance criteria
- Soft separation as in D-079, tunable from data, uses the spatial hash, and stays deterministic.
- Tests: the chosen behaviour is covered (for example two overlapping enemies separate over a few ticks); determinism test still green.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Tick order and phase timing are fixed for 004 and 005 together in `02_TECH_ARCHITECTURE.md` 3a "Tick order" (D-083, PROPOSED). 004 is phase (1). 005 may land before or after this task; see "Shared with 005" below.

Behaviour (soft separation, D-079):
- Two enemies `i`, `j` overlap when their distance `d < r_i + r_j` (the collision `radius` already in data is the separation radius). Each one is pushed away from the other by `0.5 * overlap * separation_strength` of its own type (`overlap = r_i + r_j - d`), so strength 1 resolves a lone pair in one tick and strength 0.5 (placeholder) halves the overlap per tick. Pressure from the chase (`speed * SIM_DT` inward per tick) keeps a small overlap in a dense crowd, as D-079 wants.
- Jacobi style: all pushes are computed from the positions at the start of the phase into scratch arrays, then applied in one pass. Order-independent, so deterministic without sorting.
- Coincident enemies (`d < 1e-6`): deterministic fallback direction, `+x` for the higher index and `-x` for the lower (no RNG, no NaN).
- Total push of one enemy per tick is capped at its own radius (stability in a dense pile). `# ponytail:` comment naming the cap.
- All enemies are pushed, whatever their `state`; `state` is not changed (an `AT_GUARDIAN` enemy pushed outward stays stopped; placeholder until the Guardian contact radius in M2).

Files:
1. `data`: `game/data/enemies/enemy_swarmer_01.json`: add `"separation_strength": 0.5`, `schema_version` 2.
2. `tools`: `tools/schemas/enemies.schema.json`: required `separation_strength`, number, `minimum 0`, `maximum 1`; `schema_version` const 2. Check `tools/tests/test_validate_data.py` fixtures still pass (update any enemy fixture).
3. `sim`: `game/sim/enemy_catalog.gd`: load `separation_strength` into a packed array like `speed`; add `max_radius: float` computed at load (and use it in `SimWorld._init` instead of the local loop).
4. `sim` (new): `game/sim/enemy_separation.gd`, `class_name EnemySeparation extends RefCounted`. Owns scratch `PackedFloat32Array` push_x/push_z and a `PackedInt32Array` query buffer (no allocation per tick once the count peaked). One method `apply(enemies: SimEnemies, grid: SpatialGrid, catalog: EnemyCatalog) -> void`: for each `i`, `grid.query_radius(x_i, z_i, r_i + catalog.max_radius, ...)`, skip `j == i`, accumulate pushes, cap, then apply. About 50 lines.
5. `sim`: `game/sim/sim_world.gd`: `var separation := EnemySeparation.new()`; `step()` as below; `_grid_count` for the safety-net rebuild.
6. Docs: `02_TECH_ARCHITECTURE.md` 3a: a bullet "Enemy separation (D-084)" describing the rule above; 3b example JSON gets `"separation_strength": 0.5` and `schema_version` 2. `DECISIONS.md`: D-084 PROPOSED (pairwise overlap push, Jacobi, per-type strength in enemy data, radius = collision radius, push cap = own radius). D-084 is reserved for 004 (005 uses D-085).

Shared with 005 (`step()` target shape; whichever task lands first adds the shared parts, the second only adds its own lines):
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

Tests (`game/tests/sim/test_enemy_separation.gd`, use `EnemySeparation` directly with a `SimEnemies` + `SpatialGrid` far from the origin, e.g. around (10, 0), and the real catalog):
- two overlapping enemies drift apart over a few `apply` calls until `d >= r_i + r_j - 1e-4`, midpoint unchanged (symmetric);
- two non-overlapping enemies do not move;
- two coincident enemies separate along x, no NaN, same result on a second run;
- strength 0 (catalog with `separation_strength[0] = 0`) leaves overlapping enemies in place;
- crowd: `SimWorld` with 200 enemies on a ring of 10, 300 ticks: the minimum pair distance is at least `0.5 * 2r` (soft, not collapsed). If the placeholder strength cannot hold this, report the measured minimum in the PR rather than silently loosening the bound.
- `test_sim_world.gd`: after one step with enemies, `phase_usec.size() == 4`.
- Determinism: `test_determinism.gd` already runs 1000 enemies into a pile at the Guardian, so it now covers separation; keep it green and copy its printed ms into the PR (before/after).

Performance: separation is the heaviest per-tick phase (one `query_radius` per enemy; query radius `r_i + max_radius` = 0.7 vs cell 1.4, so 4 cells at most). Print the per-tick cost of `separation.apply` for 3000 enemies piled at the Guardian (one `gut.p` in the crowd test or a scaled run) and put it in the PR. If it is above 4 ms in headless debug, replace the `query_radius` call by direct iteration over `grid.cell_start`/`cell_items` (no `clear`/`append`/`sort`; see the ponytail note in `spatial_grid.gd`) in this PR. Otherwise leave it and let 008 measure in release.

Order: data + schema + validator tests, catalog, `EnemySeparation` + unit tests, `step()` wiring + crowd test, docs, `scripts\test.ps1` twice, `scripts\validate.ps1`.
Size: about 80 lines of code, about 90 of tests. One PR.

## Questions

## Review log
