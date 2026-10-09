# 044 — Tools: fail the test run on control characters in tracked text files
- Status: todo
- Milestone: M3
- Depends on: -
- PR: -

## Goal
Agents writing Windows paths have repeatedly turned backslash sequences into control characters (`scripts\bench.ps1` became a backspace, `scripts\validate.ps1` a vertical tab, `Godot\4.7.2` a 0x04) in docs, task files and once in `.claude/settings.local.json`. Add one Python test so `scripts\test.ps1` fails when any tracked text file contains such characters.

## Context
- `tools/tests/` (Python unittest, run by `scripts\test.ps1`)
- Found and fixed by hand on 2026-10-08 and 2026-10-09 (four times)

## Acceptance criteria
- A test in `tools/tests/` lists tracked files (`git ls-files`), checks text files (md, gd, json, ps1, py, cfg, tscn, gdshader, godot, csv) outside `game/addons/gut/`, and fails naming each file and offset that contains a byte below 0x20 other than tab, LF and CR.
- It also fails on CRLF line endings in those files (the repo is LF).
- The suite stays green on the current tree; the test is fast (under 1 s).
- Headless tests green twice; docs updated (02_TECH_ARCHITECTURE.md section 6, testing) in the same PR.

## Plan

## Questions

## Review log
