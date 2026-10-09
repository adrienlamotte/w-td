# 030 — Sim: tower levels, UPGRADE_TOWER and derived tower stats
- Status: todo
- Milestone: M3
- Depends on: 029
- PR:

## Goal
Placed towers have a level (1-4) bought per tower with gold, and every tower's effective stats come from packed derived arrays that are recomputed only when the layout or a modifier changes. This is the base that perks, meta nodes, synergies and auras plug into.

## Context
- `docs/10_M3_CONTENT.md` 3.2 (levels, `UPGRADE_TOWER{tower_uid}`, upgrade gold adds to `paid`, rebuild keeps the level, level values absolute), 3.3 (derived stats, dirty flag, recompute once in the next PATH phase), 2.5 (modifier rule: multipliers of one stat add up; cooldown clamp at 50% of the level value and at least 1 tick).
- D-134 (levels 2-3 gold, level 4 needs the signature card), D-137 (per placed tower), D-113 (sell refund, rebuild fraction), D-105 (no building while paused), D-121 (UI verdicts come from the sim query the command uses), D-124 (maze tick budget).
- `docs/02_TECH_ARCHITECTURE.md` 3a: Towers, Tower attacks, tower building. Data shape from task 029 (`levels`, `needs_card`).

## Acceptance criteria
- `UPGRADE_TOWER{tower_uid}`: only while RUNNING and not paused (and not drafting once 033 lands); refused on a husk, at max level, without gold, or for level 4 without its unlock; price = the next level's `cost`; `paid` grows; `TOWER_UPGRADED` (a = uid, value = level). A read-only `check_upgrade` (reason + price) that the command itself uses, for the UI.
- Per-tower `level` (hashed) and derived arrays (damage, cooldown ticks, range, max HP and the per-kind fields) read by targeting and attacks instead of catalog lookups. A modifier store (`stat`, `op`, `target`, per the 2.5 vocabulary) feeds the recompute; nothing fills it in this task except tests.
- Recompute on place, sell, rebuild, upgrade, husk and modifier change, once in the next PATH phase; max HP rise adds the difference, a fall clamps HP; never per tick.
- Tests: upgrade rules and refusals, sell and rebuild with upgrade gold, derived stats per level, modifier sum and clamps, determinism. `scripts\bench.ps1`: `pc_maze`, `pc_maze_combat`, `pc_combat_stress` within noise of `reports/perf_m2.md` (D-124); numbers in the PR.
- Headless tests green twice; data validator green; docs (`02_TECH_ARCHITECTURE.md` 3a) and a PROPOSED decision in the same PR.

## Plan

## Questions

## Review log
