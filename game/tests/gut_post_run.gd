extends GutHookScript
## GUT post-run hook: fails the run when any test script could not be loaded.
## GUT only prints a warning for such scripts and skips the rest of the run.


func run() -> void:
	var failed: int = 0
	for script: Variant in gut.get_test_collector().scripts:
		if not script.is_loaded:
			gut.logger.error("TEST SCRIPT FAILED TO LOAD: %s" % script.path)
			failed += 1
	# Leave the exit code unset otherwise, so GUT's own failure code stands.
	if failed > 0:
		set_exit_code(1)
