# 011 — Data: M2 content definitions and schemas
- Status: review
- Milestone: M2
- Depends on: -
- PR: #16

## Goal
Define all M2 content as data with schemas, so later tasks only read it: enemies, towers, Guardian, run timeline and economy.

## Context
- `01_GAME_DESIGN.md` 3, 4, 6, 8
- D-042 (build radius ~20, cost grows per copy), D-043 (tower HP, husks), D-044 (Guardian skills), D-045 (3 tower types), D-047 (boss at 15:00), D-093 (60 s waves), D-095 (swarmer, brute, ranged + bosses), D-097 (mini-bosses 5:00 and 10:00)
- `02_TECH_ARCHITECTURE.md` 3b, 5 (data + JSON Schema, localisation keys, schema_version)

## Acceptance criteria
- Enemy files for swarmer, brute, ranged, 2 mini-bosses and the final boss: hp, speed, radius, contact damage, attack range and cooldown (ranged), gold drop, separation strength, name as a localisation key.
- Tower files for the 3 M2 types (ranged single target, splash, slow): cost, cost growth per extra copy, hp, range, damage, cooldown, splash radius, slow amount and duration, sell refund fraction, husk rebuild fraction.
- Guardian file: hp, contact radius, the 2 skills (Area blast ~12 s cooldown, Shield ~25 s cooldown) with their numbers.
- Run file: wave length 60 s, break 15-20 s, spawn curve per wave (counts and enemy mix), mini-boss times 5:00 and 10:00, final boss 15:00, starting gold, build radius, placement grid step.
- Every number is a placeholder and says so; sim catalogs load them; the validator checks them (schemas, references between files).
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Order with 012: 011 first, 012 after (both append to `DECISIONS.md` and `02_TECH_ARCHITECTURE.md` 3a, and 012's StartRun loads the `RunData` defined here). 011 does not touch `sim_world.gd` or `enemy_separation.gd`. Decision ID: **D-099** (012 uses D-100).

Every value below is a placeholder: each new data file has `"placeholder": true` (required boolean in every new schema and in enemies v3) and each schema `description` says the numbers are placeholders. Content files only; no code constant holds a game number.

### Data (`data/`, excluded from the line budget)
1. `game/data/enemies/` (schema `enemies.schema.json` bumped to `schema_version` 3; update `enemy_swarmer_01.json`):
   - add `placeholder` (bool), `name_key` (string, pattern `^[a-z0-9_.]+$`, e.g. `enemy.swarmer.name`), `attack_range` (number >= 0; 0 = melee, attacks at contact), `attack_cooldown_sec` (number > 0);
   - rename `contact_damage` to `damage` (damage per hit, melee or ranged: one name for both);
   - `archetype` becomes an enum: `swarmer`, `brute`, `ranged`, `miniboss`, `boss`;
   - `drops[].type` becomes the enum `["gold"]` (gold counts on death, D-094; `chance` stays).
   - Files: `enemy_swarmer_01` (radius 0.35), `enemy_brute_01` (slow, high hp, radius 0.4), `enemy_ranged_01` (radius 0.35, attack_range about 6), `enemy_miniboss_01`, `enemy_miniboss_02` (radius 0.8), `enemy_boss_01` (radius 1.0). Keep horde radii <= 0.4 (see Performance).
2. `game/data/towers/` (new schema `towers.schema.json`, v1): `id` (`^tower_`), `placeholder`, `name_key`, `attack` (enum `single`, `splash`, `slow`), `cost` (int), `cost_per_copy` (int: gold added per copy of this type already on the field; linear growth, D-099), `hp`, `radius` (footprint used for blocking in 015), `range`, `damage`, `cooldown_sec`, `sell_refund` (0..1), `rebuild_fraction` (0..1), `husk_blocks` (bool, 015 reads it), `sprite`, `tags`. With `if/then` on `attack`: `splash` requires `splash_radius` > 0; `slow` requires `slow_factor` (speed multiplier, 0 < f < 1) and `slow_sec` > 0. Files: `tower_single_01`, `tower_splash_01`, `tower_slow_01` (generic ids: the roster waifus map onto them later; PlaceTower uses this id).
3. `game/data/skills/` (new schema `skills.schema.json`, v1): `id` (`^skill_`), `placeholder`, `name_key`, `kind` (enum `area_blast`, `shield`), `cooldown_sec`; `if/then`: `area_blast` requires `radius`, `damage` (disk around the Guardian); `shield` requires `absorb` (damage absorbed) and `duration_sec`. Files: `skill_area_blast` (cooldown 12), `skill_shield` (cooldown 25).
4. `game/data/guardians/` (new schema `guardians.schema.json`, v1): `id` (`^guardian_`), `placeholder`, `name_key`, `hp`, `contact_radius`, `skills` (array of skill ids, 1-4 items, unique), `sprite`. File: `guardian_placeholder_01` with the 2 skills.
5. `game/data/runs/` (new schema `runs.schema.json`, v1): `id` (`^run_`), `placeholder`, `guardian`, `towers` (array of tower ids offered in the build menu), `starting_gold` (int), `build_radius` (20), `grid_step` (placement grid, e.g. 0.5), `spawn_ring_min` / `spawn_ring_max` (spawn ring, must stay outside the camera bounds; 013 tests it against `data/camera`), `first_wave_sec` (0), `wave_sec` (60), `break_sec` (15), `waves` (array, each `{count: int, mix: [{enemy: id, weight: number > 0}]}`; an array, not an object, so the order is fixed; the last entry repeats once the list runs out, which is how the horde keeps coming after 15:00, D-096), `bosses` (array of `{at_sec, enemy}`: 300 `enemy_miniboss_01`, 600 `enemy_miniboss_02`), `final_boss` (`{at_sec: 900, enemy: enemy_boss_01}`). File: `run_m2` with 13 wave entries (60 + 15 = 75 s per cycle, so 12 cycles fill 15:00 and bosses land on wave starts).

### Validator (`tools/`)
6. `tools/validate_data.py`: after the schema pass, a reference check: every string value anywhere in a document (nested included) that matches `^(enemy|tower|skill|guardian|run)_[a-z0-9_]+$` and is not the document's own `id` must be a known id. Generic, about 15 lines; it also covers `bench_m1.enemy_type`. Plus one rule: `runs` `bosses[].enemy` / `final_boss.enemy` must have archetype `miniboss`/`boss` (about 5 lines). Replace the existing `ponytail:` note about cross-file references.
7. `tools/tests/test_validate_data.py`: dangling reference rejected (run pointing at `enemy_nope`), boss reference to a non-boss enemy rejected, tower `splash` without `splash_radius` rejected, skill `shield` without `absorb` rejected, enemy v2 file rejected. The existing `test_repo_data_is_valid` covers all new files.

### Sim catalogs (`sim/`)
8. `game/sim/data_files.gd` (new, `class_name DataFiles`): `static func read_dir(path) -> Array[Dictionary]` (the loop now in `EnemyCatalog.load_dir`: every `.json`, parse, error + assert on bad JSON, sorted by `id`) and `static func read_id(path, id) -> Dictionary`. `static func ticks(sec: float) -> int` = `roundi(sec * SimWorld.TICK_RATE)`: every `_sec` value becomes integer ticks at load, so the sim never accumulates float time.
9. `game/sim/enemy_catalog.gd`: use `DataFiles.read_dir`; add packed arrays `damage`, `attack_range`, `attack_cooldown` (ticks, `PackedInt32Array`), `gold` (amount) and `gold_chance`, `is_boss` (`PackedByteArray`, archetype `miniboss` or `boss`), `name_key` (`PackedStringArray`). **`max_radius` = largest radius over non-boss types** (see Performance); document it on the field.
10. `game/sim/tower_catalog.gd` (new, `class_name TowerCatalog`): same pattern as `EnemyCatalog` (`load_dir("res://data/towers")`, sorted by id, `type_of(id)`); packed arrays per field; `attack` as an int enum `Attack { SINGLE, SPLASH, SLOW }`; `cooldown` and `slow_ticks` in ticks; `splash_radius` 0 and `slow_factor` 1 when absent.
11. `game/sim/run_data.gd` (new, `class_name RunData`): `static func load_id(run_id: String, enemies: EnemyCatalog, towers: TowerCatalog) -> RunData` reads `data/runs/<id>.json`, its guardian and the guardian's skills, and resolves every id to a catalog index (`push_error` + assert on an unknown id). Fields: `starting_gold`, `build_radius`, `grid_step`, `spawn_ring_min/max`, `first_wave_tick`, `wave_ticks`, `break_ticks`, `wave_count: PackedInt32Array`, `wave_mix_types: Array[PackedInt32Array]`, `wave_mix_weights: Array[PackedFloat32Array]`, `boss_ticks` / `boss_types` (`PackedInt32Array`, final boss not included), `final_boss_tick`, `final_boss_type`, `tower_types: PackedInt32Array`; Guardian: `guardian_hp`, `guardian_contact_radius`; skills as arrays indexed by skill slot: `skill_ids: PackedStringArray`, `skill_kind` (enum `Skill { AREA_BLAST, SHIELD }`), `skill_cooldown` (ticks), `skill_radius`, `skill_damage`, `skill_absorb`, `skill_duration` (ticks). No wave/timeline logic here (013); it is a typed, resolved view of the file. Guardian and skills live in `RunData` rather than their own classes: one Guardian per run, a few fields.

### Tests (`tests/`, GUT)
12. `game/tests/sim/test_tower_catalog.gd`: values match the JSON for every file, sorted ids, `type_of` unknown = -1, seconds converted to ticks, defaults for absent splash/slow fields.
13. `game/tests/sim/test_run_data.gd`: `run_m2` loads; `wave_ticks == 1800`, `final_boss_tick == 27000`, boss ticks 9000 and 18000; every mix type resolves (>= 0) and the final boss type `is_boss`; Guardian has 2 skills with cooldowns 360 and 750 ticks (computed from the JSON, not hard-coded numbers: the test reads the file and converts).
14. `game/tests/sim/test_enemy_catalog.gd`: new fields match the JSON; `max_radius` equals the max over non-boss types; boss types flagged.
15. **Fix tests that assume `type_id` 0 is the swarmer**: the catalog is sorted by id, so `enemy_boss_01` becomes type 0. In `test_determinism`, `test_enemy_separation`, `test_sim_enemies`, `test_sim_towers`, `test_sim_world`, `test_spatial_grid` use `catalog.type_of("enemy_swarmer_01")` (a `const SWARMER := "enemy_swarmer_01"` per file is enough). `test_spatial_grid` line 134 asserts `cell_size == 4 * max_radius`. The bench and `game_view.gd` already use `type_of`.

### Performance
- The grid cell is `4 * catalog.max_radius` and separation scans `ri + max_radius` (3a). A boss radius in that max would grow the cell from 1.4 to 4.0 (8x cell area) and slow separation, already 60-79% of a tick. So `max_radius` covers horde types only; bosses cannot spawn before 013, and **013 adds the boss separation pass** (a note is added to 013's Context). Brute radius 0.4 grows the cell 1.4 -> 1.6 (about 1.3x cell area); report the `test_determinism` timing before/after in the PR; 023 re-benches.
- Catalog loading is once per world; no per-tick cost.
- `horde_renderer.gd` makes one MultiMesh per enemy type: now 6. No change needed.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md`: 3b example updated to enemies v3 (`damage`, `attack_range`, `attack_cooldown_sec`, `name_key`, `placeholder`); a short "M2 data files" list (folders, what each holds, ids resolved to indices at load, seconds to ticks, `max_radius` over horde types); 5: the validator now checks references between files.
- `01_GAME_DESIGN.md` 4 "Build radius and costs": "cost grows linearly per copy (`cost + cost_per_copy * copies`, placeholder, D-099)".
- `DECISIONS.md`: **D-099 PROPOSED**: M2 data layout (enemies v3 with `damage`/`attack_range`/`attack_cooldown_sec`, towers/skills/guardians/runs folders, `placeholder` flag); tower cost grows linearly per copy; run timeline = first wave at `first_wave_sec`, then `wave_sec` waves separated by `break_sec`, the last wave entry repeats after the list ends (D-096); boss times are data; seconds converted to integer ticks at load; grid cell size from horde (non-boss) radii. The owner should confirm the linear cost growth and the "last wave repeats" rule at CP-M2.

### Order
1. Schemas + data files, validator + Python tests (`scripts\validate.ps1` green).
2. `DataFiles`, `EnemyCatalog` changes, fix the type-0 tests.
3. `TowerCatalog`, `RunData` + GUT tests.
4. Docs, D-099. `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 300 lines of GDScript/Python code and 150 of tests (schemas and data excluded). One PR.

## Questions

## Review log
