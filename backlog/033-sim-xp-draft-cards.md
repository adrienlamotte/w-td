# 033 — Sim: XP, level-up draft and card effects
- Status: done
- Milestone: M3
- Depends on: 030
- PR: #43

## Goal
Kills give XP; a level-up freezes the run and offers 3 cards; `PICK_CARD` applies one. Card effects feed the modifier store (030), unlock towers and level 4, and change the run-scope stats.

## Context
- `docs/10_M3_CONTENT.md` 1 (XP in DEATHS times the XP multiplier, float total, curve `xp_base + xp_step * (L - 1)`, `LEVEL_UP` then `drafting` frozen like a pause, draw with the `cards` RNG: weighted type then a uniform card, filler `card_purse`, queued level-ups, pause allowed during a draft), 2 (card pool, eligibility, `max_picks`), 2.4 (`perk_maze` via `hit[c] != -1`; `perk_expand`: build grid allocated for the largest reachable radius), 2.5 (effect vocabulary).
- D-051 (cards never give a tower for free; no reroll, banish or skip), D-134 (the signature card unlocks level 4), `docs/02_TECH_ARCHITECTURE.md` 3a (per-concern RNG `hash([seed, "cards"])`, commands, events).
- Skill-scope effects (`skill_power`, `skill_cooldown`, `shield_*`) are stored here and consumed by 034.

## Acceptance criteria
- XP, level, the open draft (3 card indices), `drafting` and picked counts live in the world and are hashed. `LEVEL_UP` (a = level), `CARD_PICKED` (a = card index). While drafting nothing moves and building, upgrades and skills are refused; `PICK_CARD{slot}` closes it; a queued draft opens right after.
- Eligibility from the run's buildable towers and the unlocked waifus given at StartRun (a new `START_RUN` field; empty = nothing rescued, so the M2 tests are unchanged).
- Effects: `unlock_tower`, `unlock_level`, `gold`, `kill_gold` (rounded down per kill, before mark gold), `xp`, `build_radius`, `rebuild_price`, `detour_damage`, and the tower stats through the modifier store.
- Tests: XP thresholds, several level-ups in one tick, draw weights and determinism (same seed, same cards), filler slots, `max_picks`, each effect, the frozen state, replay from `(seed, commands)` with picks. `scripts\bench.ps1` maze and combat scenarios within noise (D-124).
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan
Decision ID: **D-147** (PROPOSED, rules below). About 330 lines of code plus about 250 of tests, one new data file. **Split:** the three effects that change existing sim rules (`build_radius` with the grid allocated for the largest reachable radius, `rebuild_price`, `detour_damage` / `perk_maze`) move to the new task **045**; here they only land in the modifier store (no effect yet). Everything is `sim/` except the tests and the run file. Order in the milestone: after 031 and 034 (docs/plans/M3.md), so the drafting gate also covers the 034 skill casts and the kill gold sits with the 031 mark gold and the 034 bounty gold in DEATHS.

