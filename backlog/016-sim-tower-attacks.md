# 016 — Sim: the 3 tower attacks
- Status: done
- Milestone: M2
- Depends on: 015
- PR: #22

## Goal
The three M2 tower types fight: ranged single target, splash, slow.

## Context
- D-117 (owner, 2026-10-09): Q-57 answered with the plan's default (no stacking, strongest slow applies, refresh to the longer duration).
- D-045, D-098 (instant hit)
- Targeting from M1 (nearest in range, D-085)
- From 014's plan (D-107): all damage goes through `SimWorld.damage_enemy(i, amount)`; tower attacks run in the ATTACKS phase before the enemy attacks; a tower skips a target with `hp <= 0` (killed earlier in the same phase; corpses are removed in the next tick's DEATHS phase).
- From 014 review: the determinism test must count `ENEMY_DIED` over the whole run (events are cleared each step) and assert at least one tower kill; 014's `test_determinism_with_combat` does not. From 015 (D-109): husks have `target == -1` and never fire.

## Acceptance criteria
- Each type attacks on its cooldown with instant hits: single target damage; splash damage around the target; slow applies a timed speed reduction (does not stack beyond the data rule).
- EnemyHit and EnemyDied events; slow affects movement in the tick order.
- Tests per type; determinism.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-114**. No data or schema change: `TowerCatalog` already loads `attack, damage, cooldown` (ticks), `splash_radius, slow_factor, slow_ticks`. Open question **Q-57** (slow stacking) added; it does not block: its ★ default is used below as a placeholder and named in D-114.

### Rules (D-114 PROPOSED)
- **When**: in the ATTACKS phase, only while RUNNING, **towers first, then enemies** (`_enemy_attacks`), so an enemy killed by a tower this tick does not attack. Towers in index order. Skipped: bare towers (`type_id < 0`: M1 demo and bench towers never fire) and husks.
- **Cooldown** (new tower array, ticks, 0 at placement and at rebuild): each live built tower decrements it if > 0; then if it is 0 and `target >= 0` and the target is alive (`enemies.hp[target] > 0`), the tower fires and resets it to `cooldown[type]`. First shot as soon as a target is in range, then one every `cooldown` ticks. A target killed earlier in the same phase (another tower) is not shot: the tower holds (cooldown stays 0) and fires next tick at its new nearest target; no in-phase retarget.
- **Shot** (instant, D-098): push `TOWER_FIRED` (new event, appended to the enum: a = tower uid, x, z = target position, value = tower type) for the view's shot effect (019), then by attack:
  - `SINGLE`: `damage_enemy(target, damage)`.
  - `SPLASH`: every enemy whose **centre** is within `splash_radius` of the target's centre, target included, takes `damage` (no falloff): `grid.query_radius` (ascending index; the grid is fresh, TARGETING ran on it), each through `damage_enemy` (corpses ignored).
  - `SLOW`: `damage_enemy(target, damage)`, then the slow on the target (bosses too: no exemption in data, placeholder).
- **Slow (Q-57 ★ A, placeholder)**: enemy arrays `slow_factor` (1 = none) and `slow_ticks` (0 = none). On a hit with `(f, n)`: if `slow_ticks == 0` or `f < slow_factor`, `slow_factor = f`; `slow_ticks = max(slow_ticks, n)`. No stacking: the strongest applies, a hit refreshes the duration to the longer. In MOVE, `advance()` moves a slowed enemy (`slow_ticks > 0`) at `speed * slow_factor`; at the end of each live enemy's advance (moving or not) `slow_ticks -= 1` if > 0, and `slow_factor = 1` when it reaches 0. A hit in tick T slows exactly the `n` MOVE phases of ticks T+1..T+n.
- Every damage goes through `damage_enemy` (`ENEMY_HIT` per enemy hit); deaths are removed in the next DEATHS with their gold (D-107).

### Files
1. `sim` (new) `game/sim/tower_attacks.gd`, `class_name TowerAttacks extends RefCounted`: `_hits: PackedInt32Array` (splash buffer, no allocation after peak); `fire(w: SimWorld)` (the loop above); `static apply_slow(enemies, i, factor, ticks)` (the Q-57 rule, tested directly). About 60 lines.
2. `sim` `game/sim/sim_towers.gd`: `cooldown: PackedInt32Array` (0 in `add`, swapped in `remove`). About +4 lines.
3. `sim` `game/sim/tower_building.gd`: `rebuild` resets `cooldown[t] = 0`. +1 line.
4. `sim` `game/sim/sim_enemies.gd`: `slow_factor: PackedFloat32Array` (1.0 in `add`), `slow_ticks: PackedInt32Array` (0), both in `remove`. About +8 lines.
5. `sim` `game/sim/enemy_movement.gd`: `advance()` applies the slow factor and counts the slow down (it already takes `enemies`). About +8 lines.
6. `sim` `game/sim/sim_events.gd`: `Kind.TOWER_FIRED` appended at the end.
7. `sim` `game/sim/sim_world.gd`: `tower_attacks := TowerAttacks.new()`; ATTACKS phase: `tower_attacks.fire(self)` then `_enemy_attacks()` (both inside the RUNNING check); `state_hash()` adds `towers.cooldown, enemies.slow_factor, enemies.slow_ticks`. About +5 lines.

