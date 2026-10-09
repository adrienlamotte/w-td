# Open questions

Agents: do not implement items here without an owner answer. The design assistant converts these into forms for the owner.

Format: each question has a stable ID (`Q-nn`, never reused), a milestone it blocks, 2-4 options and a **recommended default** (marked ★). Until the owner answers, agents use the ★ default only where the item says "safe to assume" and flag it in their report; otherwise they do not implement. The list is ordered by priority: blockers for the current milestone first (M1 is done, so **M2** is current), then M3 and later, then deferred and long-term items. Placeholder numbers (HP, costs, damage) are never questions: they go in data files and are tuned in balancing.

Last reviewed: 2026-10-09 (daily docs review). M2 blockers Q-43..Q-49 added; M1 is done (D-090), `docs/plans/M2.md` does not exist yet.

---

## Answered (2026-10-08, owner session)
| Question | Answer | Decision |
|---|---|---|
| Q-01 Test framework | GUT | D-033 |
| Q-02 Data format | JSON + JSON Schema | D-034 |
| Q-03 Where builds, tests and nightly runs execute | Everything on the owner's PC | D-035 (scheduling: Q-35) |
| Q-04 Godot version | Pin at M0 start | D-036 |
| Q-41 Enemy crowding | Soft separation | D-079 |
| Q-42 Steam Deck for the M1 benchmark | No Deck: estimate from PC | D-080 |
| Q-38 Steam Deck build | Windows build through Proton first | D-075 |
| Q-39 How task PRs are merged | Milestone branch, owner merges into `main` | D-073 |
| Q-40 Length of a loop run | Until a real stop | D-074 |
| Q-05 Which proposed decisions to confirm | Sim/view split only | D-037 |
| Q-06 Sim tick rate | 30 Hz | D-038 |
| Q-07 Base resolution | 2560x1440 | D-039 |
| Q-08 Between waves | Short break, building always allowed | D-032 |
| Q-09 Tower placement | Free grid placement, no cap, sell not move, movable camera | D-040 (follow-ups answered: D-041, D-042) |
| Q-10 Do enemies hurt towers | Yes, towers have HP; dead towers leave a rebuildable husk | D-043 |
| Q-11 Guardian skills in M2 | Area blast + Shield, no auto-attack | D-044 |
| Q-12 Tower types in M2 | Ranged, area, slow | D-045 |
| Q-13 Towers in the very first run | 2 starter waifus | D-031 |
| Q-14 Gamepad building | Radial menu + centre cursor | D-046 |
| Q-15 Run end | Fixed timeline, kill the final boss | D-047 |
| Q-16 Loss rewards | Reduced hearts, pick a Guardian again | D-048 |
| Q-17 Guardian offer | 3 locked waifus, fixed until one is rescued | D-050 |
| Q-18 Cards vs gold | Cards unlock the right to build; gold pays | D-051 |
| Q-19 Meta currency | Hearts + per-waifu bond | D-052 |
| Q-20 Saves | Profile + suspend save | D-053 |
| Q-21 Outfit depth | Cosmetic only, no effect | D-054 (new question: Q-36) |
| Q-22 Rival bosses | 2 rivals at launch | D-055 |
| Q-23 Who writes the roster | Agent drafts, owner approves | D-056 (task: `backlog/001-roster-proposal.md`) |
| Q-24 Chibi vs adult look | No chibi, adult proportions everywhere | D-030 |
| Q-25 Art style and models | Owner generates the first character externally; brief in `08_FIRST_CHARACTER_BRIEF.md` | D-060 |
| Q-26 Hand touch-ups | Owner or artist on 3 key characters | D-061 |
| Q-27 Endgame size | 3 tiers, endless, 4-6 modifiers | D-059 |
| Q-29 Audio | Licensed music, no voices | D-062 |
| Q-30 Languages | English first, French after EA | D-063 |
| Q-28 Guardian in late modes | Any waifu the player chooses | D-058 |
| Q-35 How local routines run | Desktop app scheduled tasks, or manually | D-049 |
| Q-36 Unique hook | Relationship synergies | D-057 |
| Q-31 Name, price, Early Access, DLC | Keep WTD until M5; EUR 7.99-9.99 in Early Access; no DLC before launch | D-064 |
| Q-33 Camera controls | Pan + zoom, cursor at screen centre | D-041 |
| Q-34 Build radius and performance with no cap | Growable radius, rising costs, 300/150 stress target | D-042 |