### Rules (D-147)
1. **XP.** `EnemyCatalog` loads `xp` per type. In DEATHS, every removed enemy (any killer) adds `xp[type] * xp_mult` to the float `xp` total, in the existing highest-index-first order (deterministic). `xp_mult` = 1 + sum of `xp` mult on target `run` (+ add), cached in the 030 recompute when `stats_dirty` (no store scan per death).
2. **Levels.** `level` starts at 1, `xp_next` = `xp_base`. At the end of DEATHS, while `xp >= xp_next`: `level += 1`, `pending += 1`, push `LEVEL_UP` (a = new level), `xp_next += xp_base + xp_step * (level - 1)` (level 2 at 30, 5 at 300, 10 at 1350). Then if not `drafting` and `pending > 0`, open a draft.
3. **Draft.** Opening draws 3 cards with the new `cards` RNG (`hash([seed, "cards"])`) and sets `drafting`. Eligible: non-filler cards with `picks < max_picks`, whose `requires.unlocked` waifu is in the StartRun `unlocked` list and whose `requires.buildable` waifu's tower is in the run's current buildable list; a `new_tower` card whose `unlock_tower` tower is already buildable is not eligible (10_M3_CONTENT.md 2.1, "not yet buildable"). Per slot: among the types `new_tower, signature, skill, perk` (this fixed order) that still have an undrawn eligible card, pick a type by `card_type_weights` (one `randf()`), then a card uniformly among that type's undrawn eligible cards in catalog (id) order (one `randi_range`). A slot with no eligible card left gets the filler (`card_purse`, the first `filler` card by id). No reroll, banish or skip (D-051).
4. **Frozen while drafting.** `step()` returns after COMMANDS (like a pause: `tick` advances, `clock`, movement and spawns do not). `PLACE_TOWER`, `SELL_TOWER`, `REBUILD_TOWER`, `UPGRADE_TOWER` and `USE_SKILL` are refused while drafting. `PAUSE` is accepted and the draft stays open.
5. **PICK_CARD{slot}.** Accepted only while RUNNING, drafting, not paused, slot 0-2. Applies the card's effects in order, `picks[card] += 1`, pushes `CARD_PICKED` (a = card index, value = slot), clears the draft; `pending -= 1`; if `pending > 0` the next draft opens at once (same tick, new draw).
6. **Effects** (`CardEffects.apply(w, effect)`, the 2.5 object): `gold` add = instant gold (`card_purse`); `unlock_tower` = append that tower type to the world's buildable list (once); everything else (`unlock_level`, tower stats, `kill_gold`, `xp`, `build_radius`, `rebuild_price`, `detour_damage`, skill stats) = `w.add_modifier(...)` unfiltered (030). Applied here: `kill_gold`: the base gold of a kill = `floori(base * kill_gold_mult)` (only when the base roll gives gold; `kill_gold_mult` cached like `xp_mult`), then mark gold (031) and bounty gold (034) are added flat; `xp` (rule 1). `build_radius`, `rebuild_price`, `detour_damage` take effect in 045. `unlock_level` is read by `TowerUpgrade` (030); skill stats by 034.
7. **Buildable list.** World state `tower_types` (a copy of `run.tower_types` at StartRun, hashed); `TowerBuilding.check_place` reads it instead of `run.tower_types`. The build bar keeps reading `run.tower_types` until task 037 shows card-unlocked towers.
8. **START_RUN** gains `unlocked: PackedStringArray` (rescued waifu ids; empty = nothing rescued, so the M2 tests and the first run behave as before). Meta effects at StartRun come with 035.
9. **Run data.** New `data/runs/run_m3.json`: `run_m2` with towers `tower_pip`, `tower_mallow` (the two starters, 2.1) and the same waves, bosses, XP and card fields; it is what tests (and later 039 and 041) use for a run with waifu towers. `run_m2` stays the M2 fixture.

