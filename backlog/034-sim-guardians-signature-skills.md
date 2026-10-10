# 034 — Sim: Guardians and signature skills
- Status: done
- Milestone: M3
- Depends on: 030
- PR: #41

## Goal
The run's Guardian comes from `StartRun` (`guardian_id`) and has her signature skill plus the shared Shield. The 6 signature skill kinds work, and skill modifiers (cards, synergy Guardian bonuses, meta) apply.

## Context
- `docs/10_M3_CONTENT.md` 4.1 (kinds `area_blast`, `guard`, `bounty`, `haste`, `snare`, `rebuild`; a cast works once in COMMANDS; timed effects store an absolute `until` tick checked where code already runs; `power_stats`; rounding), 2.3 (`card_skill_sig_power`, `card_skill_sig_quick`, `card_skill_shield_plus`, `card_skill_mending`), 5.1 (Guardian-side synergy bonuses), 8 (`START_RUN` gains `guardian_id`; the run file drops `guardian`).
- D-133, D-139 (signature skills), D-110 (cooldowns on the run clock, Shield), D-044 (Heal as an upgrade), D-117 (Tangle uses the slow rule).
- `skill_area_blast` and `guardian_placeholder_01` stay for the M2 tests and the bench.

## Acceptance criteria
- `START_RUN{run_seed, run_id, guardian_id}`; the placeholder Guardian stays usable by tests and the bench.
- Each signature kind as specified; `guard_until`, `bounty_until`, `haste_until` hashed; Big Finish and Tangle one linear scan per cast; Emergency Rebuild restores every husk.
- Skill modifiers: signature power multiplies `power_stats` (integer stats rounded down), signature and all-skill cooldown multipliers (clamp at 50%), Shield absorb and duration, Mending heal on a Shield cast, Guardian max HP.
- Tests per kind and per modifier, timed effects expire on the run clock (frozen while paused), determinism. `scripts\bench.ps1` maze and combat scenarios within noise (D-124).
- Headless tests green twice; data validator green; docs and a PROPOSED decision in the same PR.

## Plan
Decision ID: **D-146** (PROPOSED, rules below). About 250 lines of code plus about 200 of tests; no data or schema change (029 shipped the 6 skill files, the Guardian files and `power_stats`). `sim/` plus a two-line HUD change in `view/`. Order in the milestone: after 031, before 033 (docs/plans/M3.md); it reads skill modifiers from the 030 store, which tests fill with `add_modifier` (033 cards and 032 synergies push the same entries later).

### Rules (D-146)
1. **Guardian from StartRun.** `START_RUN{run_seed, run_id, guardian_id}`; an empty `guardian_id` falls back to the run file's `guardian` (kept, still required by the schema), so `run_m2`, the M2 tests, the bench and the balance runner keep `guardian_placeholder_01` unchanged. `RunData.load_id(run_id, enemies, towers, guardian_id)`. The M3 run flow (039) always passes an id.
2. **Signature slot.** The Guardian's signature skill is her skill whose kind is not `shield` (placeholder: Area blast). Modifier targets for skill slot `s`: `guardian` (all her skills), `signature` (the signature slot only), `skill:<id>`.
3. **Cast-time values.** A cast reads the store once (a short linear scan of the entries, in COMMANDS, never per tick): power `p` = sum of `skill_power` mult (signature slot only); each `power_stats` field = base x (1 + p), integer fields (`gold_per_kill`) rounded down, durations converted to ticks after the multiply (`DataFiles.ticks`). Only what `power_stats` lists is powered: Tangle's `slow_factor`, Stand Firm's `damage_factor` and Crescendo's `cooldown_factor` are not. Cooldown ticks = `(base + add) * (1 + mult)` of `skill_cooldown`, clamped at `max(1, ceili(base * 0.5))` like towers (D-144; share the clamp function with `TowerStats`). Shield: absorb x (1 + `shield_absorb` mult), duration + `shield_duration` add (seconds); Mending: `shield_heal` add = HP restored on each Shield cast, capped at max HP.
4. **Guardian max HP.** New hashed `guardian_max_hp` = (Guardian `hp` + `hp` add) x (1 + `hp` mult) over entries targeting `guardian`. Set at StartRun with `guardian_hp = guardian_max_hp`; recomputed with the tower stats when `stats_dirty` (030); a rise adds the difference, a fall clamps (same rule as towers). The HUD reads `world.guardian_max_hp` instead of `run.guardian_hp`.
5. **Kinds** (one cast in COMMANDS; timed effects store an absolute run-clock `until`, checked where code already runs; the run clock stops while paused, so they freeze too):
   - `area_blast`: the M2 rule with the powered `damage` (Big Finish = her numbers).
   - `guard`: `guard_until = clock + duration`. While `clock < guard_until`, `SimWorld.damage_tower` and `_hit_guardian` multiply the damage by `damage_factor` (0.5), before the Shield absorbs. Thorns (031) unchanged. The `TOWER_HIT` and `GUARDIAN_HIT` values are the reduced damage.
   - `bounty`: `bounty_until`, `bounty_gold` (powered, rounded down). DEATHS adds `bounty_gold` to every kill while `clock < bounty_until`, flat (after the base gold and the mark gold, not multiplied by `kill_gold`), included in the `ENEMY_DIED` value.
   - `haste`: `haste_until`. In `TowerAttacks.fire`, the cooldown reset is `maxi(1, roundi(reload[t] * cooldown_factor))` while `clock < haste_until`, on top of the derived value (the 50% clamp of 2.5 is for modifiers; Crescendo is a timed skill).
   - `snare`: one linear scan; every enemy whose body touches the disk of `radius` around her (the Area blast edge rule, D-107) gets `apply_slow(0.15, powered duration ticks)` (D-117), bosses too.
   - `rebuild`: one loop over towers: every husk is restored for free exactly like `REBUILD_TOWER` (hp = `max_hp`, husk 0, cooldown 0, cells solid, `TOWER_PLACED`, `stats_dirty`, level kept; extract the shared part of `TowerBuilding.rebuild` into `restore(w, t)`), then `guardian_hp = min(guardian_max_hp, guardian_hp + powered guardian_heal)`.
   - `shield`: the M2 rule with rule 3's values and the Mending heal.
