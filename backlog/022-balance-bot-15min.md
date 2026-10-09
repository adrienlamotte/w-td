# 022 — Headless bot run: a 15-minute run is playable
- Status: review
- Milestone: M2
- Depends on: 013, 016, 017, 024, 026
- PR: #32
- Labels: needs-human:balance

## Goal
Prove the M2 run works end to end without a human: a simple scripted bot builds towers and uses skills; tune placeholder data so a run can be both won and lost.

## Context
- `06_ROADMAP.md` M2 'done when' (a full 15-minute run is playable start to finish)
- `02_TECH_ARCHITECTURE.md` 6 (balance runner proper is M3)

## Acceptance criteria
- A headless command runs N seeded runs with 2-3 simple bot strategies and writes `reports/balance_m2.md` (win rate, time of death, gold curve).
- Placeholder numbers tuned so a decent strategy usually wins and a passive one loses; changes stay in data.
- Marked needs-human:balance; the owner reviews at CP-M2.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan
Decision ID: **D-126** (PROPOSED: M2 balance bot and its targets, below). No sim rule change: bots are sim clients like `PlayerInput`, they only queue `SimCommand`s and read state and the read-only queries (`check_place`, `price`, `rebuild_price`). Tuning changes only `game/data`. This is the M2 precursor of the M3 balance runner (`02_TECH_ARCHITECTURE.md` 6).

### Lead-dev probe on m2/dev (2026-10-09, headless console exe, seed 11, not committed)
- Passive (nothing built): LOST at 0:47, under 1 s of wall time.
- A naive spread bot (cheapest tower whenever affordable, skills on cooldown): LOST at 4:20 with only 5 towers bought; gold income is clearly too low for the current prices. Max live enemies 37.
- Worst case for runtime: a Guardian that never falls and no towers, a full 15:00 (27000 ticks): **65 s** wall time, horde up to 2485 enemies. A run that kills enemies is cheaper; a passive run ends in about 1 s.
- So `N` runs cost at most about `2 strategies x N x 65 s` plus a few seconds: default **N = 5 seeds** (worst case about 11 min, expected well under). `-Runs` overrides it.

### Rules (D-126 PROPOSED)
- **Strategies** (`BalanceBot`, no randomness; acts every 15 ticks, 0.5 s):
  - all: cast every skill as soon as `skills.ready_at[slot] <= clock`; rebuild a husk before buying a new tower when `gold >= rebuild_price`;
  - `passive`: skills only, never builds (if this wins, towers are pointless);
  - `spread`: buys the run tower with the lowest current `price()` (ties: run order) at the next free spot of a sunflower spiral around the Guardian (first `check_place` OK, at most 64 candidates per act);
  - `ring`: a maze: a ring of towers at radius `RING_R` (7, bot constant) with one gap of `RING_GAP` (2 units) at angle 0, built from angle PI toward the gap on both sides, spacing = footprint side from `check_place`; once the ring is closed, extra towers on a sunflower around the inner side of the gap (the kill zone). Same cheapest-type rule.
- **Run:** StartRun `run_m2` with run seed `1..N`; stop on WON, LOST or `MAX_SEC` (1000 s: the final boss spawns at 900 s; a run still alive at 1000 s is a `timeout`, which counts as not won).
- **Metrics per run:** outcome, time of end (run clock), towers bought, husks rebuilt; every 60 s: gold on hand, gold earned (sum of the `ENEMY_DIED` event gold value, read after each step), towers alive, live enemies; wall time.
- **Targets for tuning:** the best of `spread` / `ring` wins at least 3 of 5 seeds (60 %), `passive` wins none. Placeholders, the owner reviews at CP-M2 (needs-human:balance).
- **What tuning may change:** placeholder numbers in `game/data` (enemy hp, speed, damage, gold drops; tower cost, cost_per_copy, damage, cooldown, range, hp; guardian hp; skills; starting gold; wave counts; boss hp). Not the decided structure: 60 s waves and 15 s breaks (D-093, D-032), mini-bosses at 5:00 and 10:00 (D-097), final boss at 15:00 (D-047). Change economy first (drops, starting gold, prices), then tower stats, then wave counts. Keep every changed file `placeholder: true`.

