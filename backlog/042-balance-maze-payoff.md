# 042 — Balance: tune M3 so the maze pays off
- Status: planned
- Milestone: M3
- Depends on: 041
- Labels: needs-human:balance
- PR:

## Goal
Tune placeholder numbers (data only) until the runner meets the M3 targets, the main one being that a maze beats spreading towers (D-128).

## Context
- D-143 (owner, 2026-10-09) answers Q-69.
- D-128; D-126 (tuning order: economy first, then tower stats, then wave counts; never the fixed timeline D-093, D-032, D-097, D-047); the task 041 report.
- Q-69 (target numbers).

## Acceptance criteria
- The Q-69 targets met over N seeds per Guardian for the `fresh` and `full` presets; report committed; every changed number listed in the PR and in a PROPOSED decision.
- Data changes only; a needed rule change becomes an open question.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan
Lead-dev, 2026-10-10. Decision **D-168** (PROPOSED, reserved here): the tuned numbers, listed old -> new, plus the measurement rules below. Data, docs and the report only: no `sim/`, `view/` or `input/` change, no bot or runner change (D-164 stays as merged). Code diff about 0 lines; tests change only where they hard-code a placeholder number.

### Starting point (041 report, 1 seed)
maze 9/9, spread 9/9, passive 0/9, every win at about 15:30; spread keeps the Guardian at full HP all run (no pressure at all); Pip deals 87-100 % of the damage. Two causes: (1) the horde never threatens a spread, so the maze has nothing to win; (2) Pip (12 dps for 50 gold, cheapest upgrades) out-values every other kind, and in `full` the maze bot builds only its pair (Bastia + Pip), so nerfing Pip also weakens that maze. The bot's cheapest-first spending also buys Bastia hp upgrades (30 gold) before Pip ones.

### Measurement (D-168)
- **Screening run** (each iteration): `--only spread,maze --profiles fresh,full --runs 2` (36 runs, about 12-15 min), report written to the session scratchpad (`--out`), never committed. Call the runner directly: `& $env:GODOT --headless --path game -s res://balance/balance_runner.gd -- --runs 2 --only spread,maze --out <scratch>\iter_<k>.md --commit <sha>`.
- **Final run:** `scripts\balance.ps1 -Runs 4` (all strategies, 108 runs, about 35-45 min). N = 4 because `fresh` has 3 Guardians: 12 runs per strategy, so 50-80 % is 6-9 wins (with N = 2, 5/6 = 83 % already fails). This report is the one committed.
- **Targets (gate, D-143):** per profile maze win rate - spread win rate >= 20 points; maze 50-80 % on `fresh`, >= 80 % on `full`; passive 0.
- **Health goal (not a gate, reported):** on `full`, Pip <= 60 % of damage in both builder strategies and at least two other sources >= 10 % in `spread`. If the gate is met and this is not, say so in the PR; the owner decides at CP-M3.

### Levers (data only, D-126 order: economy, then tower stats, then wave counts)
Never touch the fixed timeline: `wave_sec`, `break_sec`, `first_wave_sec`, boss and final-boss `at_sec` (D-093, D-032, D-097, D-047). Prefer files only `run_m3` uses (`runs/run_m3.json`, the 8 M3 towers, cards, synergies, meta nodes, the 6 named Guardians). The enemy files are shared with `run_m2` and the bench (`bench_m1` combat uses `run_m2`): change them only if the run_m3 levers are not enough, and then note it for 043 (perf re-bench). More enemies per wave raise the per-tick cost: prefer enemy hp over wave counts; flag any wave-count increase over +25 % for 043.
1. **Pressure / economy:** `run_m3` `starting_gold`, meta gold nodes (`meta_gold_1/2`, `meta_kill_gold`), `perk_bounty`, `card_purse`. Aim: spread starts losing (its Guardian hp curve dips) on `fresh`.
2. **Tower stats (the layout must pay):** Pip down (damage, upgrade damage, maybe cost up); other damage kinds up (Cinder damage / splash, Tansy, Clover); slows (Mallow, Tansy `slow_sec` / `slow_factor`) up, since slow time scales with path length; Bastia cheaper to place (`cost`, `cost_per_copy`) and dearer to upgrade, so a maze is cheap and gold goes to damage; `perk_maze` `detour_damage` up; relationship bonus values (`syn_bff_pip_mallow`, `syn_mentor_bastia_pip`, `syn_rivals_mallow_cinder`) up.
3. **Wave counts / mix** in `run_m3` (counts, brute and ranged weights) to set the final difficulty once 1 and 2 have shaped the maze-vs-spread gap.

