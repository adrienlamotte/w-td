# 007 — View: MultiMesh billboard rendering for the horde and towers
- Status: done
- Milestone: M1
- Depends on: 006
- PR: #11

## Goal
Render enemies (and placeholder towers) as billboarded sprites through one MultiMeshInstance3D per type, animated by a shader, never one Node per enemy.

## Context
- `02_TECH_ARCHITECTURE.md` 2: MultiMesh per enemy type/atlas updated from packed arrays; the shader reads the frame index from per-instance custom data
- `03_ART_PIPELINE.md` 3: enemy frames 256 px, walk 6-8 frames, horde about 85-130 px on screen at 1440p, faces right and flips horizontally, bottom-centre pivot

## Acceptance criteria
- One `MultiMeshInstance3D` per enemy type; the instance buffer is filled from the sim arrays each frame (bulk buffer write, no per-instance Node).
- Billboard, frame animation and horizontal flip in a shader using per-instance custom data.
- Placeholder art is generated procedurally at runtime (no binary art files committed).
- Off-screen culling: only on-screen instances are drawn (or a measured reason why it is not needed).
- Sprite size on screen in the 85-130 px range at 2560x1440 at the default zoom.
- The placeholder towers are rendered too (same shader, one MultiMesh).
- The main scene (`scripts\run.ps1`) shows a demo horde for CP-M1: enemies spawn on rings around the Guardian and keep coming, so the scene never empties (placeholder, no spawn curve design), plus a few placeholder towers.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Design:
- **Sizes (data).** `game/data/render/render_default.json`, schema `tools/schemas/render.schema.json` (validator picks it by folder name, like `camera`). Fields, all placeholders judged at CP-M1: `schema_version` (1), `id` (`render_default`, pattern `^render_[a-z0-9_]+$`), `enemy_sprite_height` (1.8 world units), `tower_sprite_height` (4.0), `walk_frames` (8, integer 1-16), `walk_fps` (12, > 0). `additionalProperties: false`. Arithmetic: Camera3D keeps height by default, so at the default zoom size 24 one world unit is 1440 / 24 = 60 px; a camera-facing billboard of height h is 60 h px tall: enemy 108 px (85-130 required), tower 240 px (waifu 215-265 px, `03_ART_PIPELINE.md` 3). Per-type sizes and frame counts move to the sprite metadata (`<asset_id>.json`) when real art exists (M4); not now.
- **Placeholder art** `game/view/placeholder_art.gd` (view, static funcs, no Node): `enemy_strip(color: Color, frames: int, cell: int) -> Image` makes one horizontal strip of `frames` cells of `cell` px (64 is enough for a placeholder), transparent background, a filled body circle that bobs by frame, two feet that alternate, and an eye on the right side so facing right / flipped is visible; `tower_image(color: Color, cell: int) -> Image` a single taller shape (body + head). Feet on the bottom edge of the cell (bottom-centre pivot). Colour per enemy type from `Color.from_hsv(fmod(type_id * 0.618, 1.0), 0.6, 0.95)`. Textures via `ImageTexture.create_from_image`. Nothing saved to disk.
- **Shader** `game/view/billboard.gdshader` (view): `shader_type spatial; render_mode unshaded, cull_disabled;` Camera-facing billboard with the instance origin as the pivot: base it on the code Godot generates for a StandardMaterial3D with billboard enabled (`MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3])`), scaled by a `uniform vec2 sprite_size`. The mesh is a `QuadMesh` of size 1x1 with `center_offset = Vector3(0, 0.5, 0)` so the bottom edge sits on the ground. Uniforms: `sampler2D tex : filter_linear_mipmap, source_color`, `int frames`, `float fps`. Per-instance custom data: `INSTANCE_CUSTOM.r` = frame offset (desynchronises neighbours), `.g` = flip (0 or 1). Frame = `(int(INSTANCE_CUSTOM.r) + int(TIME * fps)) % frames`; UV x is mirrored when flip > 0.5, then mapped into that frame's cell. Pass them from `vertex()` to `fragment()` with varyings. `ALPHA_SCISSOR_THRESHOLD = 0.5` (opaque depth-tested cut-out: no transparency sorting of thousands of quads). The frame comes from TIME in the shader, not from the sim's `anim_frame` (nothing advances it in M1); the animation is cosmetic so it stays in the view. Update `02_TECH_ARCHITECTURE.md` 2 accordingly ("frame offset" instead of "frame index").
- **Batcher** `game/view/horde_batcher.gd` (view, `RefCounted`, no Node so it is testable headless): owns one `PackedFloat32Array` buffer and one count per batch. Layout per instance: 12 floats of `TRANSFORM_3D` (row-major 3x4: basis row 0, origin.x, basis row 1, origin.y, basis row 2, origin.z) + 4 floats of custom data = stride 16. The basis is identity (the shader sizes and orients the quad), written once when a buffer grows; each frame writes only origin x (offset 3), y (7, always 0), z (11) and custom r, g (12, 13) of the visible instances, packed from slot 0. `fill(xs, zs, prev_x, prev_z, alpha, type_id, cull)` loops over the enemies once, by index:
  - position = `lerp(prev, cur, alpha)` when `i < prev.size()`, else `cur`; also `cur` when the squared jump `(cur - prev)^2` is above `SNAP_DIST_SQ` (const, 2 units squared; no enemy moves that far in one tick). This snap is the "view snaps them" fix from the 006 caveat, and it hides the teleport of a recycled enemy (below). Update the caveat in `02_TECH_ARCHITECTURE.md` 3a.
  - culling: skip the instance when its ground point is outside the camera's view rectangle grown by a margin (the sprite height). `cull` is a small value built once per frame from the camera (orthographic): the camera-space x and y of a ground point are each `a*x + b*z + c` with 6 precomputed floats taken from `camera.global_transform.affine_inverse()`, plus the half extents `size / 2 * aspect` and `size / 2`. No `Transform3D * Vector3` per instance: inline the multiply-adds (GDScript call overhead).
  - flip: the sprite faces the Guardian, `flip = 1` when the enemy is right of the Guardian on screen (camera-space x of the ground point minus that of (0, 0) > 0). Stable in a jostling crowd, unlike velocity. Ponytail note: velocity-based facing when enemies chase something other than the Guardian (M2).
  - frame offset = `i % walk_frames`.
  - Batch index = `type_id[i]`. Per batch, if the count would exceed capacity, grow the buffer (double) before writing.
  `counts: PackedInt32Array`, `buffers: Array[PackedFloat32Array]`. Towers use a second `HordeBatcher` with one batch: pass the tower arrays as both current and previous (they do not move), alpha 0, and a `type_id` array of zeros kept at the tower count.
