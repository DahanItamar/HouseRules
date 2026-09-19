class_name BlackjackDealerPresenter
extends Node2D
## Presentation-only dealer silhouette and gesture layer for the Blackjack table.
##
## The node never reads or changes Blackjack state. CabinetPanel tells it when a
## deal or result beat occurred, while MotionPolicy owns how that beat is shown.

const DEALER_TEXTURE := preload("res://assets/production/blackjack/dealer_presenter.png")
const DISPLAY_SIZE := Vector2(200, 216)
const DISPLAY_SCALE := Vector2(200.0 / 1226.0, 216.0 / 1283.0)
const REST_CUE_ALPHA: float = 0.34

var _sprite: Sprite2D
var _cue: ColorRect
var _gesture_tween: Tween
var _idle_time: float = 0.0
var _gesture_active: bool = false
var last_gesture: StringName = &"idle"


func _ready() -> void:
	_cue = ColorRect.new()
	_cue.name = "DealerGestureCue"
	_cue.position = Vector2(50, 217)
	_cue.size = Vector2(100, 3)
	_cue.color = Color("8a682f")
	_cue.modulate.a = REST_CUE_ALPHA
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cue)

	_sprite = Sprite2D.new()
	_sprite.name = "DealerPortrait"
	_sprite.texture = DEALER_TEXTURE
	_sprite.centered = false
	_sprite.scale = DISPLAY_SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)

	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if _gesture_active or not MotionPolicy.allows_continuous_motion():
		return
	_idle_time += delta
	# One pixel of breathing keeps the host present without disturbing the table.
	_sprite.position.y = roundf(sin(_idle_time * TAU / 3.6))


func play_deal(card_count: int = 1) -> void:
	last_gesture = &"deal"
	_begin_gesture(Color("d9b44a"))
	if MotionPolicy.is_reduced():
		_play_reduced_cue()
		return
	_gesture_active = true
	_gesture_tween = create_tween()
	for _index: int in range(clampi(card_count, 1, 4)):
		_gesture_tween.tween_property(_sprite, "position", Vector2(0, 3), 0.08).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
		_gesture_tween.parallel().tween_property(_sprite, "rotation", 0.018, 0.08)
		_gesture_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.11).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN)
		_gesture_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.11)
	_gesture_tween.tween_property(_cue, "modulate:a", REST_CUE_ALPHA, 0.14)
	_gesture_tween.finished.connect(_finish_gesture)


func play_reveal() -> void:
	last_gesture = &"reveal"
	_begin_gesture(Color("48c5d5"))
	if MotionPolicy.is_reduced():
		_play_reduced_cue()
		return
	_gesture_active = true
	_gesture_tween = create_tween()
	_gesture_tween.tween_property(_sprite, "position", Vector2(5, -2), 0.11).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_gesture_tween.parallel().tween_property(_sprite, "rotation", -0.012, 0.11)
	_gesture_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.18).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN_OUT)
	_gesture_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.18)
	_gesture_tween.parallel().tween_property(_cue, "modulate:a", REST_CUE_ALPHA, 0.18)
	_gesture_tween.finished.connect(_finish_gesture)


func play_result(color: Color, positive: bool) -> void:
	last_gesture = &"result_win" if positive else &"result_loss"
	_begin_gesture(color)
	if MotionPolicy.is_reduced():
		_play_reduced_cue()
		return
	_gesture_active = true
	var emphasis := Vector2(1.035, 1.035) if positive else Vector2(0.985, 0.985)
	var nod := -0.014 if positive else 0.014
	_gesture_tween = create_tween()
	_gesture_tween.tween_property(_sprite, "scale", DISPLAY_SCALE * emphasis, 0.11).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_gesture_tween.parallel().tween_property(_sprite, "rotation", nod, 0.11)
	_gesture_tween.tween_property(_sprite, "scale", DISPLAY_SCALE, 0.18).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_gesture_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.18)
	_gesture_tween.parallel().tween_property(_cue, "modulate:a", REST_CUE_ALPHA, 0.18)
	_gesture_tween.finished.connect(_finish_gesture)


func reset_feedback() -> void:
	_stop_gesture()
	last_gesture = &"idle"
	_set_rest_pose()
	if _cue != null:
		_cue.color = Color("8a682f")
		_cue.modulate.a = REST_CUE_ALPHA


func has_active_gesture() -> bool:
	return _gesture_tween != null and _gesture_tween.is_running()


func visual_bounds() -> Rect2:
	return Rect2(position + _sprite.position, DISPLAY_SIZE)


func _begin_gesture(color: Color) -> void:
	_stop_gesture()
	_set_rest_pose()
	_cue.color = color
	_cue.modulate.a = 1.0


func _play_reduced_cue() -> void:
	# A fixed color cue acknowledges the event while the dealer pose stays still.
	_gesture_active = false
	_gesture_tween = create_tween()
	_gesture_tween.tween_interval(MotionPolicy.finite_duration(0.16))
	_gesture_tween.tween_property(
		_cue, "modulate:a", REST_CUE_ALPHA, MotionPolicy.finite_duration(0.12)
	)
	_gesture_tween.finished.connect(_finish_gesture)


func _finish_gesture() -> void:
	_gesture_active = false
	_gesture_tween = null
	_set_rest_pose()


func _stop_gesture() -> void:
	if _gesture_tween != null and _gesture_tween.is_valid():
		_gesture_tween.kill()
	_gesture_tween = null
	_gesture_active = false


func _set_rest_pose() -> void:
	if _sprite == null:
		return
	_sprite.position = Vector2.ZERO
	_sprite.rotation = 0.0
	_sprite.scale = DISPLAY_SCALE


func _apply_motion_preference(reduced: bool) -> void:
	set_process(not reduced)
	if reduced:
		_stop_gesture()
		_set_rest_pose()
		if _cue != null:
			_cue.modulate.a = REST_CUE_ALPHA
