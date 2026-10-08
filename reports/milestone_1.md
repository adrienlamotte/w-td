# M1 review pack: Horde and performance spike

For the owner, at checkpoint CP-M1. Branch `m1/dev`, PR to `main` linked in the session.

## What was built
- **Simulation (no rendering, deterministic, 30 Hz):** enemies as packed arrays that chase the Guardian, a spatial grid for neighbour queries, soft separation so the horde spreads into a crowd (D-079), and placeholder towers that pick their nearest enemy every tick (no attacks yet).
- **View:** an orthographic isometric camera over a flat ground, the horde and towers drawn as billboard sprites through MultiMesh (no node per enemy), placeholder art generated at runtime.
- **Demo horde:** 1500 placeholder enemies walk in from rings and are recycled when they reach the Guardian, so the screen never empties. 12 placeholder towers.
- **Benchmark:** `scripts\bench.ps1` runs 6 fixed scenarios in the release build and writes `reports/perf_<date>.json`.
- **Test runner fix:** a broken test file now fails the test run (it used to be silently skipped).

## Result in one paragraph
On your PC (i7-13700K, RTX 5070 Ti, 2560x1440) the typical and stress cases pass the budgets: 1%-low around 110-125 FPS, sim step 5.7-6.6 ms per tick against 8 ms. The only miss is everyone piled on the Guardian (8.6 ms, 8% over), a case partly caused by M1 placeholders. Drawing costs under 1 ms per frame; the time is in the simulation, mostly separation. The Steam Deck numbers are an **estimate** (no Deck, D-080), but stay above 40 FPS in every case. Recommendation: **keep the 3D billboard view** (D-089), no native-code rewrite now. Full details: `reports/perf_m1.md`.

## How to run it
1. `git fetch` then `git switch m1/dev` (or check out the PR branch).
2. `scripts\run.ps1` opens the game on the demo horde.
3. Controls (D-041, PC only in M1): **WASD or arrow keys** to pan, **move the mouse to a screen edge** to scroll, **mouse wheel** to switch between the 3 zoom levels. The camera stops at the build radius plus a margin.
4. Optional: `scripts\bench.ps1` reruns the benchmark (about 3 minutes, keep the window focused and the PC idle).

## What to look at
- **Feel and readability of the horde:** does it read as a crowd swarming the Guardian? Is it too dense, too sparse, too regular?
- **Camera:** angle (placeholder: pitch 30°, yaw 45°), the 3 zoom levels, pan speed, edge scroll, the bounds.
- **Crowding:** how much enemies overlap. The push strength is a placeholder.
- Everything you see is placeholder art and numbers; judge movement, density and camera, not looks.

## Values you can try yourself (edit, save, relaunch `scripts\run.ps1`)
| What | File | Field |
|---|---|---|
| Camera angle, distance, zoom sizes, pan speed, edge scroll, bounds | `game/data/camera/camera_default.json` | `pitch_deg`, `yaw_deg`, `distance`, `zoom_sizes`, `pan_speed`, `edge_scroll_px`, `bounds_margin` |
| Enemy push strength (0.5 now; about 1.0 overlaps less) | `game/data/enemies/enemy_swarmer_01.json` | `separation_strength` |
| Sprite sizes, walk animation speed | `game/data/render/render_default.json` | |

Run `scripts\validate.ps1` after editing to check the values.

## Questions for you
1. Do you accept M1 (merge `m1/dev` into `main`)?
2. Horde feel and camera: fine for now, or what should change?
3. Enemy push strength: keep 0.5, use about 1.0, or decide during M2 balancing?
4. Do you confirm the proposed decisions D-081 to D-089, including the GO for 3D billboards (D-089)?

## Known limits (by design in M1)
- No damage, deaths, waves, Guardian HP, gold or UI: that is M2.
- Gamepad camera controls: M2.
- A real Steam Deck run is still needed (by M6).
- When enemies start dying (M2), a removed enemy's slot can jump on screen for one frame; the fix comes with enemy death.
