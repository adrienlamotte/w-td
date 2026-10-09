# 024 — Sim: maze pathfinding (flow field)
- Status: planned
- Milestone: M2
- Depends on: 015
- PR: -

## Goal
Enemies path around towers to the Guardian (maze-style, D-101), cheaply enough for thousands of enemies, with a bounded per-tick cost. Walled-in attacks on towers (D-103) are task 026.

## Context
- D-118 (owner, 2026-10-09): towers block ranged enemies' line of sight. A ranged enemy shoots the Guardian only when its straight line is clear (the flow field's per-cell "first tower on the straight line" gives this for free); otherwise it keeps walking the maze. Update the plan's steering/stop rule for ranged enemies accordingly.
- D-101 to D-104; D-111 (every enemy is a point for pathing); D-112 (placing on enemies allowed, enemies pushed out); D-079 (soft separation still applies)
- `02_TECH_ARCHITECTURE.md` 3a (tick order D-083, spatial grid), 4 (budgets); `reports/perf_m1.md` (separation already 60-79% of a tick)
- Technical approach is the lead dev's call (a flow field from the Guardian over the build grid, recomputed only when towers or husks change, is the expected direction)
- From 011 review: the path grid should be the build grid (`RunData.grid_step`, `build_radius`). Outside the build radius there are no towers, so enemies head straight for the build area.
- From 014's plan (D-107): movement is `EnemyMovement.steer()` (per enemy `dir_x, dir_z` and `gap` = distance left to the attack position) then `advance()`. This task replaces `steer()` only. 014 also adds a queue rule in `EnemySeparation` (an enemy overlapping a stopped one closer to the Guardian is `QUEUED`): this task swaps its "closer" test (squared distance to the origin) for the flow-field distance of each enemy's cell, so enemies queue along corridors.
- From 015 (D-109): `world.build` (`BuildGrid`) is the path grid: `S x S` cells of `grid_step` centred on the Guardian, `solid` (1 = live tower; husks 0, walkable) and `version` (bumped on every `solid` change). A tower covers `n x n` cells (2 x 2 = 1 x 1 unit now). Placing or rebuilding over enemies is allowed (D-112): this task moves enemies out of solid cells.
- Split (lead-dev plan, 2026-10-09): walled-in enemies attacking the blocking tower (D-103), the per-enemy attack target and the gap-opening tests moved to **026**. Until 026 lands, a walled-in enemy keeps the straight chase and presses against the wall (pushed out of the towers), without attacking them.

## Acceptance criteria
- Enemies never end a tick with their centre in a tower cell; inside the build area they follow the shortest path around towers; outside it they head for the build area.
- The path data is recomputed only when the tower layout changes (place, sell, death, rebuild), never more than one recompute in flight, with a fixed per-tick work budget.
- With no towers, movement is exactly the 014 straight chase (same positions).
- A husk and a sold tower's cells are walkable once the field has caught up.
- Determinism kept; tests for routing around a wall, a serpentine maze, a full wall (no path: straight chase), a husk being walkable, push-out after placing on an enemy, the corridor queue.
- Per-tick cost measured in the release bench with 3000 enemies and a realistic maze, plus a worst-case churn scenario; reported in the PR.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-115** (D-114 is 016's, D-116 is 026's). Uses D-111 (point pathing) and D-112 (push-out). Schema change: optional fields in `bench.schema.json` only (old files still validate, `schema_version` stays 1).

