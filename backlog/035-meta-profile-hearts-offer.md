# 035 — Meta: profile, hearts, meta tree, Guardian offer and win-unlock
- Status: review
- Milestone: M3
- Depends on: 033, 034, 045
- PR: #46

## Goal
A persistent meta profile: hearts earned per run, the 12-node meta tree, the Guardian offer of 3 locked waifus, and the rescued Guardian unlocked as a tower on a win. The run gets everything from the profile through `START_RUN`, so a run stays a pure function of `(seed, start data, commands)`.

## Context
- `docs/10_M3_CONTENT.md` 6.1 (hearts: win 100, loss formula, abandon = loss at the time reached, added at run end only), 6.2 (tree, `requires`, effects applied at StartRun), 7 (profile `user://profile.json`, atomic write, `schema_version` with one migration step per version, `profile.bad.json`, offer derived not stored, bond kept at 0), 2.1 (rescued Guardians become new-tower cards; starters buildable from the start).
- D-023 (win unlocks the Guardian as a tower), D-048 (loss hearts), D-050 (3 locked waifus, fixed until one is rescued), D-052, D-053, D-131 (higher tiers after all 6 rescues: M3 stores only the unlock state), `docs/07_ROSTER.md` 3 (offer order).
- Q-68 (offer once all 6 are rescued): safe to assume ★ A.

## Acceptance criteria
- Pure rules (no file access): the offer from `unlocked` + `offer_order`; hearts from the end state; buying a node (cost, `requires`, enough hearts); the `START_RUN` config (Guardian, starter towers, unlocked waifus, meta effects as modifiers, grid sized for the largest radius).
- Profile file I/O outside `sim/`: atomic write (temp + rename), load with the migration chain, an unreadable file kept as `profile.bad.json` and a fresh profile used.
- Run end: hearts added, stats updated, the Guardian unlocked on a win; written once.
- Tests: offer at 0, 1 and 6 rescues; hearts at 0:00, 7:30, after the final boss spawned, and on a win; tree purchase rules; StartRun applies meta effects; profile round trip; migration from an older fixture; corrupt file handling.
- Headless tests green twice; data validator green; docs (`02_TECH_ARCHITECTURE.md` 7) and a PROPOSED decision in the same PR.

## Plan
Decision ID: **D-152** (PROPOSED, rules below). About 330 lines of code plus about 260 of tests and one test fixture; no game data or schema change. Pure rules in `sim/`, file I/O in a new `game/save/` folder (no Node, no scene; task 036 puts the suspend save there too), one hook in `view/game_view.gd`. **Depends on 045 too** (added above): StartRun must apply the meta effects before 045 sizes the build grid, and the `rebuild_fraction` rule below sits next to 045's `rebuild_price`.

