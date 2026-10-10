# 040 — View: placeholder feedback for M3 towers, skills and relationships
- Status: planned
- Milestone: M3
- Depends on: 032, 034
- Labels: needs-human:art
- PR:

## Goal
The playtest can read what happens: tower looks per kind, active relationships, aura and repair, marks, thorns and the 6 signature skills, all with placeholder art.

## Context
- D-120 (looks from `data/render`, `FxPool` from sim events, no Node per enemy or effect), `docs/02_TECH_ARCHITECTURE.md` 2.
- Events and state from 031-034: `TOWER_REPAIRED`, thorns as `ENEMY_HIT`, `SKILL_USED`, `guard_until`, `bounty_until`, `haste_until`, the mark arrays.

## Acceptance criteria
- Distinct placeholder looks per kind (wall, aura, repair, mark, slow_area) in render data; a marker on towers with an active relationship; aura radius ring; repair beam; marked enemies tinted; one effect per signature skill (ring, tint or disc from state); all cosmetic.
- No per-enemy Node; `scripts\bench.ps1` shows no view fill regression.
- Headless tests for the new `FxPool` mappings.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan
Lead-dev, 2026-10-10. Decision **D-163** (PROPOSED, reserved here): the M3 placeholder feedback mappings below. View only, plus one sim event payload change (step 1). About 250 changed lines of code, data excluded: one PR.

What exists (D-120): `tower_looks` already lists the 5 new kinds, but they reuse the `single`, `slow` and `bare` shapes; `FxPool` maps the M2 events; `FxLayer` draws discs (MultiMesh), ribbons and the blast ring (ImmediateMesh) and the Shield disc; `HordeBatcher` writes 4 custom floats per instance (r frame, g flip, b flash, a unused).

### Mappings (D-163)
| What | Source (read-only) | Effect |
|---|---|---|
| Tower look per kind | `tower_looks` | 5 new placeholder shapes in `PlaceholderArt.tower_image`: `wall` (wide low block), `aura` (orb with a halo), `repair` (body + cross), `mark` (body + target dot), `slow_area` (wide body + 2 orbs) |
| Relationship marker | live built tower with `towers.syn_mask[t] != 0` | small heart-colour disc above the tower (state, every frame) |
| Aura radius ring | live tower of kind AURA, radius `towers.reach[t]` | thin static ring centred on the tower (state) |
| Repair beam | `TOWER_REPAIRED` event | ribbon from the repairer to the healed tower (uid lookup, skipped if gone) or to the Guardian (a = -1) |
| Marked enemy | `enemies.mark_until[i] > world.clock` | enemy sprite tinted (custom `a` = 1, the shader mixes a `tint` colour) |
| Thorns | `ENEMY_HIT` | nothing new: the existing hit flash shows it (an effect per hit is too many, as D-120) |
| Big Finish / Area blast (`area_blast`) | `SKILL_USED` | existing growing ring to `skill_radius` |
| Tangle (`snare`) | `SKILL_USED` | growing ring to `skill_radius`, snare colour |
| Emergency Rebuild (`rebuild`) | `SKILL_USED` | growing ring to `fx.rebuild_radius`, rebuild colour |
| Stand Firm (`guard`) | `world.clock < skills.guard_until` | translucent disc at the Guardian, like the Shield disc (`guard_radius`, `guard_color`) |
| Clearance Sale (`bounty`) | `world.clock < skills.bounty_until` | static gold ring at the Guardian (`bounty_radius`) |
| Crescendo (`haste`) | `world.clock < skills.haste_until` | every tower sprite tinted (custom `a` = 1 on the tower batches, haste tint) |

