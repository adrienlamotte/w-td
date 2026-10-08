# 006 — View: isometric camera, ground plane and tick interpolation
- Status: done
- Milestone: M1
- Depends on: 002
- PR: #10

## Goal
Show the sim in a 3D scene with an orthographic isometric-style camera over a flat ground plane, interpolating positions between sim ticks, with the PC camera controls from D-041.

## Context
- `02_TECH_ARCHITECTURE.md` 2 (2.5D, orthographic iso camera, movable camera), 3a (the view interpolates between ticks)
- D-039 base resolution 2560x1440; D-041 camera controls

## Acceptance criteria
- A view scene drives the sim with a fixed-step accumulator (one `step()` per 1/30 s) and interpolates between the previous and current tick for rendering.
- Orthographic camera; its angle, distance and the 3 zoom levels are tunable values in a data or resource file (the final angle is judged at the checkpoint).
- PC controls: WASD/arrows pan, edge scroll, mouse wheel switches between the 3 zoom levels; the camera is limited to the build radius (about 20 units, D-042) plus a margin. Gamepad camera is M2.
- Placeholder ground plane and a Guardian marker at (0, 0). No game rules in view code.
- The game opens on this scene (`scripts\run.ps1`).
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan
Design:
- `view/sim_driver.gd` (RefCounted, no Node so it is testable headless) owns the fixed-step loop and interpolation. `advance(delta: float) -> int`: adds `delta` to an accumulator, and while it is `>= SimWorld.SIM_DT` it copies the current `pos_x`/`pos_z` into `prev_x`/`prev_z`, calls `world.step()`, subtracts `SIM_DT`; returns the number of steps. At most `MAX_STEPS_PER_FRAME = 5` steps per call; extra accumulated time is dropped (no spiral of death after a hitch). `alpha() -> float` = accumulator / SIM_DT. `interp_x(i)` / `interp_z(i)` = `lerp(prev, current, alpha)`; when `i >= prev.size()` (enemy spawned this tick) it returns the current position. 007 reads these (or a bulk version it adds) to fill the MultiMesh.
- Swap-remove (D-081) makes `prev[i]` belong to a different enemy for one tick after a removal. Nothing removes enemies in M1, so the driver ignores it: ponytail note in code, the fix (sim marks moved slots, or the view snaps them) comes with enemy death in M2.
- Camera values live in data: `game/data/camera/camera_default.json` with schema `tools/schemas/camera.schema.json` (the validator picks it up by folder name). Fields, all placeholders: `schema_version`, `id`, `yaw_deg` (45), `pitch_deg` (30, the angle judged at CP-M1), `distance` (40, camera distance from the focus point along its view axis; only matters for clipping with an orthographic camera), `zoom_sizes` (exactly 3 orthographic sizes in world units, for example [16, 24, 36]), `default_zoom` (index, 1), `pan_speed` (world units per second at the default zoom, scaled by zoom size / default size), `edge_scroll_px` (margin in pixels, for example 24), `bounds_radius` (20, mirrors the D-042 build radius until the sim owns it in M2), `bounds_margin` (for example 6). `additionalProperties: false`, numbers with sensible minimums, `zoom_sizes` `minItems = maxItems = 3`.
- `view/iso_camera.gd` (`extends Node3D`, the camera rig at the focus point, with a child `Camera3D` in orthogonal projection): loads the JSON in `_ready` (FileAccess + JSON, same as EnemyCatalog), places the child camera at `distance` along the direction given by yaw and pitch, looking at the rig. `_process(delta)`: pan direction from the actions plus edge scroll, rotated by yaw so "up" moves toward the top of the screen, moved by `pan_speed * delta` (view-only use of `delta`, allowed), then the focus is clamped. `_unhandled_input`: wheel up/down steps the zoom index. Pure static helpers so the logic is testable: `clamp_focus(p: Vector2, max_r: float) -> Vector2`, `edge_dir(mouse: Vector2, viewport: Vector2, margin: float) -> Vector2`, `step_zoom(index: int, dir: int, n: int) -> int`. Edge scroll only when the window has focus and the mouse is inside the viewport.
- Input actions in `project.godot` `[input]`: `cam_pan_up/down/left/right` (W/A/S/D and arrows), `cam_zoom_in/out` (wheel up/down). This is the input mapping layer; the camera is view state, not a sim command, so nothing goes in `input/` code yet.
- `view/game_view.gd` (`extends Node3D`, root of `view/main.tscn`): creates `SimWorld.new(RUN_SEED)` (a const placeholder seed until `StartRun` exists in M2) and a `SimDriver`, calls `driver.advance(delta)` in `_process`. It spawns nothing: 007 adds the demo horde and its rendering. No game rule here.
- `view/main.tscn` (rewritten as text): `Main` (Node3D, game_view.gd) > `CameraRig` (Node3D, iso_camera.gd) > `Camera3D`; `Ground` (MeshInstance3D, PlaneMesh about 2 x (bounds_radius + bounds_margin) + some extra wide, unshaded StandardMaterial3D); `Guardian` (MeshInstance3D, a small CylinderMesh at (0, 0), unshaded, distinct colour). Unshaded materials, so no light is needed. No binary assets.
- `project.godot`: keep `run/main_scene="res://view/main.tscn"` (so `scripts\run.ps1` opens this scene); set the base resolution from D-039 (`display/window/size/viewport_width=2560`, `viewport_height=1440`, `stretch/mode="canvas_items"`, `stretch/aspect="expand"`).

