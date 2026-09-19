extends Node
## Shared presentation-only motion preference.
##
## Gameplay and domain code must never depend on this service. Presentation nodes use
## it to remove ambient motion and shorten finite feedback while preserving final state.

signal motion_preference_changed(reduced: bool)

const SETTING_PATH := "accessibility/reduced_motion"
const REDUCED_DURATION_SCALE := 0.6
const DEFAULT_PREFERENCE_PATH := "user://accessibility.cfg"

var _test_override: Variant = null
var preference_path: String = DEFAULT_PREFERENCE_PATH
var persistence_enabled: bool = true


func _ready() -> void:
	load_preference()


func is_reduced() -> bool:
	if _test_override is bool:
		return _test_override as bool
	return bool(ProjectSettings.get_setting(SETTING_PATH, false))


func allows_continuous_motion() -> bool:
	return not is_reduced()


func allows_camera_emphasis() -> bool:
	return not is_reduced()


func finite_duration(full_motion_seconds: float) -> float:
	if is_reduced():
		return full_motion_seconds * REDUCED_DURATION_SCALE
	return full_motion_seconds


func set_reduced_motion(reduced: bool) -> void:
	## Update the live player preference. This remains presentation-only and does not
	## enter the deterministic save or gameplay state.
	_test_override = null
	ProjectSettings.set_setting(SETTING_PATH, reduced)
	if persistence_enabled:
		var config := ConfigFile.new()
		config.set_value("accessibility", "reduced_motion", reduced)
		config.save(preference_path)
	motion_preference_changed.emit(reduced)


func load_preference() -> Error:
	if not persistence_enabled:
		return OK
	var config := ConfigFile.new()
	var error := config.load(preference_path)
	if error == ERR_FILE_NOT_FOUND:
		return OK
	if error != OK:
		return error
	var reduced := bool(config.get_value("accessibility", "reduced_motion", false))
	ProjectSettings.set_setting(SETTING_PATH, reduced)
	motion_preference_changed.emit(reduced)
	return OK


func set_reduced_motion_for_tests(reduced: bool) -> void:
	_test_override = reduced
	motion_preference_changed.emit(reduced)


func clear_test_override() -> void:
	_test_override = null
	motion_preference_changed.emit(is_reduced())
