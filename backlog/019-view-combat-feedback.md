# 019 — View: combat feedback and enemy/tower visuals
- Status: review
- Milestone: M2
- Depends on: 016, 017
- PR: #25

## Goal
Make combat readable: hits, deaths, shots, coins, skills, husks, and distinct placeholder looks per enemy and tower type.

## Context
- D-098 (shot effect is visual only), D-094 (coins fly to the Guardian), D-087 (MultiMesh rendering)
- M1 known gap: a removed enemy's slot can jump for one frame (fix it here)
- From 012's plan: `world.events` (SimEvents, SoA) is cleared at the start of every `step()`; the driver runs up to 5 steps per frame, so read events after each step.
- From 016/026 plans: tower shots come as `TOWER_FIRED` (a = tower uid, x, z = target position, value = tower type); enemy hits on towers as `TOWER_HIT` (a = tower uid, x, z = attacker position, value = damage); Guardian hits as `GUARDIAN_HIT` (source position). Tower `hp`/`husk` and enemy `slow_ticks` are readable arrays.

## Acceptance criteria
- Placeholder visuals distinct per enemy type; bosses visibly bigger; tower types distinct; husks visible.
- Hit flash, death effect, shot lines, coin flight, blast ring and shield effects, all driven by sim events; no Node per enemy.
- The removal jump is fixed.
- Benchmark still runs.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-120**. Mostly `view/`; three presentation-only fields in `sim/` (no rule reads them, not in `state_hash()`). Independent of 018, 024 and 026: `TOWER_HIT` is handled only if 026 has added it (`SimEvents.Kind.get("TOWER_HIT", -1)`, never a parse-time reference). If 018 lands first, its `PlayerInput` wiring in `game_view.gd` stays; small rebase only.

### Rules (D-120 PROPOSED, view behaviour; no game rule)
- **Removal jump fix (M1 gap):** interpolation data moves into `SimEnemies` so it follows every swap-remove: `prev_x, prev_z` (positions at the start of the tick, copied by `step()` before COMMANDS; `add()` sets them to the spawn position) and `hit_tick` (tick of the last `damage_enemy`, a large negative value at add). They go through `remove()` like every array, so slot `i` always interpolates from its own enemy. `SimDriver` drops its own `prev_x/prev_z` copies and reads `world.enemies.prev_*`. `HordeBatcher.SNAP_DIST_SQ` stays (demo recycle jumps).
- **Corpses hidden:** the batcher skips `hp <= 0` (the enemy stays in the arrays until DEATHS).
- **Looks from data:** enemies by `archetype` (swarmer, brute, ranged, miniboss, boss): shape, colour, height scale (bosses visibly bigger). Towers by attack kind (single, splash, slow) plus `husk` (grey, lower) and `bare` (M1 bench towers). One enemy batch per type as now; towers become one batch per tower type + husk + bare.
- **Hit flash:** an enemy flashes white while `world.tick - hit_tick <= flash_ticks` (`flash_ticks = ceil(flash_sec / SIM_DT)`; custom data `b`, the shader mixes to white). The Guardian flashes on `GUARDIAN_HIT` (albedo of her mesh for `flash_sec`).
- **FX from events, read after every `step()`** (driver callback; up to 5 steps per frame):
  - `ENEMY_DIED`: a puff at the position, colour and size from the type's look; if value > 0, a coin flies from there to the Guardian over `coin_sec` (D-094: gold is already counted, the coin is cosmetic).
  - `TOWER_FIRED`: a shot ribbon from the tower (`towers.uid.find(a)`, skipped if gone) to the target position for `shot_sec` (D-098, visual only), coloured by the tower look.
  - `GUARDIAN_HIT` from a type with `attack_range > 0`: a ribbon from the source to the Guardian.
  - `TOWER_HIT` (only if the kind exists): a spark at the tower.
  - `SKILL_USED` of an AREA_BLAST slot (`run.skill_kind`): a ring growing from 0 to `skill_radius` over `ring_sec`.
  - Shield: a translucent disc around the Guardian, shown while `clock < skills.shield_until and skills.shield_left > 0` (state read, no event needed).
  - `ENEMY_HIT` spawns nothing (the flash covers it; one blast can hit thousands).