Files:
1. `game/view/sim_driver.gd` (view, new).
2. `game/view/iso_camera.gd` (view, new).
3. `game/view/game_view.gd` (view, new).
4. `game/view/main.tscn` (view, rewrite).
5. `game/project.godot` (config, change): input actions, base resolution.
6. `game/data/camera/camera_default.json` (data, new) and `tools/schemas/camera.schema.json` (tools, new). The export filter `data/*.json` already ships it; check the exported build still lists it if `scripts\export.ps1` is cheap to run, otherwise state it in the PR.
7. Docs: `02_TECH_ARCHITECTURE.md` section 2 (camera values in `data/camera`, rig + orthographic camera, angle open until CP-M1) and 3a (view driver: accumulator, max 5 steps per frame, interpolation between previous and current tick, the swap-remove caveat). `CLAUDE.md` Commands: "Run game: `scripts\run.ps1`". D-086 (PROPOSED) in `DECISIONS.md`: camera tunables in `data/camera/*.json`, placeholder pitch 30 / yaw 45 until CP-M1, fixed-step driver drops time beyond 5 steps per frame.

Tests (headless, GUT), new folder `game/tests/view/`:
- `test_sim_driver.gd`: `advance(0.05)` runs 1 step and leaves alpha 0.5, `advance(0.11)` runs 3 steps (avoid exact multiples of SIM_DT, they are float-boundary cases); `advance(10.0)` runs at most 5 steps; interpolation with one enemy moving from x=10: at alpha 0 equals prev, after a further half tick equals the midpoint of prev and current; an enemy added after the last step returns its current position.
- `test_iso_camera.gd`: the camera JSON loads with exactly 3 zoom sizes and a default index in range (read values from the file, do not hard-code them); `clamp_focus` keeps a point inside `bounds_radius + bounds_margin` and leaves inner points unchanged; `step_zoom` clamps at 0 and 2; `edge_dir` gives (-1, 0) at the left edge, (0, 0) in the middle, a diagonal in a corner.
- `tools/tests`: the validator accepts `camera_default.json` and rejects a copy with 2 zoom sizes (add to the existing Python test file if it already has a fixture pattern for this).

Performance notes: the driver copies two packed arrays per tick (30 times a second, 12 KB each at 3000 enemies), no per-frame allocation. The camera does constant work per frame. 007 must read positions through the driver in bulk, not one call per enemy if that shows in the profile.

Order: data + schema + validator test, sim_driver + tests, iso_camera + tests, game_view + main.tscn + project.godot, launch with `scripts\run.ps1` once to check the scene opens and the controls work (state in the PR what was checked by hand), docs, `scripts\test.ps1` twice, `scripts\validate.ps1`.
Size: about 250 lines of code and tests plus the scene and data; one PR.

Note for the owner (CP-M1): the camera angle, zoom sizes and pan speed are placeholders in `game/data/camera/camera_default.json`; edit and relaunch to judge them.

## Questions

## Review log
- 2026-10-08 lead-dev: approved, squash-merged PR #10 into m1/dev. Tests 44/44 + Python green, validator OK. `scripts\export.ps1` run on the PR branch: `camera_default.json` is in the pack, `WTD.exe --quit-after 120` exits 0 with no errors. Driver `duplicate()` per tick is correct (packed arrays are shared on assignment); pan basis, clamp and zoom logic checked by reading. Controls not tried by hand: part of CP-M1 (owner). Nit for later, not blocking: schema allows `pitch_deg` 90, where `look_at` with the default up vector fails; use `exclusiveMaximum` if anyone edits the schema.
