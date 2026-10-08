# 02 — Technical Architecture

Status key: **[D]** decided, **[P]** proposed, **[O]** open.

## 1. Engine and languages
- **Engine: Godot 4.x, version pinned at the start of M0 (D-036)** **[D]**. Reasons: all project files are text (scenes `.tscn`, resources `.tres`, scripts), so agents can read/diff/edit them; runs headless from CLI for tests and screenshots; light; free; good Steam support through GodotSteam.
- **Language: GDScript** for gameplay and tools inside Godot **[P]**. Static typing required (`var x: int`, typed function signatures).
- **Performance escape hatch:** if profiling proves GDScript cannot hit budgets, move only the hot loop (horde simulation) to a **GDExtension in Rust or C++** **[P]**. Do not do this before a profile shows the need.
- **Tooling language:** Python 3 for tools (`/tools`): asset forge, validators, balance runner **[P]**.
- Alternative considered: Bevy (Rust). Rejected for now: slow compiles, fast-changing API, no editor.

## 2. Rendering approach **[P]**
- 3D scene with an **orthographic isometric-style camera** and **billboarded sprites** (2.5D). Gameplay happens on a flat ground plane (x, z).
- **Horde rendering:** one `MultiMeshInstance3D` per enemy type/atlas, updated from packed arrays. **Never one Node per enemy.**
- Waifus/towers (few instances): can be regular nodes with skeletal 2D parts (see `03_ART_PIPELINE.md`).
- Sprite animation for the horde through a shader reading frame index from per-instance custom data (no AnimatedSprite nodes).
- **Base resolution [D]:** 2560x1440, scaled down to 1280x800 on Steam Deck (D-039).
- **Movable camera [D]:** the player can move the camera (D-040), so the sim world is larger than the screen and the view culls off-screen entities. Controls and bounds: D-041.
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
- **Units:** 1 world unit = 1 metre-ish; Guardian at (0, 0); ground plane x/z; the sim never uses floats from the view or from `delta`.
- **Determinism:** one `RandomNumberGenerator` per concern (spawns, loot, cards, combat), each seeded from the run seed as `hash([run_seed, "<concern>"])` (e.g. `_spawn_rng` uses `"spawns"`); no use of global `randf()`; iteration order over entity arrays is by index; no dictionaries iterated in unordered fashion for results.
- **Commands (only way to change the sim from outside):** `PlaceTower{waifu_id, pos}`, `SellTower{tower_id}`, `UseSkill{skill_id}`, `PickCard{index}`, `ChooseGuardian{waifu_id}`, `StartRun{seed, config}`, `Pause{bool}`. Commands carry the tick they apply to so a run can be replayed from `(seed, commands)`.
- **Events out (for the view):** `EnemyDied`, `EnemyHit`, `TowerPlaced`, `TowerDied`, `SkillUsed`, `LevelUp`, `GuardianHit`, `WaveStarted`, `RunEnded`. The view reads events and state arrays; it never calls back into rules.
- **Entity arrays (SoA, `PackedFloat32Array` / `PackedInt32Array`):** enemy `pos_x, pos_z, hp, type_id, state, anim_frame, target_id`; tower `pos_x, pos_z, hp, waifu_id, level, cooldown`.
- **Enemy arrays (implemented in `sim/sim_enemies.gd`, D-081):** every array has `size() == count`; `remove(i)` swap-removes (the last enemy moves into slot `i`) in one function that every per-enemy array goes through, so **an enemy index is only valid within one tick**. `type_id` is the index of the type in `EnemyCatalog` (`sim/enemy_catalog.gd`), which loads every `data/enemies/*.json` sorted by `id`; per-type stats (`speed`, `radius`, `hp`) are packed arrays indexed by `type_id`. `target_id` is added when something uses it (M2).
- **Enemy movement (placeholder):** each tick a `MOVING` enemy moves `min(speed * SIM_DT, dist - radius)` straight toward (0, 0), using its own `radius` from data; at `dist <= radius` it becomes `AT_GUARDIAN` and stops moving. Replaced when the Guardian gets a contact radius (M2).
- **Spatial hash (implemented in `sim/spatial_grid.gd`, D-082):** a bounded uniform grid over the square `[-64, 64]` on x/z; positions outside are clamped into the edge cells, so queries stay exact anywhere (only slower far out). Cell size = largest enemy collision diameter x 2 = `4 * max(radius)` over the enemy catalog, derived from data (currently 1.4 units). `SimWorld.step()` rebuilds it after enemy movement each tick with a counting sort into packed arrays (no per-cell arrays, no allocation once the enemy count has peaked); it is derived state, not in `state_hash()`. Queries take the position arrays as arguments: `query_radius(x, z, r, xs, zs, out)` fills `out` with the indices within `r`, ascending; `nearest(x, z, max_range, xs, zs)` returns the closest index within `max_range` (lowest index on ties) or -1.
- **Tick order (D-083):** `SimWorld.step()` runs these phases in this order: (1) enemy separation (task 004), which reads the grid built at the end of the previous tick, so grid and positions match exactly; (2) chase movement; (3) grid rebuild, the only one per tick (about 2 ms per 3000 enemies in headless debug, task 003); (4) tower targeting (task 005) on the fresh grid, so every target is exact for this tick's positions. Invariant: when `step()` starts, the grid matches the enemy arrays; as a safety net `step()` first rebuilds the grid if the enemy count differs from the last rebuild (enemies added or removed outside `step()`, e.g. `spawn_ring`). Phases that add, remove or move enemies (M2: deaths, spawns) go before (3). `step()` records the wall-clock time of each phase in `phase_usec` (indexed by `SimWorld.Phase`) for the benchmark (task 008); it is diagnostics only, never read by rules and not in `state_hash()`.
- **Build area:** towers snap to a fine grid inside the build radius, which starts at about 20 units from the Guardian and can grow (D-042). Tower count is not capped, so tower arrays must grow dynamically and the M1 benchmark must include the 300-tower stress case.