### Rules (D-115 PROPOSED)
- **Path grid = build grid plus a margin.** `BuildGrid` grows by `MARGIN = 2.0` units on every side: `S = 2 * ceili((build_radius + MARGIN) / step)` (88 x 88 = 7744 cells for `run_m2`). Placement rules are unchanged (`dist + radius <= build_radius`), so the margin is always free: enemies can walk around the outermost towers (the build circle touches the old grid edge on the axes).
- **Flow field** (`FlowField`, same cells and indexing as `BuildGrid`), integer and deterministic:
  - Goal cells: free cells whose centre is within `max(guardian_contact_radius, step)` of (0, 0) (contact radius 0 in IDLE).
  - `dist`: octile cost to the goal (2 per orthogonal step, 3 per diagonal step), Dial's algorithm (4 buckets, lazy deletion), 8 neighbours; **a diagonal step is allowed only if both orthogonal neighbours are free** (no corner cutting, so towers touching at a corner form a wall). Solid and unreachable cells: `INF = 1 << 30`.
  - `dir`: per cell, index 0..7 of the neighbour that last improved its `dist` (the step toward the goal), 255 if none. Fixed neighbour order (E, W, S, N, then the diagonals), so ties are deterministic.
  - `hit`: first solid cell on the straight line from the cell centre to the Guardian, -1 = clear line. Built from static geometry computed once per grid: `order` (cells by the integer key `(2i - S + 1)^2 + (2j - S + 1)^2`, then index; counting sort) and `pred` (the cell holding `centre - step * centre / |centre|`, always earlier in `order`; -1 for goal-radius cells). Pass in `order`: `hit[c] = c` if solid; -1 if `pred[c] == -1`; if the step to `pred` is diagonal and one of the two orthogonal cells is solid, that cell (the first in fixed order); else `hit[pred[c]]`.
  - `escape`: per cell, the nearest free cell (itself for a free cell), by a 4-neighbour BFS from the free cells bordering solid ones, seeded in index order.
- **Recompute only on change, with a work budget.** In a new phase `PATH` (after COMMANDS, before SEPARATE): if no computation is running and `build.version` differs from the last version computed, start one on a snapshot of `build.solid` (`duplicate()`, 7.7 KB). Each tick it does at most `CELLS_PER_TICK` units of work (one unit = one cell reset, one settled cell in Dial, one cell in the `hit` pass, one solid cell in the escape BFS), into working arrays; when it finishes it swaps them into the published `dist, dir, hit, escape`. A change during a computation is picked up when it ends (no restart, so constant churn cannot starve it): the per-tick cost is bounded by the budget whatever the change rate, and a layout change shows up within at most two computation lengths. At StartRun (and when a field is first created) the first computation runs to the end at once. The field is derived from the tower arrays and the command history: not in `state_hash()` (two replays have the same field and progress).
- **Steer** (replaces `EnemyMovement.steer`; `advance()` unchanged; `gap` is still the straight distance to the Guardian minus the stop distance, D-107). Per live enemy, with `c` = its cell:
  1. No build grid (IDLE demo and the M1 bench scenarios) or outside the grid: straight to the Guardian (as 014; outside, that is toward the build area).
  2. If `escape[c] != c` (the enemy is inside a tower), use `c = escape[c]`.
  3. `hit[c] == -1` (clear line): straight to the Guardian. This keeps the open field and any cell with a free line identical to 014.
  4. Else if `dist[c] < INF`: the unit vector of `dir[c]` (8 constant vectors).
  5. Else (walled in, no path): straight to the Guardian (task 026 turns this into the attack on the blocking tower).
- **Push-out** (D-112), at the end of MOVE after `advance()` and before the recycle: every live enemy whose cell is solid in `build.solid` and has `escape[c] != c` is clamped into the square of cell `escape[c]` (nearest point, `1e-4` inside). An enemy inside a tower placed less than one computation ago (its cell was free in the published field) is pushed out once the field catches up (a few ticks).
- **Queue key** (D-107's "closer" test), in path cost units: `EnemySeparation.apply` fills a per-enemy `PackedFloat64Array` key once at its start, with `d = sqrt(x*x + z*z)` and `c` = the cell of the position clamped into the grid. No field: `d` (same order as 014's squared radii). `dist[c] == INF` (walled in): `1e6 + d` (behind every enemy with a path, radial among themselves). Outside the grid or `hit[c] == -1` (clear line): `d * 2 / step` (the straight distance in cost units, so the open field orders exactly as 014). Else: `dist[c] + 1e-3 * d` (path cost; the small radial term only breaks ties inside one cell). Both the horde loop and `_push_pair` compare keys instead of squared radii.
- **Ranged enemies** keep the 014 stop rule (straight distance): one with a path still stops and shoots the Guardian from its range, across towers. Named in D-115 as a CP-M2 playtest point.

