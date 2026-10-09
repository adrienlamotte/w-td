# 10 — M3 content proposal: cards, upgrades, synergies, meta tree

Status: **DECIDED** (approved by the owner on 2026-10-09: D-133 to D-138), **except section 4.1 (the 6 Guardian signature skills) and the skill cards in section 2.3, which are PROPOSED** and await the owner's approval. Every number is a placeholder (data files carry `"placeholder": true`) and is tuned by the M3 balance runner. Names are placeholders (D-064). Owner answers: Q-62 (D-133), Q-63 (D-134), Q-64 (D-135), Q-65 (D-136), Q-66 (D-137); the rest is D-138.

Sources: `01_GAME_DESIGN.md` 4, 5, 7, 8; `07_ROSTER.md` (D-130); `02_TECH_ARCHITECTURE.md` 3a; D-023, D-031, D-044, D-048, D-050 to D-058, D-099, D-101 to D-118, D-124, D-128, D-131, D-132.

## 0. Scope and why it is small
- **25 cards, 4 upgrade levels per waifu, 10 relationship rules, 12 meta nodes.** That is the smallest set that still makes two runs differ: which waifus you draft (6 new-tower cards), which of them you push to a signature level (8 signature cards), how your Guardian plays (4 skill cards) and which global bend you take (6 perks, 3 of them stackable). Each extra card costs data, UI text, a test and balance-runner time; M5 adds content once the loop is proven (CP-M3).
- **M3 ships the 8 non-rival waifus** (2 starters, 6 Guardians) as data with placeholder art. The 2 rivals (Vexa, Gilda) appear only on higher tiers, which open after all 6 rescues (D-131) and are not in M3 scope (`06_ROADMAP.md` M5); their tower kinds are specified in section 3 so the sim supports them, but their cards and data files come with the tiers.
- **Per-tick cost:** the maze scenarios sit at the 8 ms budget (D-124). Every new mechanic below is either computed only when the layout changes (synergies, aura, derived stats) or reuses an existing per-shot path (single, splash, slow). No new per-enemy, per-tick loop is added. Section 3.3 lists the cost of each kind.

## 1. XP and level-ups
- **Earning XP:** each enemy type already has `xp` in data (swarmer 1, ranged 2, brute 4, mini-bosses 50 / 80, final boss 200). XP is added in the DEATHS phase with the gold, for every enemy killed by any source (towers, thorns, skills), times the run's XP multiplier (perks, meta). The run keeps a float XP total (added in index order, so deterministic) and compares it with the level thresholds below.
- **Curve (linear step, quadratic total):** XP to go from level `L` to `L + 1` = `xp_base + xp_step * (L - 1)`, with `xp_base = 30`, `xp_step = 30` (run data). Level 2 at 30 XP, level 5 at 300, level 10 at 1350, level 17 at 4080. At the M2 wave counts a 15-minute run yields about 4800 XP, so **about 17 level-ups per run (level 18 at 4590 XP), a bit more than one per wave**, steady because the wave counts ramp as fast as the curve.
- **When the draft happens:** a level-up is detected at the end of the DEATHS phase; the sim pushes `LEVEL_UP` (a = new level) and enters `drafting` (frozen exactly like a pause: no movement, no clock, commands still applied, building refused like D-105). The 3 cards are drawn at that moment with the `cards` RNG (`hash([seed, "cards"])`, already planned in 3a) and stored in the world (replays stay deterministic). A new `PICK_CARD{slot 0..2}` command applies the card and leaves `drafting`. Several level-ups in one tick queue: the next draft opens right after the pick. Pausing during a draft is allowed; the draft stays open.
- **What the 3 cards are drawn from:** the eligible cards (section 2) minus cards at their pick limit. Draw 3 distinct cards without replacement: first pick a card type by weight among types that still have an eligible card (`new_tower` 3, `signature` 2, `skill` 2, `perk` 2), then a card uniformly within that type. If fewer than 3 cards are eligible, the empty slots show the filler card `card_purse`. No reroll, banish or skip (D-051): the player must take one.

