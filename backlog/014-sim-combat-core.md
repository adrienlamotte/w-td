# 014 — Sim: enemy HP and death, Guardian HP, gold, win and lose
- Status: blocked
- Milestone: M2
- Depends on: 011, 012, 013, 025
- PR: -

## Goal
Make the run winnable and losable: damage, deaths, Guardian contact, ranged enemies, automatic gold.

## Context
- D-043 (enemies attack what blocks their straight path, else the Guardian; with the maze, D-101 to D-103, pathing and tower attacks by walled-in enemies are task 024: here enemies only target the Guardian), D-094 (gold on death), D-098 (instant hit), D-047 (win by killing the final boss)
- M1 placeholder to replace: enemies stopped at their own radius (no Guardian contact radius)

## Acceptance criteria
- Enemies have HP; deaths remove them with events and add gold immediately (D-094).
- Guardian has HP and a contact radius from data; melee enemies stop at contact and attack on a cooldown.
- Ranged enemies stop at their attack range from their target and hit instantly on a cooldown (D-098).
- Lose when Guardian HP reaches 0; win when the final boss dies; RunEnded event.
- Tests for each rule; determinism with combat.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Depends on **013** too (series, see 013's plan): it builds on 013's phase list and `WaveSpawner`. Decision ID: **D-107**. No data or schema change (Guardian hp/contact radius, enemy damage/range/cooldown/gold, starting gold are all in 011's data).

Maze note (D-101 to D-105): this task keeps the straight-line chase, but splits movement into **steer** (direction + remaining gap, per enemy) and **advance** (move along it, stop, switch state). Task 024 replaces only `steer()` with the flow field (and, when walled in, steers to the blocking tower and adds a per-enemy attack target); `advance()`, the cooldowns and the death/gold/win/lose rules stay as they are.

### Rules (D-107 PROPOSED)
- **Stop distance** per enemy type: `stop = guardian contact_radius + enemy radius + attack_range` (range is measured between the two bodies' edges; `attack_range` 0 = melee = contact). Before StartRun (IDLE) the contact radius is 0, so the M1 demo/bench keep today's "stop at own radius" behaviour.
- **Steer** (each live enemy, each tick): `d` = distance to (0, 0), `dir = -pos / d` (0 if `d < 1e-6`), `gap = d - stop`.
- **Advance**: `gap <= 0`: `ATTACKING`, no move (never pushed outward by movement); `0 < gap <= speed * dt`: move by `gap` and become `ATTACKING` in the same tick; else move `speed * dt`, `MOVING`. State is re-evaluated every tick (no longer sticky): an attacker pushed out of range by separation walks back in; enemies held behind the front row do not attack. `SimEnemies.State.AT_GUARDIAN` is renamed `ATTACKING` (024 reuses it for tower attacks).
- **Enemy attacks** (only while RUNNING): per-enemy `cooldown` (ticks, 0 at spawn). Each tick for each enemy with `hp > 0`: if `cooldown > 0` decrement; else if `ATTACKING`: hit the Guardian for `damage[type]` (instant, D-098, melee and ranged alike) and set `cooldown = attack_cooldown[type]`. So the first hit lands on arrival, then one per cooldown. Hits go through one `_hit_guardian(type, x, z, dmg)` (017 inserts the Shield there): `guardian_hp -= dmg`, push `GUARDIAN_HIT`. When `guardian_hp <= 0`: `run_state = LOST`, push `RUN_ENDED` (a = 0), stop the loop.
- **Damage and death**: `SimWorld.damage_enemy(i, amount)` is the single entry point for every damage source (016 towers, 017 Area blast): ignored if `hp[i] <= 0`; else `hp -= amount`, push `ENEMY_HIT`. A killed enemy stays in the arrays (inert: no move, no attack, never retargeted) until the **DEATHS** phase of the next tick, which scans from the highest index down, swap-removes every `hp <= 0` enemy (descending order keeps the other indices valid, D-081), rolls gold (`chance >= 1` or `_loot_rng.randf() < chance`; new RNG `hash([seed, "loot"])` in `_seed_rngs`), adds it to `gold` at once (D-094) and pushes `ENEMY_DIED` (value = gold gained). Why not remove at once: removals before the single grid rebuild keep D-083 (one rebuild per tick); removing after the attacks would force a second rebuild. Cost: death events and removal arrive one tick (33 ms) after the killing hit; 019 hides `hp <= 0` enemies.
- **Win**: in DEATHS, if a removed enemy's type is `run.final_boss_type`: `run_state = WON`, push `RUN_ENDED` (a = 1) after its `ENEMY_DIED` (gold still counted). Mini-bosses never win. If the Guardian dies in the same tick the boss's lethal hit lands, the run is LOST (the frozen world never reaches the next DEATHS phase).
- Guardian state: `guardian_hp` and `gold` set from `run.guardian_hp` / `run.starting_gold` at StartRun.

### Files
1. `sim` (new) `game/sim/enemy_movement.gd`, `class_name EnemyMovement extends RefCounted`: `dir_x, dir_z, gap: PackedFloat32Array` (resized to the enemy count each tick, no allocation after peak), `stop_dist: PackedFloat32Array` per type; `set_stop(catalog, contact_radius)`, `steer(enemies)`, `advance(enemies, speed, dt)`. Corpses (`hp <= 0`) are skipped. Replaces `SimEnemies.chase_guardian` (deleted). About 60 lines.
2. `sim` `game/sim/sim_enemies.gd`: `cooldown: PackedInt32Array` (0 in `add`, swapped in `remove`); rename `AT_GUARDIAN` -> `ATTACKING`; drop `chase_guardian`.
3. `sim` `game/sim/sim_world.gd`: `Phase` = `COMMANDS, SEPARATE, MOVE, DEATHS, SPAWN, GRID, TARGETING, ATTACKS`; `movement := EnemyMovement.new()` with `set_stop(catalog, 0.0)` in `_init` and `set_stop(catalog, run.guardian_contact_radius)` at StartRun; `guardian_hp: float`, `gold: int`, `_loot_rng`; `damage_enemy()`, `_deaths()`, `_enemy_attacks()`, `_hit_guardian()`; StartRun sets hp/gold; `_recycle` uses `ATTACKING`. DEATHS runs in every state that simulates (IDLE included: nothing dies there without damage); ATTACKS only while RUNNING and returns as soon as the run is LOST. `state_hash()` adds `guardian_hp, gold, _loot_rng.state, enemies.cooldown`. About +80 lines.
4. `view` `game/view/bench/bench.gd`: `PHASES` gains `"deaths"` (after `"movement"`) and `"attacks"` (last), in `Phase` order.

### Tests (`game/tests/sim/`)
- `test_enemy_movement.gd` (the chase tests move here from `test_sim_enemies.gd`): moves `speed * dt` toward the origin, diagonal too; IDLE swarmer stops at its own radius (M1 behaviour); after StartRun a swarmer stops at `contact + radius`, a ranged enemy at `contact + radius + attack_range` (1 + 0.35 + 6 in `run_m2`); an attacker pushed out by 0.05 walks back and is `ATTACKING` in that same tick; an enemy farther than one step from its stop point stays `MOVING`; a corpse does not move.
- `test_combat.gd`: `damage_enemy` lowers hp and pushes `ENEMY_HIT` (type, position, amount); a hit on a corpse does nothing; a killed enemy is still present after the killing tick and gone after the next step, with `ENEMY_DIED` and the gold (boss: 100 at chance 1) added to `gold`; two deaths in one tick remove the right enemies (the survivors' positions are kept); gold starts at `starting_gold`; a melee enemy at contact hits on arrival then every `attack_cooldown` ticks (`GUARDIAN_HIT` with its type and damage); a ranged enemy hits from range; IDLE: enemies at the Guardian never hit; lose: `guardian_hp` set to 1, one attacker -> LOST, exactly one `RUN_ENDED` (a = 0), then the world is frozen (positions unchanged, `clock` stops); win: add one `run.final_boss_type` enemy, kill it -> next step WON, `ENEMY_DIED` then `RUN_ENDED` (a = 1), gold counted; a mini-boss death does not win.
- Determinism with combat: two worlds, StartRun seed 7, real waves from 013, `damage_enemy(0, 5)` on every 10th tick from the test, 3000 ticks (enemies reach the Guardian and hit her) -> equal `state_hash`, and `guardian_hp < run.guardian_hp` (combat actually happened); seed 8 -> different.
- Existing tests: `AT_GUARDIAN` -> `ATTACKING` in `test_sim_enemies.gd` / `test_sim_world.gd`; `test_sim_world` phase count uses `Phase.size()` (013).

### Performance
Movement becomes two passes (steer, advance) instead of one, and the piled crowd is no longer skipped once arrived (state is re-evaluated each tick): about two extra `sqrt` loops over 3000 enemies, est. 0.3-0.6 ms per tick in headless debug. DEATHS is one compare per enemy; ATTACKS one compare/decrement per enemy. The PR reports the MOVE + DEATHS + ATTACKS phase times with 3000 piled enemies (headless, like `test_separation_cost_3000_piled`); 023 re-benches and may fuse steer/advance if the budget needs it.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: replace the "Enemy movement (placeholder)" bullet (steer/advance, stop distance, non-sticky state, the 024 seam); new "Combat" bullet (damage entry point, corpse until the next DEATHS, gold and the loot RNG, enemy attacks and cooldown, the `_hit_guardian` hook for 017, win/lose and their tie rule); entity arrays add `cooldown`; tick order lists all 8 phases; run state: who sets WON/LOST.
- `DECISIONS.md`: **D-107 PROPOSED** (the rules above).

### Order
1. `EnemyMovement` + move the chase tests; rename the state. 2. Enemy cooldown, ATTACKS, `_hit_guardian`, lose. 3. `damage_enemy`, DEATHS, gold, loot RNG, win. 4. Hash, bench names, determinism test. 5. Docs, D-107; `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 170 lines of code, about 220 of tests. One PR.

## Questions
**Q1 (blocking): the non-sticky ATTACKING state makes a piled crowd collapse.** Implemented as planned on `task/014-sim-combat-core` (WIP commit pushed, no PR). With the state re-evaluated each tick, every enemy behind the front row keeps walking inward forever (in M1 they latched `AT_GUARDIAN` one by one and the crowd relaxed). Measured:
- `test_crowd_stays_soft_not_collapsed` fails: min pair distance 0.014 (bound 0.14, was 0.164); D-079 says "overlap slightly".
- Separation cost explodes with the density: headless debug `test_separation_cost_3000_piled` 79.9 ms/tick (was 25-38); release bench `pc_piled` step 54.9 ms (separation 50.8 ms, 4.5 FPS; was about 6 ms), `deck_piled` 15.2 ms. `pc_typical` 4.87 ms and `pc_stress` 5.72 ms are fine (movement 0.47, deaths 0.03 ms).
- Tried a walk-back threshold (an ATTACKING enemy only walks back if pushed out by more than its radius): no help (min distance 0.027, 64.5 ms debug).
- Other phases are cheap: 3000 piled during a run, move 0.60, deaths 0.05, attacks 0.20 ms/tick (headless debug).

Options:
- A ★ Queue behind the front: an enemy also stops (stays `MOVING`, does not attack) when it overlaps a neighbour that is closer to the Guardian and already stopped. The separation pass already visits every overlapping pair, so it can set a per-enemy `blocked` flag that `advance()` reads next tick. Keeps the D-079 soft crowd and the M1 cost; 024's flow field keeps the same rule. About +20 lines, one new test.
- B Back to the M1 latch: once ATTACKING an enemy never moves by itself (pushed-out attackers keep attacking from where they are). Smallest change; the "walks back in" acceptance point is dropped; whether the back rows still pile at a contact ring of 1.35 is unmeasured.
- C Keep the plan, lower the crowd test bound and leave the cost to 023 (cap the pushes per enemy). `pc_piled` stays at about 55 ms per tick until then.

Notes on the WIP (no decision needed, for the reviewer):
- Attack cooldown: the plan's literal order (decrement, else hit) gives one hit every `attack_cooldown + 1` ticks; the WIP decrements first, then hits at 0, so hits land on arrival and then exactly every `attack_cooldown` ticks.
- Determinism-with-combat test: `damage_enemy(0, 5)` every 10th tick kills wave 0 faster than it spawns (nobody reaches the Guardian); the WIP uses 1 damage.
- Since 025 the code the plan relies on did not move (cell size change only); no adaptation needed.

## Review log
