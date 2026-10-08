# 003 — Sim: uniform spatial hash grid
- Status: done
- Milestone: M1
- Depends on: 002
- PR: #6

## Goal
Add the uniform spatial hash grid used for all spatial queries, rebuilt every tick.

## Context
- `02_TECH_ARCHITECTURE.md` 3, 3a: cell size = largest enemy collision diameter x 2 (start 2.0 units), rebuilt each tick

## Acceptance criteria
- Grid rebuilt from the enemy arrays every tick, using packed arrays (no Dictionary per cell, no allocation per tick after warm-up).
- Queries: enemies within a radius of a point; nearest enemy to a point within a max range.
- Results are deterministic (ordered by enemy index).
- Tests: query results match a brute-force scan on a seeded random layout; rebuild after enemies move.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Design (a bounded uniform grid built with a counting sort; no hashing of cell keys needed):
- The grid covers the square `[-half_extent, +half_extent]` on x and z (default `half_extent = 64.0`, a technical constant, not a design value). Cell coordinates are clamped to the edge cells, so an enemy outside the square lands in an edge cell. Queries clamp their cell range the same way, so results stay exact for any position; only the speed suffers if many enemies are far out. With cell size 1.4 that is 92 x 92 cells.
- Cell size = largest enemy collision diameter x 2 = `4 * max(catalog.radius)`, computed by `SimWorld` from the catalog (rule from 3a). With the current data (swarmer radius 0.35) that is 1.4, not the 2.0 starting guess in 3a; the doc is updated to say the size is derived.
- Rebuild = counting sort over three member `PackedInt32Array`s: `cell_start` (n_cells + 1), `cell_items` (count), `_enemy_cell` (count). Steps: `cell_start.fill(0)`; per enemy compute its cell and count it; prefix sum; scatter enemy indices with a cursor array (a reused member array, or reuse `cell_start` and shift back). Enemies are scattered in index order, so each cell's slice is in ascending index order. Arrays are resized in place and never recreated, so no allocation per tick once the enemy count has peaked.
- `rebuild()` takes the position arrays as arguments and the queries also take them as arguments. The grid never stores the enemy arrays (holding a second reference would make the next sim write copy the whole array).
- `query_radius(x, z, r, xs, zs, out: PackedInt32Array) -> void`: clears `out`, scans the clamped cell range covering the circle, appends every index with `dx*dx + dz*dz <= r*r`, then `out.sort()` (native) so results are ordered by enemy index. The caller owns and reuses `out`. The test must prove the caller sees the writes (Godot 4 passes packed arrays by reference; if that fails, return the array instead).
- `nearest(x, z, max_range, xs, zs) -> int`: returns the enemy index with the smallest squared distance `<= max_range^2`, lowest index on ties, `-1` if none. Search the cells in square rings around the point's cell (ring 0, 1, 2, ...) up to the ring that covers `max_range`; stop early once `(k - 1) * cell_size` is greater than the best distance found. This keeps the 005 per-tower queries cheap in a dense horde.
- `SimWorld` owns `grid: SpatialGrid` and calls `grid.rebuild(enemies.pos_x, enemies.pos_z)` in `step()` right after `chase_guardian`, so the grid matches the positions at the end of the movement phase. 004 (separation) and 005 (targeting) run after the rebuild in the same `step()`. The grid is derived state and is not added to `state_hash()`.

Files:
1. `game/sim/spatial_grid.gd` (sim, new, `class_name SpatialGrid`, RefCounted): `_init(p_cell_size: float, p_half_extent: float = 64.0)`, `rebuild(xs, zs)`, `query_radius(...)`, `nearest(...)`, small private `_cell_coord(v: float) -> int` (floor + clamp). Typed, about 120 lines.
2. `game/sim/sim_world.gd` (sim, change): create the grid in `_init` with `4.0 * max radius in catalog`; rebuild in `step()` after movement.
3. Docs: `02_TECH_ARCHITECTURE.md` 3a "Spatial hash" bullet: bounded clamped grid, counting-sort rebuild after movement each tick, cell size derived from data (currently 1.4), query API and ordering. Add D-082 (PROPOSED) to `DECISIONS.md`: spatial grid is a bounded uniform grid with edge clamping and a counting-sort rebuild; query results ordered by enemy index; nearest ties go to the lowest index. No data or schema change.

Tests (headless, GUT), `game/tests/sim/test_spatial_grid.gd`:
- Seeded layout (local `RandomNumberGenerator`, fixed seed): 2000 points in [-40, 40], plus a few far outside the grid (for example (100, -90), (-200, 5)) to cover clamping. 200 seeded queries with radius in [0, 12]: `query_radius` equals a brute-force scan (sorted indices); `nearest` with a seeded max range equals brute force (lowest index on ties), including a query far from everything returning -1.
- Exact tie: two enemies at the same distance, nearest returns the lower index.
- Rebuild after movement: move every point by a seeded offset, rebuild, re-run the brute-force comparison. Rebuild with fewer points (count shrinks) and with more points: still matches.
- Empty grid: `query_radius` gives an empty result, `nearest` gives -1.
- `SimWorld`: after `spawn_ring(0, 500, 30)` and 60 steps, `world.grid` queries match brute force on `world.enemies` positions.
- `test_determinism.gd` stays unchanged and green (the grid is rebuilt inside `step()`).

Performance notes:
- Rebuild is O(count + cells) with one floor/clamp per enemy; no Dictionary, no Vector2, no per-cell arrays.
- In the PR, report the time of 100 rebuilds of 3000 enemies and of 300 `nearest` calls (max range 8) in a 3000-enemy layout (print from a test or a scratch run; no perf assertion). This is the first signal for 004/005/008.
- `query_radius` allocates through `out.clear()` + `append`. Fine for 005; if 004 calls it per enemy per tick and it shows in the profile, 004 adds an index-range iteration API over `cell_start`/`cell_items` instead. ponytail note in code.

Order: SpatialGrid + its brute-force tests, SimWorld wiring + its test, docs (3a, D-082), `scripts\test.ps1` twice, `scripts\validate.ps1`.
Size: about 120 lines of code and 120 of tests; one PR.

## Questions

## Review log
- 2026-10-08 lead-dev: approved, PR #6 squash-merged into m1/dev. test.ps1 green twice (21/21, 5/5 test scripts loaded, no parse/script errors in GUT output), validate.ps1 OK. Ring early-stop bound and edge clamping checked. Note for 008: rebuild is about 1.8-2.0 ms per 3000 enemies in headless debug; measure in release in the benchmark.
