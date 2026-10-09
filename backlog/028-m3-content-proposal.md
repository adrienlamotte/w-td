# 028 — M3 content proposal: cards, upgrades, synergies, meta tree
- Status: done
- Milestone: M3
- Depends on: 001 (approved roster)
- PR: #35
- Owner: agent drafts, owner approves (like the roster, D-056)

## Goal
Write `docs/10_M3_CONTENT.md`: a concrete proposal of the M3 roguelite content for the owner to edit and approve, so the M3 implementation tasks can be written from it without inventing design.

## Context
- `01_GAME_DESIGN.md` 4 (level-ups, 3 cards, card types), 5 (towers: role, attack pattern, 3-5 upgrade levels, tags; synergies), 7 (meta), 8 (economy)
- D-023 (win unlocks the Guardian as a tower), D-031 (2 starters), D-048 (loss keeps 30-50% hearts), D-050 (3 locked waifus offered, data order), D-051 (card rules: no free towers, upgrades bought with gold, no reroll/banish/skip in M3), D-052 (hearts buy flat permanent upgrades from a data tree; bond only gates outfits), D-053 (saves), D-054 (outfits cosmetic), D-057 (relationship synergies are the hook), D-058, D-128 (M3 balance goal: the maze must pay off)
- The approved roster `docs/07_ROSTER.md` (task 001)
- The M2 sim and data (`game/data/`, `02_TECH_ARCHITECTURE.md` 3a)

## Content required
- **XP and level-ups:** how XP is earned, a placeholder XP curve, when the draft happens, what the 3 cards are drawn from (weights, no reroll/banish/skip in M3).
- **Card pool for M3:** every card with its type (new tower waifu, tower upgrade, Guardian skill upgrade, global perk), effect and placeholder numbers; how "new tower waifu" cards interact with the 2 starters and the unlocked roster (D-051).
- **Tower waifus:** for each roster waifu, her attack kind and role mapped onto the M2 attack kinds (single, splash, slow) or a new kind if her role needs one (support, tank, economy), and her 3-5 upgrade levels bought with gold.
- **Guardian skills:** whether each Guardian brings her own skills or shares the M2 ones (Area blast, Shield, Heal later per D-044); propose one, with the alternative.
- **Synergies:** the rule format in data (relationship tags, distance, bonus) and the initial relationship bonuses for the roster (rivals, best friends, mentor/student per D-057), designed so a maze layout can benefit (D-128).
- **Meta tree:** the hearts earned per run (win and loss, D-048), and the first tree of flat permanent upgrades with costs.
- **Save scope:** what the meta profile holds; the suspend save at card and wave boundaries (D-053).
- **Open questions:** anything the docs do not decide goes in `docs/OPEN_QUESTIONS.md` with options and a recommended default, not decided in the proposal.

## Acceptance criteria
- Everything is marked PROPOSED; numbers are placeholders; no decision is recorded until the owner approves.
- Every card, upgrade, synergy and meta node is concrete enough to become data without further design.
- Respects the content limits (`05_STEAM_AND_COMPLIANCE.md`): no nudity or explicit content; all characters adult.

## Plan

## Questions

## Review log
