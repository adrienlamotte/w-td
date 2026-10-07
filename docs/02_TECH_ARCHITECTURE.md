# 02 — Technical Architecture

Status key: **[D]** decided, **[P]** proposed, **[O]** open.

## 1. Engine and languages
- **Engine: Godot 4.x (latest stable)** **[D]**. Reasons: all project files are text (scenes `.tscn`, resources `.tres`, scripts), so agents can read/diff/edit them; runs headless from CLI for tests and screenshots; light; free; good Steam support through GodotSteam.
- **Language: GDScript** for gameplay and tools inside Godot **[P]**. Static typing required (`var x: int`, typed function signatures).
- **Performance escape hatch:** if profiling proves GDScript cannot hit budgets, move only the hot loop (horde simulation) to a **GDExtension in Rust or C++** **[P]**. Do not do this before a profile shows the need.
- **Tooling language:** Python 3 for tools (`/tools`): asset forge, validators, balance runner **[P]**.
- Alternative considered: Bevy (Rust). Rejected for now: slow compiles, fast-changing API, no editor.

## 2. Rendering approach **[P]**
- 3D scene with an **orthographic isometric-style camera** and **billboarded sprites** (2.5D). Gameplay happens on a flat ground plane (x, z).
- **Horde rendering:** one `MultiMeshInstance3D` per enemy type/atlas, updated from packed arrays. **Never one Node per enemy.**
- Waifus/towers (few instances): can be regular nodes with skeletal 2D parts (see `03_ART_PIPELINE.md`).
- Sprite animation for the horde through a shader reading frame index from per-instance custom data (no AnimatedSprite nodes).
- **Fallback decision:** if 3D billboarding costs too much on Steam Deck, switch the view layer to pure 2D with iso-looking art. Because the simulation is independent of rendering (below), this is a contained change.

## 3. Architecture: simulation / view split **[D]**
```
game/
  sim/      <- pure game rules. No Node/scene dependencies. Deterministic with a seed.
  view/     <- rendering, VFX, audio, UI. Reads sim state; never mutates rules.
  data/     <- content: waifus, enemies, outfits, cards, waves (JSON or .tres)
  input/    <- keyboard/mouse/gamepad mapping to sim commands
  tests/    <- headless tests
```
- The sim exposes a fixed-timestep `step(dt)` and a command queue (`PlaceTower`, `UseSkill`, `PickCard`...).
- The sim stores entities in **packed arrays** (structure-of-arrays: positions, hp, types) for speed.
- Spatial queries (nearest enemy, collisions) through a **uniform spatial hash grid**.
- Why: (1) performance, (2) **headless balance simulation** (run thousands of runs overnight), (3) swappable view layer, (4) agents can test rules without launching the game.

## 4. Performance budgets (targets, validated in milestone M1) **[P]**
| Platform | Target |
|---|---|
| PC (mid-range) | 60 FPS with ~3000 enemies + 50 towers |
| Steam Deck | 40-60 FPS with ~1500 enemies + 50 towers |
- Sim step budget: under 4 ms/frame at max load on PC.
- Numbers are initial guesses; M1 spike will measure and update this section.

## 5. Content as data **[D]**
- Waifu, enemy, outfit, card, wave definitions in `game/data/` with a schema (JSON Schema or typed Resource scripts).
- A validator in `/tools` checks all data files (missing assets, invalid stats, broken references) and runs in CI.

## 6. Testing **[P]**
- Unit/integration tests with a Godot test framework (GUT or gdUnit4; choose in M0 and record in `DECISIONS.md`) run headless: `godot --headless ...`.
- **Sim determinism test:** same seed + same commands = same result.
- **Balance runner:** headless bot plays N runs with scripted strategies, outputs win rate, time-to-death, DPS curves into `/reports`.
- **Screenshot tests:** scripted scenes captured by a non-headless run for visual regression (human reviews diffs).
- **Perf benchmark scene:** fixed scenario, outputs FPS/frame-time JSON.

## 7. Platform / Steam integration **[P]**
- **GodotSteam** (achievements, cloud saves, later Steam Input).
- Steam Deck: gamepad-first UI, readable text at 1280x800, no mouse-only interactions.
- Saves: local JSON with versioning and migration.

## 8. Build and CI **[O]**
- Repo host and CI provider not decided. Minimum: scripted `build.sh` for Windows export + tests, runnable by an agent.

## 9. Coding standards for agents
- Typed GDScript, small files, one responsibility per file.
- No game rule in `view/`. No scene access in `sim/`.
- New content = data first, code only if a new mechanic is needed.
- Every new system gets at least one headless test.
