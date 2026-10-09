# 042 — Balance: tune M3 so the maze pays off
- Status: blocked
- Milestone: M3
- Depends on: 041
- Blocked on: Q-69
- Labels: needs-human:balance
- PR:

## Goal
Tune placeholder numbers (data only) until the runner meets the M3 targets, the main one being that a maze beats spreading towers (D-128).

## Context
- D-128; D-126 (tuning order: economy first, then tower stats, then wave counts; never the fixed timeline D-093, D-032, D-097, D-047); the task 041 report.
- Q-69 (target numbers).

## Acceptance criteria
- The Q-69 targets met over N seeds per Guardian for the `fresh` and `full` presets; report committed; every changed number listed in the PR and in a PROPOSED decision.
- Data changes only; a needed rule change becomes an open question.
- Headless tests green twice; data validator green; docs in the same PR.

## Plan

## Questions

## Review log