- Effects are capped at `max_effects` (new ones dropped when full); lifetimes are view seconds; no Node per enemy or per effect.
- **Coordination with 020 (added at 020 planning):** if 020 has merged first, the main scene already queues StartRun and the player builds; skip this item (no scripted towers). If 019 merges first, 020 keeps the StartRun and deletes the scripted list.
- **Main scene runs a real run** (placeholder until 021's start screen): `game_view` queues `StartRun(RUN_SEED, "run_m2")` and a short scripted tower list (const array of `(tick, tower_id, x, z)`: single and slow at tick 0, splash at about 30 s once gold allows; rejected silently if not affordable). Commands only, the view writes no sim state. The M1 demo horde (`spawn_ring`, recycle, bare towers) leaves the main scene. `demo = false` (bench) skips it as today.

### Files
1. `sim` `game/sim/sim_enemies.gd`: `prev_x, prev_z, hit_tick` (add, remove). `game/sim/sim_world.gd`: copy `prev_*` at the start of `step()` (`duplicate()`, as the driver did), `hit_tick[i] = tick` in `damage_enemy` (not on a corpse). `game/sim/enemy_catalog.gd`: load `archetype: PackedStringArray`. About +15.
2. `view` `game/view/sim_driver.gd`: no own prev copies; `interp_x/z` read `world.enemies.prev_*`; `var on_step: Callable` called after each `world.step()` when valid. About -5.
3. `view` `game/view/horde_batcher.gd`: `fill()` also takes `hp`, `hit_tick` and the flash threshold tick; skips corpses, writes custom `b` = 1 when flashing. About +8.
4. `view` `game/view/billboard.gdshader`: pass `INSTANCE_CUSTOM.b`, `mix(c.rgb, vec3(1.0), flash)`. +3.
5. `view` `game/view/placeholder_art.gd`: `enemy_strip(color, frames, cell, shape)` with shapes `blob` (today's), `brute` (wide square body), `ranged` (blob + staff), `crown` (blob + crown, bosses); `tower_image(color, cell, shape)` for `single` (tall), `splash` (wide), `slow` (orb on top), `husk` (low broken block), `bare` (today's). About +40.
6. `view` `game/view/horde_renderer.gd`: looks from config by `catalog.archetype` and `tower_catalog.attack`; tower batches (per type, husk, bare) via a per-frame view batch-index array; passes `hp`/`hit_tick` to the batcher. About +25.
7. `view` (new) `game/view/fx_pool.gd`, `class_name FxPool extends RefCounted`: SoA of effects (`kind, x0, z0, x1, z1, age, life, color, size`), `read_events(world)`, `advance(delta)` (swap-remove expired), cap. Headless-testable. About 100.
8. `view` (new) `game/view/fx_layer.gd` (Node3D, child in `main.tscn`): owns an `FxPool`; one `MultiMeshInstance3D` (puffs, coins, sparks: billboard discs, alpha blended, per-instance colour and scale through `use_colors` and the basis) with new `game/view/fx.gdshader` (about 20 lines); one `MeshInstance3D` + `ImmediateMesh` rebuilt per frame (shot ribbons and the blast ring as flat quads at y = 0.5, vertex colours, unshaded); a shield mesh; the Guardian flash. About 90.
9. `view` `game/view/game_view.gd` + `main.tscn`: placeholder run instead of the M1 demo horde; `$FxLayer.setup(driver, $Guardian)`; `driver.on_step = $FxLayer.on_step`. About +10.
10. `data` `game/data/render/render_default.json` + `tools/schemas/render.schema.json` (`schema_version` 2): `enemy_looks` (required keys swarmer, brute, ranged, miniboss, boss; each `shape` enum, `color` [r, g, b] in 0..1, `height_scale`), `tower_looks` (single, splash, slow, husk, bare: `shape`, `color`, `height_scale`), `fx` (`flash_sec, death_sec, death_size, coin_sec, coin_size, shot_sec, shot_width, spark_sec, ring_sec, ring_width, max_effects, shield_color` [r, g, b, a]). All placeholders.

### Tests
- `test_sim_enemies.gd`: `remove(i)` swaps `prev_*` and `hit_tick` with the rest; `add()` sets prev = position. Combat test: `damage_enemy` sets `hit_tick`; a corpse hit does not. Existing determinism/replay tests stay green (fields not hashed).
- `test_sim_driver.gd`: two nearby enemies (closer than the snap distance), the lower index dies; after the step the survivor now in slot 0 interpolates from its own previous position (the M1 gap: fails on today's code); `on_step` is called once per step in a 3-step frame.
- `test_horde_batcher.gd`: corpses not packed; a recently hit enemy has `b = 1`, others 0.
- `test_placeholder_art.gd`: every shape gives a non-empty image; shapes differ pixel-wise.
- `test_render_config.gd`: every archetype in `data/enemies` and every attack kind in `data/towers` has a look; miniboss and boss `height_scale` > swarmer's.
- `test_fx_pool.gd` (world with StartRun `run_m2`; events made by real sim calls where cheap, else `world.events.push`): ENEMY_DIED with gold -> puff + coin, without -> puff only; a coin ends at the Guardian; TOWER_FIRED with a live uid -> one shot from the tower position to the target, unknown uid -> none; ranged GUARDIAN_HIT -> ribbon, melee -> none; blast SKILL_USED -> ring, shield -> none; ENEMY_HIT -> none; `advance` expires by `life`; the cap holds; TOWER_HIT handled only when the kind exists.

### Performance
Per tick: the two `duplicate()`s move from the driver to the sim (same cost; headless balance runs pay them too, microseconds at 3000), one int store per hit. Per frame: one extra compare per enemy in the batcher; FX `advance` + upload O(live effects) <= `max_effects`; the ribbon mesh is rebuilt from live shots only. Events read once per step, O(events). Bench scenarios are IDLE with bare towers (no events): run `scripts\bench.ps1` once and report `fill_ms` against `reports/perf_m1.md` to show no regression.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 2 (looks from data, corpses hidden, flash, FX layer and its cap) and 3a (View driver: `prev_*` and `hit_tick` live in `SimEnemies`, the swap-remove gap is fixed, `on_step`; Entity arrays: the presentation fields, not hashed; the "view hides corpses (019)" note becomes as-built).
- `DECISIONS.md`: **D-120 PROPOSED** (the rules above, including the scripted placeholder run in the main scene until 021).
- Visual feel is needs-human:art at CP-M2 (placeholders).

### Order
1. Sim fields + driver + batcher (removal fix, corpses, flash), tests. 2. Looks: data, schema, art shapes, renderer batches, tests. 3. FxPool, tests. 4. FxLayer, shaders, main-scene placeholder run; run the game and look at it. 5. Docs, D-120; `scripts\test.ps1` twice, `scripts\validate.ps1`, `scripts\bench.ps1` once.

Size: about 330 lines of code (+ about 60 lines of data/schema), about 200 of tests. One PR; if it passes 400 code lines, move the FX (items 7-8) to a follow-up task file and say so in the PR.

## Questions

## Review log
