# 02 — Technical Architecture

Status key: **[D]** decided, **[P]** proposed, **[O]** open.

## 1. Engine and languages
- **Engine: Godot 4.x, version pinned at the start of M0 (D-036)** **[D]**. Reasons: all project files are text (scenes `.tscn`, resources `.tres`, scripts), so agents can read/diff/edit them; runs headless from CLI for tests and screenshots; light; free; good Steam support through GodotSteam.
- **Language: GDScript** for gameplay and tools inside Godot **[P]**. Static typing required (`var x: int`, typed function signatures).
- **Performance escape hatch:** if profiling proves GDScript cannot hit budgets, move only the hot loop (horde simulation) to a **GDExtension in Rust or C++** **[P]**. Do not do this before a profile shows the need. M1 measured no need yet; the triggers to revisit are in `reports/perf_m1.md` section 6.
- **Tooling language:** Python 3 for tools (`/tools`): asset forge, validators, balance runner **[P]**.
- Alternative considered: Bevy (Rust). Rejected for now: slow compiles, fast-changing API, no editor.

## 2. Rendering approach **[P]**
- 3D scene with an **orthographic isometric-style camera** and **billboarded sprites** (2.5D). Gameplay happens on a flat ground plane (x, z).
- **Horde rendering:** one `MultiMeshInstance3D` per enemy type/atlas, updated from packed arrays. **Never one Node per enemy.** As built (D-087): `view/horde_renderer.gd` owns one MultiMesh per enemy type in the catalog plus one for the placeholder towers; `view/horde_batcher.gd` (RefCounted, tested headless) packs the visible instances each frame into one `PackedFloat32Array` per batch (TRANSFORM_3D with identity basis + 4 custom floats), uploaded in bulk with `visible_instance_count` set to the visible count. Off-screen culling is done on the CPU in the fill loop (ground point against the orthographic view rectangle grown by the sprite height); each MultiMesh has a fixed `custom_aabb` over the sim area, so Godot never recomputes it. `last_fill_usec` records the fill + upload time (diagnostics). Placeholder sprites are generated at runtime by `view/placeholder_art.gd`; sprite heights (world units), walk frames and fps are in `data/render/*.json` (schema `tools/schemas/render.schema.json`), placeholders until CP-M1; per-type values move to sprite metadata in M4.
- Waifus/towers (few instances): can be regular nodes with skeletal 2D parts (see `03_ART_PIPELINE.md`).
- Sprite animation for the horde through a shader (`view/billboard.gdshader`, no AnimatedSprite nodes): a camera-facing billboard pivoted at the bottom centre, unshaded, alpha scissor 0.5 (opaque cut-out, no transparency sorting). Per-instance custom data: `r` = frame offset (desynchronises neighbours), `g` = flip (1 when the enemy is right of the Guardian on screen, so it faces the Guardian). The frame is `(offset + int(TIME * fps)) % frames`: the walk cycle is cosmetic and stays in the view (the sim's `anim_frame` is not used).
- **Base resolution [D]:** 2560x1440, scaled down to 1280x800 on Steam Deck (D-039).
- **Movable camera [D]:** the player can move the camera (D-040), so the sim world is larger than the screen and the view culls off-screen entities. Controls and bounds: D-041.
- **Camera rig [P]:** `view/iso_camera.gd` is a `Node3D` at the focus point on the ground with a child orthographic `Camera3D` placed by yaw, pitch and distance. Its tunables (angle, distance, the 3 zoom sizes, pan speed, edge-scroll margin, bounds radius + margin) live in `data/camera/*.json` (schema `tools/schemas/camera.schema.json`, D-086). The angle is a placeholder (pitch 30, yaw 45) until CP-M1. Input actions `cam_pan_*` and `cam_zoom_in/out` are in `project.godot`.
- **Fallback decision:** if 3D billboarding costs too much on Steam Deck, switch the view layer to pure 2D with iso-looking art. Because the simulation is independent of rendering (below), this is a contained change.

## 3. Architecture: simulation / view split **[D]**
> Confirmed by the owner on 2026-10-08 (D-020, D-037).

```
game/
  sim/      <- pure game rules. No Node/scene dependencies. Deterministic with a seed.
  view/     <- rendering, VFX, audio, UI. Reads sim state; never mutates rules.
  data/     <- content: waifus, enemies, outfits, cards, waves (JSON or .tres)
  input/    <- keyboard/mouse/gamepad mapping to sim commands
  tests/    <- headless tests
```
- The sim exposes a fixed-timestep `step()` (each call advances exactly one `SIM_DT` tick; the caller accumulates frame time, D-069) and a command queue (`PlaceTower`, `UseSkill`, `PickCard`...).
- The sim stores entities in **packed arrays** (structure-of-arrays: positions, hp, types) for speed.
- Spatial queries (nearest enemy, collisions) through a **uniform spatial hash grid**.
- Why: (1) performance, (2) **headless balance simulation** (run thousands of runs overnight), (3) swappable view layer, (4) agents can test rules without launching the game.

### 3a. Concrete sim contract **[P]** (details for implementers; the 30 Hz tick is decided, D-038)
- **Tick:** fixed `SIM_DT = 1/30 s`; the view interpolates positions between the previous and current tick. Render rate is independent.
- **View driver (D-086):** `view/sim_driver.gd` (RefCounted) accumulates frame time and runs one `step()` per `SIM_DT`, at most 5 per frame; time beyond that is dropped (no spiral of death). Before each step it copies `pos_x`/`pos_z` into `prev_x`/`prev_z`; rendering uses `lerp(prev, current, alpha)` with `alpha = accumulator / SIM_DT`, and the current position for enemies added after the last step. After a swap-remove (D-081) or a recycle `prev[i]` can be far from the current position: the horde view snaps to the current position when the jump in one tick is above 2 units (`HordeBatcher.SNAP_DIST_SQ`, D-087). A swap-remove between two nearby enemies still interpolates from the other enemy for one tick (invisible at that distance).
- **Units:** 1 world unit = 1 metre-ish; Guardian at (0, 0); ground plane x/z; the sim never uses floats from the view or from `delta`.
- **Determinism:** one `RandomNumberGenerator` per concern (spawns, loot, cards, combat), each seeded from the run seed as `hash([run_seed, "<concern>"])` (e.g. `_spawn_rng` uses `"spawns"`); no use of global `randf()`; iteration order over entity arrays is by index; no dictionaries iterated in unordered fashion for results.
- **Commands (only way to change the sim from outside, D-100):** `SimCommand` (`sim/sim_command.gd`) with `type` in `START_RUN{run_seed, run_id}` (`run_id` = a `data/runs` id), `PAUSE{paused}`, `PLACE_TOWER{tower_id, x, z}` (`tower_id` = a `data/towers` id), `SELL_TOWER{tower_uid}`, `USE_SKILL{skill_id}` (a `data/skills` id); one static constructor per type. `tower_uid` is a stable id assigned on placement (task 015), never an array index (D-081). `PickCard` (M3) and `ChooseGuardian` (M2 takes the Guardian from the run file) come later. Every command carries `tick`: `SimWorld.queue(cmd)` stamps `tick = max(cmd.tick, world.tick)` (a late command applies at the next step; the stamped tick is what a replay records) and keeps the queue sorted by tick, then enqueue order. `step()` applies every queued command with `tick <= world.tick` first, so a run replays from `(seed, commands)`. StartRun is ignored unless IDLE; it reseeds the RNGs (`_seed_rngs`) and loads `RunData`. PlaceTower and SellTower are ignored while paused (D-105). Handlers: PlaceTower/SellTower task 015, UseSkill task 017.
- **Events out (for the view, D-100):** `world.events` (`SimEvents`, `sim/sim_events.gd`) holds the events of the last `step()` as SoA: `kind, a` (`PackedInt32Array`), `x, z, value` (`PackedFloat32Array`), `count` valid entries. Cleared at the start of every `step()` (capacity kept; it grows by doubling and never allocates once its peak is reached). The driver runs up to 5 steps per frame, so the view reads events after **each** step. Events never hold enemy indices (D-081). The view reads events and state arrays; it never calls back into rules. `LevelUp` comes with cards (M3). Payload per kind (the emitting tasks fill them):

  | Kind | a | x, z | value |
  |---|---|---|---|
  | ENEMY_DIED | enemy type_id | position | gold gained |
  | ENEMY_HIT | enemy type_id | position | damage |
  | TOWER_PLACED | tower_uid | position | tower type |
  | TOWER_DIED | tower_uid | position | 0 |
  | SKILL_USED | skill slot | 0, 0 | 0 |
  | GUARDIAN_HIT | source enemy type_id | source position | damage after shield |
  | WAVE_STARTED | wave index (0-based) | 0, 0 | 0 |
  | RUN_ENDED | 1 won, 0 lost | 0, 0 | 0 |
- **Run state (D-100):** `SimWorld.run_state` in `IDLE, RUNNING, WON, LOST` (014 sets WON/LOST), plus `paused`. `tick` is the command clock and advances on every `step()`; `clock` is the run clock (013's timeline reads it) and advances only while RUNNING and not paused. While paused, WON or LOST, `step()` applies commands and advances `tick` only: nothing moves. IDLE (no StartRun) still simulates, so the M1 demo, the bench and the tests behave as before. `state_hash()` includes `tick, clock, run_state, paused` and the run id.
- **Entity arrays (SoA, `PackedFloat32Array` / `PackedInt32Array`):** enemy `pos_x, pos_z, hp, type_id, state, anim_frame, target_id`; tower in M1 `pos_x, pos_z, attack_range, target` (`hp, waifu_id, level, cooldown` are added when M2 uses them).
- **Towers (D-085):** `SimTowers` holds packed arrays that grow with no cap (D-040, D-042); `towers.add(x, z, range)` adds one tower (PlaceTower wires it in task 015; the range is a parameter until waifu data exists in M2). Every tick, in the targeting phase, each tower stores in `target` the index of its nearest enemy within `attack_range` via `SpatialGrid.nearest` (lowest index on ties, -1 if none); like all enemy indices it is valid within that tick only (D-081). No attacks yet (M2).
- **Enemy arrays (implemented in `sim/sim_enemies.gd`, D-081):** every array has `size() == count`; `remove(i)` swap-removes (the last enemy moves into slot `i`) in one function that every per-enemy array goes through, so **an enemy index is only valid within one tick**. `type_id` is the index of the type in `EnemyCatalog` (`sim/enemy_catalog.gd`), which loads every `data/enemies/*.json` sorted by `id`; per-type stats (`speed`, `radius`, `hp`, `separation_strength`, `damage`, `attack_range`, `attack_cooldown` in ticks, `gold`, `gold_chance`, `is_boss`, `name_key`) are packed arrays indexed by `type_id`, and `max_radius` is computed at load over the horde (non-boss) types only (D-099). `target_id` is added when something uses it (M2).
- **Demo recycle (test/benchmark/demo API, D-087):** `SimWorld.recycle_radius` (default 0 = off). When > 0, in the MOVE phase right after the chase, every `AT_GUARDIAN` enemy is moved, in index order, to a point on the ring of that radius (angle from `_spawn_rng`) and set back to `MOVING`; no removal, so indices and count are unchanged. The main scene uses it for a never-ending demo horde; a run spawns from its timeline instead (D-106).
- **Enemy movement (placeholder):** each tick a `MOVING` enemy moves `min(speed * SIM_DT, dist - radius)` straight toward (0, 0), using its own `radius` from data; at `dist <= radius` it becomes `AT_GUARDIAN` and stops moving. Replaced when the Guardian gets a contact radius (M2).
- **Spatial hash (implemented in `sim/spatial_grid.gd`, D-082):** a bounded uniform grid over the square `[-64, 64]` on x/z; positions outside are clamped into the edge cells, so queries stay exact anywhere (only slower far out). Cell size = largest horde collision diameter = `2 * max(radius)` over the horde (non-boss) types of the enemy catalog, derived from data (currently 0.8 units, brute radius 0.4; D-108, was `4 * max(radius)` until task 025), so the separation scan reach `r_i + max_radius` spans at most one cell beyond the enemy's own. Bosses are excluded so one large radius does not grow every cell (D-099); bosses get their own separation pass (D-106, below). `SimWorld.step()` rebuilds it after enemy movement each tick with a counting sort into packed arrays (no per-cell arrays, no allocation once the enemy count has peaked); it is derived state, not in `state_hash()`. Queries take the position arrays as arguments: `query_radius(x, z, r, xs, zs, out)` fills `out` with the indices within `r`, ascending; `nearest(x, z, max_range, xs, zs)` returns the closest index within `max_range` (lowest index on ties) or -1; it searches square rings of cells outward, scans each ring's top and bottom rows as one contiguous `cell_items` range and its side cells one by one, and stops once a ring cannot beat the best distance (the result does not depend on the visit order).
- **Enemy separation (implemented in `sim/enemy_separation.gd`, D-079, D-084):** two enemies overlap when their distance `d < r_i + r_j` (the collision `radius` from data is the separation radius). Each one is pushed directly away from the other by `0.5 * overlap * separation_strength` of its own type (`overlap = r_i + r_j - d`; `separation_strength` in enemy data, 0..1), so strength 1 resolves a lone pair in one tick and strength 0.5 halves the overlap per tick; the chase keeps a small overlap in a dense crowd. Jacobi style: all pushes are computed from the positions at the start of the phase, then applied in one pass; each pair is visited once in fixed grid order, so the result is deterministic. Coincident enemies (`d < 1e-6`) are pushed along x: `-x` for the lower index, `+x` for the higher. The total push of one enemy per tick is capped at its own radius. **Boss pass (D-106):** the horde loop skips every pair with a boss (`is_boss`), since its scan reach `r_i + max_radius` misses a boss's larger radius; bosses are collected in index order, then each boss scans the grid cells within `r_boss + max_radius` for horde enemies and checks every later boss directly (bosses are few), with the same pair rule and Jacobi buffers, before the capped apply pass. Every enemy is pushed whatever its `state`, and `state` is not changed. It iterates the grid cells (`cell_start`/`cell_items`) directly instead of `query_radius`, because one query per enemy cost about 73 ms per tick at 3000 piled enemies; the grid lookups are inlined (task 025). Cost after task 025: about 25-38 ms per tick for 3000 enemies piled at the Guardian in headless debug (`test_separation_cost_3000_piled`), and in the release bench 3.4 ms (`pc_typical`, `pc_stress`) and 5.1 ms (`pc_piled`) per tick (it was 5.4-7.9 ms before task 025).
- **Waves and spawns (implemented in `sim/wave_spawner.gd`, D-106):** stateless, driven by the run `clock` (D-100) in integer ticks and `_spawn_rng`, so nothing new goes into `state_hash()`. With `P = wave_ticks + break_ticks`: nothing before `first_wave_tick`; then `rel = clock - first_wave_tick`, wave `w = rel / P`, offset `t = rel % P`. At `t == 0` a `WAVE_STARTED` event (a = w). `t < wave_ticks` spawns, `t >= wave_ticks` is the break and spawns no horde (D-032). Wave entry `e = min(w, waves - 1)`: the last entry repeats (D-096, D-099), `w` keeps counting. Even spread: at offset `t`, `((t + 1) * n) / wave_ticks - (t * n) / wave_ticks` enemies (`n = wave_count[e]`, integer division), exactly `n` per wave. Per spawn, RNG draws in this order: type by weighted pick over the entry's mix (`randf() * total weight`, cumulative walk), angle `randf() * TAU`, radius `lerp(spawn_ring_min, spawn_ring_max, randf())`, around the Guardian; hp from the catalog. Mini-bosses spawn when `clock == boss_ticks[k]` and the final boss when `clock == final_boss_tick`, after that tick's horde, on the same ring, in a wave or a break; the horde goes on after the final boss. Only while RUNNING: an IDLE world never spawns (M1 demo, benchmark and tests use `spawn_ring` and `recycle_radius`). The ring (30-44 in `run_m2`) is outside the camera pan bounds (`bounds_radius + bounds_margin` = 26); at the widest zoom near the pan edge the view can reach past it (CP-M2 playtest point).
- **Tick order (D-083):** `SimWorld.step()` runs these phases in this order: (0) commands (D-100): apply queued commands due this tick, then stop here if paused, won or lost; (1) enemy separation (task 004), which reads the grid built at the end of the previous tick, so grid and positions match exactly; (2) chase movement; (2b) spawns (task 013, D-106: `WaveSpawner.step` while RUNNING); (3) grid rebuild, the only one per tick (about 2 ms per 3000 enemies in headless debug, task 003); (4) tower targeting (task 005) on the fresh grid, so every target is exact for this tick's positions. Invariant: when `step()` starts, the grid matches the enemy arrays; as a safety net `step()` first rebuilds the grid if the enemy count differs from the last rebuild (enemies added or removed outside `step()`, e.g. `spawn_ring`). Phases that add, remove or move enemies (M2: deaths, spawns) go before (3). `step()` records the wall-clock time of each phase in `phase_usec` (indexed by `SimWorld.Phase`: `COMMANDS, SEPARATE, MOVE, SPAWN, GRID, TARGETING`; the arrays are sized from `Phase.size()`) for the benchmark (task 008), and adds them to the running sum `phase_usec_sum` (the caller resets it; averages = sum / ticks run); both are diagnostics only, never read by rules and not in `state_hash()`.
- **Build area:** towers snap to a fine grid inside the build radius, which starts at about 20 units from the Guardian and can grow (D-042). Tower count is not capped, so tower arrays must grow dynamically and the M1 benchmark must include the 300-tower stress case.

### 3b. Data schema example **[P]** (JSON + JSON Schema is decided, D-034)
```json
{
  "schema_version": 3,
  "id": "enemy_swarmer_01",
  "placeholder": true,
  "name_key": "enemy.swarmer_01.name",
  "archetype": "swarmer",
  "hp": 8,
  "speed": 3.2,
  "damage": 1,
  "attack_range": 0,
  "attack_cooldown_sec": 1.0,
  "radius": 0.35,
  "separation_strength": 0.5,
  "xp": 1,
  "drops": [{"type": "gold", "amount": 1, "chance": 0.6}],
  "sprite": "enemies/swarmer_01",
  "tags": []
}
```
All displayed text (names, barks, card text) is stored as localisation keys, never literals, so adding a language is data only. Every data file has a `schema_version` integer; the validator rejects unknown fields and dangling ids. All numbers shown above are placeholders and not balance decisions. `damage` is the damage per hit, melee or ranged; `attack_range` 0 means melee (attacks at contact).

**M2 data files (D-099).** Every M2 content file has `"placeholder": true` while its numbers are placeholders. Sim loaders read them once per world through `sim/data_files.gd` (`DataFiles`): ids are resolved to catalog indices and every `*_sec` value becomes integer ticks (`DataFiles.ticks`) at load, so the sim never accumulates float time.
- `data/enemies/`: swarmer, brute, ranged, 2 mini-bosses, final boss (`archetype` enum `swarmer, brute, ranged, miniboss, boss`) -> `EnemyCatalog`.
- `data/towers/`: the 3 M2 types (`attack` `single`, `splash`, `slow`): cost, `cost_per_copy` (linear growth), hp, footprint `radius`, range, damage, cooldown, splash radius, slow factor/duration, sell refund, husk rebuild fraction (husks are walkable, D-104) -> `TowerCatalog` (`sim/tower_catalog.gd`).
- `data/skills/`: Guardian skills (`kind` `area_blast`, `shield`) and `data/guardians/`: Guardian hp, contact radius, skill ids.
- `data/runs/`: run timeline and economy (starting gold, build radius, placement grid step, spawn ring, `first_wave_sec`, `wave_sec`, `break_sec`, `waves` with count and enemy mix, the last entry repeating once the list runs out, mini-boss times, final boss, towers offered) -> `RunData` (`sim/run_data.gd`), which also holds the run's Guardian and her skills.
## 4. Performance budgets (targets, validated in milestone M1) **[P]**
| Platform | Target |
|---|---|
| PC (mid-range) | 60 FPS with ~3000 enemies + 50 towers (typical); stress case 300 towers (D-042) |
| Steam Deck | 40-60 FPS with ~1500 enemies + 50 towers (typical); stress case 150 towers (D-042) |
- Sim step budget: under 4 ms per frame at max load on PC (at a 30 Hz tick, the per-tick cost may be up to 8 ms; see section 3a and D-038).
- **Measured in M1 (task 009, `reports/perf_m1.md`)**: release export, i7-13700K + RTX 5070 Ti, 2560x1440, vsync off, median of 3 runs. The Deck columns are an **estimate** from PC numbers (D-080: no Deck; expected `k_cpu` 2.2, pessimistic 2.74, from public single-thread benchmarks); a real Deck run is still due by M6.

| Scenario | 1%-low FPS | Frame p99 | Sim step / tick | Top phase | Deck tick frame, expected / pessimistic (estimate) |
|---|---|---|---|---|---|
| `pc_typical` 3000/50 | 125 | 6.8 ms | 5.7 ms (PASS) | separation 79% | - |
| `pc_stress` 3000/300 | 112 | 7.6 ms | 6.6 ms (PASS) | separation 68% | - |
| `pc_piled` 3000/300, piled at the Guardian | 90 | 10.2 ms | 8.6 ms (over 8 ms by ~8%; M1 placeholder worst case) | separation 75% | - |
| `deck_typical` 1500/50 | (PC) 333 | 2.5 ms | 2.4 ms | separation 68% | 6.1 / 7.6 ms |
| `deck_stress` 1500/150 | (PC) 282 | 3.0 ms | 2.8 ms | separation 60% | 7.0 / 8.8 ms |
| `deck_piled` 1500/150, piled | (PC) 140 | 7.0 ms | 4.0 ms | separation 67% | 15.4 / 19.2 ms (40-60 FPS) |

View cost on PC: GPU <= 0.24 ms, render CPU ~0.03 ms, MultiMesh fill <= 0.6 ms per frame. Frames are CPU-bound; the slowest frames are the ones that run a sim tick. Owner confirms at CP-M1.

## 5. Content as data **[D]**
- Waifu, enemy, outfit, card, wave definitions in `game/data/` as JSON files validated by JSON Schema (D-034).
- A validator in `/tools` checks all data files (missing assets, invalid stats, broken references) and runs in CI. Implemented: schema per folder, unique ids matching file names, references between files (every string shaped like an `enemy_`/`tower_`/`skill_`/`guardian_`/`run_` id must name a known file) and run bosses must be `miniboss`/`boss` enemies (D-099). Asset existence is not checked yet.

## 6. Testing **[P]**
- Unit/integration tests with a Godot test framework (**GUT**, D-033) run headless: `godot --headless ...`. The run fails if GUT ignores any test script (parse error, or not extending GutTest), via the post-run hook `tests/gut_post_run.gd`; a runtime error inside a test fails that test (GUT default).
- **Sim determinism test:** same seed + same commands = same result.
- **Balance runner:** headless bot plays N runs with scripted strategies, outputs win rate, time-to-death, DPS curves into `/reports`.
- **Screenshot tests:** scripted scenes captured by a non-headless run for visual regression (human reviews diffs).
- **Perf benchmark scene (task 008, D-088):** `scripts\bench.ps1` exports the release build and starts it with the user arg `--bench` (release templates refuse a scene path argument), which opens `view/bench/bench.tscn`. Scenarios live in `data/bench/bench_m1.json` (seed, spawn rings, recycle radius, tower range, and per scenario enemies, towers, `piled`, warm-up, camera zoom, `render_scale`): `pc_typical` 3000/50, `pc_stress` 3000/300, `deck_typical` 1500/50, `deck_stress` 1500/150 (both at `render_scale` 0.5, about 1280x720 3D pixels, as the Deck pixel proxy) `pc_piled` 3000/300 and `deck_piled` 1500/150 (`render_scale` 0.5) with no recycle (the crowd piled at the Guardian). Moving cases spawn on rings 24-44 and recycle at 40, so the crowd keeps crossing the tower field (towers on a sunflower spiral over the build radius). Each scenario runs in the real main scene with vsync off and no FPS cap, warms up, then measures for `measure_sec` of wall time. Output `reports/perf_<date>.json`: the machine (OS, CPU, GPU, Godot version, release flag, window size, `vsync_mode` and `max_fps` as proof of an uncapped run, commit) and per scenario: frames, average FPS (frames / time), 1%-low FPS (1e6 / mean of the slowest 1% of frame times), average / p99 / max frame ms; sim ticks, ticks per second, step and per-phase ms per tick (from `phase_usec_sum`); view fill ms per frame; `cpu_gpu` (`process_ms_avg` = sim steps + fill per frame, `render_cpu_ms_avg`, `gpu_ms_avg` from the viewport's measured render times) for the Deck estimate (D-080); `mean_speed` of the enemies over the last tick (recycle jumps excluded; near 0 when piled).

## 7. Platform / Steam integration **[P]**
- **GodotSteam** (achievements, cloud saves, later Steam Input).
- Steam Deck: gamepad-first UI, readable text at 1280x800, no mouse-only interactions.
- Saves: local JSON with versioning and migration. The meta profile is saved; a run is not resumable after the app is closed except for an automatic suspend save at card and wave boundaries (D-053). **[D]**

## 8. Build and CI **[D]**
- The repo is on GitHub. Builds, headless tests, balance runs and perf benchmarks run on the owner's PC (D-035), not in cloud CI. The scripts are PowerShell files in `/scripts` (`test.ps1`, `validate.ps1`, `run.ps1`, `export.ps1`, D-068), listed in the Commands section of `CLAUDE.md`. Nightly runs are triggered by desktop-app scheduled tasks, or manually (D-049). GitHub Actions can be added later without changing the scripts.

## 9. Coding standards for agents
- Typed GDScript, small files, one responsibility per file.
- No game rule in `view/`. No scene access in `sim/`.
- New content = data first, code only if a new mechanic is needed.
- Every new system gets at least one headless test.
