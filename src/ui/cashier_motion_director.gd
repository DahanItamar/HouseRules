extends Node
## Presentation-only choreography for the cashier's existing controls.
##
## The floor owns cashier state and its outer modal transition. This director adds
## a short, ordered content reveal without touching financial or input behavior.

const ENTRY_OFFSET := Vector2(0, 7)
const ENTRY_DURATION := 0.16
const STAGGER := 0.025
var _floor: Node
var _panel: Control
var _controls: Array[Control] = []
var _rest_positions: Dictionary = {}
var _reveal_tween: Tween
var _target_open: bool = false


func bind(floor: Node) -> void:
	if _floor != null and _floor.is_connected("cashier_visibility_changed", _on_visibility_changed):
		_floor.disconnect("cashier_visibility_changed", _on_visibility_changed)
	_floor = floor
	_panel = floor.get("_cashier_panel") as Control
	_collect_controls()
	if not _floor.is_connected("cashier_visibility_changed", _on_visibility_changed):
		_floor.connect("cashier_visibility_changed", _on_visibility_changed)
	if not MotionPolicy.motion_preference_changed.is_connected(_on_motion_preference_changed):
		MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


func tracked_control_count() -> int:
	return _controls.size()


func has_active_motion() -> bool:
	return _reveal_tween != null and _reveal_tween.is_valid() and _reveal_tween.is_running()


func play_open() -> void:
	_kill_reveal()
	_apply_final_state()
	if MotionPolicy.is_reduced() or _panel == null:
		return
	for index: int in range(_controls.size()):
		var control := _controls[index]
		control.position = _rest_positions[control] + ENTRY_OFFSET
		control.modulate.a = 0.0
	_reveal_tween = create_tween().set_parallel(true)
	for index: int in range(_controls.size()):
		var control := _controls[index]
		var delay := index * STAGGER
		_reveal_tween.tween_property(
			control, "position", _rest_positions[control], ENTRY_DURATION
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_reveal_tween.tween_property(control, "modulate:a", 1.0, 0.12).set_delay(delay)


func _collect_controls() -> void:
	_controls.clear()
	_rest_positions.clear()
	if _panel == null:
		return
	for child: Node in _panel.get_children():
		var control := child as Control
		if control == null or control.name in [&"TransactionFlash", &"ChipTransferLayer"]:
			continue
		_controls.append(control)
		_rest_positions[control] = control.position
	_controls.sort_custom(
		func(left: Control, right: Control) -> bool:
			return (
				left.position.y < right.position.y
				or (is_equal_approx(left.position.y, right.position.y) and left.position.x < right.position.x)
			)
	)


func _on_visibility_changed(is_open: bool) -> void:
	_target_open = is_open
	if is_open:
		_play_open_if_still_visible.call_deferred()
	else:
		_kill_reveal()
		_apply_final_state()


func _play_open_if_still_visible() -> void:
	if _target_open and _panel != null and _panel.visible:
		play_open()


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		_kill_reveal()
		_apply_final_state()


func _kill_reveal() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = null


func _apply_final_state() -> void:
	for control: Control in _controls:
		if is_instance_valid(control):
			control.position = _rest_positions[control]
			control.modulate = Color.WHITE


func _exit_tree() -> void:
	_kill_reveal()
	if _floor != null and _floor.is_connected("cashier_visibility_changed", _on_visibility_changed):
		_floor.disconnect("cashier_visibility_changed", _on_visibility_changed)
	if MotionPolicy.motion_preference_changed.is_connected(_on_motion_preference_changed):
		MotionPolicy.motion_preference_changed.disconnect(_on_motion_preference_changed)
