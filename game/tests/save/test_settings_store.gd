extends GutTest
## Settings file (D-157, D-154 rule 9) in a scratch folder.

const DIR := "user://test_settings/"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)


func after_each() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + f)
	DirAccess.remove_absolute(DIR)
	RunFlow.slow_time_placing = false


func _load_text(text: String) -> bool:
	var f := FileAccess.open(DIR + SettingsStore.FILE, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	RunFlow.slow_time_placing = true
	SettingsStore.load_into_run_flow(DIR)
	return RunFlow.slow_time_placing


func test_missing_and_round_trip() -> void:
	RunFlow.slow_time_placing = true
	SettingsStore.load_into_run_flow(DIR)
	assert_false(RunFlow.slow_time_placing, "missing file: off")
	RunFlow.slow_time_placing = true
	assert_eq(SettingsStore.save(DIR), OK)
	RunFlow.slow_time_placing = false
	SettingsStore.load_into_run_flow(DIR)
	assert_true(RunFlow.slow_time_placing)


func test_bad_files_load_the_defaults() -> void:
	for text: String in ['{"slow_', '[true]', '{"schema_version": 2, "slow_time_placing": true}',
			'{"schema_version": 1, "slow_time_placing": "yes"}', '{"slow_time_placing": true}']:
		assert_false(_load_text(text), text)


func test_unknown_key_ignored() -> void:
	assert_true(_load_text('{"schema_version": 1, "slow_time_placing": true, "volume": 3}'))
