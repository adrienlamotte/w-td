# 024 — Sim: maze pathfinding and walled-in attacks
- Status: todo
- Milestone: M2
- Depends on: 015
- PR: -

## Goal
Enemies path around towers to the Guardian (maze-style, D-101), cheaply enough for thousands of enemies. When the player walls the Guardian in (allowed, D-102), enemies fall back to the straight path and attack the tower that blocks it until a gap opens (D-103).

## Context
- D-101 to D-104; D-043 (the straight-path attack rule, now the walled-in fallback); D-079 (soft separation still applies)
- `02_TECH_ARCHITECTURE.md` 3a (tick order D-083, spatial grid), 4 (budgets); `reports/perf_m1.md` (separation already 60-79% of a tick)
- Technical approach is the lead dev's call (a flow field from the Guardian over the build grid, recomputed only when towers or husks change, is the expected direction)
- From 011 review: the path grid should be the build grid (`RunData.grid_step`, `build_radius`; 0.5 and 20 give about 80x80 cells inside the radius). Enemy radii go up to 0.4 (brute) and bosses up to 1.0, so the plan must state how corridor width relates to enemy radius (for example, can a boss pass through a one-cell gap?). Outside the build radius there are no towers, so enemies head straight for the build area.

## Acceptance criteria
- Enemies never walk through tower cells; inside the build area they follow the shortest path around towers; outside it they head for the build area.
- The path data is recomputed only when the tower layout changes (place, sell, death, rebuild), not every tick.
- Walled in: enemies with no path take the straight path and attack the first blocking tower (D-103); when a gap opens (tower dies and becomes a walkable husk, D-104, or is sold), they path through it.
- Determinism kept; tests for routing around a wall, a full wall, a gap opening, and a husk being walkable.
- Per-tick cost measured with 3000 enemies and a realistic maze; reported in the PR.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
