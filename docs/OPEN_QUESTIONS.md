# Open questions

Agents: do not implement items here without an owner answer. The design assistant converts these into forms for the owner.

Format: each question has a stable ID (`Q-nn`, never reused), a milestone it blocks, 2-4 options and a **recommended default** (marked ★). Until the owner answers, agents use the ★ default only where the item says "safe to assume" and flag it in their report; otherwise they do not implement. The list is ordered by priority: blockers for the current milestone (M0) first, then M1, M2, M3 and later, then compliance-critical and long-term items.

Last reviewed: 2026-10-08 (daily docs review).

---

## A. Blocks M0 (current milestone) and M1

### Q-01 Test framework (blocks M0)
Needed to wire the headless test command (`02_TECH_ARCHITECTURE.md` section 6).
- A) **GUT** ★ — long-established, plain GDScript, CLI runner (`gut_cmdln.gd`), JUnit XML export for CI.
- B) **gdUnit4** — richer assertions/mocking, CLI runner and JUnit/HTML reports, heavier setup.
- C) Let the agent run a 1-hour spike with both in M0 and pick the one that is easier to run headless in the cloud container (record in `DECISIONS.md`).
Recommended: A, unless the spike (C) shows a headless problem.

### Q-02 Data file format (blocks M0: validator skeleton)
`02_TECH_ARCHITECTURE.md` section 5 says "JSON or .tres". The validator, balance runner and the asset forge are in Python, which favours plain files.
- A) **JSON files + JSON Schema** ★ — easy to diff, validated in Python and in GDScript, trivial for the headless sim to load.
- B) Godot `.tres` Resources with typed scripts — editor-friendly, but harder to validate outside Godot.
- C) JSON as source of truth, generated `.tres` for editor use (extra build step).
Recommended: A.

### Q-03 Repo host / CI provider and where routines run (blocks M0 "one command" build)
Observed: the repo is on GitHub (so GitHub Actions is available); D-029 puts the daily review in a cloud scheduled task. Still unclear: where nightly builds/tests/balance runs execute.
- A) **GitHub Actions for build + headless tests; nightly balance/perf runs also in Actions or a cloud scheduled task** ★ — no dependence on the owner's PC being on. Windows export from a Linux runner with Godot export templates.
- B) Owner's PC runs everything nightly (needed anyway for ComfyUI/GPU work), cloud only for docs review.
- C) Hybrid: tests/build in Actions, perf (needs real GPU) and ComfyUI on the owner's PC when it is on.
Recommended: A for tests/build/balance, with C for perf and art generation.

### Q-04 Pinned Godot version (blocks M0)
"Latest stable" (D-018) is not reproducible, and GodotSteam builds target specific Godot versions.
- A) **Pin to the latest 4.x stable at M0 start, record the exact version in `DECISIONS.md` and in `tools/`; upgrade only through an explicit task** ★
- B) Track the latest stable continuously (fast, but breakage risk and Steam plugin lag).
- C) Pin to the newest version that GodotSteam supports (decide after checking compatibility).
Recommended: A, with a quick compatibility check against GodotSteam (C) before M6.

### Q-05 Confirm the proposed technical decisions (blocks M1)
D-019 (2.5D with MultiMesh), D-020 (deterministic sim/view split) and D-021/D-022 are still PROPOSED, yet `02_TECH_ARCHITECTURE.md` (sections 3 and 5) and `CLAUDE.md` hard rules 3-4 already treat the sim split and data-driven content as mandatory.
- A) **Confirm D-020 (sim/view split) now as DECIDED; keep D-019 as "to be validated in M1" with the 2D fallback** ★
- B) Confirm all of D-019 to D-022 now.
- C) Keep all PROPOSED until the M1 spike result.
Recommended: A.

