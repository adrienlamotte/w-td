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
| Q-33 Camera controls | Pan + zoom, cursor at screen centre | D-041 |
| Q-34 Build radius and performance with no cap | Growable radius, rising costs, 300/150 stress target | D-042 |

---

## A. Blocks the first asset import and M3

### Q-37 Where are large art files stored? (blocks the first asset import)
PNG parts at 2048 px and later sprite sheets will make the git repo heavy (tens of MB per character).
- A) **Git LFS for `assets_src/` and `game/` binary assets (PNG, PSD, audio)** ★ — history stays small; needs LFS enabled on the GitHub repo and installed on the owner's PC (cloud sessions can read and write pointers).
- B) Plain git — simplest, but the repo grows quickly and cannot be slimmed afterwards without rewriting history.
- C) Keep sources outside git (the Dropbox folder), commit only the exported in-game assets and the manifest.
Recommended: A.

---

## B. Long-term / business (not blocking until M5-M6)

### Q-31 Name, price, Early Access, DLC (existing)
- A) **Keep "WTD" as working title until M5; EUR 7.99-9.99 Early Access; no DLC until after launch** ★
- B) Decide the final name and price before M4 so the art can include a logo.
- C) Free to play with cosmetic DLC (conflicts with the plan in `05_STEAM_AND_COMPLIANCE.md`).

### Q-32 Steam Deck performance (measured in M1)
Not a question for the owner: results will go to `DECISIONS.md`. Kept so that nothing from the earlier list is dropped.

---

## Cleanup notes (for the owner)
- Earlier numbering skipped item 7; this list uses stable `Q-nn` IDs instead.
- `DECISIONS.md` D-013 note ("Whether unlocked waifus can be Guardians later is OPEN") is partly overtaken by D-027; see Q-28. Not edited here because decision rows are owner-only.
- D-021 (chibi) is superseded by D-030.
- D-024 still says "special story bosses"; D-028 already clarifies that this means named rival bosses. `01_GAME_DESIGN.md` wording was aligned.
