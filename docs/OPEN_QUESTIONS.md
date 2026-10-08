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
| Q-24 Chibi vs adult look | No chibi, adult proportions everywhere | D-030 |
| Q-33 Camera controls | Pan + zoom, cursor at screen centre | D-041 |
| Q-34 Build radius and performance with no cap | Growable radius, rising costs, 300/150 stress target | D-042 |

---

## A. Blocks M0 (current priority)

### Q-35 How are the local routines scheduled? (blocks M0 automation)
D-035 puts builds, tests, balance and perf runs and ComfyUI jobs on the owner's PC, so the cloud cannot trigger them.
- A) **Scheduled tasks in the Claude desktop app, running on the PC while it is on and the app is open; the loop procedure lives in the repo docs; the owner can also run them manually** ★
- B) Manual only: the owner starts a loop in Claude Code on the PC during work sessions.
- C) Windows Task Scheduler launching Claude Code in headless mode (more setup, independent of the desktop app).
Recommended: A.

---

## B. Blocks M3 (roguelite layer)

### Q-17 Guardian pick details (D-026 left these open)
How many locked waifus are offered before a run and whether they are always the same.
- A) **3 offered, drawn at random from the locked pool; the player can reroll once per run start** ★ (when fewer than 3 locked remain, show all of them)
- B) 3 offered, always the same three until one is rescued (predictable, easier to balance).
- C) 2 offered (simpler UI).
- D) All locked waifus are shown (needs a bigger screen but zero randomness).

### Q-18 Level-up card system rules (blocks M3)
`01_GAME_DESIGN.md` section 4 lists four card types but not their interaction with gold-based building.
- A) **Cards never give free towers; "new tower waifu" cards unlock the right to build that tower this run (then gold pays for each placement)** ★
- B) Cards give the tower itself for free (no gold needed for the first copy).
- C) Remove "new tower waifu" cards; only upgrade, Guardian and perk cards remain.
Also: tower upgrade levels (3-5 per waifu): bought with gold (★) or with cards only? Reroll/banish/skip mechanics for the 3 cards: none (★) for M3.

### Q-19 Meta-currency and permanent upgrades (blocks M3)
Section 7/8 are [P] and thin: "hearts" buy permanent upgrades; "bond" unlocks outfits.
- A) **One meta currency (hearts) buys flat permanent upgrades from a data-defined tree; bond is per-waifu and only gates outfits** ★
- B) Hearts split by waifu (each waifu has her own affection currency).
- C) No permanent stat upgrades; meta progression is only unlocks (waifus, outfits, starting perks).

### Q-20 Save system scope (blocks M3)
Runs last 15-20 min; the Steam Deck can suspend mid-run.
- A) **Save only the meta profile; a run is lost if the app is closed, except an automatic "suspend save" at card/wave boundaries** ★
- B) Profile only, no mid-run save.
- C) Full deterministic run resume (replay seed + commands) — possible thanks to the deterministic sim, more work.

### Q-21 Outfit system depth (existing question)
- A) **Pure stat trade-offs; bond unlocks new outfits only** ★
- B) Stat trade-offs plus bond-gated extra barks (voice-less lines).
- C) Stat trade-offs plus per-outfit passive effects (more build depth, more data to balance).
Related: do outfits also change the tower's attack, or only stats? (★ only stats and visuals.)

### Q-22 Rival bosses (existing question)
Which bosses are recruitable (D-024), how many, and when.
- A) **2 rival bosses at launch, appearing as the mini-boss at about 10:00 on higher difficulty tiers; defeating one for the first time unlocks her** ★
- B) 1 rival at launch, on any difficulty, tied to a specific Guardian.
- C) None at launch; added after Early Access.
Also: do rival waifus count in the 8-10 roster (D-025)? ★ yes, a rival counts as one of the 8-10.

### Q-23 Roles and identities of the 8-10 launch waifus (existing)
Needs: role per waifu (damage / crowd control / support / tank / economy), tags for synergies, personality archetypes.
- A) **Agent proposes a roster table (name placeholder, role, tags, archetype) in a PR for owner approval; balanced across 5 roles** ★
- B) Owner provides the roster list.
- C) Owner gives only archetypes ("tsundere, knight...") and the agent expands.
Blocks the content in M5 but M3 synergy rules need tags, so decide before M3 closes. Also includes choosing the 2 starter waifus (D-031).

---

## C. Art (decide before any art work in M4)

### Q-25 Style references and models (existing)
- A) **Owner provides 5-10 reference images; the art spike (M4) evaluates 2-3 models/LoRAs against them** ★
- B) Agent proposes a style from text only, owner approves a test sheet.
- C) Owner generates the first character externally and imports it through the spec in `03_ART_PIPELINE.md` section 7.

### Q-26 Hand touch-ups of key characters (existing)
- A) **Owner or a hired artist touches up the 3 key characters (Guardian candidates on key art); the others stay pipeline-only** ★
- B) All characters stay AI-generated with human curation only (weaker IP position, see compliance doc).
- C) Commission or hand-paint every roster waifu (expensive, outside the "no spending" rule for agents).

---

## D. Long-term / business (not blocking until M5-M6)

### Q-27 Endgame details (modes decided in D-027)
Also see Q-28 below, which is the gap this creates.
- A) **3 difficulty tiers at launch (Normal, Hard, Nightmare), endless mode scored by survival time and kills, 4-6 challenge modifiers** ★
- B) 5 tiers, endless mode only.
- C) 2 tiers, modifiers only after Early Access.

### Q-28 Who is the Guardian once every waifu is unlocked? (gap between D-026 and D-027)
D-027 says replaying with an already-unlocked waifu as Guardian is not part of the plan, but difficulty tiers, endless mode and modifiers all need a protected waifu, and D-026 only offers locked waifus. DECISIONS D-013 still says "Whether unlocked waifus can be Guardians later is OPEN".
- A) **After all are unlocked, any waifu may be the Guardian in tier/endless/modifier runs (no new unlocks)** ★
- B) Those modes use a fixed "defender" (e.g. a mascot waifu who is not part of the roster).
- C) Each waifu has a tier-specific "remix" Guardian version with a different outfit (extra art).
Recommended: A. If chosen, D-027's note needs the owner to supersede it explicitly.

### Q-29 Audio direction (existing)
- A) **Music: upbeat orchestral/chiptune-flavoured cute fantasy tracks from licensed/royalty-free libraries; no voice acting; short synthesized barks (text-only plus sound blips); SFX from licensed packs** ★
- B) Japanese voice lines (outsourced, paid, outside agent rules).
- C) No music at launch beyond 2-3 loops.
Note: any AI-generated audio must be disclosed (`05_STEAM_AND_COMPLIANCE.md` section 3).

### Q-30 Languages at launch (existing)
- A) **English only at launch, all text in localisation tables from day one (keys, not literals), French added after Early Access** ★
- B) English + French at launch.
- C) English + French + Simplified Chinese/Japanese.

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
