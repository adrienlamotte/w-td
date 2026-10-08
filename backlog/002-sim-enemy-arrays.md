# 002 — Sim: enemy arrays, spawning and chasing the Guardian
- Status: planned
- Milestone: M1
- Depends on: -
- PR: -

## Goal
Store enemies in the sim as packed arrays and move them straight toward the Guardian at (0, 0) every 30 Hz tick.

## Context
- `02_TECH_ARCHITECTURE.md` 3, 3a (SoA arrays, determinism, per-concern RNG), D-038
- `01_GAME_DESIGN.md` section 2: enemies path straight toward the Guardian
- Enemy data: `game/data/enemies/enemy_swarmer_01.json` (placeholder numbers)

## Acceptance criteria
- Enemy state lives in `PackedFloat32Array` / `PackedInt32Array` (pos_x, pos_z, hp, type_id, state, anim_frame) that grow dynamically; no Node, no per-enemy object.
- Enemy stats (speed, radius) come from the data file, not code.
- A spawn API places enemies on a ring around the Guardian at positions drawn from the seeded spawn RNG (the benchmark and tests need it; the real spawn curve is M2).
- Each tick moves every enemy toward (0, 0) at its speed x SIM_DT; enemies stop at the Guardian (no damage yet).
- Removing an enemy is O(1) (swap-remove).
- Headless tests: movement per tick, spawn count, and the determinism test extended so `state_hash()` covers the enemy arrays (same seed = same hash, different seed = different hash) after 1800 ticks with 1000 enemies.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Design (keeps 003-007 compatible):
- `type_id` = index of the enemy type in `EnemyCatalog`, which loads every `res://data/enemies/*.json` sorted by `id` (deterministic order). Per-type stats are packed arrays indexed by `type_id` (`speed`, `radius`), so the hot loop does `speed[type_id[i]]`, no Dictionary lookups.
- Enemy arrays always have `size() == count` (grow with `append`, shrink with `resize`). All per-enemy arrays are swap-removed in ONE function `remove(i)`; 006 adds its `prev_x/prev_z` arrays there. Indices are not stable across removals: 003 rebuilds the hash each tick and 005 recomputes targets each tick, so this is fine; nobody keeps an enemy index across ticks.
- "Stop at the Guardian": an enemy moves `min(speed * SIM_DT, dist - radius)` toward (0, 0) and switches `state` from `MOVING` (0) to `AT_GUARDIAN` (1) when its distance is `<= radius` (its own radius from data). This avoids a zero-length direction (004 normalises offsets). Placeholder until the Guardian gets a contact radius in M2 (no damage now). Arrived enemies are skipped by the movement loop.
- `anim_frame` is stored (0 at spawn) and not advanced here; 007 decides how it animates. `target_id` (3a) is not added: nothing uses it before M2.
- Per-concern RNG: replace `_rng` with `_spawn_rng`, seeded from `hash([run_seed, "spawns"])`. Other concerns add their own RNG the same way when they land.

Files:
1. `game/sim/enemy_catalog.gd` (sim, new, `class_name EnemyCatalog`, RefCounted): `static func load_dir(path := "res://data/enemies") -> EnemyCatalog`; fields `ids: PackedStringArray`, `speed`, `radius: PackedFloat32Array`, `hp: PackedFloat32Array`; `func type_of(id: String) -> int`. Uses `DirAccess`/`FileAccess`/`JSON` only (no Node). Fails loudly (`push_error` + assert) on an unreadable file; the schema validator is the real gate.
2. `game/sim/sim_enemies.gd` (sim, new, `class_name SimEnemies`, RefCounted): arrays `pos_x, pos_z, hp: PackedFloat32Array`, `type_id, state, anim_frame: PackedInt32Array`; `count() -> int`, `add(type_id, x, z, hp) -> int`, `remove(i)` (swap with last, then `resize`), `chase_guardian(speed: PackedFloat32Array, radius: PackedFloat32Array, dt: float)`.
3. `game/sim/sim_world.gd` (sim, change): `_init(run_seed: int, catalog: EnemyCatalog = null)` (null = `EnemyCatalog.load_dir()`), owns `enemies: SimEnemies` and `catalog`; `spawn_ring(type_id: int, count: int, ring_radius: float)` draws one angle per enemy with `_spawn_rng.randf() * TAU` (ring radius is the caller's argument, so no design value here; the spawn curve is M2); `step()` calls `enemies.chase_guardian(...)` then `tick += 1`; `state_hash()` = `hash([tick, _spawn_rng.state, pos_x, pos_z, hp, type_id, state, anim_frame])`.
4. `game/export_presets.cfg` (tools/config, change): `include_filter="data/*.json"` so the data files ship in exported builds (`all_resources` drops plain JSON).
5. Docs: `02_TECH_ARCHITECTURE.md` 3a: type_id = catalog index sorted by id; enemy indices are only valid within one tick (swap-remove); spawn RNG seeding pattern; stop rule placeholder. Add D-081 (PROPOSED) to `DECISIONS.md`: enemy arrays keep `size == count`, swap-remove, indices valid within a tick only. No schema change (speed, radius, hp already exist).

Tests (headless, GUT):
- `game/tests/sim/test_enemy_catalog.gd`: loads `enemy_swarmer_01`, its speed and radius equal the JSON values (read the JSON in the test, do not hard-code 3.2).
- `game/tests/sim/test_sim_enemies.gd`: one enemy at (10, 0) moves exactly `speed * SIM_DT` toward the origin after one step (and along a diagonal case); an enemy near the centre stops at distance `radius`, state becomes `AT_GUARDIAN`, and stays there after more steps; `spawn_ring(0, 1000, 30)` gives count 1000, every enemy at distance 30 +- 1e-3; `remove()` of a middle index moves the last enemy into it on every array and shrinks count by 1; removing the last index works.
- `game/tests/sim/test_determinism.gd` (change): spawn 1000 enemies on a ring, step 1800 ticks; same seed = same hash, different seed = different hash. Compute each run once (`before_all`) if the file gets slow.

Performance notes:
- Packed arrays are copy-on-write values: the hot loop lives inside `SimEnemies` and writes to its own member arrays (`pos_x[i] = ...`), never to a local copy and never through another object per element. Read the per-type stat arrays into locals once per call (read-only, no copy).
- No allocation per enemy per tick (no Vector2 arrays, no Dictionary). One `sqrt` per moving enemy.
- Report the determinism test time (1000 x 1800 = 1.8M updates per run) in the PR; it is a first rough per-tick cost signal for 008. If one run takes over ~5 s, say so in the PR (no optimisation in this task).

Order: catalog + its test, SimEnemies + its tests, SimWorld spawn/step/hash, determinism test, export filter, docs, run `scripts	est.ps1` twice and `scriptsalidate.ps1`.
Size: about 250-300 lines of code and tests; one PR.

## Questions

## Review log
