# 032 — Sim: relationship synergies, Hymn's aura and Poppy's repair
- Status: review
- Milestone: M3
- Depends on: 031
- PR: #47

## Goal
Relationship bonuses (the game's hook, D-057) and the two neighbour-based kinds (`aura`, `repair`) are computed in the derived-stats recompute, so their per-tick cost stays near zero.

## Context
- `docs/10_M3_CONTENT.md` 5.1-5.2 (active rule, distance window centre to centre, the Guardian measured from her body edge, one partner is enough, different relationships add up, Guardian-side bonus once per relationship), 3.1 (`aura`: the strongest Hymn in reach applies, no stacking; `repair`: lowest HP fraction in range every `cooldown`, else the Guardian if in range, level 4 two targets), 3.3 (pair scan through build-grid cells within the largest reach, neighbour list for repair).
- D-132 (the Guardian counts as a placed waifu), D-135 (repair), D-136 (rivals 2-6 units), D-128 (the maze must pay off).
- Rival rows (Vexa, Gilda) are supported by the format but have no files in M3.

## Acceptance criteria
- Synergy catalog loaded from `data/synergies`; each tower's active relationships and bonuses folded into its derived stats; Guardian-side bonuses (shield absorb, skill cooldown, skill power) written to the modifier store for 034.
- `aura`: Hymn never fires; towers whose centre is within `aura_radius` get her damage and cooldown bonus, strongest Hymn only.
- `repair`: on its cooldown only, heals the live tower in range with the lowest HP fraction below 100% (husks excluded; `heal_targets` at level 4), else the Guardian if in range for `guardian_heal` (capped at max HP); `TOWER_REPAIRED` (a = uid or -1, value = HP).
- Husks and bare towers never count as partners; place, sell, husk, rebuild and upgrade re-evaluate. The pair scan runs per change, never per tick.
- Tests: each 5.2 row, window edges (rivals 2-6), no stacking per partner, the Guardian as a partner, aura strongest-only, repair targeting and Guardian fallback, determinism; recompute time of a 300-tower layout measured in a headless test. `scripts\bench.ps1` maze and combat scenarios within noise (D-124).
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan
Decision ID: **D-150** (PROPOSED, rules below). About 330 lines of code plus about 280 of tests; no data or schema change (029 shipped `data/synergies`, `data/waifus` and the Hymn and Poppy fields). Everything is `sim/` except the tests. Order in the milestone: after 034, 033 and 045 (docs/plans/M3.md). **Builds on 034** (in progress on its own branch): `run` holds the chosen Guardian, `SimModifiers.skill_sums` / `guardian_sums` read entries targeting `guardian`, `guardian_max_hp` is recomputed next to `TowerStats.recompute`, and the Crescendo reset sits in `TowerAttacks.fire`. Start from `m3/dev` after 034 is merged; nothing here changes 034's casts.

### Rules (D-150)
1. **Waifu of a tower and of the Guardian.** `SynergyCatalog` maps each tower type and the Guardian to a waifu through the waifu files (`tower`, `guardian` fields). The M2 `tower_*_01` types and `guardian_placeholder_01` have no waifu, so `run_m2`, the M2 tests and the bench never get a relationship. A rule whose waifu has no file (the M5 rival rows) is skipped at load.
2. **Who counts.** Only live built towers (`type_id >= 0`, not a husk) are partners, get bonuses or aura, and are in a repair list. The Guardian always counts as a partner while the run is RUNNING (D-132), at the origin; for her the distance is `d - guardian_contact_radius` (body edge).
3. **Relationship active for a tower** when at least one partner is within `[min_distance, max_distance]`, both ends inclusive, centre to centre. One partner is enough (no stacking per partner); different rules on the same tower add up. Per tower, a bit mask `syn_mask` (bit = rule index) records the active rules; the tower's side of each active rule is added to its modifier sums.
4. **One formula.** Every derived stat = `(level value + add) * (1 + mult)` where add and mult are the store sums (cards, meta, D-144) plus that tower's synergy and aura terms. `TowerStats.MODDED` grows by the synergy stats `slow_sec`, `thorns`, `mark_gold` (rounded with `roundi`), `aura_radius`, `heal`, plus `guardian_heal`; the cooldown clamp (50% of the level value, 1 tick) applies after synergy and aura.
5. **Guardian side.** When the Guardian's waifu is in a rule and a partner tower is in reach (rule 2 distance), she gets the rule's `guardian_bonus` once per rule. The recompute writes these as store entries with target `guardian`, flagged `layout`: `SimModifiers.clear_layout()` removes the previous ones first, so they never accumulate. 034's `skill_sums` reads them unchanged. Written directly, not through `add_modifier`, so they never set `stats_dirty` again. `guardian_syn_mask` (int, bit = rule) for the view (040).
6. **Aura** (`aura`, Hymn): never targets or fires (D-145 rule 1). Her reach = derived `aura_radius` (with her own synergies). Every other live tower whose centre is within it, Hymns excluded, gets `aura_damage` added to its `damage` mult and `-aura_cooldown` to its `cooldown` mult. Strongest only: the Hymn with the higher `aura_damage` applies, then the higher `aura_cooldown`, then the lower uid; no stacking. M2 towers and Poppy (her repair cooldown) get it too.
7. **Repair** (`repair`, Poppy): heal range = derived `range` (`attack_range` stays 0, D-145 rule 1), stored in `reach`. The recompute builds her neighbour list: the live towers whose centre is in range, herself included, ascending index. In the ATTACKS phase she counts her cooldown down like any tower; at 0 she pulses and the cooldown resets to `reload` (Crescendo does not apply: it shortens shots, 4.1). A pulse heals the `heal_targets` (1, Signature 2) live towers of her list with the lowest `hp / max_hp` below 1 (ties: lower uid), each by `heal` capped at `max_hp`; if none needs it and the Guardian's body is in range (`d - contact_radius <= range`) and below `guardian_max_hp`, the Guardian gets `guardian_heal`, capped. A pulse with nothing to heal is spent (every `cooldown`, 3.1). `TOWER_REPAIRED` per heal: a = uid or -1, x, z = the healed position, value = HP restored.
8. **When.** The whole pass runs inside `TowerStats.recompute` (dirty flag, D-144: place, sell, rebuild, husk, upgrade, card pick, 034's Emergency Rebuild), never per tick. Sells move indices only in COMMANDS and set dirty, so the repair lists are rebuilt in PATH before ATTACKS reads them; a tower turned husk later in the tick is skipped by the pulse's husk check.
9. **Cost.** The pair scan uses a `SpatialGrid` over the tower positions (cell 6 = the largest `max_distance`), rebuilt in the recompute; each waifu tower, Hymn and Poppy queries its own largest reach once. When no live tower has a waifu, an aura or a repair kind, the pass is skipped entirely (M2 runs and the bench pay nothing). This replaces the "build-grid cells" scan of 3.3 with the same bound (towers x nearby towers, per change).

### Files
1. `sim` `game/sim/synergy_catalog.gd` (new, ~65): loads `data/waifus` and `data/synergies` once (in `SimWorld._init`, next to `TowerCatalog`). `waifu_of_tower: PackedInt32Array` (per tower type, -1 none), `waifu_of_guardian(guardian_id) -> int`; per rule `min_d`, `max_d`, the 2 waifus, each side's bonus `stat/op/value`, `guardian_stat/op/value`; `rules_for(a, b) -> PackedInt32Array` (rules with waifu a on one side and b on the other), `max_reach: float`. Rules sorted by id (deterministic bit order); at most 31 rules (bit mask), asserted at load.
2. `sim` `game/sim/tower_links.gd` (new, ~130): `TowerLinks` instance on `SimWorld` (`links`). `compute(w)` returns the per-tower extra sums (rules 2-6), writes the guardian entries of rule 5, and builds the repair lists `heal_first`, `heal_count`, `heal_list` (CSR by tower index, valid until the next recompute). Owns its tower `SpatialGrid` (cell 6, half extent = build radius + 1) and query buffer. If it passes ~150 lines, move the aura step to `tower_aura.gd`.
3. `sim` `game/sim/tower_stats.gd` (~25): `MODDED` grows (rule 4); `recompute` calls `w.links.compute(w)` first and adds each tower's extra sums to the cached per-type sums before `_derive`; `_derive` writes `reach` (`aura_radius` for aura, `range` for repair, else 0), `heal`, `guardian_heal`, `heal_targets`, and `slow_ticks`, `thorns`, `mark_gold` through `value()`. `apply` (a new tower) stays per type without links: the recompute in the same tick's PATH adds them.
4. `sim` `game/sim/sim_towers.gd` (+20): derived `reach`, `heal`, `guardian_heal` (float), `heal_targets`, `syn_mask` (int), through `add()` and `remove()`.
5. `sim` `game/sim/tower_catalog.gd` (+1): `_LEVEL_DEFAULTS` gains `aura_radius` 0, `aura_damage` 0, `aura_cooldown` 0, `heal` 0, `guardian_heal` 0, `heal_targets` 1.
6. `sim` `game/sim/tower_attacks.gd` (+35): in `fire`, a `REPAIR` tower pulses when its cooldown reaches 0 (before the target check) and resets to `reload`; static `repair(w, t)` (rule 7).
7. `sim` `game/sim/sim_modifiers.gd` (+15): `layout: PackedByteArray`; `add(..., p_layout := false)`; `clear_layout()`; `hash_parts()` adds `layout`.
8. `sim` `game/sim/sim_world.gd` (+10): `synergies` catalog and `links` in `_init`; `guardian_syn_mask`; `state_hash()` adds `towers.reach`, `heal`, `guardian_heal`, `heal_targets`, `syn_mask`, `guardian_syn_mask`. If 034 did not keep the chosen Guardian id on `RunData`, add `guardian_id` there (+2, `run_data.gd`).
9. `sim` `game/sim/sim_events.gd` (+1): `TOWER_REPAIRED` appended at the end of `Kind` (after 033's kinds).

### Tests (headless)
- `game/tests/sim/test_synergies.gd` (new): StartRun `run_m2`, towers laid with `TowerBuilding.add_built` at exact centres (2 x 2 footprints, centres on 0.5 multiples). Each of the 7 M3 rows of 5.2 gives both sides their bonus (Pip damage x1.2 and Mallow `slow_ticks` + 30; Mallow reload x0.8 and Cinder damage x1.25; Bastia max HP x1.3 and Pip damage x1.25; Bastia thorns +3 and Clover mark gold +1; Hymn reach +1 and Poppy heal x1.5; Hymn reach +1 and Tansy slow +1 s; Cinder range +1 and Tansy reload x0.8). Window edges: bff at 2.5 on, 3.0 off; rivals at 1.5 off, 2.0 on, 6.0 on, 6.5 off. No stacking: two Mallows next to one Pip = x1.2; Pip next to Mallow and Bastia = damage mult 0.45 (both add). A husk partner and a bare tower do not count; sell, husk (lethal `damage_tower`), rebuild and upgrade re-evaluate at the next step (D-144 HP rule on Bastia). Guardian: StartRun with `guardian_cinder`, a Mallow 2-6 from her edge gets reload x0.8 and the store holds one `skill_power` +0.25 `guardian` layout entry; two Mallows = still one entry; after selling them, none; a card entry added with `add_modifier` survives the recompute. `run_m2` with M2 towers only: derived values unchanged.
- `game/tests/sim/test_aura_repair.gd` (new): Hymn never targets or fires; a Pip at 3.0 gets damage x1.2 and reload x0.9, at 3.5 not; two Hymns (L1 and L4 via an `unlock_level` entry) = only the L4 values; aura plus a `damage` mult card entry add up; the cooldown clamp holds. Repair: the lowest-fraction damaged tower in range is healed by 20 (capped at max HP) on the first pulse and again after `ticks(2.0)`, not between; a husk, a full tower and a tower out of range are skipped; she counts herself; L4 heals the two lowest by 40; with no damaged tower and the Guardian in range below max she gets 10 (capped), out of range nothing; `TOWER_REPAIRED` payloads (uid / -1, value = HP restored); a pulse with nothing to heal still resets the cooldown.
- Perf: a 300-tower layout (the 8 M3 waifus mixed, 2 x 2 spacing) in the run grid; time `TowerStats.recompute` with `Time.get_ticks_usec()`, print it, assert under 30 ms (debug, headless; a guard against a quadratic pass). Number in the PR.
- `test_determinism.gd`: a replay with Hymn, Poppy, Pip, Mallow and Bastia built, a Guardian with a waifu, damage to towers and a sell mid-run, same `state_hash` twice. `test_sim_towers.gd`: the new arrays in its `remove()` check.
- Release bench `scripts\bench.ps1`: `pc_maze`, `pc_maze_combat`, `pc_combat_stress` within noise of `reports/perf_m2.md` (D-124); table in the PR. Expected neutral: the bench builds M2 towers only, so the link pass is skipped (rule 9); the per-tick cost is one kind compare per tower in `fire`.

### Perf
No per-tick loop: the pair scan, aura and repair lists run only in the dirty recompute; a Poppy pulse scans her own list once per `cooldown`. The recompute is per change; if the 300-tower number is high, the upgrade path is an incremental update around the changed tower (`ponytail:` comment in `tower_links.gd`).

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: derived tower stats (the link pass, rules 2-6, the extra stats, `reach`, `syn_mask`), Tower attacks (repair pulse), events table (`TOWER_REPAIRED`), the modifier store `layout` entries, the state hash list.
- `10_M3_CONTENT.md` 3.3: one line, the pair scan uses a tower spatial grid (rule 9).
- `DECISIONS.md`: D-150 PROPOSED (rules 1-9). `docs/plans/M3.md`: 032 row.

### Order
1. `SynergyCatalog`, catalog defaults, new derived arrays (existing suites green). 2. `TowerLinks` relationships + guardian layout entries; synergy tests. 3. Aura. 4. Repair lists and pulse, `TOWER_REPAIRED`. 5. Perf test, determinism, bench, docs, D-150; `scripts\test.ps1` twice, `scripts\validate.ps1`.

## Questions
Non-blocking: the plan takes the readings below (recorded in D-150); the owner can change any of them at review for a line or two of code.
- Poppy can heal herself (she is a live tower in her own range; 3.1 says "the live tower in range").
- At Signature level (2 targets), the Guardian is healed only when no tower needs a heal, even if just one tower was healed (D-135: "if none needs it").
- Hymn's aura also shortens Poppy's repair cooldown (3.1: "every other live tower"); Crescendo does not (it shortens the cooldown "after a shot").
- A repair pulse with nothing to heal is spent (3.1: "every `cooldown`"), so a newly damaged tower may wait up to one cooldown.

## Review log