---

## M2 blockers (current milestone: core loop vertical slice)
Found by reading `01_GAME_DESIGN.md` and `02_TECH_ARCHITECTURE.md` against the M2 scope in `06_ROADMAP.md`: an implementing agent could not build these rules without guessing. Until answered, agents do not implement the item; the lead-dev may plan around the ★ default if the task file says so.

### Q-43 How do enemies damage the Guardian and towers? (blocks M2: Guardian HP, tower HP, loss)
Today only `contact_damage` exists in enemy data (`02` 3b); nothing says when or how often it applies. Enemies in `AT_GUARDIAN` state stop moving (`02` 3a).
- A) **Melee on a timer: an enemy in contact hits its target every `attack_interval` seconds (data, per enemy type) for `contact_damage`; the swarm's total damage grows with the crowd touching the target** ★
- B) Continuous damage per second while in contact (no interval; `contact_damage` is per second).
- C) Kamikaze: the enemy deals its damage once and dies on contact.
Also needed whatever the answer: a cap on how many enemies can hit the same target at once? (★ no cap in M2; the crowd's size is the pressure; revisit in balancing.)

### Q-44 What exactly is a "wave"? (blocks M2: spawn curve, build breaks, `WaveStarted` event)
`01` section 3 says both "continuous spawn curve with waves" and "a short break of 15-20 s with no new spawns" (D-032), but not how often breaks happen or how waves are authored.
- A) **Waves are a data list: each wave has a start time, a duration, spawn groups (enemy type, count, ring radius/arc) and is followed by a 15-20 s break; the final boss time is a separate field (D-047). The 15:00 run in M2 is about 10 waves of ~75 s plus breaks** ★
- B) One continuous spawn-rate curve (function of time) with a break inserted every fixed N seconds.
- C) Waves of equal length generated from a few parameters (base count, growth per wave); no hand-authored lists.

### Q-45 What does "blocks their straight path" mean for towers? (blocks M2: enemy targeting)
D-043 says enemies attack the tower that blocks their straight path, otherwise the Guardian. There is no pathfinding and enemies push each other (D-079), and towers have no radius/footprint in the docs.
- A) **Each tower has a `radius` (data). While chasing, an enemy whose straight line to the Guardian passes within `radius + enemy radius` of a tower stops at the tower and attacks it; a dead tower (husk) no longer blocks** ★
- B) Enemies attack any tower within a melee reach of the enemy while they keep walking; towers never stop movement.
- C) Towers are solid obstacles and enemies path around them (needs steering/pathfinding; risk for the 3000-enemy budget, would need a new perf check).

### Q-46 Gold: how is it collected, and what do you start with? (blocks M2: economy)
`02` 3b has drops with `amount` and `chance`, but not pickup. `01` 4 says "spending resources dropped by kills".
- A) **Gold is added to the wallet the moment the enemy dies (no pickup objects, no ground clutter, gamepad-friendly)** ★
- B) Gold drops on the ground and flies to the Guardian inside a magnet radius (more juice, more entities to render).
- C) The player must move a cursor over drops to collect (mouse-first; conflicts with D-046 for gamepad).
Starting gold: ★ enough for 2 towers of the cheapest type (placeholder in data). In M2 there are no cards (M3), so ★ all 3 tower types are buildable from the start of the run.