- **Renderer** `game/view/horde_renderer.gd` (view, `extends Node3D`, child of `Main`): in `setup(driver: SimDriver, camera: Camera3D)` called by `game_view.gd`, loads `render_default.json` (same FileAccess + JSON pattern as `IsoCamera.load_config`), builds one `MultiMeshInstance3D` per enemy type in `driver.world.catalog` plus one for towers, each with its own `ShaderMaterial` (texture, frames, fps, sprite_size; towers: frames 1). MultiMesh: set `transform_format = TRANSFORM_3D` and `use_custom_data = true` while `instance_count` is 0 (Godot only allows format changes then), set `custom_aabb` to cover the sim area (the grid square plus sprite height) so Godot never recomputes the AABB from the buffer and the whole batch is not culled by a stale AABB. `_process`: build the cull values from the camera and viewport size, `batcher.fill(...)`, then per batch: when capacity grew, set `instance_count` to the buffer capacity; assign `multimesh.buffer = buffers[t]` and `visible_instance_count = counts[t]`. Keep `last_fill_usec: int` (diagnostics for task 008, like `phase_usec`).
- **Demo horde (sim, small).** Enemies piled at the Guardian never leave in M1, so a steady stream needs them to come back. Add to `SimWorld` a benchmark/demo setting `recycle_radius: float = 0.0` (0 = off, default, so every current test and the 008 "piled" case are unchanged). When > 0, `step()` moves every `AT_GUARDIAN` enemy to a point on the ring of that radius (angle from `_spawn_rng`, same as `spawn_ring`) and sets it back to `MOVING`, in index order, inside the MOVE phase right after `chase_guardian` and before the grid rebuild (D-083: phases that move enemies go before (3)). No swap-remove, so indices and the count stay stable. Comment it as a test/benchmark/demo API like `spawn_ring`; the real spawn curve is M2. Task 008 reuses it ("respawn on the ring any enemy that reaches the Guardian").
- **Demo scene** `game/view/game_view.gd`: in `_ready`, set up a placeholder scenario through the existing test/benchmark APIs, then call `$HordeRenderer.setup(driver, $CameraRig/Camera3D)`. Consts marked placeholder until `StartRun` and waves (M2): `DEMO_ENEMIES = 1500` spread over 6 `spawn_ring` calls with radii from 24 to 44 (so arrivals are spread in time and the stream is continuous), `world.recycle_radius = 40.0`, 12 towers on a circle of radius 10 with range 6 via `world.towers.add`. Type via `world.catalog.type_of("enemy_swarmer_01")`. No game rule in the view: it only sets up the scenario and reads state.
- `game/view/main.tscn`: add `HordeRenderer` (Node3D, horde_renderer.gd) under `Main`.

