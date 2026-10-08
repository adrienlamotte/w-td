# 010 — Test runner: a broken test file must fail the run
- Status: review
- Milestone: M1
- Depends on: -
- PR: #7

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
Re-planned 2026-10-08 after Q1 (decision: option A, plus a contract test that pins GUT's warning text; see Q1 answer).

Facts (GUT 9.7.1, verified by game-dev):
- A test file that fails to parse (or whose dependency fails to parse) is dropped by `test_collector.gd` `add_script()`: it logs the warning `Ignoring script <path> because it does not extend GutTest` and removes the script from `collector.scripts`. Later files still run. Exit code 0.
- Runtime script errors inside a test already fail the run with GUT defaults (`Unexpected Errors`, exit 1). Criterion 2 is met; no config change.
- GUT's post-run hook (`post_run_script`, `GutHookScript.set_exit_code()`) sets the process exit code. Fix point stays there.

Files (all test infra, `game/tests/`, no GUT file changed):
1. `game/tests/gut_post_run.gd` (change the WIP hook): replace the `is_loaded` loop with a scan of `gut.logger.get_warnings()` (an array of the logged strings): for each entry that starts with `Ignoring script `, log `TEST SCRIPT FAILED TO LOAD: <entry>` via `gut.logger.error(...)` and count it. Keep the prefix as a `const IGNORED_PREFIX: String = "Ignoring script "`. If count > 0, `set_exit_code(1)`; otherwise leave it unset (unchanged WIP behaviour). Drop the `is_loaded` check (it never fires) and fix the header comment (later scripts are not skipped). About 15 lines.
2. `game/.gutconfig.json`: keep the WIP `post_run_script` line.
3. `game/tests/fixtures/not_a_gut_test.gd` (new, about 3 lines): `extends RefCounted`, nothing else. Outside the `test_` prefix so GUT never collects it. Used only by the contract test below.
4. `scripts/test.ps1`: no change (already fails on a non-zero GUT exit).
5. `docs/02_TECH_ARCHITECTURE.md` testing bullet: one sentence: the run fails if GUT ignores any test script (parse error or not extending GutTest; post-run hook `tests/gut_post_run.gd`), and runtime errors inside a test fail that test (GUT default).

Tests (`game/tests/tools/test_gut_post_run.gd`, adapt the WIP):
- Stubs: `StubLogger` gets `warnings: Array[String]` and `get_warnings()`; `StubGut` no longer needs a collector. Cases: no warnings -> exit code null, no errors; an unrelated warning only -> null; one `Ignoring script res://tests/sim/test_x.gd because ...` warning -> exit code 1 and the error names the path.
- Contract test (guards the coupling to GUT's text): create `GutUtils.TestCollector.new()`, give it a fresh logger (`set_logger(GutUtils.Logger.new())` or whatever `GutUtils.get_logger()` builds; check `utils.gd`), call `add_script("res://tests/fixtures/not_a_gut_test.gd")`, assert that one warning starts with `gut_post_run.gd`'s `IGNORED_PREFIX` and contains the path. If a GUT upgrade rewords the message, this test fails. Make sure the fresh logger does not print into or pollute the main run's logger (otherwise the hook would fail the real run); if it cannot be isolated, assert that the hook ignores it, or flag it in the PR.
- End-to-end check, manual, recorded in the PR (broken files not committed): (a) `game/tests/sim/test_aa_broken.gd` and `test_zz_broken.gd` with a syntax error: `scripts	est.ps1` exits non-zero, prints `TESTS FAILED` and names both files. (b) a test doing `null.free()`: run fails (already true). Remove them; `scripts	est.ps1` twice green; `scriptsalidate.ps1`.

Performance: none (runs once after the suite).
Order: hook change, fixture, unit + contract tests, e2e checks, doc sentence, test.ps1 twice, validate.ps1.
Size: about 20 lines of code, about 60 of tests; one PR. Continue on the existing branch `task/010-test-runner-fails-on-broken-files`.

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

**Answer (lead-dev, 2026-10-08): A**, with a contract test. Reasons: GUT is pinned and vendored; A is about 5 lines and reports the exact path GUT dropped. B duplicates GUT's file discovery (dirs, subdirs, prefix, suffix) and would falsely fail filtered runs (`-gselect`, `-gtest`, `-gunit_test_name`), where files are legitimately not collected. A's weakness, coupling to the warning text, is covered by a unit test that feeds GUT's real collector a fixture not extending GutTest (same code path as a parse error) and asserts the prefix the hook matches; a GUT upgrade that rewords the message breaks that test. C parses console text in PowerShell; D is slow. Technical choice, no DECISIONS entry.

## Review log