### Q-47 Sell refund and husk rebuild cost (blocks M2: SellTower, husk rebuild)
D-040 says "partial refund" and D-043 says "a fraction of the cost"; both fractions are unspecified.
- A) **Sell refunds 50% of the gold actually paid; rebuilding a husk costs 50% of the current price of that tower** ★
- B) Sell refunds 70%; rebuild costs 30%.
- C) Sell refunds 100% during the build breaks and 50% during waves; rebuild 50%.
(Values stay in data; this question is only about the rule shape.)

### Q-48 Bosses in M2 and what appears at 5:00 and 10:00 (blocks M2: the "one boss" in the roadmap)
`01` 3 proposes a mini-boss about every 5 minutes; `01` 6 and D-055 say the 10:00 mini-boss is a rival only on higher tiers; there are no tiers in M2, and D-047 fixes the final boss at 15:00 (M2).
- A) **M2 has only the final boss at 15:00: a large single-type enemy (lots of HP, slow, high contact damage), no special attacks, killing it wins the run. Mini-bosses wait for M5** ★
- B) Final boss plus one placeholder mini-boss at 5:00 and 10:00 (same enemy type, scaled up) to test the timeline.
- C) Final boss with one scripted special (for example a periodic summon of swarmers) to exercise the event system.

### Q-49 Run flow, pause and the placeholder Guardian in M2 (blocks M2: win/lose screens, input)
No doc says what the player sees before and after a run in M2, whether the game can be paused, or which Guardian is used while there is no roster (roster arrives in M3/M5; `backlog/001-roster-proposal.md` is still `todo`).
- A) **Main menu with Start -> run (fixed placeholder Guardian, no pick screen) -> win or lose screen with Retry and Quit; Esc / Start button opens a pause menu that freezes the sim; no speed-up** ★
- B) As A, plus a 2x speed toggle for testing.
- C) As A, but no pause (the run keeps going; menu only after the end).
Build grid cell size and tower footprint are also needed: ★ cell 1.0 world unit (towers snap to cell centres), each tower occupies one cell, no overlap with the Guardian or another tower; alternatives 0.5 or 2.0.

---

## A. Deferred until the first real asset arrives

### Q-37 Where are large art files stored? (DEFERRED by the owner: decide when the first real asset arrives)
Rough size estimates (not measurements): about 40-60 MB per waifu (14+ PNG layers at 1024x2048, outfits, portraits), roughly 0.5-1 GB for the launch project, and git keeps every re-export forever.
Facts checked 2026-10-08: GitHub Free includes 10 GiB of Git LFS storage and 10 GiB of LFS bandwidth per month; beyond that usage is metered, or blocked if the budget is $0. Without LFS, GitHub warns at 50 MiB per file, blocks at 100 MiB, and recommends repos under 1 GB (strongly under 5 GB).
- A) **Hybrid: exported in-game assets via Git LFS, raw sources and ComfyUI intermediates in Dropbox, referenced by the manifest** ★
- B) Git LFS for everything.
- C) Plain git (small test assets only) and decide properly with real file sizes.
Interim rule until decided: the first test character (`waifu_test01`) is committed as plain files on a branch; cloud sessions should not fetch large files.
---

## B. Long-term / business (not blocking until M5-M6)

### Q-32 Steam Deck performance (measured in M1)
Not a question for the owner: results will go to `DECISIONS.md`. Kept so that nothing from the earlier list is dropped.
Estimated in `reports/perf_m1.md` (D-080); real Deck run pending, by M6.

---

## Cleanup notes (for the owner)
- Earlier numbering skipped item 7; this list uses stable `Q-nn` IDs instead.
- `DECISIONS.md` D-013 note ("Whether unlocked waifus can be Guardians later is OPEN") is partly overtaken by D-027; see Q-28. Not edited here because decision rows are owner-only.
- D-021 (chibi) is superseded by D-030.
- D-024 still says "special story bosses"; D-028 already clarifies that this means named rival bosses. `01_GAME_DESIGN.md` wording was aligned.
