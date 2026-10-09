# Open questions

Agents: do not implement items here without an owner answer. The design assistant converts these into forms for the owner.

Format: each question has a stable ID (`Q-nn`, never reused), a milestone it blocks, 2-4 options and a **recommended default** (marked ★). Until the owner answers, agents use the ★ default only where the item says "safe to assume" and flag it in their report; otherwise they do not implement. The list is ordered by priority: blockers for the current milestone (M0) first, then M1, M2, M3 and later, then compliance-critical and long-term items.

Last reviewed: 2026-10-08 (daily docs review; owner answers recorded the same day).

---

## Answered (2026-10-08, owner session)
| Question | Answer | Decision |
|---|---|---|
| Q-01 Test framework | GUT | D-033 |
| Q-02 Data format | JSON + JSON Schema | D-034 |
| Q-03 Where builds, tests and nightly runs execute | Everything on the owner's PC | D-035 (scheduling: Q-35) |
| Q-04 Godot version | Pin at M0 start | D-036 |
| Q-57 Slow stacking | No stacking, strongest applies, refresh | D-117 |
| Q-58 Ranged enemies and the maze | Towers block line of sight | D-118 |
| Q-54 Narrow gaps for big enemies | Every enemy is a point for pathing | D-111 |
| Q-55 Placing on enemies | Allowed, enemies pushed out | D-112 |
| Q-56 Husk economy | Counts as a copy, no refund, rebuild fraction | D-113 |
| Q-49 Building while paused | No | D-105 |
| Q-50 Path blocking | Maze: enemies path around towers | D-101 |
| Q-51 Full walls | Allowed | D-102 |
| Q-52 When enemies attack towers | Only when walled in | D-103 |
| Q-53 Husks block the path | No, walkable | D-104 |
| Q-43 Wave length | 60 s waves | D-093 |
| Q-44 Gold collection | Automatic on death | D-094 |
| Q-45 M2 enemy types | Swarmer, brute, ranged + bosses | D-095 |
| Q-46 After the final boss spawns | Horde continues | D-096 |
| Q-47 Mini-bosses in M2 | At 5:00 and 10:00 | D-097 |
| Q-48 Shots | Instant hit, visual effect only | D-098 |
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

## M2 (blocks CP-M2 sign-off on performance)

### Q-59 The maze tick budget: what to do about `pc_maze_churn` at ~8.1 ms (budget 8 ms)
Task 023 (`reports/perf_m2.md`) made separation 15-20% faster (D-123). `pc_maze` is at 7.55 ms per tick and `pc_maze_churn` at 8.12 ms (median of 3 runs, range 7.98-8.16). A lead-dev rerun gave 8.03 / 8.06 ms, so both scenarios sit on the 8 ms line within run-to-run noise (about +-0.4 ms). `pc_maze_churn` is a synthetic worst case: one tower flips every frame, so a path recompute is always running. In play a recompute only follows a build, a sale or a tower death. All other scenarios pass, combat included (`pc_maze_combat` 7.04 ms). The worst estimated Deck tick frame is 15.6 ms against 25 ms. None of the `perf_m1.md` section 6 GDExtension triggers fired. Frames stay above 90 FPS 1%-low on PC. Separation is still about 60% of a maze tick, and the remaining cost is the work done for each overlapping pair, which plain GDScript cannot reduce without changing the rule.
- A) **Accept for M2: the maze gate becomes "about 8 ms" (`pc_maze` and `pc_maze_churn` within noise of 8 ms), `pc_maze_churn` is tracked as the known worst case, and every milestone bench re-checks it. A GDExtension separation loop (D-018) is planned only when a section 6 trigger fires (for example, M3 adds load).** ★ Why: the miss is 1.5%, inside the noise. The scenario cannot happen at that rate in play. The Deck estimate has 40% headroom. A native module now adds a C++ build to every machine and to the Proton path for a gain no player would see.
- B) GDExtension separation loop now (D-018): expected several times faster and clears the gate for good, at the cost of a C++ toolchain, a per-platform build and a second code path to keep in step with the GDScript rule.
- C) Threaded GDScript separation (split the horde into bands and merge the pushes in a fixed order): no new toolchain, but threads in the sim make determinism harder to keep and to test, and on the Deck's 4 cores the gain is uncertain.
- D) Change the rule: skip pairs where both enemies are stopped (queued or attacking). This is probably the cheapest fix in corridors, but it changes how crowds pile up and needs a playtest.
Safe to assume: yes, A (no code change). Agents keep the budget at 8 ms in `02_TECH_ARCHITECTURE.md` 4 until the owner answers.

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
