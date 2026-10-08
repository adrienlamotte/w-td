# 013 — Sim: waves, spawn curve and bosses
- Status: todo
- Milestone: M2
- Depends on: 011, 012
- PR: -

## Goal
Drive spawns from the run data: 60 s waves with breaks, the spawn curve, mini-bosses at 5:00 and 10:00, the final boss at 15:00, and the horde continuing while she is alive.

## Context
- D-032 (break: no new spawns, the clock keeps running), D-093, D-096, D-097, D-047
- M1 `recycle_radius` stays for the benchmark only

## Acceptance criteria
- Spawns follow the data timeline exactly; breaks spawn nothing; WaveStarted events.
- Enemies spawn outside the camera bounds on a seeded ring; mix from data.
- Mini-bosses at 5:00 and 10:00, final boss at 15:00; spawns continue after the boss (D-096).
- Tests: a simulated 16 minutes produces the expected wave count, boss spawns at the right ticks, determinism.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
