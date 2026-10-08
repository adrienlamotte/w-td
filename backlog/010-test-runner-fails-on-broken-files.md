# 010 — Test runner: a broken test file must fail the run
- Status: blocked
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
Findings (GUT 9.7.1, read from `addons/gut`, not edited):
- A test script that fails to load (parse error in it, or in a sim script it uses) is only printed as `!!! <path> could not be loaded` by `test_collector.gd`, and `gut.gd` then `break`s out of the script loop, so every later script is silently skipped too. The exit code only counts failed asserts, so the run exits 0.
- GUT already supports a post-run hook (`post_run_script` in `.gutconfig.json`, a script extending `GutHookScript`). `GutRunner.gd` uses the hook's `set_exit_code()` value as the process exit code when it is set. That is the fix point: no GUT file changes, no output parsing in PowerShell.
- Script errors raised during a test: GUT's default `failure_error_types` is `["engine", "gut", "push_error"]`, so an engine error inside a test should already fail that test. Verify it (step 4); only if it does not, add `"failure_error_types": ["engine", "gut", "push_error"]` explicitly to `.gutconfig.json` and re-check.

Files:
1. `game/tests/gut_post_run.gd` (tools/test infra, new, about 20 lines, `extends GutHookScript`; the name does not start with `test_`, so GUT does not collect it). `run()`: loop over `gut.get_test_collector().scripts`; for each with `is_loaded == false`, print `TEST SCRIPT FAILED TO LOAD: <path>` through `gut.logger.error(...)`; if there is at least one, `set_exit_code(1)`. Leave the exit code unset otherwise (setting it would override GUT's own failure code).
2. `game/.gutconfig.json` (change): add `"post_run_script": "res://tests/gut_post_run.gd"`.
3. `scripts/test.ps1`: no change expected (it already fails on a non-zero GUT exit). Only touch it if the end-to-end check below shows otherwise.
4. Docs: `02_TECH_ARCHITECTURE.md` testing bullet (line "Unit/integration tests with ... GUT"): add one sentence: the run fails if any test script cannot be loaded (post-run hook `tests/gut_post_run.gd`), and engine/push_error errors inside a test fail that test. No DECISIONS entry needed (test infra, no design choice).

Tests:
- `game/tests/tools/test_gut_post_run.gd` (new, GUT): instantiate the hook, give it a stub `gut` object (an inner class with `get_test_collector()` returning an object whose `scripts` array holds stubs with `is_loaded` and `path`; a stub `logger` with `error()`), call `run()`: all loaded -> `get_exit_code() == null`; one not loaded -> `1`. (`GutHookScript.gut` is untyped, so a stub can be assigned.)
- End-to-end check, manual, recorded in the PR (do not commit the broken file): (a) add `game/tests/sim/test_zz_broken.gd` with a syntax error, run `scripts	est.ps1`: it must exit non-zero, print `TESTS FAILED` and name the file; also add a broken file named `test_aa_broken.gd` to confirm the later scripts being skipped still fails the run. (b) add a test that calls a method on `null` (a runtime script error) and confirm the run fails. Remove both files, then run `scripts	est.ps1` twice green and `scriptsalidate.ps1`.

Performance: none (runs once after the suite).

Order: hook + gutconfig, unit test, end-to-end checks (a) and (b), doc sentence, test.ps1 twice, validate.ps1.
Size: about 20 lines of code and 40 of tests; one PR.

## Questions
**Q1 (game-dev, 2026-10-08): the plan's detection does not see a test file with a syntax error.**
Observed with GUT 9.7.1 (WIP hook pushed on `task/010-test-runner-fails-on-broken-files`, suite green with it, 23/23):
- `test_zz_broken.gd` and `test_aa_broken.gd` with a parse error: Godot prints `ERROR: Failed to load script ... "Parse error"`, then GUT logs `[GUT WARNING] Ignoring script res://tests/sim/test_aa_broken.gd because it does not extend GutTest` and removes it from `test_collector.scripts` (`add_script`, line ~131). So it never has `is_loaded == false` and the hook sees nothing. Run: `Scripts 6, Tests 23, All tests passed`, `ALL TESTS PASSED`, exit 0.
- The plan's "later scripts are skipped" finding does not hold either: with `test_aa_broken.gd` all later scripts still ran.
- Runtime error (`null.free()` inside a test): already fails without any config change: `SCRIPT ERROR: Invalid call... [Failed]: Unexpected Errors`, `Failing Tests 1`, `TESTS FAILED (gut=1, python=0)`, exit 1. Criterion 2 is met by GUT's defaults.

Options:
- A ★ Keep the post-run hook, but also fail on GUT's logged warnings: in `run()`, scan `gut.logger.get_warnings()` for entries starting with `Ignoring script ` and report each path as `TEST SCRIPT FAILED TO LOAD`, `set_exit_code(1)`. Small (about 5 more lines), names the file, no GUT edit. Couples to GUT's warning text (GUT is pinned, the unit test would catch a change only via a fake; the manual e2e check covers it). Side effect: a `test_*.gd` file that really does not extend GutTest also fails the run, which is arguably correct.
- B Hook lists `test_*.gd` files under the configured dirs itself and fails for each one missing from `collector.scripts`. Independent of GUT's message text; about 15 more lines (directory walk duplicates GUT's config: dirs, subdirs, prefix/suffix).
- C Grep the GUT output in `scripts/test.ps1` for `Failed to load script` / `Ignoring script` and fail. No hook needed, but parses console text in PowerShell, which the plan wanted to avoid.
- D Run `godot --headless --check-only -s <file>` per test file before the suite. Exact parse check, but one Godot launch per file (slow as the suite grows).

## Review log
