# 015 — Sim: placing, selling, tower HP, husks and blocking
- Status: todo
- Milestone: M2
- Depends on: 014
- PR: -

## Goal
Building in real time and during breaks: placement on the fine grid inside the build radius, costs that grow per copy, selling, tower HP, enemies attacking towers that block their path, husks.

## Context
- D-040 (fine grid, no cap, sell partial refund, no move), D-042 (radius ~20, cost growth per copy), D-043 (tower HP, husk rebuilt for a fraction, no repair), D-101 to D-105 (maze, full walls allowed, walkable husks, no building while paused)
- M1 SimTowers (D-085) grows into the full tower arrays

## Acceptance criteria
- PlaceTower snaps to the grid, checks the radius, free cell and gold, applies cost growth per copy; SellTower refunds the data fraction.
- Towers occupy grid cells and are solid for pathing (the path itself is task 024); towers have HP.
- A dead tower leaves a walkable husk (D-104) that can be rebuilt for the data fraction of the cost.
- No placement while paused (D-105).
- Tests for each rule, including 300 towers still placeable.
- Headless tests green twice; data validator green; docs updated in the same PR; all numbers are placeholders in data.

## Plan

## Questions

## Review log