### Files
1. `tools` (new) `game/balance/balance_bot.gd`, `class_name BalanceBot extends RefCounted`: `_init(strategy: String)`, `act(w: SimWorld) -> void` (queues commands only). About 120.
2. `tools` (new) `game/balance/balance_runner.gd`, `extends SceneTree` (run with `-s`): parses user args `--runs N --out <path>`, runs every strategy x seed through `SimWorld.step()` (no `SimDriver`, no scene), collects the metrics, writes the Markdown report; static `run_one(strategy, seed, max_sec) -> Dictionary` and `report(results, runs) -> String` so tests call them. Exit code 0 even when targets are missed (the report says so). About 130.
3. `tools` (new) `scripts/balance.ps1`: `-Runs` (default 5); import like `test.ps1`, then `--headless --path game -s res://balance/balance_runner.gd -- --runs N --out <repo>/reports/balance_m2.md`; prints the summary table and total wall time. About 15.
4. `tools` `game/export_presets.cfg`: add `balance/*` to `exclude_filter` (not shipped).
5. `data` tuned placeholders in `game/data/{enemies,towers,runs,guardians,skills}` as the runs require.
6. Output `reports/balance_m2.md` (generated, committed): run date, commit, N, `MAX_SEC`, wall time per run; per strategy: wins / N, win rate, outcomes per seed, time of death (median, min, max) for losses, time of win; per strategy a per-minute table of the median gold earned, gold on hand, towers alive and live enemies across seeds; a **Data** section dumping the numbers the runs used (starting gold, guardian hp, per tower cost / cost_per_copy / damage / cooldown / range / hp, per enemy hp / speed / damage / gold drop, wave counts, boss hp) so the report always shows the tuned values; a targets line (met / not met).

### Tests
- `game/tests/balance/test_balance_bot.gd` (short runs, `max_sec` 60, so the suite stays fast):
  - determinism: `run_one("spread", 3, 60)` twice gives the same result dictionary (and the same final `state_hash()`);
  - bots only use commands: during a run the world gold never goes below 0 and every tower built came from a `TOWER_PLACED` event (no direct writes); `passive` builds nothing and its `SKILL_USED` count is > 0;
  - `spread` has placed at least one tower by 60 s; `ring` towers all sit at `RING_R` +- one footprint and none in the gap;
  - `report()` on a fixed fake results list contains the strategy rows, the win rates and the Data section.
- `scripts\test.ps1` twice, `scripts\validate.ps1` after tuning; `scripts\balance.ps1` once at the end, its report committed.

### Performance
Headless sim only, no rendering. Per act at most 64 `check_place` calls, every 15 ticks: negligible next to the step. The runner prints the wall time per run; if the default command goes over 15 min, lower the default N in `balance.ps1` and say so in the PR rather than optimise the sim here.

### Docs (same PR)
- `CLAUDE.md` Commands: replace "Balance simulation: _TBD in M3_" with "M2 balance bot: `scripts\balance.ps1` (`-Runs N`, default 5; headless bot runs of `run_m2`, writes `reports/balance_m2.md`, about 5-11 min). The full balance simulation is M3."
- `02_TECH_ARCHITECTURE.md` 6 Balance runner: the M2 bot (strategies, metrics, where it lives, not exported).
- `DECISIONS.md`: **D-126 PROPOSED** (strategies, targets, what tuning may change). needs-human:balance at CP-M2.

### Order
1. `BalanceBot` (passive, spread, ring) and `run_one`, tests. 2. Metrics and `report()`, test. 3. `balance.ps1`, export filter. 4. Run, tune data in small steps (economy first) until the targets hold, rerun. 5. Commit the final report, docs, D-126; tests twice, validator.

Size: about 265 lines of code (+ data), about 100 of tests. One PR. Out of scope: card or XP strategies (M3), nightly scheduling (M3), DPS curves (M3), optimising the sim for the runner.

## Questions

## Review log
- 2026-10-09 Review round 1 (lead-dev): changes needed, bot code only.

Checked: 247/247 GUT + Python tests green, validator 0 errors. Bots use only `SimCommand`s plus the read-only `check_place` / `price` / `rebuild_price`; `balance/*` is excluded from export; data changes are placeholders (`placeholder: true`), timings D-093 / D-032 / D-097 / D-047 untouched; the report is clear. Those parts are fine.

Required fix: the `ring` bot must be a real maze strategy (the maze is M2's core hook, D-101). Today the ring sits at radius 7, outside the useful range of the towers (5-6), and it does nothing until it is closed (about 40 towers), so it loses at 3:35 with 8 towers. That tests the bot, not the game.

1. `game/balance/balance_bot.gd`, kill zone first: the first `KILL_ZONE_FIRST` towers (bot constant, 6) go on the existing kill-zone sunflower inside the gap (corridor kept open); only then the ring, then any extras back on the kill zone.
2. `RING_R` = 4.0 (bot constant; the smallest run tower range 5 minus the Guardian contact radius 1), so every ring tower covers the Guardian and the corridor. Gap, spacing and build order unchanged.
3. Test `test_ring_towers_on_the_ring_and_not_in_the_gap`: every ring tower is on the ring at `RING_R` +- one footprint or a kill-zone tower; none is in the gap or the corridor (`p.x > 0` and `|p.y| < RING_GAP * 0.5`, beyond the ring and inside it); the first 6 towers are kill-zone towers.
4. No data or rule changes in this round. Re-run `scripts\balance.ps1` (N = 5), commit the new `reports/balance_m2.md`; targets must still hold (best builder >= 60 %, passive 0). Whatever ring scores, report it honestly. If ring now beats spread, or loses only to the boss, say so in the PR.
5. Docs in the same PR: `02_TECH_ARCHITECTURE.md` 6 and the D-126 row (radius 4, kill zone first), and the PR description results table.
6. Tests twice, validator.
