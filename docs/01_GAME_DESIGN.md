# 01 — Game Design Document

Status key: **[D]** decided, **[P]** proposed, **[O]** open.

## 1. Pitch
You protect a waifu at the center of an open field while an enormous horde swarms from every direction. You build defenses out of other waifus, level up and draft upgrades like in Vampire Survivors, and use the protected waifu's active skills. Win a run and the waifu you protected joins your roster as a tower. **[D]**

Tone: cute and comedic fantasy. **[D]** All characters are clearly adult with adult proportions; no chibi (D-030). **[D]**

## 2. Pillars
1. **Protect her.** The protected waifu ("the Guardian") is the emotional stake. Lose condition = her HP reaches 0. **[D]**
2. **Horde chaos.** Hundreds to thousands of enemies on screen, constant escalation, satisfying kills. **[D]**
3. **Build over time.** Roguelite draft choices create different builds each run. **[D]**
4. **Relationships are the hook; fanservice is cosmetic.** Outfits are purely cosmetic (D-054). The unique gameplay hook is relationship synergies between waifus (D-057). **[D]**
5. **Collect them all.** Winning unlocks new waifus; the roster is the long-term goal. **[D]**

## 3. Run structure **[D unless noted]**
- Length: **15-20 minutes** per run.
- Map: **open field, 360° swarm**, no lanes. Enemies path straight toward the Guardian; they attack whatever tower blocks their straight path, otherwise the Guardian. Enemies softly push each other apart so the horde spreads into a crowd (D-079). Towers have HP; a dead tower leaves a husk that can be rebuilt for a fraction of the cost; no repair in M2 (D-043). **[D]**
- Escalation: continuous spawn curve with **60 s waves** (D-093); **mini-bosses at 5:00 and 10:00** (D-097, regular enemies) and a **final boss at the end**; the horde keeps coming while the final boss is alive (D-096). **[D]**
- **Between waves:** a short break of 15-20 s with no new spawns; leftover enemies keep attacking, the clock keeps running, and building is allowed at any time (D-032). **[D]**
- Win: kill the final boss, who spawns at a data-defined time (15:00 in M2, tuned toward 15-20 min later; D-047). Lose: Guardian HP = 0. **[D]**
- **Loss:** keeps a reduced hearts reward (30-50% depending on time survived); the player picks a Guardian again from the offered locked waifus (D-048). **[D]**
- **Win reward:** the Guardian protected in this run is unlocked as a **tower waifu** for future runs.
- **Guardian each run:** before the run, the player **picks the Guardian from a few locked waifus** she wants to "rescue". Unlocked waifus are towers only. **[D]** **3 locked waifus are offered, always the same three until one is rescued**; when fewer than 3 remain, all remaining are shown (D-050). **[D]** The order in which locked waifus enter the offer is data-defined: **[O]** (Q-23).
- **After everyone is unlocked (replay value):** **difficulty tiers**, **endless mode** and **challenge modifiers** **[D]**. Launch scope (D-059): 3 difficulty tiers (Normal, Hard, Nightmare), an endless mode scored by survival time and kills, and 4-6 challenge modifiers. **[D]** In these modes any waifu chosen by the player can be the Guardian, with no new unlocks (D-058). **[D]**
- **No story or campaign.** Pure gameplay; waifus only have short personality lines (barks). **[D]**
- **Roster target at Early Access launch: 8-10 waifus.** **[D]**
- **Starter roster:** 2 waifus are unlocked from the start as towers and count toward the 8-10; Guardians are picked among the remaining locked waifus (D-031). **[D]** Which two: **[O]** (Q-23).

### Known rule gaps (implementation blockers) **[O]**
Agents must not guess these; each has options and a recommended default in `OPEN_QUESTIONS.md`.
| Gap | Question |
|---|---|

