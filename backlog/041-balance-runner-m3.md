# 041 — Balance: M3 headless runner and first balance report
- Status: review
- Milestone: M3
- Depends on: 032, 033, 034, 035, 045
- Labels: needs-human:balance
- PR: #50

## Goal
The full balance runner: bots that build, upgrade and pick cards, a maze strategy against a spread strategy, profile presets, and the first M3 balance report.

## Context
- `docs/02_TECH_ARCHITECTURE.md` 6 (M2 bot, D-126: deterministic sim clients that only queue commands and use read-only queries; `scripts\balance.ps1`), `docs/04_AGENT_WORKFLOW.md` 5 (nightly balance routine, `reports/balance_<date>.md`).
- D-128 (the maze must pay off: the report shows maze vs spread), `docs/10_M3_CONTENT.md`.
- Q-69 (numeric targets) blocks only the tuning task 042; this task reports the numbers.

## Acceptance criteria
- Bots `passive`, `spread`, `maze` (a corridor layout with walls and relationship pairs along the walls); each picks cards by a fixed deterministic priority, buys upgrades and rebuilds husks.
- Profile presets: `fresh` (nothing rescued, no meta) and `full` (all 6 rescued, whole tree), with each Guardian of the offer.
- `reports/balance_<date>.md`: win rate, death and win times, per-minute curves (as M2) plus level, cards picked, upgrades, active relationships and damage per tower kind; a maze vs spread summary line.
- `scripts\balance.ps1` runs it; a smoke test runs one short run headless.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan
Lead-dev, 2026-10-10. Decision **D-164** (PROPOSED, reserved here): the M3 bot policies, run matrix, damage attribution and report below; they replace the M2 runner (D-126). No sim change: the bots stay sim clients (commands + read-only queries + events). About 350 changed lines of code, report and data excluded: one PR.