### 3b. Data schema example **[P]** (JSON + JSON Schema is decided, D-034)
```json
{
  "id": "enemy_swarmer_01",
  "archetype": "swarmer",
  "hp": 8,
  "speed": 3.2,
  "contact_damage": 1,
  "radius": 0.35,
  "xp": 1,
  "drops": [{"type": "gold", "amount": 1, "chance": 0.6}],
  "sprite": "enemies/swarmer_01",
  "tags": []
}
```
All displayed text (names, barks, card text) is stored as localisation keys, never literals, so adding a language is data only. Every data file has a `schema_version` integer; the validator rejects unknown fields and dangling ids. All numbers shown above are placeholders and not balance decisions.
## 4. Performance budgets (targets, validated in milestone M1) **[P]**
| Platform | Target |
|---|---|
| PC (mid-range) | 60 FPS with ~3000 enemies + 50 towers (typical); stress case 300 towers (D-042) |
| Steam Deck | 40-60 FPS with ~1500 enemies + 50 towers (typical); stress case 150 towers (D-042) |
- Sim step budget: under 4 ms per frame at max load on PC (at a 30 Hz tick, the per-tick cost may be up to 8 ms; see section 3a and D-038).
- Numbers are initial guesses; M1 spike will measure and update this section.

## 5. Content as data **[D]**
- Waifu, enemy, outfit, card, wave definitions in `game/data/` as JSON files validated by JSON Schema (D-034).
- A validator in `/tools` checks all data files (missing assets, invalid stats, broken references) and runs in CI.

## 6. Testing **[P]**
- Unit/integration tests with a Godot test framework (**GUT**, D-033) run headless: `godot --headless ...`. The run fails if GUT ignores any test script (parse error, or not extending GutTest), via the post-run hook `tests/gut_post_run.gd`; a runtime error inside a test fails that test (GUT default).
- **Sim determinism test:** same seed + same commands = same result.
- **Balance runner:** headless bot plays N runs with scripted strategies, outputs win rate, time-to-death, DPS curves into `/reports`.
- **Screenshot tests:** scripted scenes captured by a non-headless run for visual regression (human reviews diffs).
- **Perf benchmark scene:** fixed scenario, outputs FPS/frame-time JSON.

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
