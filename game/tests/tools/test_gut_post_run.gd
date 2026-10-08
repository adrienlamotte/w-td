extends GutTest

const HookScript: GDScript = preload("res://tests/gut_post_run.gd")


class StubScript:
	var path: String
	var is_loaded: bool

	func _init(p: String, loaded: bool) -> void:
		path = p
		is_loaded = loaded


class StubCollector:
	var scripts: Array = []


class StubLogger:
	var errors: Array[String] = []

	func error(text: String) -> void:
		errors.append(text)


class StubGut:
	var collector: StubCollector = StubCollector.new()
	var logger: StubLogger = StubLogger.new()

	func get_test_collector() -> StubCollector:
		return collector


func _run_hook(scripts: Array) -> Array:
	var stub: StubGut = StubGut.new()
	stub.collector.scripts = scripts
	var hook: GutHookScript = HookScript.new()
	hook.gut = stub
	hook.run()
	return [hook.get_exit_code(), stub.logger.errors]


func test_all_loaded_leaves_exit_code_unset() -> void:
	var result: Array = _run_hook([StubScript.new("res://a.gd", true), StubScript.new("res://b.gd", true)])
	assert_null(result[0])
	assert_eq(result[1].size(), 0)


func test_unloaded_script_sets_exit_code_and_names_file() -> void:
	var result: Array = _run_hook([StubScript.new("res://a.gd", true), StubScript.new("res://broken.gd", false)])
	assert_eq(result[0], 1)
	assert_eq(result[1].size(), 1)
	assert_string_contains(result[1][0], "res://broken.gd")