### Steps and files
1. `game/sim/tower_attacks.gd` (**sim**, event payload only): in `repair()`, both `TOWER_REPAIRED` pushes carry x, z = the **repairer's** position (`towers.pos_x[t]`, `towers.pos_z[t]`) instead of the healed tower's (the healed one is found by its uid, the Guardian stands at the origin). No rule or state change; `state_hash` unaffected. Update the payload row in `docs/02_TECH_ARCHITECTURE.md` 3a (events table) and the event line in `docs/10_M3_CONTENT.md` 8. Add one assert in `game/tests/sim/test_aura_repair.gd` that the event's x, z are the repairer's position.
2. `game/data/render/render_default.json` + `tools/schemas/render.schema.json` (**data**): `schema_version` 3; the `tower_look.shape` enum gains `wall`, `aura`, `repair`, `mark`, `slow_area`, and the 5 kind looks use them (their colours already differ). `fx` gains, all required, placeholders: `link_color`, `link_size`, `link_height`, `aura_color`, `aura_width`, `beam_sec`, `beam_width`, `beam_color`, `snare_color`, `rebuild_color`, `rebuild_radius`, `guard_radius`, `guard_color` (rgba), `bounty_radius`, `bounty_width`, `bounty_color`, `mark_tint` and `haste_tint` (rgba: rgb colour, a = mix amount). Run `scripts\validate.ps1`.
3. `game/view/placeholder_art.gd` (**view**): the 5 shapes (match arms reusing `fill_rect` and `_disc`). `game/tests/view/test_placeholder_art.gd`: extend `test_shapes_are_visible_and_differ` to every tower shape of the enum.
4. `game/view/billboard.gdshader`, `game/view/horde_batcher.gd`, `game/view/horde_renderer.gd` (**view**): custom `a` = tint flag; the shader gets `uniform vec4 tint` and `ALBEDO = mix(mix(c.rgb, tint.rgb, v_tint * tint.a), vec3(1.0), v_flash)` (header comment updated). `HordeBatcher.fill` gains optional `mark_until: PackedInt32Array` + `clock: int` (enemies: `buf[k + 15] = 1.0 if mark_until[i] > clock else 0.0`) and `tint_all: bool` (towers: 1.0 on every instance while true). `HordeRenderer` sets the `tint` uniform per material (enemy batches `mark_tint`, tower batches `haste_tint`), passes `e.mark_until, world.clock` to the enemy fill and `world.run != null and world.clock < world.skills.haste_until` to the tower fill. `game/tests/view/test_horde_batcher.gd`: one test for the mark flag (marked, expired, never marked), one for `tint_all`.
5. `game/view/fx_pool.gd` (**view**): new `Kind.BEAM` (a ribbon like SHOT, beam colour and life); `read_events` maps `TOWER_REPAIRED` (beam from (x, z) to the healed tower or the origin) and the `SKILL_USED` kinds `SNARE` and `REBUILD` to `RING` with their own colour and radius. State overlays: a second small SoA (`ov_kind` LINK disc or RING, `ov_x`, `ov_z`, `ov_r`, `ov_color`) rebuilt by a new `read_state(world)` each frame (cleared first, its own cap, not `max_effects`), from one pass over the towers (link markers, aura rings) plus the bounty ring; empty while `world.run == null`. If `fx_pool.gd` grows past about 200 lines, put the overlays in `game/view/fx_overlays.gd` (RefCounted, same tests).
6. `game/view/fx_layer.gd` (**view**): call `pool.read_state(_world)` in `_process`; draw `BEAM` with `_ribbon`; generalise `_ring(r, width)` to `_ring(cx, cz, r, width)`; draw the overlay rings in the same ImmediateMesh surface and the link discs in the disc MultiMesh (`instance_count` = `max_effects` + the overlay cap, extras dropped); a `_guard` MeshInstance3D like `_shield`, visible while `clock < guard_until`.
7. Tests in `game/tests/view/test_fx_pool.gd` (headless, at least one per mapping): a repair event gives one BEAM from the repairer to the healed tower, and to the origin for a = -1; a beam to a sold tower is skipped; Tangle and Emergency Rebuild casts give a RING with their radius and colour (worlds started with `guardian_tansy` and `guardian_poppy`, D-146); `read_state`: a linked tower gives one LINK, an unlinked one none, a husk none; an aura tower gives one RING of radius `reach`; bounty active gives the ring, expired none; two calls rebuild the overlays, never accumulate. `game/tests/view/test_render_config.gd`: the 5 new kinds have pairwise distinct shapes.
8. Bench: `scripts\bench.ps1`; compare the view fill ms per frame of the combat and maze scenarios with `reports/perf_m2.md` (within noise) and paste the numbers in the PR. New per-frame work: one array read per visible enemy, one flag per tower, one overlay pass over the towers (a few hundred at most); no per-enemy loop in `FxLayer`.
9. Docs: `docs/02_TECH_ARCHITECTURE.md` 2 (looks: new shapes; FX layer: BEAM, snare and rebuild rings, overlays, guard disc, the tint channel in the custom-data line), 3a events table (step 1); `docs/DECISIONS.md` D-163 PROPOSED; `docs/plans/M3.md` row. Capture one frame with the overlays from the game's own viewport (scratchpad, never committed) for the owner's art check (`needs-human:art`).

Order: 1, 2, 3, 4, 5 with 7 (pool tests first), 6, 8, 9. Headless tests green twice, validator green.

Not touched here: the stray mid-line tabs in `game/sim/tower_links.gd` (~147) and `game/sim/tower_stats.gd` (~93) from the 032 review; 040 does not edit those files, so they are noted for 041.

## Questions
- None blocking. Shapes and colours are placeholders for the owner's art review (`needs-human:art`). Thorns get no new effect (the hit flash covers it, D-163); say so if a distinct thorns spark is wanted.

## Review log
