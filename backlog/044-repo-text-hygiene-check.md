# 044 — Tools: fail the test run on control characters in tracked text files
- Status: review
- Milestone: M3
- Depends on: -
- PR: #37

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
No decision ID (tooling only, no design). One new file, about 40 lines; nothing in `game/`.

1. `tools` `tools/tests/test_text_hygiene.py` (new, unittest like `test_validate_data.py`):
   - `git ls-files -z` from the repo root (`subprocess.run`, `cwd=ROOT`); keep the extensions of the criteria plus `txt`, `tres`, `uid` (cheap, same failure mode); skip paths under `game/addons/gut/`.
   - Read bytes; collect every offset of a byte in `0x00-0x08`, `0x0B`, `0x0C`, `0x0E-0x1F`, and every `CR LF`.
   - Markdown only: also flag a tab that is not at the start of a line (regex `[^\t\n]\t`). `\t` written by an agent becomes a real tab (`scripts\test.ps1` -> `scripts<TAB>est.ps1`); it is the same corruption but invisible to the byte rule, and the tree has no legitimate mid-line tab in `.md` (code blocks indent with leading tabs only). Not applied to `.gd` (tabs are the indent and can follow code before a comment).
   - One test method; on failure the message lists `path:line:col` and the byte (`repr`), at most 50 entries plus a count, so a whole-file CRLF does not flood the output. Line/column rather than raw offset: easier to fix by hand (meets "file and offset").
   - Self-check of the scanner: a second small test feeds the scan function a bytes sample with `\x08`, `\x0b`, `CR LF` and a mid-line tab in an `.md` name, and expects 4 hits, and a clean sample with leading tabs and 0 hits. The scanner is a plain function `scan(name, data) -> list[str]` so both tests share it.
2. Current tree: the lead dev already fixed the remaining hits on `m3/dev` (commit `dda3e92`: `backlog/015`, `024`, `025`, `docs/plans/M3.md`, CRLF in `backlog/010` and `tools/requirements.txt`), so the suite is green when the test lands. If a new hit appears before then, fix the file in the same PR, with the backslash written as text.
3. Docs: `02_TECH_ARCHITECTURE.md` 6 (Testing), one bullet: what the hygiene test checks and why (backslash sequences in agent-written paths). Note for agents in the same bullet: write a Windows path in a shell or Python string with forward slashes or `chr(92)`, never a bare backslash.
4. Perf: about 600 tracked files, a few MB read once: well under 1 s; assert nothing about time, just check it in the PR.

Order: scanner + self-check test, then the repo test, then the doc bullet; `scripts\test.ps1` twice.

## Questions

## Review log