## 4. Player actions **[D]**
- **Build:** both real-time during action (spending resources dropped by kills) **and** during the short breaks between waves (D-032).
- **Placement (D-040):** free placement on a fine grid inside a radius around the Guardian; **no tower cap**; towers can be sold for a partial gold refund but not moved. The player can move the camera (controls: Q-33). **[D]**
- **Towers = waifus.** Each tower is a waifu character placed around the Guardian, with her own attack, role and personality.
- **Guardian active skills:** the Guardian stays at the center and has active skills the player triggers (cooldown-based). The Guardian does not move and has no auto-attack. **[D]** M2 skills: Area blast (~12 s cooldown) and Shield (~25 s cooldown); Heal comes later as an upgrade (D-044). Numbers are placeholders in data.
- **M2 tower types:** ranged single-target damage, area (splash) damage, crowd control (slow) (D-045). **[D]**
- **Build radius and costs:** the buildable area starts at about 20 world units around the Guardian and grows via meta upgrades or cards; each extra copy of a tower costs more, which is the soft limit (D-042). **[D]** The cost grows linearly per copy (`cost + cost_per_copy * copies`, placeholder, D-099).
- **Level-ups:** killing enemies grants XP; on level-up the game pauses and offers a choice of **3 cards**. **[P]** Card types: new tower waifu, tower upgrade, Guardian skill upgrade, global perk. **Rules (D-051) [D]:** cards never give a tower for free; a "new tower waifu" card unlocks the right to build that tower this run and gold pays each placement; tower upgrade levels are bought with gold; no reroll, banish or skip in M3.

## 5. Waifu towers **[P]**
Each waifu has: role (damage / crowd control / support / tank / economy), attack pattern, 3-5 upgrade levels, tags (for synergies), 2-4 outfits, personality lines for barks.

### Synergies
- **Adjacency and relationships:** waifus with matching tags near each other get bonuses (e.g. "rivals" get a damage bonus, "best friends" share shields). Implemented through tag rules in data.
- Synergies are the main build-depth layer after the card draft, and the game's unique hook (D-057): waifus have named relationships (rivals, best friends, mentor/student) that give bonuses when placed near each other, and the roster and rescue order are designed around them. **[D]**

### Outfits **[P]**
- Each waifu can wear one outfit at a time. Outfits are **purely cosmetic**: no stats, no passives, no change to attacks (D-054). **[D]**
- Outfits unlock via a **Bond** level that rises when you use a waifu.
- Visual rule: stays within `05_STEAM_AND_COMPLIANCE.md`.

## 6. Enemies **[P]**
- Horde types in archetypes: swarmer (fast, weak), brute (slow, strong), ranged, flyer, elite, boss. M2 has swarmer, brute and ranged plus the bosses (D-095). Shots (towers and ranged enemies) hit instantly; the effect is visual only (D-098).
- Regular bosses are enemies only. **Only special named rival bosses ("rivals") are recruitable** as waifus after being defeated (no story involved, see D-028). **[D]** **2 rivals at launch**, appearing as the ~10:00 mini-boss on higher difficulty tiers; beating one for the first time unlocks her; they count toward the 8-10 roster (D-055). **[D]**
- Counts target: see performance budgets in `02_TECH_ARCHITECTURE.md`.

## 7. Meta-progression **[D that it exists; details P]**
- Hub screen between runs: spend meta currency on permanent upgrades, view roster, change outfits, view bond.
- Unlocks: new waifus (via victory), outfits (via bond), starting perks.

## 8. Economy **[P]**
- In-run: **gold** (drops, for building/upgrading towers; collected automatically when an enemy dies, coins fly to the Guardian as a visual, D-094) and **XP** (level-up cards).
- Meta: **hearts** (earned at run end, used in the hub) are the single meta currency and buy flat permanent upgrades from a data-defined tree (D-052). **[D]** **Bond** is tracked per waifu and only gates outfits. **[D]**

## 9. Controls and platforms **[D]**
- Windows PC (mouse + keyboard) and **Steam Deck** (gamepad). Gamepad must be a first-class input from the start; no feature may require a mouse only.
- **Camera (D-041):** PC uses WASD/arrows, edge scroll and mouse-wheel zoom; gamepad pans with the right stick, zooms with the bumpers and recentres on the Guardian with a button. The camera is limited to the buildable radius plus a margin and has 3 zoom levels. **[D]**
- **Gamepad building (D-046):** hold a button to open a radial tower menu, release to select; the placement cursor is at the screen centre (the world moves under it, snapped to the grid); A places, B cancels, skills are on the triggers. A slow-time-while-placing toggle is an accessibility option. Exact mapping goes in a controls spec. **[D]**

## 10. Art direction **[P]**
- Adult-proportioned stylized waifus (no chibi, D-030), 2.5D: 3D isometric camera, billboarded 2D art. Base resolution 2560x1440 (D-039). Details in `03_ART_PIPELINE.md`.
- Readability first: the horde must stay readable against the background; effects must not hide the Guardian.

## 11. Audio **[D]**
Licensed or royalty-free music, no voice acting, text barks with short sound blips, SFX from licensed packs (D-062). **[D]** Any AI-generated audio is disclosed to Steam.

## 12. Not in scope (for now)
Multiplayer, mobile, story campaign with cutscenes, adult-only content, live-generated AI content.