## 2. Card pool (25 cards)
Data: `data/cards/card_<id>.json` with `id`, `type` (`new_tower`, `signature`, `skill`, `perk`, `filler`), `name_key`, `desc_key`, `max_picks` (filler: 0 = unlimited), `requires` (eligibility, below) and an `effects` list using the effect vocabulary of section 2.5.

### 2.1 New tower waifu (6)
| Card | Effect | Eligible when |
|---|---|---|
| `card_tower_cinder` | Adds `tower_cinder` to the run's buildable towers | Cinder is unlocked in the profile (rescued) and not yet buildable this run |
| `card_tower_bastia` | Adds `tower_bastia` | same rule |
| `card_tower_clover` | Adds `tower_clover` | same rule |
| `card_tower_hymn` | Adds `tower_hymn` | same rule |
| `card_tower_tansy` | Adds `tower_tansy` | same rule |
| `card_tower_poppy` | Adds `tower_poppy` | same rule |

Interaction with the roster (D-031, D-051): the 2 starters (Pip, Mallow) are buildable from the start of every run and have no new-tower card. A rescued Guardian (D-023) becomes eligible as a new-tower card in later runs; the card only grants the right to build her, and gold pays each placement with the usual rising price (D-099). The current Guardian is still locked, so her card is never eligible in her own run. The first run (nothing rescued) therefore has no new-tower card at all; its drafts are signatures, skills and perks, and the run plays with Pip and Mallow only (both M2 kinds, `07_ROSTER.md` 4).

### 2.2 Tower upgrade: signature (8)
One per M3 waifu: `card_sig_pip`, `card_sig_mallow`, `card_sig_cinder`, `card_sig_bastia`, `card_sig_clover`, `card_sig_hymn`, `card_sig_tansy`, `card_sig_poppy`. Effect: unlocks level 4 (her signature, section 3.2) for every copy of that waifu this run; each copy still buys the level with gold. Eligible when that waifu is buildable this run. `max_picks` 1. Per D-134 (levels 2-3 with gold only, level 4 needs the card).

### 2.3 Guardian skill upgrade (4) — PROPOSED
Every Guardian has her own signature skill plus the shared Shield (D-133, section 4). The two signature cards work on whichever signature skill the Guardian has: each skill file lists its `power_stats` (section 4.1), so one card covers all six.
| Card | Effect (Shield: 50 absorb, 5 s, 25 s cooldown) | Max |
|---|---|---|
| `card_skill_sig_power` | Signature skill power +50% (multiplies her `power_stats`, section 4.1) | 1 |
| `card_skill_sig_quick` | Signature skill cooldown -25% | 1 |
| `card_skill_shield_plus` | Shield absorb x2 and duration +2 s | 1 |
| `card_skill_mending` | Heal (D-044): casting Shield also restores 40 Guardian HP (capped at max HP). An upgrade of an existing skill, so no third skill button | 1 |

### 2.4 Global perk (6) and filler (1)
| Card | Effect | Max |
|---|---|---|
| `perk_sharp` | All towers damage +10% | 3 |
| `perk_bounty` | Gold from kills +20% (rounded down per kill, before mark gold) | 2 |
| `perk_study` | XP gained +15% | 2 |
| `perk_masonry` | All towers max HP +30%; rebuild price -50% | 1 |
| `perk_expand` | Build radius +3 | 2 |
| `perk_maze` | "Lost in the maze": towers deal +20% damage to enemies that are detouring (their cell has no clear line to the Guardian, `hit[c] != -1` in the flow field) | 2 |
| `card_purse` (filler) | +40 gold. Only fills empty draft slots | unlimited |

`perk_maze` is the most direct maze payoff (D-128): enemies walking a corridor take more damage than enemies on a straight run. `perk_expand` needs the build grid to be allocated at StartRun for the largest reachable radius (base + meta + 2 perks); placement still checks the current radius (note for the implementer: a bigger grid lengthens a flow-field computation, not the per-tick cost, which is capped by `CELLS_PER_TICK`).