### Files
1. `sim` `game/sim/build_grid.gd`: `MARGIN`, new `size` formula; `cell_of(x, z) -> int` (flat index, -1 outside), used by the field, steer, push-out and the key. About +10 lines.
2. `sim` (new) `game/sim/flow_field.gd`, `class_name FlowField extends RefCounted`: static geometry (`order`, `pred`, goal flags) built in `_init(build, contact_radius)`; published and working `dist, dir, hit, escape`; `update(build, budget) -> void` (start/continue/swap, resumable state: phase, bucket index, read position, current cost); `const CELLS_PER_TICK`; `const DIR_X, DIR_Z` (8 unit vectors); `recomputes: int` (diagnostic counter for tests, not state). Neighbour checks unrolled (no per-neighbour loop over an offset table in the hot loop). About 190 lines; if it passes 200, split the static geometry into `flow_geometry.gd`.
3. `sim` `game/sim/enemy_movement.gd`: `steer(enemies, build, field)` with the 5 cases; `push_out(enemies, build, field)`. About +35 lines.
4. `sim` `game/sim/enemy_separation.gd`: `apply(enemies, grid, catalog, build, field)`, `_key` fill, compares on `_key` (horde loop and `_push_pair`). About +15 lines, minus the inline squared radii.
5. `sim` `game/sim/sim_world.gd`: `Phase.PATH` after `COMMANDS`; `field: FlowField` (null until a build grid exists; created at StartRun with a full first computation, or lazily in PATH when a test or the bench sets `world.build` on an IDLE world); PATH runs `field.update(build, FlowField.CELLS_PER_TICK)`; steer/separation/push-out get `build` and `field`. About +15 lines.
6. `sim` `game/sim/tower_building.gd`: split `place` into the checks and `add_built(w, type, x, z) -> int` (snap, free cells, append, fill; returns the uid or -1 when a cell is taken; no gate, gold, radius or run checks). `add_built` is the test/bench API to lay out a maze on an IDLE world. About +5 lines net.
7. `view` `game/view/bench/bench_scenario.gd`: maze scenarios set `world.build = BuildGrid.new(cfg.build_radius, cfg.grid_step)` and lay out `cfg.maze_rings` (concentric rings; towers every 0.5 units of arc with `add_built`, taken cells skipped; one gap of `maze_gap` units per ring, alternating at angle 0 and PI, so the path snakes half a ring per level). About +25 lines.
8. `view` `game/view/bench/bench.gd`: `PHASES` gains `"path"` (same order as `SimWorld.Phase`); `churn` scenarios flip the `solid` cells of one outer-ring tower every frame (`world.build.fill`, harness only, like `spawn_ring`), so a recompute is always in flight (the worst case); the report adds `maze_towers` (tower count). About +15 lines.
9. `data` `game/data/bench/bench_m1.json`: top level `grid_step` 0.5, `maze_tower` `tower_single_01`, `maze_rings` [8, 13, 18], `maze_gap` 2; scenarios `pc_maze` (3000, towers 0, maze, recycle, zoom 1, scale 1.0), `deck_maze` (1500, maze, scale 0.5), `pc_maze_churn` (3000, maze, churn). `tools/schemas/bench.schema.json`: those optional fields (`maze`, `churn` booleans per scenario).

### Tests
- `test_build_grid.gd`, `test_tower_building.gd`: size 88 for `run_m2`; cell indices in the existing asserts shift by +4 (the margin is 4 cells).
- `test_flow_field.gd` (IDLE world or a bare `BuildGrid`, towers via `add_built` or `fill`; full updates with a huge budget unless the test is about slicing):
  - empty grid: every cell `hit == -1`, goal cells `dist == 0`, a cell 4 cells east `dist == 8`, one 3 east 3 north `dist == 9`;
  - a straight wall between a cell and the Guardian: that cell has `hit` on the wall, a finite `dist` larger than the empty-grid one, and `dir` pointing along the wall toward its nearer end;
  - a closed ring: outside cells `INF`, inside finite; same ring with one tower made a husk (`fill(..., 0)`): finite again;
  - a diagonal line of corner-touching towers blocks both `dist` (no corner cutting) and `hit`;
  - `escape` of a tower cell is a free neighbour; the inner cell of a 2 x 2 block of towers escapes to the nearest border cell;
  - slicing: `update` with budget 100 called until done gives arrays equal to one full update; a `version` change mid-computation is applied by the following computation (`recomputes` goes up by exactly 2), and the published arrays stay the old ones until the swap;
  - only on change: 100 world steps with no layout change after the first computation leave `recomputes` unchanged; one PlaceTower adds exactly one.
  - cost (informative, `gut.p`): full computation time on the bench maze layout, headless debug.
