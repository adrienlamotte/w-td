# 07 — Launch roster (proposal)

Status: **PROPOSED** (task 001, D-056). Everything here waits for the owner's approval; nothing is recorded in `DECISIONS.md` yet. All names are placeholders (Q-31, D-064).

Content rules: all waifus are clearly adult women with adult proportions, no chibi (D-030), and every look stays within `05_STEAM_AND_COMPLIANCE.md` section 2. The default looks below are modest; any suggestive outfit is a later Bond outfit (cosmetic only, D-054) and gets its own review.

## 1. Summary
10 waifus (D-025): 2 starters (D-031), 6 rescuable Guardians (D-050), 2 rival bosses (D-055).

| # | Name | Role | Status | Attack (sketch) | Tags | Relationships |
|---|---|---|---|---|---|---|
| 1 | Pip | damage | starter | single target (M2) | `steel`, `bff_pip_mallow`, `mentor_bastia_pip`, `rivals_vexa_pip` | best friend of Mallow; student of Bastia; rival of Vexa |
| 2 | Mallow | crowd control | starter | slow (M2) | `arcane`, `bff_pip_mallow`, `rivals_mallow_cinder` | best friend of Pip; rival of Cinder |
| 3 | Cinder | damage | Guardian, offer 1 | splash (M2) | `arcane`, `rivals_mallow_cinder`, `bff_cinder_tansy` | rival of Mallow; best friend of Tansy |
| 4 | Bastia | tank | Guardian, offer 2 | new kind (wall, 028) | `steel`, `mentor_bastia_pip`, `bff_bastia_clover` | mentor of Pip; best friend of Clover |
| 5 | Clover | economy | Guardian, offer 3 | new kind (gold, 028) | `nature`, `coin`, `bff_bastia_clover`, `rivals_gilda_clover` | best friend of Bastia; rival of Gilda |
| 6 | Hymn | support | Guardian, offer 4 | new kind (aura, 028) | `holy`, `mentor_hymn_poppy`, `bff_hymn_tansy` | mentor of Poppy; best friend of Tansy |
| 7 | Tansy | crowd control | Guardian, offer 5 | slow, area (M2 slow or new kind, 028) | `nature`, `bff_cinder_tansy`, `bff_hymn_tansy` | best friend of Cinder and Hymn |
| 8 | Poppy | support | Guardian, offer 6 | new kind (tower repair, 028) | `holy`, `mentor_hymn_poppy` | student of Hymn |
| 9 | Vexa | damage | rival boss | single target, long range (M2) | `arcane`, `rivals_vexa_pip`, `bff_vexa_gilda` | rival of Pip; best friend of Gilda |
| 10 | Gilda | economy | rival boss | new kind (gold on hit, 028) | `coin`, `rivals_gilda_clover`, `bff_vexa_gilda` | rival of Clover; best friend of Vexa |

Role count: damage 3 (Pip, Cinder, Vexa), crowd control 2 (Mallow, Tansy), support 2 (Hymn, Poppy), economy 2 (Clover, Gilda), tank 1 (Bastia). All five roles covered, none above 3.

Tags: a **relationship tag** (`bff_*`, `rivals_*`, `mentor_*`) names one pair and is carried by exactly those two waifus, so every relationship tag appears on two waifus and can trigger. **Trait tags** (`steel`, `arcane`, `holy`, `nature`, `coin`) are each shared by at least two waifus; they are reserved for cards and upgrades in task 028 and do nothing on their own.

## 2. Relationships (D-057)
10 pairs: 5 best friends, 3 rivals, 2 mentor/student. Bonus numbers, distance and rule format belong to task 028; the placement intent below is what the bonuses should reward in a maze (D-101, D-128).

| Tag | Pair | Kind | Maze placement intent |
|---|---|---|---|
| `bff_pip_mallow` | Pip + Mallow | best friends | The starter pair: slow and shoot at the same corridor. Teaches the hook from the very first run. |
| `rivals_mallow_cinder` | Mallow + Cinder | rivals | Frost vs fire: slow the crowd so it bunches up, then splash it at the same bend. Rivals compete, so the bonus should reward both covering the same corridor. |
| `mentor_bastia_pip` | Bastia (mentor) + Pip (student) | mentor/student | Bastia is the wall piece that walled-in enemies attack (D-103); Pip shoots from right behind her. |
| `bff_bastia_clover` | Bastia + Clover | best friends | Bastia guards the shop: an economy tower placed safely inside the maze behind the tank. |
| `rivals_gilda_clover` | Gilda + Clover | rivals | Two economy towers on the same kill zone, competing for the gold. |
| `mentor_hymn_poppy` | Hymn (mentor) + Poppy (student) | mentor/student | A support cluster in the middle of the maze, buffing and repairing the towers around them. |
| `bff_hymn_tansy` | Hymn + Tansy | best friends | Hymn's aura on a slow field: long corridors where enemies stay in range. |
| `bff_cinder_tansy` | Cinder + Tansy | best friends | Second slow + splash combo, available without the starters. |
| `rivals_vexa_pip` | Vexa + Pip | rivals | Two single-target shooters covering a long straight corridor. |
| `bff_vexa_gilda` | Vexa + Gilda | best friends | The rival duo: a sniper protecting the tax collector. |

