# 008 — Benchmark scene and perf report command
- Status: todo
- Milestone: M1
- Depends on: 004, 005, 007
- PR: -

## Goal
A fixed, seeded benchmark scenario that outputs FPS and frame-time numbers as JSON, runnable with one command.

## Context
- `02_TECH_ARCHITECTURE.md` 4 (budgets), 6 (perf benchmark scene)
- D-042 stress cases; `04_AGENT_WORKFLOW.md` 5 (`/reports/perf_<date>.json`)

## Acceptance criteria
- Scenarios: PC typical (3000 enemies + 50 towers), PC stress (3000 + 300 towers), Deck typical (1500 + 50), Deck stress (1500 + 150).
- Enemies must keep moving for the whole measurement (for example respawn on the ring any enemy that reaches the Guardian, or a larger ring); otherwise they stop after about 280 ticks and the per-tick cost is understated (found in 002).
- Each runs a fixed number of seconds after warm-up and records average and 1%-low FPS, frame time, and sim step time per tick (ms).
- Per-phase sim timings (ms/tick, from `SimWorld.phase_usec`: separation, movement, grid rebuild, targeting) are reported for every scenario, measured in a release export, plus a "piled at the Guardian" worst case (3000 enemies allowed to pile up, no respawn) next to the moving-crowd cases (task 004 measured separation at ~34-45 ms/tick piled vs ~10 ms spread in headless debug).
- Targeting cost uses a realistic enemy layout around the towers: in the tower scenarios, part of the crowd walks through the tower field (towers spread over the build radius, enemies crossing it on their way to the Guardian), not only enemies outside every tower's range. Task 005 found dense cells among towers cost more than empty rings (headless debug, 300 towers / 3000 enemies: ~4-6 ms none in range vs ~10-12 ms packed among towers); report targeting ms/tick for both the moving-crowd and piled cases.
- Output: `reports/perf_<date>.json` with the machine description (CPU, GPU, OS, Godot version).
- One command `scripts\bench.ps1` (state whether it runs the exported build or the editor binary), and the Commands section of `CLAUDE.md` updated.
- Headless tests green twice; data validator green; docs updated in the same PR.

## Plan

## Questions

## Review log