### Files
1. `sim` `game/sim/card_catalog.gd` (new, ~60): loads `data/cards` (sorted by id) and `data/waifus` (waifu id to tower type); packed `type`, `max_picks`, `req_unlocked`, `req_buildable_type` (-1 = none), `unlock_type` (-1 = none), `effects: Array`; `filler: int`. Load time only.
2. `sim` `game/sim/card_draft.gd` (new, ~110): `xp`, `level`, `xp_next`, `pending`, `drafting`, `draft: PackedInt32Array` (3 card indices), `picks: PackedInt32Array`, the `cards` RNG; `add_xp`, `check_levels(w)`, `open(w)`, `pick(w, slot)`, `hash_parts()`. `reset(...)` at StartRun.
3. `sim` `game/sim/card_effects.gd` (new, ~30): rule 6.
4. `sim` `game/sim/sim_world.gd` (+40): `var draft`, `var tower_types`, `var unlocked`, `xp_mult` / `kill_gold_mult` caches; StartRun resets; `PICK_CARD` branch; `drafting` in the building/skill gates and in the early return of `step()`; XP and kill gold in `_deaths`, level check at its end; the caches next to `TowerStats.recompute`; `state_hash()` adds `draft.hash_parts()`, `tower_types`, `unlocked`.
5. `sim` `game/sim/sim_command.gd`, `game/sim/sim_events.gd` (+12): `PICK_CARD` + `pick_card(tick, slot)`, `start_run(..., unlocked := PackedStringArray())`; `LEVEL_UP`, `CARD_PICKED`.
6. `sim` `game/sim/enemy_catalog.gd` (+2): `xp`. `game/sim/run_data.gd` (+8): `xp_base`, `xp_step`, `card_type_weights` (4 floats in rule 3's order). `game/sim/tower_building.gd` (1): `w.tower_types`.
7. `data` `game/data/runs/run_m3.json` (new, rule 9). No schema change.
8. **Stopgap clients** (a draft opens on every run once XP reaches 30, and nothing can pick it before the draft UI, task 037): `view` `game/view/game_view.gd`, `game/balance/balance_bot.gd` and `game/view/bench/bench_scenario.gd` each queue `PICK_CARD(slot 0)` when they see `world.draft.drafting` (a few lines each, sim clients only, no rule). The game-view one carries a comment that 037 replaces it; the bot and the bench keep it (the M2 balance report and the bench numbers stay comparable).

### Tests (headless)
- `game/tests/sim/test_card_draft.gd` (new): XP per kill and with `xp` +0.15 (float total); thresholds 30 / 60 / 90 per level; several level-ups in one tick queue drafts that open one after another on each pick; frozen state (no clock, no movement, no spawn; place, upgrade, sell, rebuild, skill refused; pause accepted, the draft stays; pick refused while paused or with a bad slot); draw determinism (same seed, same 3 cards) and a different seed changes them; type weights over many draws with a fixed seed roughly match 3:2:2:2 (loose bound); eligibility: first run (`unlocked` empty, `run_m3`) never offers `new_tower` cards, `unlocked = [waifu_cinder]` offers `card_tower_cinder` until picked, signatures only for buildable waifus (`card_sig_pip` on `run_m3`, none on `run_m2`), `max_picks` respected (`perk_sharp` 3 times then gone); filler fills empty slots when fewer than 3 cards are eligible.
- `game/tests/sim/test_card_effects.gd` (new): `card_purse` +40 gold; `card_tower_cinder` makes `check_place` of `tower_cinder` OK; `card_sig_pip` lets a Pip reach level 4 (030); `perk_sharp` x2 = damage x1.2 at the next step; `perk_bounty` floors per kill (base 1 x 1.2 = 1) and mark gold is added after; `perk_masonry` raises tower max HP; skill and run stats land in the store.
- `test_determinism.gd` / `test_replay.gd`: a replay from `(seed, commands)` with picks on `run_m3`, same `state_hash` twice and equal to a run replayed from the recorded command list.
- Release bench `scripts/bench.ps1`: `pc_maze`, `pc_maze_combat`, `pc_combat_stress` within noise of `reports/perf_m2.md` (D-124); table in the PR. Note: combat bench deaths now cost one float multiply-add each and open drafts, which the bench picks at once (Files 8).

### Perf
Per death: one multiply-add (XP) and one compare; per level-up: one draw over at most 25 cards. The run-scope multipliers are cached in the recompute, never summed per kill.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: commands (`PICK_CARD`, `START_RUN.unlocked`), events (`LEVEL_UP`, `CARD_PICKED`), run state (`drafting` frozen like a pause), RNG list (`cards`), XP and draft rules, card effects, buildable list, state hash. 3b: `run_m3`.
- `DECISIONS.md`: D-147 PROPOSED (rules 1-9).

### Order
1. Catalogs (cards, waifus, enemy xp, run fields) and `run_m3`. 2. XP, levels, draft draw and frozen state. 3. `PICK_CARD` and effects, buildable list, kill gold. 4. Tests, replay, bench, docs, D-147; `scripts/test.ps1` twice, `scripts/validate.ps1`.

## Questions

## Review log
- 2026-10-10 lead-dev: approved and merged PR #43 (squash). test.ps1 308/308 + tools green, validate.ps1 OK. Matches plan and D-147; stopgap slot-0 picks in game view (until 037), bot and bench as planned. Owner: balance report numbers shift when regenerated; draft freezes from the tick after it opens.