- `test_maze_movement.gd` (StartRun `run_m2`, `guardian_hp` raised, gold set, towers by PlaceTower; enemies by `enemies.add`):
  - no towers: positions after 60 steps equal those of the same run with the steer forced straight (or a reference computed with 014's formula), exactly;
  - straight wall across the line to the Guardian: the enemy reaches `ATTACKING` and at **every** step its centre is not in a solid cell;
  - serpentine (two rings with gaps on opposite sides): the enemy crosses each ring at its gap (angle at the ring radius within the gap) and reaches the Guardian;
  - full ring: no path, the enemy ends pressed against the ring (outside it, `MOVING` or `QUEUED`), never inside a tower, the Guardian untouched; after `damage_tower` kills one ring tower (husk) and a few steps, the enemy goes through the husk and reaches the Guardian; same with SellTower;
  - place a tower on an enemy (D-112): within `latency + 1` steps the enemy's centre is outside the tower;
  - corridor queue: in a U-shaped corridor, a stopped enemy nearer along the path but farther radially makes the one behind it `QUEUED` (the old radial compare would not).
- Determinism: two-seed hash test with towers placed, one killed into a husk and one sold mid-run, enemies routing; add a PlaceTower that walls part of the field to `test_replay.gd`.
- Existing tests stay green unchanged except the index shifts above (the open field is the 014 path).

### Performance (budget: under 8 ms per tick in the release bench, D-038; current 5.1-5.7 ms)
- Per enemy per tick: one cell lookup in steer, one for the key, one for push-out (each two `floori`, a bounds check and an array read); the separation pair compare reads a key instead of computing squared radii. The key adds one `sqrt` per enemy (not per pair). Expected +0.3 to +0.6 ms per tick at 3000 enemies (release).
- Recompute: about 7744 cells x 8 neighbours for Dial plus one `hit` pass; estimated 3-5 ms release in full, so it is sliced. `CELLS_PER_TICK`: the game-dev sets it from `pc_maze_churn` so the PATH phase averages at most **1.5 ms** per tick (release), and reports the resulting latency in ticks (expected 3-6 ticks, 0.1-0.2 s). With no change in flight, PATH is one int compare.
- Worst case "many changes per second": changes coalesce into the next computation, one in flight at a time, so the per-tick cost never exceeds the budget; only the latency grows (at most two computation lengths). `pc_maze_churn` measures exactly this.
- Memory: about 7744 x 13 bytes x 2 buffers, plus the static `order`/`pred` (about 60 KB). No allocation per tick (working arrays reused; the solid snapshot is one 7.7 KB copy per computation).
- Gates reported in the PR (release `scripts\bench.ps1`): `pc_maze` and `pc_maze_churn` step under 8 ms; the six M1 scenarios unchanged within noise (they have no build grid). If a gate fails, report it on the task with the phase breakdown and stop; do not shrink the maze or the enemy count. Remaining combat load (tower attacks, walled-in attacks) is 023's.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: new "Pathing" bullet (path grid and margin, the flow field arrays and their rules, recompute on `version` with the budget and latency, steer cases, push-out, queue key, D-111 point pathing, the ranged playtest point); Enemy movement and Enemy separation bullets point to it ("task 024 replaces..." sentences become the description); Build area: the margin and the 88 size; tick order: phase (0a) PATH; `phase_usec` list. Section 6 bench: the maze and churn scenarios.
- `DECISIONS.md`: **D-115 PROPOSED** (the rules above).

### Order
1. `BuildGrid` margin and `cell_of`, fix the shifted tests. 2. `FlowField` full computation (`dist`, `dir`), tests. 3. `hit` pass and `escape`, tests. 4. Slicing and the PATH phase, tests. 5. Steer cases and push-out, movement tests. 6. Queue key, corridor test. 7. Determinism and replay. 8. Bench maze and churn scenarios, release bench, set `CELLS_PER_TICK`. 9. Docs, D-115; `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 310 lines of code (field 190, sim wiring 75, bench 45) plus data, about 300 of tests. One PR.

## Questions

## Review log