### Design (D-164)
- **One runner, run_m3 only.** `balance_runner.gd` plays `run_m3`; `reports/balance_m2.md` stays as the M2 record and is no longer regenerated. The `ring` strategy is replaced by `maze` (a ring is a one-ring maze); its tests go with it.
- **Matrix:** strategies `passive`, `spread`, `maze` x profiles x the Guardians of each profile's offer x seeds `1..N`.
  - `fresh`: `MetaProfile.fresh(cat)` (nothing rescued, no meta nodes): `offer()` = the first 3 Guardians in offer order.
  - `full`: every Guardian rescued (`unlocked` = `cat.offer_order`) and every meta node (`meta_nodes` = `cat.ids`): `offer()` = all 6.
  - The StartRun comes from `MetaProfile.start_command(cat, 0, seed, "run_m3", waifu)` (the hub's own path, D-152). 3 x 9 x N runs; `scripts\balance.ps1 -Runs N`, **default 2** (54 runs). `--only <strategies>` stays; add `--profiles fresh,full` (same parsing).
- **Card picks (all bots):** the open draft's slot whose card ranks first by `CardCatalog.Type` order `NEW_TOWER`, `SIGNATURE`, `SKILL`, `PERK`, `FILLER`, ties by lower card index. Fixed, so strategies stay comparable.
- **Spending (spread and maze), one build command per act (every 15 ticks, as M2):** rebuild the first affordable husk; else the cheaper of (a) the next placement and (b) the cheapest upgrade with `TowerUpgrade.check(...).reason == OK` (lowest uid on ties); ties go to the placement; no spot left, upgrade only. Skills: every ready skill, as M2.
- **spread:** sunflower around the Guardian (M2 code); tower type = the next in run tower-type order, round robin, skipping `wall` kinds (a lone wall does nothing in a spread); waits for gold rather than skipping a type.
- **maze:** corridor layout of concentric rings `MAZE_RINGS` = [4, 7, 10] (walls 1 unit thick, corridors about 2 units, inside every tower's range), one `MAZE_GAP` = 2 gap per ring, gaps alternating at angle 0 and PI (the bench maze shape, D-115), the inner ring first, each ring built from the side opposite its gap toward the gap (the M2 ring order). Slot k of a ring gets `pair[k % 2]`; the pair is recomputed at each placement from the run's buildable types: the first (run order) pair (a, b) with a 0-2.5 relationship rule (`SynergyCatalog.rules_for`), preferring a pair with a `wall` kind; none: the cheapest type on every slot. Fresh runs use Pip and Mallow (`bff_pip_mallow`); once Bastia is buildable, Bastia + Pip or Clover. Rivals rules (2-6) are not used for slots.
- **Damage per tower type, no sim change:** event order is fixed in the sim: `TOWER_FIRED` (value = tower type) precedes the `ENEMY_HIT`s of its shot, `TOWER_HIT` (a = tower uid) precedes the thorns `ENEMY_HIT`, `SKILL_USED` precedes the cast's hits. The runner credits each `ENEMY_HIT` value to the source of the latest of those three events in the step (thorns: the hit tower's type, found by uid in the arrays; skills: a `skills` row). Overkill included (the event value is the amount applied); the report says so.
- **Report `reports/balance_<date>.md`** (date from the system clock; `--out` overrides):
  - header (date, commit, N, MAX_SEC 1000, note "placeholder numbers, needs-human:balance");
  - **targets line (D-143):** per profile maze win rate - spread win rate >= 20 points; maze wins 50-80 % on `fresh` and >= 80 % on `full`; passive wins none; each item met / NOT met, plus the overall **maze vs spread summary line** (win rates and median end times per profile);
  - per strategy x profile: wins / runs, win rate, death time median (min-max), win times, wall s; a per-Guardian wins table;
  - per strategy x profile, the M2 per-minute medians plus `Level` (`draft.level`) and `Linked towers` (live towers with `syn_mask != 0`);
  - per run: profile, Guardian, seed, outcome, end, towers bought, upgrades (`TOWER_UPGRADED` count), husks rebuilt, skills used, cards picked (ids from `CARD_PICKED` a), relationships active at the end (rule ids from the live towers' `syn_mask` bits), gold earned, wall s;
  - damage per tower type (kind) and `skills`, per strategy x profile: total and share %;
  - the Data section, now from `run_m3` and the M3 towers (level 1 stats) and skills.

### Steps and files
1. Hygiene from the 032 review (task 040 does not touch these files): re-wrap the stray mid-line tabs in `game/sim/tower_links.gd` (~147) and `game/sim/tower_stats.gd` (~93) into a normal line continuation. No behaviour change (`state_hash` tests unchanged).
2. `game/balance/balance_bot.gd` (**tools**, not exported): `_pick_card`, `_spend` (rebuild / place / upgrade choice), spread round robin, maze rings and pair choice; remove the ring code. Keep constants at the top with one-line reasons. If the file passes about 200 lines, move the maze layout to `game/balance/maze_layout.gd` (RefCounted).
3. `game/balance/balance_runner.gd` (**tools**): `RUN_ID` `run_m3`, profile presets, the matrix loop, per-run counters (upgrades, cards, damage attribution, links, level per minute), the report sections above, the D-143 targets line. `run_one(strategy, profile, guardian, seed, max_sec, on_step)`.
4. `scripts/balance.ps1` (**tools**): default `-Runs 2`, output `reports/balance_<yyyy-MM-dd>.md`, optional `-Profiles`; header comment updated.
5. Tests `game/tests/balance/test_balance_bot.gd` (headless, 60 s of run clock each, as M2):
   - deterministic: the same (strategy, profile, Guardian, seed) twice gives the same result and `state_hash`;
   - bots only use commands (keep the M2 test, now on `run_m3`);
   - card priority: on a world with an open draft, the bot queues `PICK_CARD` of the best-ranked slot;
   - spending: with gold set high, the bot queues the cheaper of placement and upgrade (test-only gold poke, as other tests do);
   - maze: after 60 s on `fresh`, every tower is on a `MAZE_RINGS` ring and not in its gap, and at least one tower has `syn_mask != 0` (the Pip-Mallow pair);
   - damage attribution: the per-source sums equal the sum of all `ENEMY_HIT` values of the run;
   - smoke: `report()` of two short runs (one per profile) contains the targets line, the maze vs spread line, the damage table and the Data section.
6. Run `scripts\balance.ps1` (default N) once on the branch and commit `reports/balance_<date>.md`; put the wall time in the PR and in the `CLAUDE.md` command line.
7. Docs: `docs/02_TECH_ARCHITECTURE.md` 6 (the balance runner paragraph: M3 runner replaces the M2 description; keep one sentence on D-126 history); `CLAUDE.md` commands (`scripts\balance.ps1`: M3 runner, default N, output name, measured time); `docs/04_AGENT_WORKFLOW.md` 5 already names `balance_<date>.md` (no change unless wording differs); `docs/DECISIONS.md` D-164 PROPOSED; `docs/plans/M3.md` row.

Order: 1, 2 with its tests, 3 with the attribution and smoke tests, 4, 6, 7. Headless tests green twice, validator green. Performance: tools only, nothing per tick in the game; the runner's event scan is per step over that step's events (as M2).

## Questions
- None blocking. Non-blocking, defaults taken in D-164 (owner may change them at CP-M3): (1) default N = 2 seeds per (strategy, profile, Guardian) = 54 runs, to keep a manual run near the M2 time per run; the nightly routine can pass more; (2) one fixed card priority for every bot (new tower > signature > skill > perk); (3) maze rings at radii 4, 7, 10 with 2-unit gaps.

## Review log
