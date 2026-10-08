extends GutHookScript
## GUT post-run hook: fails the run when GUT ignored any test script.
## GUT drops a script that fails to parse (or does not extend GutTest) with only
## a warning and runs the others; this turns that warning into a failed run.

## Start of GUT 9.7.1's warning in test_collector.gd add_script(); pinned by
## tests/tools/test_gut_post_run.gd.
const IGNORED_PREFIX: String = "Ignoring script "


func run() -> void:
	var failed: int = 0
	for entry: Variant in gut.logger.get_warnings():
		if str(entry).begins_with(IGNORED_PREFIX):
			gut.logger.error("TEST SCRIPT FAILED TO LOAD: %s" % entry)
			failed += 1
	# Leave the exit code unset otherwise, so GUT's own failure code stands.
	if failed > 0:
		set_exit_code(1)