Files:
1. `game/data/render/render_default.json` (data, new), `tools/schemas/render.schema.json` (tools, new).
2. `game/view/placeholder_art.gd` (view, new).
3. `game/view/billboard.gdshader` (view, new).
4. `game/view/horde_batcher.gd` (view, new).
5. `game/view/horde_renderer.gd` (view, new).
6. `game/view/game_view.gd`, `game/view/main.tscn` (view, change).
7. `game/sim/sim_world.gd` (sim, change): `recycle_radius` and the recycle in the MOVE phase.
8. Docs: `02_TECH_ARCHITECTURE.md` 2 (horde rendering as built: one MultiMesh per type + one for towers, camera-facing billboard, custom data r = frame offset / g = flip, frame from TIME, alpha scissor, CPU culling in the fill loop, custom AABB, sizes in `data/render`) and 3a (`recycle_radius`; the snap replaces the swap-remove caveat). D-087 (PROPOSED) in `DECISIONS.md` covering those choices. `docs/plans/M1.md` unchanged unless scope moves.

Tests (headless, GUT):
- `game/tests/view/test_horde_batcher.gd`: with a hand-built camera transform and extents (no Camera node needed): 3 enemies of 2 types, one far off-screen, gives counts [1, 1] (or as placed) and the culled one absent; origin x/z in the buffer equal the interpolated position at alpha 0.5; a jump above the snap distance writes the current position; flip is 1 for an enemy right of the Guardian on screen and 0 on the left; custom r = `i % walk_frames`; capacity growth past the initial size keeps earlier instances intact and the identity basis in new slots.
- `game/tests/view/test_placeholder_art.gd`: the enemy strip is `frames * cell` by `cell`, a corner pixel is transparent, the cell centre is opaque, two frames differ; the tower image is non-empty with a transparent corner.
- `game/tests/view/test_render_config.gd` (or added to `test_iso_camera.gd`): from the two data files (not hard-coded), `enemy_sprite_height * 1440 / zoom_sizes[default_zoom]` is within 85-130 px; tower height within 215-265 px.
- `game/tests/sim/test_sim_world.gd`: with `recycle_radius = 10`, an enemy spawned at distance 0.5 is, after one step, `MOVING` at distance about 10 and the count is unchanged; with the default 0 it stays `AT_GUARDIAN`.
- `game/tests/sim/test_determinism.gd`: set `recycle_radius = 30.0` in `_run` (the minute is long enough for arrivals), so the recycle path is covered by the same-seed / different-seed checks.
- `tools/tests`: the validator accepts `render_default.json` and rejects a copy with an extra field.

Performance notes:
- The per-frame cost is the GDScript fill loop: about 3000 iterations at PC load, each a lerp, two cull dot products, a flip test and 5 buffer writes. Target: under 3 ms per frame at 3000 enemies in a release export; `last_fill_usec` lets 008 measure it. No allocation per frame once capacity has peaked (buffers grow by doubling, never shrink). If 008 shows it over budget, the options are a lower-level fill (skip interpolation when the frame rate is low) or the GDExtension escape hatch (`02_TECH_ARCHITECTURE.md` 1); not now.
- One buffer upload per batch per frame; `visible_instance_count` limits the drawn instances to the on-screen ones; custom AABB avoids an AABB recompute per upload. Alpha scissor keeps the quads opaque (early depth, no sort).
- The recycle loop is O(n) per tick over `state`, negligible next to separation.

Order: data + schema + validator test; `recycle_radius` + sim tests (determinism test twice); placeholder_art + test; shader; horde_batcher + tests; horde_renderer, game_view, main.tscn; launch `scripts\run.ps1` and a `--write-movie` capture to check the sprites show, animate, flip, are about 108 px and the stream never empties (state in the PR what was checked); size test; docs; `scripts\test.ps1` twice; `scripts\validate.ps1`.
Size: about 300-380 lines of code and tests plus data, one PR. If it runs over, the tower MultiMesh is the part to split into a follow-up task.

Note for the owner (CP-M1): sprite heights and walk speed are placeholders in `game/data/render/render_default.json`; demo counts are consts in `game/view/game_view.gd`.

## Questions

## Review log
- 2026-10-08 lead-dev: approved and merged PR #11 (squash) into m1/dev. Ran `scripts	est.ps1` (52/52 GUT, 6/6 Python) and `scriptsalidate.ps1` (OK) on the branch; `scripts\export.ps1` builds and `build\windows\WTD.exe` runs 8 s with no errors. Checked: one MultiMesh per type + one for towers, no Node per enemy; batcher/renderer are view only (no rules); `recycle_radius` off by default, `_spawn_rng`, index order, covered by the determinism test; no binary art. Accepted deviation: one fill pass per enemy type (packed-array copy-on-write), ponytail-noted. Sprite sizes, walk fps and demo counts (needs-human:playtest) are judged at CP-M1.