### Iteration loop (bounded)
- Iteration 0: screening run on the unchanged branch (2-seed baseline).
- Each iteration: one lever group changed, one screening run, one line in the PR body iteration log: `k | files: old -> new | fresh maze/spread | full maze/spread | Pip share full`.
- Phase A (lever 1, then 3 if needed) until spread loses some `fresh` runs; phase B (lever 2) until the maze lead appears; phase C retunes pressure (lever 1 or 3) into the 50-80 % / >= 80 % bands; then the final run. If the final misses a target by one run, at most 2 more iterations and one more final run.
- **Budget:** at most 10 screening iterations and 2 final runs (about 4 h of runner time).
- **Stop condition:** stop early if after iteration 6 the maze lead is still <= 0 points on both profiles (the layout does not pay with these rules), or when the budget is spent. Then commit the best data set and its final `-Runs 4` report, open the PR marked "D-143 targets NOT met" with the iteration log, and do not tweak further. The lead-dev review decides whether the partial tuning merges; the task goes `blocked` on **Q-80** (the rule the owner picks becomes a new sim task, then 042 resumes).

### Files
- `game/data/runs/run_m3.json`, `game/data/towers/tower_{pip,mallow,cinder,bastia,clover,tansy,hymn,poppy}.json`, `game/data/cards/*.json`, `game/data/synergies/*.json`, `game/data/meta/*.json`, `game/data/guardians/guardian_{bastia,cinder,clover,hymn,tansy,poppy}.json` (**data**): numbers only, no new fields, no new files, schemas unchanged. Enemy files only per the rule above.
- `game/tests/**` (**tests**): a test that breaks only because it hard-codes a changed placeholder number reads the number from the data (preferred) or gets the new value; no test logic removed. Golden `state_hash` values on `run_m3` are re-recorded only if they fail, with a line in the PR saying which and why. No new system, so no new test is required.
- `reports/balance_<date>.md` (**report**): the final `-Runs 4` report.
- Docs: `docs/10_M3_CONTENT.md` 3.2 table and every other table or sentence quoting a changed number (cards, synergies, meta nodes, the "Pip, Mallow and Cinder level 1 are exactly the M2 values" sentence if no longer true); `docs/DECISIONS.md` D-168 PROPOSED (every changed number old -> new, screening and final N, the health goal, needs-human:balance at CP-M3); `docs/plans/M3.md` row.

### Steps
1. Branch `task/042-balance-maze-payoff` from `m3/dev`; iteration 0 baseline.
2. Phases A-C as above, one commit per iteration (`042: iter k <lever>`), so any step can be reverted.
3. Final `scripts\balance.ps1 -Runs 4`; commit the report.
4. Tests green twice (`scripts\test.ps1`), validator green (`scripts\validate.ps1`); docs and D-168; PR into `m3/dev` with the changed-number table and the iteration log.

Performance: no code change; only enemy counts can move the per-tick cost (rule above, re-measured in 043).

## Questions
- **Q-80** (not blocking; needed only if the stop condition fires): which rule change if data alone cannot make the maze pay off. Defaults taken by lead-dev in D-168 (owner may change them at CP-M3): final N = 4 seeds; the Pip-share health goal is reported, not gated; shared enemy files are touched only as a last resort.

## Review log