### 2.5 Effect vocabulary (data)
`{"stat": <name>, "op": "add" | "mult", "value": <number>, "target": <scope>}` with targets `all_towers`, `tower:<id>`, `guardian`, `skill:<id>`, `run`. Stats: `damage`, `cooldown`, `range`, `hp`, `kill_gold`, `xp`, `build_radius`, `rebuild_price`, `detour_damage`, `skill_power` (multiplies the signature skill's `power_stats`), `skill_cooldown`, `shield_absorb`, `shield_duration`, `shield_heal`, `gold` (instant), plus `unlock_tower` and `unlock_level` for new-tower and signature cards. Multipliers of the same stat add up (two `perk_sharp` = +20%, not 1.1 x 1.1); final cooldowns are clamped to at least 50% of the level value and at least 1 tick.

## 3. Tower waifus
### 3.1 Attack kinds
M2 kinds are unchanged (D-114). New kinds, each defined so the sim cost stays flat:

| Kind | Waifu | Rule |
|---|---|---|
| `single` | Pip, Vexa | M2: hits the nearest enemy in range |
| `slow` | Mallow | M2: hits and slows the target (D-117) |
| `splash` | Cinder | M2: hits every enemy centre within `splash_radius` of the target |
| `slow_area` | Tansy | Like `splash` (same query), but every enemy hit is also slowed (`slow_factor`, `slow_sec`, D-117 rule) |
| `wall` | Bastia | Never targets or fires. Cheap, high HP. **Thorns:** when a walled-in enemy hits her (D-116 path), the attacker takes `thorns` damage through `damage_enemy`. Her job is to be the maze wall |
| `aura` | Hymn | Never targets or fires. Every other live tower whose centre is within `aura_radius` of hers gets `aura_damage` (damage +x%) and `aura_cooldown` (cooldown -x%). Auras do not stack: the strongest Hymn in reach applies (like slows, D-117) |
| `repair` | Poppy | Every `cooldown`, heals `heal` HP to the live tower in range with the lowest HP fraction (below 100%; husks excluded). Per D-135: if no tower needs it and the Guardian's body is in range, heals the Guardian for `guardian_heal` instead. L4 heals the 2 lowest |
| `mark` | Clover | Shoots the nearest enemy for `damage` and marks it for `mark_sec`: if a marked enemy dies (any source), it drops `mark_gold` extra gold. Marks do not stack: the higher `mark_gold` applies and the longer expiry wins |
| `tax` | Gilda | Like `single`, and each hit adds `gold_per_hit` gold at once |

### 3.2 Stats and upgrade levels
Pattern for every waifu: **4 levels**, level 1 when placed; levels 2 and 3 are bought with gold on a placed tower at any time (no card); level 4 is the **signature** and needs her signature card this run (D-134). Upgrades are per placed tower (D-137) through a new `UPGRADE_TOWER{tower_uid}` command (RUNNING, not paused or drafting; refused on a husk or without gold). The upgrade price does not grow with copies. Upgrade gold adds to `paid`, so selling refunds `sell_refund` of everything paid and a rebuild costs `rebuild_fraction` of it and keeps the level (D-113). Level values are absolute (no compounding). Shared by all unless listed: `radius` 0.5 (2 x 2 cells), `sell_refund` 0.5, `rebuild_fraction` 0.3.

Level columns: cost to buy that level, then only the stats that change.

| Waifu (kind) | Level 1 (place) | Level 2 | Level 3 | Level 4 signature |
|---|---|---|---|---|
| Pip (`single`) | cost 50 (+10/copy), hp 100, range 6, damage 6, cooldown 0.5 s | 40: damage 8 | 60: damage 10, range 7 | 100 "Double tap": cooldown 0.35 s |
| Mallow (`slow`) | 60 (+10), hp 80, range 5, damage 0.5, cooldown 1.0 s, slow 0.5 for 2 s | 45: slow 3 s | 75: slow factor 0.4, range 6 | 120 "Deep freeze": slow factor 0.3, damage 2 |
| Cinder (`splash`) | 80 (+15), hp 80, range 5, damage 3, cooldown 1.2 s, splash 1.5 | 60: damage 4.5 | 100: damage 6, splash 2.0 | 160 "Overheat": cooldown 0.8 s |
| Bastia (`wall`) | 40 (+5), hp 400, thorns 3 | 30: hp 600 | 50: hp 800, thorns 6 | 80 "Bulwark": hp 1200, thorns 10 |
| Clover (`mark`) | 60 (+10), hp 80, range 5, damage 1, cooldown 1.0 s, mark 4 s, mark gold 2 | 45: mark gold 3 | 75: cooldown 0.7 s, range 6 | 120 "Lucky charm": mark gold 5, mark 6 s |
| Hymn (`aura`) | 90 (+15), hp 80, aura radius 3, damage +20%, cooldown -10% | 70: damage +30% | 110: aura radius 4 | 170 "Encore": damage +40%, cooldown -20% |
| Tansy (`slow_area`) | 80 (+15), hp 80, range 5, damage 0.5, cooldown 1.5 s, area 1.5, slow 0.6 for 2 s | 60: area 2.0 | 100: slow factor 0.5, slow 3 s | 160 "Overgrowth": area 2.5, cooldown 1.0 s |
| Poppy (`repair`) | 70 (+10), hp 80, range 4, cooldown 2.0 s, heal 20, Guardian heal 10 | 50: heal 30, Guardian heal 15 | 80: cooldown 1.5 s, range 5 | 130 "Field hospital": 2 targets, heal 40, Guardian heal 20 |
| Vexa (`single`, M5) | 90 (+15), hp 80, range 10, damage 20, cooldown 1.5 s | 60: damage 28 | 100: damage 36, range 12 | 150 "Executioner": damage 50 |
| Gilda (`tax`, M5) | 80 (+15), hp 80, range 6, damage 3, cooldown 0.8 s, 1 gold per hit | 60: damage 4 | 90: 2 gold per hit | 140 "Audit": 3 gold per hit, cooldown 0.6 s |

Pip, Mallow and Cinder level 1 are exactly the M2 `tower_single_01`, `tower_slow_01`, `tower_splash_01` values, so the M2 balance baseline carries over. Bastia is the cheapest tower on purpose: a cheap wall piece makes building a maze affordable (D-128).

Data shape (extends the M2 tower file, D-099): the level 1 stats stay where they are; a new `levels` array holds levels 2-4 as `{"cost": n, <changed stats>}`, and level 4 carries `"needs_card": "card_sig_<waifu>"`. New fields per kind: `thorns`, `aura_radius`, `aura_damage`, `aura_cooldown`, `heal`, `guardian_heal`, `heal_targets`, `mark_sec`, `mark_gold`, `gold_per_hit`. Tower ids `tower_<waifu>`; a new `data/waifus/waifu_<id>.json` holds `role`, `tags`, `status` (`starter`, `guardian`, `rival`), `offer_order`, and references `tower_<id>` and `guardian_<id>`, so `07_ROSTER.md` lives in data in one place.

### 3.3 Per-tick cost
- **Derived tower stats** (level x perks x aura x synergies: effective damage, cooldown ticks, range, max HP, plus aura and relationship flags) are stored per tower in packed arrays and recomputed only when the layout or a modifier changes: place, sell, rebuild, upgrade, a tower dying (husk), a card pick. The change sets a dirty flag; the recompute runs once in the next PATH phase. It scans tower pairs within the largest reach (synergy max distance 6, aura radius 4) through the build grid cells, so it is about towers x nearby towers, once per change, never per tick. When max HP rises the tower gains the difference; when it falls HP is clamped.
- `wall`, `aura`: no targeting and no firing: cheaper per tick than any M2 tower (they skip the targeting phase).
- `slow_area`: one `query_radius` per shot, the same as `splash`.
- `mark`: one shot like `single`; two new enemy arrays `mark_gold` and `mark_until` (absolute clock tick, so nothing counts down per tick), swapped in `remove()`, read once in DEATHS.
- `tax`: one shot like `single` plus a gold add.
- `repair`: on its cooldown only, scans the towers in its range from a neighbour list built by the derived-stats recompute.
- Thorns: one `damage_enemy` inside the existing walled-in enemy attack.
- `perk_maze`: one cell lookup (`hit[c]`) per tower hit, only when the perk is held.

## 4. Guardian skills
Decided (D-133): each Guardian has her **own signature skill in place of Area blast**; **Shield is shared**. Her identity also comes from her relationships (D-132, section 5). Cooldowns run on the run clock and both skills are ready at the start (D-110). The 2 starters and the 2 rivals become Guardians only once everything is unlocked (D-058: tier, endless and challenge runs), so **their signature skills are deferred to M5**.

### 4.1 The 6 signature skills — PROPOSED
Cost rules: a cast does its work once, in the COMMANDS phase (a linear scan over enemies or towers is allowed only inside the cast, like Area blast, D-110). A timed effect stores an absolute `until` clock tick that an existing code path checks where it already runs (no per-tick loop, zero cost when idle). `power_stats` are what `card_skill_sig_power` and the rivals' Guardian bonus multiply.

| Guardian | Skill (kind) | Effect | Cooldown | `power_stats` | Cost |
|---|---|---|---|---|---|
| Cinder | **Big Finish** (`area_blast`, the M2 kind with her numbers) | Every enemy whose body touches the disk of radius 6 around her takes 40 damage | 14 s | `damage` | One linear scan per cast (as Area blast) |
| Bastia | **Stand Firm** (`guard`) | For 6 s, every tower and the Guardian take 50% less damage | 25 s | `duration_sec` | `damage_tower` and `_hit_guardian` check `clock < guard_until` |
| Clover | **Clearance Sale** (`bounty`) | For 8 s, every enemy that dies drops 4 extra gold | 30 s | `gold_per_kill` | DEATHS checks `clock < bounty_until` |
| Hymn | **Crescendo** (`haste`) | For 6 s, each tower's cooldown after a shot is 60% of its value | 25 s | `duration_sec` | The tower-attack cooldown reset checks `clock < haste_until` |
| Tansy | **Tangle** (`snare`) | Every enemy within radius 7 of her is slowed to 0.15 for 3 s (the D-117 slow rule; bosses too, like tower slows) | 18 s | `duration_sec` | One linear scan per cast, then the existing slow arrays |
| Poppy | **Emergency Rebuild** (`rebuild`) | Rebuilds every husk for free (full HP, cells solid again) and heals the Guardian 40 HP | 40 s | `guardian_heal` | One loop over towers per cast |

Maze fit: Big Finish clears the crowd queued at the Guardian's end of the corridors; Stand Firm holds a full wall (D-102) while walled-in enemies hit it; Clearance Sale pays for the maze during a wave peak; Crescendo multiplies a dense kill zone; Tangle freezes the crowd inside the corridors near her; Emergency Rebuild closes the gaps husks opened (D-104) in one cast. Placeholder rules: the power card rounds integer stats down (Clearance Sale 4 to 6 gold); Tangle's slow factor is not multiplied, only its duration.

Data: one `data/skills/skill_<id>.json` per signature skill (`kind` in `area_blast, guard, bounty, haste, snare, rebuild`, `cooldown_sec`, the effect fields above, `power_stats`); one `data/guardians/guardian_<waifu>.json` per Guardian (hp 400, contact radius 1.0, skills `[skill_<her signature>, skill_shield]`). The run's Guardian comes from `StartRun` (a new `guardian_id` field) instead of the run file. `skill_area_blast` stays for the M2 placeholder Guardian and the tests.

## 5. Synergies (relationship rules)
### 5.1 Rule format
One file per relationship: `data/synergies/syn_<tag>.json`.
```json
{
  "schema_version": 1,
  "id": "syn_bff_pip_mallow",
  "placeholder": true,
  "tag": "bff_pip_mallow",
  "kind": "bff",
  "name_key": "syn.bff_pip_mallow.name",
  "min_distance": 0,
  "max_distance": 2.5,
  "bonuses": [
    {"waifu": "waifu_pip", "stat": "damage", "op": "mult", "value": 0.2},
    {"waifu": "waifu_mallow", "stat": "slow_sec", "op": "add", "value": 1}
  ],
  "guardian_bonus": {"stat": "shield_absorb", "op": "mult", "value": 0.25}
}
```
- **Active for a tower** when at least one live partner (a live tower of the other waifu, or the current Guardian if she is the other waifu, D-132) has its centre within `[min_distance, max_distance]` of the tower's centre. For the Guardian the distance is measured from her body edge (`d - guardian contact_radius`), since she is larger than a tower. Husks and bare towers never count.
- **No stacking per partner:** one partner is enough; two Mallows near one Pip still give Pip +20% once. Different relationships on the same tower add up (Pip next to Mallow and Bastia gets both).
- **Guardian side:** when the Guardian is a member and at least one partner tower is in reach, she gets `guardian_bonus` once per relationship. Per kind: best friends `shield_absorb` +25%, mentor/student `skill_cooldown` -10%, rivals `skill_power` +25%.
- **Why the maze pays off (D-128):** best friends and mentor/student need `max_distance` 2.5 (centre to centre; touching towers are 1.0 apart), so pairs sit in the same wall segment, which is how maze walls are built. Rivals need `min_distance` 2 and `max_distance` 6 (D-136): rivals refuse to stand together, so their bonus only fires across a corridor, from the two walls lining it. Combined with slows (longer time in range), Bastia's cheap walls, Hymn's aura over a wall cluster and `perk_maze`, a corridor layout gets bonuses a ring of spread towers does not.
- Cost: evaluated in the derived-stats recompute (section 3.3), never per tick.

### 5.2 Initial relationship bonuses
| Tag | Distance | Tower bonuses | Guardian bonus |
|---|---|---|---|
| `bff_pip_mallow` | 0-2.5 | Pip damage +20%; Mallow slow +1 s | shield absorb +25% |
| `rivals_mallow_cinder` | 2-6 | Mallow cooldown -20%; Cinder damage +25% | skill power +25% |
| `mentor_bastia_pip` | 0-2.5 | Bastia hp +30%; Pip damage +25% | skill cooldown -10% |
| `bff_bastia_clover` | 0-2.5 | Bastia thorns +3; Clover mark gold +1 | shield absorb +25% |
| `rivals_gilda_clover` | 2-6 | Gilda gold per hit +1; Clover mark gold +1 | skill power +25% |
| `mentor_hymn_poppy` | 0-2.5 | Hymn aura radius +1; Poppy heal +50% | skill cooldown -10% |
| `bff_hymn_tansy` | 0-2.5 | Hymn aura radius +1; Tansy slow +1 s | shield absorb +25% |
| `bff_cinder_tansy` | 0-2.5 | Cinder range +1; Tansy cooldown -20% | shield absorb +25% |
| `rivals_vexa_pip` | 2-6 | Vexa damage +20%; Pip cooldown -20% | skill power +25% |
| `bff_vexa_gilda` | 0-2.5 | Vexa range +1; Gilda gold per hit +1 | shield absorb +25% |

Rival rows (Vexa, Gilda) ship with the rivals (M5); the data format supports them now. Trait tags (`steel`, `arcane`, `holy`, `nature`, `coin`) get no rule in M3: no card or rule needs them yet, and they stay reserved (`07_ROSTER.md` 1).

Guardian examples: with Cinder as Guardian, a Mallow 2-6 units from her edge gets -20% cooldown and Cinder gets +25% skill power (Big Finish damage); a Tansy right next to her gets -20% cooldown and Cinder +25% shield absorb.

## 6. Meta-progression
### 6.1 Hearts per run (D-048)
- **Win:** 100 hearts.
- **Loss:** `floori(100 * (0.30 + 0.20 * min(1, clock / final_boss_tick)))`: 30 at 0:00, 40 at 7:30, 50 if she falls after the final boss spawned.
- **Abandon** (Main menu from the pause menu, or discarding a suspended run) counts as a loss at the time reached. Hearts are added to the profile at run end only.
- Run data: `hearts_win`, `hearts_loss_min`, `hearts_loss_max`.

### 6.2 Meta tree (12 nodes, flat permanent upgrades, D-052)
Data: `data/meta/meta_<id>.json` with `id`, `name_key`, `desc_key`, `cost`, `requires` (node ids), `effects` (the card effect vocabulary, applied at StartRun). Three branches; a node needs its `requires` bought. Total cost 1240 hearts: the whole tree after about 12 wins (or more runs with losses), roughly when the 6 Guardians are rescued.

| Node | Branch | Effect | Cost | Requires |
|---|---|---|---|---|
| `meta_gold_1` | Economy | Starting gold +50 | 60 | - |
| `meta_gold_2` | Economy | Starting gold +50 | 120 | `meta_gold_1` |
| `meta_kill_gold` | Economy | Gold from kills +10% | 120 | `meta_gold_1` |
| `meta_refund` | Economy | Sell refund +0.15 (0.5 to 0.65) | 60 | - |
| `meta_hp_1` | Guardian | Guardian max HP +10% | 80 | - |
| `meta_hp_2` | Guardian | Guardian max HP +10% | 160 | `meta_hp_1` |
| `meta_skill_cd` | Guardian | Skill cooldowns -10% | 150 | `meta_hp_1` |
| `meta_xp` | Guardian | XP gained +10% | 100 | - |
| `meta_tower_hp` | Towers | Tower max HP +15% | 80 | - |
| `meta_rebuild` | Towers | Rebuild fraction -0.1 (0.3 to 0.2) | 60 | `meta_tower_hp` |
| `meta_radius` | Towers | Build radius +2 | 100 | - |
| `meta_discount` | Towers | Tower placement price -5% | 150 | `meta_radius` |

## 7. Save scope (D-053)
- **Meta profile** (`user://profile.json`, written at run end and after every hub purchase, atomically: write a temp file, then rename): `schema_version`; `unlocked` (rescued waifu ids; starters are implicit); `hearts`; `meta_nodes` (bought ids); `bond` (per waifu, an integer kept at 0 in M3: bond only gates outfits, D-052, D-054, and its gain rule comes with outfits); `stats` (runs, wins, losses, best time per Guardian). The Guardian offer (D-050) is derived from `unlocked` and the data offer order, not stored. Loading runs one migration step per older `schema_version`; an unreadable profile is kept aside as `profile.bad.json` and never silently overwritten.
- **Suspend save** (`user://suspend.json`): written when a draft opens (card boundary) and at `WAVE_STARTED` (wave boundary), never mid-wave. Holds the run id, Guardian id, seed, the full sim state (entity arrays, gold, XP, level, open draft, picked cards, tower levels and paid, RNG states, command queue, clock) and `state_hash()` to check on load. On launch with a suspend file the start screen offers Resume or Abandon (abandon = loss, section 6.1). Deleted at run end. Technical note for the lead dev: a snapshot, not a replay from `(seed, commands)`, because replaying up to 27 000 ticks would take minutes.
- Not saved: settings (session-only so far, D-125), the derived grids and fields (rebuilt on load).

## 8. Sim and data summary (for the implementation plan)
- New data folders: `cards`, `synergies`, `meta`, `waifus`; new tower and guardian files per waifu; run file gains `xp_base`, `xp_step`, the hearts fields and drops `guardian` (now a StartRun field).
- New commands: `PICK_CARD{slot}`, `UPGRADE_TOWER{tower_uid}`; `START_RUN` gains `guardian_id` and the profile modifiers (unlocked waifus, meta effects) so the run stays a pure function of `(seed, start data, commands)`.
- New events: `LEVEL_UP` (a = level), `CARD_PICKED` (a = card index), `TOWER_UPGRADED` (a = uid, value = level), `TOWER_REPAIRED` (a = uid or -1 for the Guardian, value = HP); thorns damage is a normal `ENEMY_HIT` (no new kind).
- New world state (hashed): `guard_until`, `bounty_until`, `haste_until`, XP, level, draft cards and `drafting`, picked-card counts, per-tower `level`, enemy `mark_gold` and `mark_until`.