### Tests (`game/tests/sim/test_tower_attacks.gd`; StartRun `run_m2`, gold set directly, towers placed with PlaceTower, enemies with `enemies.add`, `world.guardian_hp` raised where enemies would end the run)
- Single: one swarmer in range: `TOWER_FIRED` (uid, target position, type) and `ENEMY_HIT` value `damage` in the first step; the next shot exactly `cooldown` ticks later, none in between (count steps between hits). No enemy in range: no shot, cooldown stays 0, and the shot comes in the very step an enemy enters range.
- Not firing: a husk (after `damage_tower` kill), a bare `towers.add()` tower, an IDLE world with a placed-like bare tower, a paused run.
- Kill: an enemy with `hp <= damage` is gone after the next step with `ENEMY_DIED` and its gold.
- Hold: two single towers, one swarmer with `hp <= damage` in both ranges plus a second swarmer only in the second tower's range but farther: tower 0 kills the first, tower 1 does not shoot the corpse (one `ENEMY_HIT` that tick, tower 1 cooldown still 0), and shoots the next tick.
- Splash: target, an enemy within `splash_radius` of the target (outside the tower's own range is fine) and one just outside: the first two get `ENEMY_HIT`, the third nothing; a corpse inside the splash gets no event.
- Slow: after a hit `slow_factor == slow_factor[type]`, `slow_ticks == slow_ticks[type]`; the enemy moves `speed * dt * factor` per tick for exactly `slow_ticks` ticks, then full speed (measure with no tower in range after the hit: move the tower out by selling it); a second hit keeps the factor (no 0.25) and resets the duration. `apply_slow` directly: a stronger factor replaces a weaker one, a weaker one keeps the stronger factor and extends the ticks to the max.
- Determinism (014 review note): two worlds, StartRun seed 7, one tower of each type placed at about 4 units from the Guardian, `guardian_hp` raised, 900 steps; **sum `ENEMY_DIED` over every step** (events are cleared per step) and assert it is > 0 (towers are the only damage source before 017), equal `state_hash()` and equal death counts for seed 7 twice; seed 8 gives a different hash.

### Performance
Per tick: a decrement and two compares per tower (300 at most). A shot costs a `damage_enemy`; a splash shot one `query_radius` of 1.5 units. Placeholder cooldowns give at most about 300 / 15 = 20 shots per tick at the 300-tower stress case. Slow adds one compare per enemy in `advance()`. Expected well under 0.2 ms per tick. The bench's bare towers do not fire, so the current bench numbers do not move; task 023 benches combat.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: events table adds `TOWER_FIRED`; entity arrays add tower `cooldown`, enemy `slow_factor, slow_ticks`; new "Tower attacks" bullet (the rules above); Enemy movement: advance applies the slow; tick order (5): towers then enemies; the Towers bullet loses "No attacks yet".
- `DECISIONS.md`: **D-114 PROPOSED** (the rules above; Q-57 ★ and "bosses are slowed" named as placeholders).

### Order
1. Arrays (tower cooldown, enemy slow) with add/remove. 2. `TowerAttacks.fire` single + cooldown + hold rule, tests. 3. Splash, tests. 4. Slow (`apply_slow`, advance), tests. 5. Hash, determinism with the kill count. 6. Docs, D-114; `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 95 lines of code, about 200 of tests. One PR. Merges with 024 in `sim_enemies.gd`, `enemy_movement.gd` and `state_hash()`: whichever lands second rebases.

## Questions

## Review log
- 2026-10-09 lead-dev: PR #22 approved and squash-merged into m2/dev. Matches the plan and D-114/D-117; sim-only, typed, all damage through damage_enemy, hash extended, determinism test counts ENEMY_DIED per step (> 0). test.ps1 138/138 + tools OK, validate 0 errors (reviewer run). Bench towers are bare, so attack cost is unmeasured until 023. needs-human:balance at CP-M2 (placeholder damage/cooldown/splash/slow, bosses slowed).
