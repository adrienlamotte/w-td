# 013 — Sim: waves, spawn curve and bosses
- Status: done
- Milestone: M2
- Depends on: 011, 012
- PR: #18

## Goal
Drive spawns from the run data: 60 s waves with breaks, the spawn curve, mini-bosses at 5:00 and 10:00, the final boss at 15:00, and the horde continuing while she is alive.

## Context
- D-032 (break: no new spawns, the clock keeps running), D-093, D-096, D-097, D-047
- M1 `recycle_radius` stays for the benchmark only
- From 011's plan: `EnemyCatalog.max_radius` covers horde (non-boss) types only, so the grid cell stays small; separation scans `ri + max_radius`, which misses boss overlaps. When bosses spawn here, add a boss separation pass (each boss scans `r_boss + max_radius` and the horde loop skips boss pairs), with a test.

## Acceptance criteria
- Spawns follow the data timeline exactly; breaks spawn nothing; WaveStarted events.
- Enemies spawn outside the camera bounds on a seeded ring; mix from data.
- Mini-bosses at 5:00 and 10:00, final boss at 15:00; spawns continue after the boss (D-096).
- Tests: a simulated 16 minutes produces the expected wave count, boss spawns at the right ticks, determinism.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Order with 014: **013 first, then 014** (014 now depends on 013). Both change `SimWorld.step()` phases, `Phase`, `state_hash()`, the bench phase names and 3a's tick order; done in series they never conflict, and 014's DEATHS phase slots in before 013's SPAWN phase. Decision ID: **D-106**. No data or schema change except one validator rule.

### Rules (D-106 PROPOSED)
- Timeline on the run `clock` (D-100), integer ticks only. With `P = wave_ticks + break_ticks`: nothing before `first_wave_tick`; then `rel = clock - first_wave_tick`, wave `w = rel / P`, offset `t = rel % P`. `t == 0`: push `WAVE_STARTED` (a = w). `t < wave_ticks`: spawning; `t >= wave_ticks`: break, no spawns (D-032). Wave entry `e = min(w, waves - 1)` (last entry repeats, D-096/D-099); `w` itself keeps counting for the event.
- Even spread inside a wave ("continuous curve", 01 section 3): at offset `t` spawn `((t + 1) * n) / wave_ticks - (t * n) / wave_ticks` enemies (`n = wave_count[e]`, integer division), so exactly `n` per wave, none lost to rounding.
- Each spawn, in this RNG order from `_spawn_rng`: type by weighted pick over the entry's mix (`randf() * total weight`, walk the cumulative sum), angle `randf() * TAU`, radius `lerp(spawn_ring_min, spawn_ring_max, randf())`. hp from the catalog.
- Bosses: when `clock == boss_ticks[k]` spawn `boss_types[k]`; when `clock == final_boss_tick` spawn `final_boss_type`; same ring rule, whether in a wave or a break. Horde spawns go on after the final boss (D-096 falls out of the repeat rule).
- Only while RUNNING (IDLE never spawns, so the M1 demo/bench/tests are unchanged; `recycle_radius` stays bench/demo only).

