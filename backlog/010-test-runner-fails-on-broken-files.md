# 010 — Test runner: a broken test file must fail the run
- Status: todo
- Milestone: M1
- Depends on: -
- PR: -

## Goal
`scripts\test.ps1` must report failure when a GUT test file fails to parse or load. Today GUT skips such a file with only a warning and the run still prints "ALL TESTS PASSED" (found by game-dev in 003). The whole development loop trusts that signal.

## Context
- `scripts/test.ps1`, `game/.gutconfig.json`, GUT 9.7.1 (`game/addons/gut`)
- `CLAUDE.md` hard rule 5 (green suite), `04_AGENT_WORKFLOW.md` 4 (merge only if tests pass)

## Acceptance criteria
- A test file with a syntax error makes `scripts\test.ps1` exit non-zero with a clear message naming the file.
- A script error raised during a test also fails the run (if GUT does not already fail it).
- The normal suite stays green; no change to GUT's own files (configure it or check its output/exit data instead).
- Headless tests green twice; docs updated if the command's behaviour description changes.

## Plan

## Questions

## Review log
