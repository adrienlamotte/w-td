# 01 — Game Design Document

Status key: **[D]** decided, **[P]** proposed, **[O]** open.

## 1. Pitch
You protect a waifu at the center of an open field while an enormous horde swarms from every direction. You build defenses out of other waifus, level up and draft upgrades like in Vampire Survivors, and use the protected waifu's active skills. Win a run and the waifu you protected joins your roster as a tower. **[D]**

Tone: cute and comedic fantasy. **[D]** Characters are adult and stylized (chibi). **[P]**

## 2. Pillars
1. **Protect her.** The protected waifu ("the Guardian") is the emotional stake. Lose condition = her HP reaches 0. **[D]**
2. **Horde chaos.** Hundreds to thousands of enemies on screen, constant escalation, satisfying kills. **[D]**
3. **Build over time.** Roguelite draft choices create different builds each run. **[D]**
4. **Fanservice as a choice.** Outfits trade defense for power; suggestive outfits are risk/reward, not just cosmetics. **[P]**
5. **Collect them all.** Winning unlocks new waifus; the roster is the long-term goal. **[D]**

## 3. Run structure **[D unless noted]**
- Length: **15-20 minutes** per run.
- Map: **open field, 360° swarm**, no lanes. Enemies path straight toward the Guardian and attack towers in the way.
- Escalation: continuous spawn curve with waves; a **mini-boss every ~5 minutes** **[P]** and a **final boss at the end**.
- Win: survive until the final boss is defeated. Lose: Guardian HP = 0.
- **Win reward:** the Guardian protected in this run is unlocked as a **tower waifu** for future runs.
- **Guardian each run:** the next **locked waifu** you "rescue". Unlocked waifus are towers only. **[D]** Rescue order (fixed vs varied) and replay value after everyone is unlocked: **[O]**, see `OPEN_QUESTIONS.md`.
- **Roster target at Early Access launch: 8-10 waifus.** **[D]**

## 4. Player actions **[D]**
- **Build:** both real-time during action (spending resources dropped by kills) **and** short build phases between waves.
- **Towers = waifus.** Each tower is a waifu character placed around the Guardian, with her own attack, role and personality.
- **Guardian active skills:** the Guardian stays at the center and has active skills the player triggers (cooldown-based; e.g. shield, heal, area blast). The Guardian does not move. **[D]**
- **Level-ups:** killing enemies grants XP; on level-up the game pauses and offers a choice of **3 cards**. **[P]** Card types: new tower waifu, tower upgrade, Guardian skill upgrade, global perk.

## 5. Waifu towers **[P]**
Each waifu has: role (damage / crowd control / support / tank / economy), attack pattern, 3-5 upgrade levels, tags (for synergies), 2-4 outfits, personality lines for barks.

### Synergies
- **Adjacency and relationships:** waifus with matching tags near each other get bonuses (e.g. "rivals" get a damage bonus, "best friends" share shields). Implemented through tag rules in data.
- Synergies are the main build-depth layer after the card draft.

### Outfits **[P]**
- Each waifu can wear one outfit at a time. Outfits modify stats (example: lingerie/bikini = high damage, low defense; armor = the opposite).
- Outfits unlock via a **Bond** level that rises when you use a waifu.
- Visual rule: stays within `05_STEAM_AND_COMPLIANCE.md`.

## 6. Enemies **[P]**
- Horde types in archetypes: swarmer (fast, weak), brute (slow, strong), ranged, flyer, elite, boss.
- Regular bosses are enemies only. **Only special story bosses ("rivals") are recruitable** as waifus after being defeated. **[D]** How many, and when: **[O]**.
- Counts target: see performance budgets in `02_TECH_ARCHITECTURE.md`.

## 7. Meta-progression **[D that it exists; details P]**
- Hub screen between runs: spend meta currency on permanent upgrades, view roster, change outfits, view bond.
- Unlocks: new waifus (via victory), outfits (via bond), starting perks.

## 8. Economy **[P]**
- In-run: **gold** (drops, for building/upgrading towers) and **XP** (level-up cards).
- Meta: **hearts/affection** (earned at run end, used in the hub).

## 9. Controls and platforms **[D]**
- Windows PC (mouse + keyboard) and **Steam Deck** (gamepad). Gamepad must be a first-class input from the start; no feature may require a mouse only.

## 10. Art direction **[P]**
- Chibi waifus, 2.5D: 3D isometric camera, billboarded 2D art. Details in `03_ART_PIPELINE.md`.
- Readability first: the horde must stay readable against the background; effects must not hide the Guardian.

## 11. Audio **[O]**
Not discussed yet. Placeholder only until decided.

## 12. Not in scope (for now)
Multiplayer, mobile, story campaign with cutscenes, adult-only content, live-generated AI content.
