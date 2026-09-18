extends Node
## Shared presentation-only motion preference.
##
## Gameplay and domain code must never depend on this service. Presentation nodes use
## it to remove ambient motion and shorten finite feedback while preserving final state.

signal motion_preference_changed(reduced: bool)

const SETTING_PATH := "accessibility/reduced_motion"
const REDUCED_DURATION_SCALE := 0.6

var _test_override: Variant = null


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


func set_reduced_motion_for_tests(reduced: bool) -> void:
	_test_override = reduced
	motion_preference_changed.emit(reduced)


func clear_test_override() -> void:
	_test_override = null
	motion_preference_changed.emit(is_reduced())
