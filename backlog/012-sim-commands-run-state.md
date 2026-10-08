# 012 — Sim: command queue, events and run state
- Status: todo
- Milestone: M2
- Depends on: -
- PR: -

## Goal
Give the sim its only input channel (commands that carry the tick they apply to) and its output channel (events), plus the run state machine.

## Context
- `02_TECH_ARCHITECTURE.md` 3, 3a (sim contract, commands, events, tick order D-083)

## Acceptance criteria
- Commands: StartRun{seed, config}, Pause{bool}, PlaceTower, SellTower, UseSkill (handlers can be stubs filled by later tasks); each command carries its tick.
- Events out for the view: at least EnemyDied, EnemyHit, TowerPlaced, TowerDied, SkillUsed, GuardianHit, WaveStarted, RunEnded (emitted by later tasks).
- Run state: clock, paused, running, won, lost.
- Replay test: the same seed and the same command list give the same state hash.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