6. **State.** Hashed: `guardian_max_hp`, `guard_until`, `bounty_until`, `bounty_gold`, `haste_until` (all 0 at StartRun). The factors are read from `run` at the signature slot.

### Files
1. `sim` `game/sim/run_data.gd` (+35): `Skill` appends `GUARD, BOUNTY, HASTE, SNARE, REBUILD` (`_SKILLS` map); per slot `skill_damage_factor`, `skill_gold_per_kill`, `skill_cooldown_factor`, `skill_slow_factor`, `skill_guardian_heal`, `skill_power_stats: Array[PackedStringArray]`; `signature_slot: int`; `load_id(..., guardian_id := "")` (rule 1).
2. `sim` `game/sim/sim_command.gd` (+3): `guardian_id` field and `start_run(tick, seed, run_id, guardian_id := "")`.
3. `sim` `game/sim/sim_modifiers.gd` (+12): `skill_sums(stat, skill_id, is_signature) -> Vector2` (the rule 2 targets) and `guardian_sums(stat)`.
4. `sim` `game/sim/guardian_skills.gd` (+60): `try_use(slot, clock, cooldown_ticks)` (cooldown computed by the caller), the `until` fields and `bounty_gold`, `cast(w, slot)` dispatching the kinds (rule 5), a `power(w, slot, base)` helper (rule 3). If it passes about 120 lines, split the casts into `game/sim/signature_skills.gd`.
5. `sim` `game/sim/sim_world.gd` (+35): StartRun (guardian id, `guardian_max_hp`), `_use_skill` calls the cast (move `_area_blast` next to the other casts), guard in `damage_tower` and `_hit_guardian`, bounty in `_deaths`, Guardian max HP recompute next to `TowerStats.recompute`, `state_hash()` (rule 6).
6. `sim` `game/sim/tower_attacks.gd` (+3): haste on the cooldown reset.
7. `sim` `game/sim/tower_building.gd` (~10): `restore(w, t)` shared by `rebuild` and the skill.
8. `sim` `game/sim/tower_stats.gd` (~5): expose the cooldown clamp as `clamped_ticks(base_ticks, sums)`, reused by skills.
9. `view` `game/view/ui/hud.gd` (2): HP bar and text use `world.guardian_max_hp`. `view/fx_pool.gd` keeps its `AREA_BLAST` effect (visuals for the new kinds are task 040).

### Tests (headless)
- `game/tests/sim/test_signature_skills.gd` (new): StartRun with each `guardian_<waifu>` gives her two skills and her hp; an empty id keeps the placeholder. Per kind: Big Finish damage and reach; Stand Firm halves tower and Guardian damage until it expires (with the Shield up: guard first); Clearance Sale adds 4 gold per kill inside the window only; Crescendo cooldown reset at 60%, then back; Tangle slows the enemies within radius 7 to 0.15 for 3 s (a boss too, one outside not); Emergency Rebuild restores every husk (cells solid, one `TOWER_PLACED` each, level kept) and heals 40 capped at max HP; timed effects do not expire while paused.
- Modifiers: `skill_power` +0.5 on `signature` (Big Finish 60 damage, Clearance Sale 4 -> 6 gold, Tangle 4.5 s, Shield unchanged); `skill_cooldown` -0.25 on `signature` and -0.1 on `guardian` (both add up on the signature, only the second on the Shield), the 50% clamp; the `card_skill_shield_plus` entries (absorb 100, 7 s); Mending heals 40 on a Shield cast, capped; a Guardian `hp` mult +0.1 raises max and current HP by the difference at the next step.
- `test_guardian_skills.gd`: existing M2 tests unchanged (placeholder Guardian).
- `test_determinism.gd`: a replay with a non-placeholder Guardian casting her signature and the Shield, same `state_hash` twice.
- Release bench `scripts/bench.ps1`: `pc_maze`, `pc_maze_combat`, `pc_combat_stress` within noise of `reports/perf_m2.md` (D-124); table in the PR. Expected neutral: a few integer compares on existing paths (tower hit, Guardian hit, death, cooldown reset).

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: `START_RUN` fields, Guardian skills (kinds, signature slot, cast-time modifiers, timed effects), `guardian_max_hp`, the guard, bounty and haste checks in combat, deaths and tower attacks; the state hash list.
- `DECISIONS.md`: D-146 PROPOSED (rules 1-6).

### Order
1. `RunData` kinds and fields, `START_RUN.guardian_id` (existing suites green). 2. Cast-time modifiers, cooldown clamp, Shield and Mending, `guardian_max_hp` and the HUD. 3. The five new kinds. 4. Tests, determinism, bench, docs, D-146; `scripts/test.ps1` twice, `scripts/validate.ps1`.

## Questions

## Review log
- 2026-10-10 lead-dev: approved and squash-merged PR #41. All criteria met and the code matches the plan (D-146 PROPOSED). GUT green and the validator passes; the release bench is within noise. Nit for the next task that touches `sim_modifiers.gd` (033): `skill_sums` line 39 has a broken line continuation (tabs where `\` plus a newline was meant). It is harmless.