### Files
1. `sim` (new) `game/sim/wave_spawner.gd`, `class_name WaveSpawner extends RefCounted`, stateless (everything derives from `clock` + `_spawn_rng`, so nothing new to hash): `static func step(clock: int, run: RunData, catalog: EnemyCatalog, enemies: SimEnemies, rng: RandomNumberGenerator, events: SimEvents) -> void` and `static func _spawn(type_id, run, catalog, enemies, rng)`. About 60 lines.
2. `sim` `game/sim/sim_world.gd`: `Phase` becomes `COMMANDS, SEPARATE, MOVE, SPAWN, GRID, TARGETING` (SPAWN after MOVE, before the single grid rebuild, D-083); in `step()` call `WaveSpawner.step(clock, run, ...)` if `run_state == RUNNING`, then `_lap(Phase.SPAWN)`. `phase_usec` / `phase_usec_sum` init with `resize(Phase.size())` instead of literals so later tasks do not touch them again.
3. `sim` `game/sim/enemy_separation.gd`: boss pass (from 011's plan). In the horde loop, a boss `i` is appended to `_bosses: PackedInt32Array` (cleared each call, no allocation after peak) and skipped; a boss `j` is skipped. Then for each boss `i` (ascending): scan the grid cells within `r_i + max_radius` and push every non-boss `j` (same pair formula and Jacobi buffers); then every later boss `b` in `_bosses` by a direct check (bosses are few). The per-enemy cap and apply pass are unchanged. About +30 lines.
4. `view` `game/view/bench/bench.gd`: `PHASES` gains `"spawn"` after `"movement"` (keep the names in `Phase` order).
5. `tools` `tools/validate_data.py`: a run's `spawn_ring_min <= spawn_ring_max`, with a case in `tools/tests`.

### Tests (`game/tests/sim/`)
- `test_wave_spawner.gd` (calls `WaveSpawner.step` directly on a bare `SimEnemies` for clock 0..28799, no movement, so 16 minutes cost under a second): `WAVE_STARTED` count == 13 (waves at 0, 75 s, ..., 900 s for `run_m2`) and at the expected clocks; per wave exactly `wave_count[e]` horde spawns; no spawn during any break tick; `run_m2` has 13 entries, so 16 minutes never repeat one: a second short case runs wave 13 (clock 29250 to 31049) and checks it spawns the last entry's count and mix (repeat rule); mini-bosses at clock 9000 and 18000, final boss at 27000, horde spawns after 27000 continue; every spawn radius in `[ring_min, ring_max]`; only types of the entry's mix spawn. A data sanity assert: `run_m2.spawn_ring_min > camera bounds_radius + bounds_margin`.
- `test_sim_world.gd`: StartRun then 1 step pushes `WAVE_STARTED` 0 and spawns; IDLE spawns nothing; `phase_usec.size() == Phase.size()`.
- `test_enemy_separation.gd`: a swarmer overlapping a boss beyond the horde reach (boss r 1.0 at origin, swarmer at 1.2) is pushed apart; two overlapping bosses are pushed apart; horde-only results unchanged (existing tests stay green).
- Determinism: two worlds, StartRun seed 7 `run_m2`, 2400 ticks (wave 0, break, start of wave 1) -> equal `state_hash`; seed 8 -> different.

### Performance
Spawning is a few adds per tick (n / wave_ticks, under 1 per tick in `run_m2`). The boss pass adds one branch per enemy in the hot separation loop plus a 3x3-cell scan per boss: negligible, but it is the hot loop, so the PR reports the M1 separation test timing before/after (headless). 023 re-benches with real spawns.

### Docs (same PR)
- `02_TECH_ARCHITECTURE.md` 3a: new "Waves and spawns" bullet (the rules above); tick order adds SPAWN between movement and grid; spatial hash and separation bullets: boss pass done (replace "task 013 gives bosses ..."). 
- `DECISIONS.md`: **D-106 PROPOSED** (timeline on the run clock, even integer spread, RNG draw order, ring rule, bosses on their tick in wave or break, SPAWN phase position, boss separation pass).
- Note for the owner: "outside the camera bounds" is taken as outside the pan bounds (`bounds_radius + bounds_margin` = 26 < ring 30). At the widest zoom near the pan edge the view reaches beyond 30, so some spawns can be seen popping in; ring and zoom are data, a CP-M2 playtest point.

### Order
1. `WaveSpawner` + `test_wave_spawner.gd`. 2. Wire SPAWN phase, phase arrays, bench names. 3. Boss separation pass + tests. 4. Validator rule. 5. Docs, D-106; `scripts\test.ps1` twice, `scripts\validate.ps1`.

Size: about 120 lines of code, about 150 of tests. One PR.

## Questions

## Review log
- 2026-10-09 lead-dev: approved, PR #18 squash-merged into m2/dev. Tests green twice (88 GUT + 13 Python), validator OK. Matches plan; one justified deviation: first spawn at offset 44 (even-spread formula with n=40, wave_ticks=1800; the plan wrongly expected one on the first tick), test adjusted. Boss pass correct (horde loop skips boss pairs, boss scan r_boss + max_radius, boss-boss direct). Bench release: pc_typical 6.59 / pc_stress 7.61 / pc_piled 10.32 ms per tick (spawn ~0, bench runs IDLE; 023 re-benches). needs-human:playtest (CP-M2): spawns may pop in at widest zoom near the pan edge (ring 30 vs pan bounds 26).
