extends GutTest

const HookScript: GDScript = preload("res://tests/gut_post_run.gd")
const FIXTURE_PATH: String = "res://tests/fixtures/not_a_gut_test.gd"


class StubLogger:
	var warnings: Array[String] = []
	var errors: Array[String] = []

	func get_warnings() -> Array[String]:
		return warnings

	func error(text: String) -> void:
		errors.append(text)


class StubGut:
	var logger: StubLogger = StubLogger.new()


func _run_hook(warnings: Array[String]) -> Array:
	var stub: StubGut = StubGut.new()
	stub.logger.warnings = warnings
	var hook: GutHookScript = HookScript.new()
	hook.gut = stub
	hook.run()
	return [hook.get_exit_code(), stub.logger.errors]


func test_no_warnings_leaves_exit_code_unset() -> void:
	var result: Array = _run_hook([])
	assert_null(result[0])
	assert_eq(result[1].size(), 0)


func test_unrelated_warning_leaves_exit_code_unset() -> void:
	var result: Array = _run_hook(["Something else happened"])
	assert_null(result[0])
	assert_eq(result[1].size(), 0)


func test_ignored_script_sets_exit_code_and_names_file() -> void:
	var path: String = "res://tests/sim/test_x.gd"
	var result: Array = _run_hook(["Ignoring script %s because it does not extend GutTest" % path])
	assert_eq(result[0], 1)
	assert_eq(result[1].size(), 1)
	assert_string_contains(result[1][0], path)


## Contract: GUT's real collector still logs the warning text the hook matches.
## Uses a private, silent logger so the main run's logger never sees it.
func test_gut_collector_warning_matches_hook_prefix() -> void:
	var lgr: Variant = GutUtils.GutLogger.new()
	lgr.disable_all_printers(true)
	var collector: Variant = GutUtils.TestCollector.new()
	collector.set_logger(lgr)
	collector.add_script(FIXTURE_PATH)
	var matched: Array = lgr.get_warnings().filter(
		func(w: Variant) -> bool:
			return str(w).begins_with(HookScript.IGNORED_PREFIX) and str(w).contains(FIXTURE_PATH)
	)
	assert_eq(matched.size(), 1)
	assert_eq(collector.scripts.size(), 0)