### Q-06 Simulation tick rate and world scale (blocks M1)
Perf budgets talk about "ms/frame" but the sim is fixed-timestep. See the concrete proposal in `02_TECH_ARCHITECTURE.md` section 3a **[P]**.
- A) **Fixed 30 Hz sim tick, view interpolates to render rate (60 FPS)** ★ — halves the sim cost for ~3000 enemies; budget then reads "under 8 ms per tick at max load on PC".
- B) Fixed 60 Hz sim tick — smoother and simpler, doubles the cost.
- C) Decide from the M1 benchmark (agent measures both).
Recommended: A, validated by C in M1.

### Q-07 Reference resolution and camera framing (blocks M1)
Not stated anywhere; affects sprite sizes in `03_ART_PIPELINE.md` section 3, UI sizing and how many enemies fit on screen.
- A) **1920x1080 base, scaled to 1280x800 on Steam Deck (16:10 handled with letterbox-free extra field of view)** ★
- B) 1280x720 base (lower cost, Deck-native-like).
- C) 2560x1440 base.
Recommended: A.

---

## B. Blocks M2 (core loop vertical slice)

### Q-08 Build phases vs continuous spawning (blocks M2)
`01_GAME_DESIGN.md` section 3 says "continuous spawn curve with waves" while section 4 says "short build phases between waves" (D-010). It is unclear what happens to enemies, the clock and the Guardian during a build phase.
- A) **Short break (15-20 s) between waves: no new spawns, remaining enemies keep attacking, clock keeps running; placement is also allowed any time during waves** ★
- B) Build phase pauses everything (turn-based feel), including remaining enemies.
- C) No explicit break: "build phase" is just a calmer stretch in the spawn curve.
Recommended: A.

### Q-09 Tower placement rules (blocks M2)
- A) **Free placement on the ground plane inside a radius around the Guardian, snapped to a fine grid (e.g. 1 cell = 1 tower footprint); gamepad uses a cursor with snapping** ★
- B) Fixed slots/rings around the Guardian (easiest for gamepad, less freedom, fewer perf concerns).
- C) Free continuous placement with collision circles (most freedom, hardest on gamepad and for determinism).
Also decide: can towers be moved/sold (★ sell for partial gold refund, no moving), and is there a tower cap (★ 50, matching the perf budget).

### Q-10 Do enemies hurt towers? (blocks M2)
`01_GAME_DESIGN.md` section 3 says enemies "attack towers in the way". Not specified: tower HP, death, repair.
- A) **Towers have HP; enemies attack whatever blocks their straight path, otherwise the Guardian; dead towers leave a rebuildable husk (pay a fraction of the cost); no repair in M2** ★
- B) Towers are invulnerable; enemies just walk through to the Guardian (simplest, removes the tank role).
- C) Towers have HP and are lost permanently when killed (harsher; tank/support roles matter more).
Recommended: A.

### Q-11 Guardian numbers and skills for M2 (blocks M2)
M2 needs "Guardian with HP and 2 active skills". Candidate set from the pitch: shield, heal, area blast.
- A) **Skills: Area blast (damage ring, ~12 s cooldown) and Shield (absorb damage, ~25 s cooldown); heal deferred to M3 upgrades** ★ (all numbers are placeholders in data, tuned by the balance runner)
- B) Skills: Area blast and Heal.
- C) Skills: Shield and Heal.
Also: does the Guardian attack on its own (★ no, skills only, to keep her role distinct from towers)?

### Q-12 The three M2 tower types (blocks M2)
Roles available: damage / crowd control / support / tank / economy.
- A) **Ranged damage (single target), area damage (splash), crowd control (slow)** ★
- B) Ranged damage, tank (blocks and absorbs), support (heals/buffs).
- C) Ranged damage, area damage, tank.
Feeds Q-17 (roles of the 8-10 launch waifus).