Graph check: every waifu has at least one relationship; Pip is the hub (3) so early runs always have something to pair; every Guardian in the first offer group (Cinder, Bastia, Clover) pairs directly with a starter or with another member of the group.

## 3. Offer order (D-050)
The data-defined order in which locked waifus enter the Guardian offer:

| Order | Waifu | Why here |
|---|---|---|
| 1 | Cinder | Brings the third M2 attack kind (splash) and a rival for Mallow. |
| 2 | Bastia | First new role (tank), mentor of the starter Pip. |
| 3 | Clover | Economy; best friend of Bastia, so rescuing Bastia and Clover gives a pair. |
| 4 | Hymn | First support, mentor of Poppy. |
| 5 | Tansy | Second crowd control; links Cinder and Hymn. |
| 6 | Poppy | Second support; completes the Hymn pair. |

Initial offer: **Cinder, Bastia, Clover** (group 1). Each rescue frees a slot that the next in order fills (Hymn, then Tansy, then Poppy), so group 2 is **Hymn, Tansy, Poppy**; with fewer than 3 left, all remaining are shown (D-050).

Rivals are never in the offer: each is unlocked the first time she is beaten as the ~10:00 mini-boss on a higher tier (D-055). Proposed: Vexa on Hard, Gilda on Nightmare. When higher tiers open relative to Guardian rescues is undecided: **Q-60**.

## 4. M2 tower kinds and roles (D-045)
| M2 kind | Role | Waifus |
|---|---|---|
| Ranged single target | damage | Pip (starter), Vexa (rival) |
| Area (splash) | damage | Cinder |
| Crowd control (slow) | crowd control | Mallow (starter), Tansy (possibly as an area variant) |

Tank, support and economy have no M2 kind; their attack kinds (wall, aura, repair, gold) are designed in task 028. The two starters use M2 kinds only, so the first run needs no new mechanic.

## 5. Waifus
Barks are short personality lines, no story (D-028).

### 1. Pip — damage, starter
- Archetype: eager rookie adventurer, overconfident and cheerful.
- Look: adult woman, ponytail, green tunic, shorts, boots, shortbow. Modest.
- Barks: "First try! ...Okay, fifth try." / "Mentor, did you see that one?"
- Note: the pipeline test character `waifu_test01` (`08_FIRST_CHARACTER_BRIEF.md`, a generic modest adventurer) fits this slot. The brief says she is not a roster member; reusing her look for Pip is the owner's call at the M4 art stage.

### 2. Mallow — crowd control, starter
- Archetype: sleepy deadpan frost mage; slows enemies because she is barely awake.
- Look: adult woman, long pale-blue hair, oversized hooded robe and scarf, staff with a snowflake.
- Barks: "Five more minutes." / "Everyone slow down. Like me."

### 3. Cinder — damage (splash), Guardian
- Archetype: hotheaded show-off fire witch.
- Look: adult woman, red bob, pointed witch hat, short cape over a fitted dress, fingerless gloves.
- Barks: "Was that too much? No such thing!" / "Mallow, you're blocking my explosions."

### 4. Bastia — tank, Guardian
- Archetype: stoic big-sister knight with a sweet tooth.
- Look: tall adult woman, short dark hair, full plate armour, tower shield, a cookie tin on her belt.
- Barks: "Behind me. Always." / "I will hold this line. And this cookie."

### 5. Clover — economy, Guardian
- Archetype: cheerful haggler running a lucky-charm stall.
- Look: adult woman, green braids, apron over a blouse and long skirt, big backpack of goods.
- Barks: "Everything's for sale! Except Bastia." / "Kill bonus? I'll take that."

### 6. Hymn — support, Guardian
- Archetype: dramatic diva priestess who sings buffs.
- Look: adult woman, golden curls, white and gold vestments, hand bell.
- Barks: "Encore! Fight harder!" / "Poppy, posture. And bandages."

### 7. Tansy — crowd control, Guardian
- Archetype: shy gardener druid; her vines tangle everything.
- Look: adult woman, brown hair with flowers, leaf-trimmed tunic, gardening gloves, watering can.
- Barks: "Sorry! The roses are angry." / "Please don't step on the seedlings."

### 8. Poppy — support, Guardian
- Archetype: bossy field medic who scolds the towers she repairs.
- Look: adult woman, red hair in a bun, medic coat and satchel, oversized wrench.
- Barks: "Hold still, I'm fixing you." / "Who let you get this dented?"

### 9. Vexa — damage, rival boss
- Archetype: smug demon sharpshooter who thinks Pip is beneath her.
- Look: tall adult woman, small horns, dark long coat and gloves, ornate crossbow.
- Barks: "Missed? I don't miss." / "Rookie. Watch and learn."

### 10. Gilda — economy, rival boss
- Archetype: greedy noble tax collector, all charm and invoices.
- Look: adult woman, piled-up blonde hair, gown with a long coat, monocle, ledger.
- Barks: "That will be a fee." / "Clover, your prices are an insult."

## 6. Open points
- **Q-60** When the higher tiers open relative to rescues, which decides when rivals can be recruited.
- **Q-61** Whether relationship bonuses count the current Guardian (she is not placed as a tower). This roster assumes **towers only** (the conservative option) until answered.
- Bonus numbers, distance and the new attack kinds: task 028.