### Rules (D-152)
1. **Profile** (`10_M3_CONTENT.md` 7): `{schema_version: 1, unlocked: [waifu ids], hearts: int, meta_nodes: [meta ids], bond: {waifu id: 0}, stats: {runs, wins, losses, best_sec: {guardian id: int}}}`. Starters are implicit (never in `unlocked`). `best_sec` = the longest run clock reached with that Guardian, in whole seconds, wins included (interpretation of "best time per Guardian", flagged in Questions). The offer is derived, never stored.
2. **Migration.** `CURRENT_VERSION = 1`. A document without `schema_version` (or 0) is the pre-release shape: step 0 -> 1 fills every missing field with its default. One step function per version, applied in order. After migration, `from_dict` checks types (arrays of strings, int hearts >= 0, dictionaries) and drops ids the data no longer has (unknown waifu or meta ids). A document that is not a Dictionary, has a wrong type, or a `schema_version` above `CURRENT_VERSION` is **unreadable**.
3. **Offer** (D-050, D-142, `07_ROSTER.md` 3): the `guardian`-status waifus sorted by `offer_order`, minus `unlocked`, first 3; fewer than 3 left = all left; none left (all 6 rescued) = all 6 in offer order (D-142, the Q-68 answer). Examples: 0 rescued -> Cinder, Bastia, Clover; Cinder rescued -> Bastia, Clover, Hymn.
4. **Hearts** (6.1, D-048), from run data: win = `hearts_win`; loss or abandon = `hearts_loss_min + (hearts_loss_max - hearts_loss_min) * mini(clock, final_boss_tick) / final_boss_tick` in integer arithmetic (equal to the doc's `floori` formula, no float error): 30 at 0:00, 40 at 7:30, 50 from the final boss spawn on, 100 on a win.
5. **Run end** (`record_run(cat, run, won, clock)`): hearts += rule 4; `runs += 1`; `wins` or `losses += 1`; `best_sec[guardian] = max(old, clock / 30)`; on a win, the waifu whose `guardian` is the run's Guardian is appended to `unlocked` if not already in it (a Guardian with no waifu, like `guardian_placeholder_01`, unlocks nothing; a rerun after all 6 rescues unlocks nothing new, D-142). Returns the hearts earned. Abandon (task 039) calls it with `won = false`.
6. **Buying a node** (6.2, D-052): `check_buy(cat, id)` -> `OK`, or in this order `UNKNOWN`, `OWNED`, `LOCKED` (a `requires` id not bought), `NO_HEARTS`; `buy(cat, id)` = check, then `hearts -= cost` and append the id. The hub (039) shows the same verdict (D-121).
7. **START_RUN config.** `start_command(cat, tick, seed, run_id, waifu_id)` returns `null` unless `waifu_id` is in the offer, else `SimCommand.start_run(tick, seed, run_id, <her guardian id>, unlocked, meta_nodes)`. Starter towers stay the run file's `towers` (`run_m3`: Pip, Mallow).
8. **StartRun applies meta** (sim): `START_RUN` gains `meta_nodes: PackedStringArray`. After `gold = starting_gold` and the modifier store reset, and **before** the build grid is created (045 sizes it from the store's `build_radius` adds plus the card maximum, so the grid fits the largest radius), every node of `MetaCatalog` in id order whose id is in `meta_nodes` applies its effects through `CardEffects.apply` (`gold` = +50 starting gold each, the rest into the store; Guardian and tower max HP follow through the existing recompute). Id order keeps the store order, and so the float sums, independent of the profile's order. With `meta_radius` the `run_m2` grid is `2 * ceili((20 + 2 + 6 + 2) / 0.5)` = 120 cells per side.
9. **The three meta-only stats** (D-140) in `TowerBuilding`, read from the store at the call (`modifiers.sums(stat, tower id)`, a few dozen entries at most, nothing cached so nothing to invalidate): placement `price` = `floori((cost + cost_per_copy * copies) * (1 + mult))` (a discount never rounds up: 50 -> 47); sell refund = `floori(paid * clampf(sell_refund + add, 0, 1))`; rebuild price = `maxi(0, floori(paid * maxf(0, rebuild_fraction + add) * (1 + rebuild_price mult)))` (045's mult on top). The build UI already reads these functions (D-121).
10. **Profile file** (`user://profile.json`, 7): save = write `profile.json.tmp`, then rename it over `profile.json` (if the rename fails because the target exists, remove the target and rename again). Load: no file -> `profile.json.tmp` if present (a crash between the two steps) -> else a fresh profile; unreadable (rule 2 or a JSON parse error) -> the file is renamed to `profile.bad.json` (replacing an older bad file), a fresh profile is used and `ProfileStore.last_error` says why (for the notice of Q-73, task 039). Written at run end (once) and after every purchase (039).

### Files
1. `sim` `game/sim/meta_catalog.gd` (new, ~45): loads `data/meta` (ids sorted; `cost`, `requires`, `effects`) and `data/waifus` (`guardian`-status ids sorted by `offer_order`, waifu -> guardian id, all waifu ids). Load time only.
2. `sim` `game/sim/meta_profile.gd` (new, ~150): `MetaProfile` fields (rule 1), `from_dict(d, cat)` with the migration chain (rule 2, returns null when unreadable), `to_dict()`, `offer(cat)`, `static hearts_for(run, won, clock)`, `record_run`, `check_buy` / `buy`, `start_command`. No file access.
3. `sim` `game/sim/sim_command.gd` (+4): `meta_nodes`, `start_run(..., p_meta_nodes := PackedStringArray())`.
4. `sim` `game/sim/sim_world.gd` (+12): rule 8 in StartRun (catalog loaded at the first StartRun that has nodes), ordered before 045's grid creation. `state_hash()` unchanged (store and gold are hashed).
5. `sim` `game/sim/run_data.gd` (+5): `guardian_id`, `hearts_win`, `hearts_loss_min`, `hearts_loss_max`.
6. `sim` `game/sim/tower_building.gd` (~8): rule 9.
7. `save` `game/save/profile_store.gd` (new, ~70): `ProfileStore` (RefCounted, static funcs): `load_profile(cat, dir := "user://")`, `save_profile(p, dir := "user://")`, `record_run_end(world, dir := "user://") -> int` (load, `record_run`, save once), `last_error`. The `dir` parameter lets tests use a scratch folder under `user://` and delete it afterwards.
8. `view` `game/view/game_view.gd` (+6): the first frame that sees WON or LOST calls `ProfileStore.record_run_end(world)` once (a `_recorded` flag; Restart and Main menu reload the scene, so a fresh flag). Not in the bench (`demo == false`). Showing the hearts is 039.
9. `tests` `game/tests/fixtures/profile_v0.json` (new, LF, ASCII): a pre-versioned profile (no `schema_version`, no `bond`, no `stats`, one unknown waifu id).

### Tests (headless)
- `game/tests/sim/test_meta_profile.gd` (new): offer at 0 rescues (Cinder, Bastia, Clover), 1 (Cinder rescued: Bastia, Clover, Hymn), 4 (the 2 left), 6 (all 6 in offer order); hearts at clock 0 (30), 13 500 ticks (40), `final_boss_tick` and later (50), a win (100); `record_run`: a win with `guardian_cinder` unlocks `waifu_cinder` once (a second win does not duplicate), a loss unlocks nothing, the placeholder Guardian unlocks nothing, stats and `best_sec`; buy: `meta_gold_2` LOCKED before `meta_gold_1`, NO_HEARTS, OK deducts the cost, then OWNED; `start_command`: null for a waifu outside the offer, else the right `guardian_id`, `unlocked`, `meta_nodes`; migration of `profile_v0.json` (defaults filled, unknown id dropped); `schema_version` 99 and wrong types are unreadable.
- `game/tests/sim/test_meta_start.gd` (new): StartRun on `run_m3` with every meta node: gold 300, Guardian max HP x1.2 after the first step, a placed Pip has max HP x1.15, Pip price 47, sell refund `floori(47 * 0.65)`, rebuild price at fraction 0.2, XP x1.1; `run_m2` with `meta_radius` has a 120-cell grid and accepts a tower at radius 22; node order in the command does not change `state_hash()`; empty `meta_nodes` = the old StartRun (existing tests unchanged).
- `game/tests/save/test_profile_store.gd` (new, scratch dir `user://test_profile/`, removed in `after_each`): round trip (save, load, equal `to_dict()`); a second save overwrites (the rename-over path on Windows); a missing file with a `.tmp` loads the tmp; corrupt files (`{"hearts": ` and a JSON array) become `profile.bad.json` with the original bytes, a fresh profile and `last_error` set; `record_run_end` on a WON `run_m3` world with `guardian_cinder` adds 100 hearts and unlocks Cinder in the file.
- `test_determinism.gd`: a `run_m3` replay with `meta_nodes`, same `state_hash` twice.
- Perf: nothing per tick (StartRun once; price, refund and rebuild sums run per command and per UI call, not per enemy). No bench run needed.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3: the `save/` folder in the tree. 3a: `START_RUN` gains `meta_nodes` (rule 8); `TowerBuilding` prices (rule 9). 7: profile file, atomic save, migration chain, bad-file rule, offer and hearts rules (short, pointing at D-152).
- `DECISIONS.md`: D-152 PROPOSED (rules 1-10).

### Order
1. `MetaCatalog`, `MetaProfile` and `test_meta_profile.gd`. 2. RunData fields, `meta_nodes`, StartRun meta (after 045's grid code), rule 9, `test_meta_start.gd`. 3. `ProfileStore`, the fixture, `test_profile_store.gd`. 4. Game-view hook. 5. Docs, D-152; `scripts/test.ps1` twice, `scripts/validate.ps1`.

## Questions
- Owner check (non-blocking, assumed in D-152 rule 1): "best time per Guardian" (`10_M3_CONTENT.md` 7) is stored as the **longest time survived** with that Guardian, wins included. Nothing in M3 shows it except the hub (039); say if you meant the fastest win instead.
- Q-73 (what the player sees when `profile.json` is unreadable) sits on the unmerged docs review branch `docs/review-2026-10-10`. This task only keeps `profile.bad.json`, starts fresh and exposes `last_error`; the notice itself is task 039. Its ★ A fits this plan.

## Review log