### Q-13 What towers does the player have in run 1? (blocks M2/M3)
Winning unlocks the Guardian as a tower (D-023), but at first launch nothing is unlocked, so the first run has no towers to build or draft. The docs do not say what the starting roster is, and D-025's 8-10 does not say whether starting waifus count.
- A) **2 starter waifus are unlocked from the start (tower-only), counted in the 8-10 total; Guardians are chosen among the remaining locked ones** ★
- B) No starter waifus: run 1 only offers generic "recruit" cards that give non-unique placeholder towers.
- C) The first run's Guardian is a fixed tutorial waifu and the run is guided; starter towers come from generic cards.
Recommended: A.

### Q-14 Gamepad building UX (blocks M2: "gamepad and mouse both work")
- A) **Radial/quick menu for tower choice + a free-moving cursor with right stick, A to place, B to cancel; skills on face buttons / triggers** ★
- B) Cursor snaps between valid slots with d-pad/left stick (pairs with Q-09 option B).
- C) Pause-and-place mode (time slows to 10-20% while placing).
Recommended: A, with the "slow time while placing" as an accessibility toggle.

### Q-15 Run end condition and length (blocks M2)
D-006 says 15-20 min; section 3 says a final boss at the end; M2 says "a full 15-minute run".
- A) **Fixed timeline: the final boss spawns at a data-defined time (default 15:00 in M2, tuned to 15-20 min later); winning requires killing her** ★
- B) Timer ends the run at a fixed length; boss is a mid-run event; surviving is the win.
- C) Variable length: player can trigger the final boss early for a bonus (risk/reward).
Recommended: A.

### Q-16 Win/lose consequences and retry (blocks M2 screens, M3 meta)
Undefined: what the player keeps after a loss, whether the same locked waifu can be rescued again (obviously yes under D-026, but is the choice re-offered?), and rewards for partial progress.
- A) **Loss keeps a reduced hearts reward (e.g. 30-50% scaled by time survived), and the player picks a Guardian again from the offered locked waifus** ★
- B) Loss gives nothing except unlocking bond XP for towers used.
- C) Loss gives full hearts (low frustration), win gives the waifu plus a bonus.
Recommended: A.

---

## C. Blocks M3 (roguelite layer)

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
Blocks the content in M5 but M3 synergy rules need tags, so decide before M3 closes.

---

## D. Compliance-critical (decide before any art work in M4)

### Q-24 Chibi proportions vs "no character that looks like a minor"
`05_STEAM_AND_COMPLIANCE.md` section 2 forbids characters who look like minors, while the art direction (D-021, still PROPOSED) is chibi and the pillars include suggestive outfits (lingerie, swimwear). Chibi proportions risk reading as childlike, which is the opposite of the content rule. Content limits themselves are not changed here; this is a question about how the art style will respect them.
- A) **Chibi only for the in-game small sprites; all portraits, outfit art and any suggestive outfit use adult proportions and clearly adult features; suggestive outfits never appear on chibi sprites** ★
- B) Drop chibi: adult-proportioned stylized characters everywhere (consistent, cleaner compliance, harder for small sprites).
- C) Chibi everywhere, but suggestive outfits are restricted to a mild list (swimwear only, no lingerie).
Recommended: A or B; the owner has the final say per `05_STEAM_AND_COMPLIANCE.md`.

### Q-25 Style references and models (existing)
- A) **Owner provides 5-10 reference images; the art spike (M4) evaluates 2-3 models/LoRAs against them** ★
- B) Agent proposes a style from text only, owner approves a test sheet.
- C) Owner generates the first character externally and imports it through the spec in `03_ART_PIPELINE.md` section 7.

### Q-26 Hand touch-ups of key characters (existing)
- A) **Owner or a hired artist touches up the 3 key characters (Guardian candidates on key art); the others stay pipeline-only** ★
- B) All characters stay AI-generated with human curation only (weaker IP position, see compliance doc).
- C) Commission or hand-paint every roster waifu (expensive, outside the "no spending" rule for agents).

---

## E. Long-term / business (not blocking until M5-M6)

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
- D-024 still says "special story bosses"; D-028 already clarifies that this means named rival bosses. `01_GAME_DESIGN.md` wording was aligned.
