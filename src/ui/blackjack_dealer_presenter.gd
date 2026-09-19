class_name BlackjackDealerPresenter
extends Node2D
## Presentation-only dealer silhouette and gesture layer for the Blackjack table.
##
## The node never reads or changes Blackjack state. CabinetPanel tells it when a
## deal or result beat occurred, while MotionPolicy owns how that beat is shown.

const DEALER_TEXTURE := preload(
	"res://assets/production/characters/hosts/blackjack_dealer_woman.png"
)
const DEALER_CARD_PROP_SCRIPT := preload("res://src/ui/blackjack_dealer_card_prop.gd")
const DISPLAY_SIZE := Vector2(200, 216)
const DISPLAY_SCALE := Vector2(200.0 / 1024.0, 216.0 / 1536.0)
const REST_CUE_ALPHA: float = 0.34
const CARD_SIZE := Vector2(16, 23)
const DEAL_HAND_REST := Vector2(146, 174)
const DEAL_HAND_EXTENDED := Vector2(160, 190)
const REVEAL_HAND_REST := Vector2(45, 163)

var _sprite: Sprite2D
var _cue: ColorRect
var _hand_anchor: Node2D
var _card_prop: Control
var _motion_trace: Line2D
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

	# The production portrait stays intact. This small foreground assembly gives
	# the held card its own timing, so the action reads as a hand-off rather than
	# translating the dealer like a rigid puppet.
	_motion_trace = Line2D.new()
	_motion_trace.name = "DealerHandTrace"
	_motion_trace.points = PackedVector2Array([
		DEAL_HAND_REST + Vector2(4, 8), Vector2(164, 194), Vector2(187, 207)
	])
	_motion_trace.width = 1.25
	_motion_trace.default_color = Color(0.85, 0.71, 0.29, 0.0)
	_motion_trace.antialiased = true
	add_child(_motion_trace)

	_hand_anchor = Node2D.new()
	_hand_anchor.name = "DealerCardHand"
	_hand_anchor.position = DEAL_HAND_REST
	_hand_anchor.z_index = 2
	add_child(_hand_anchor)

	_card_prop = DEALER_CARD_PROP_SCRIPT.new()
	_card_prop.name = "DealerCardProp"
	_card_prop.size = CARD_SIZE
	_card_prop.visible = false
	_hand_anchor.add_child(_card_prop)

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
		_gesture_tween.tween_callback(_prime_deal_card)
		_gesture_tween.tween_property(_hand_anchor, "position", DEAL_HAND_EXTENDED, 0.12).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
		_gesture_tween.parallel().tween_property(_sprite, "position", Vector2(0, 1), 0.12)
		_gesture_tween.parallel().tween_property(_sprite, "rotation", 0.004, 0.12)
		_gesture_tween.parallel().tween_property(
			_motion_trace, "default_color:a", 0.42, 0.12
		)
		# The hand recoils first; the released card continues along the table lane.
		_gesture_tween.tween_property(_hand_anchor, "position", DEAL_HAND_REST, 0.13).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN_OUT)
		_gesture_tween.parallel().tween_property(_card_prop, "position", Vector2(18, 11), 0.13)
		_gesture_tween.parallel().tween_property(_card_prop, "rotation", 0.07, 0.13)
		_gesture_tween.parallel().tween_property(_card_prop, "modulate:a", 0.0, 0.13)
		_gesture_tween.parallel().tween_property(_sprite, "position", Vector2.ZERO, 0.13)
		_gesture_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.13)
		_gesture_tween.parallel().tween_property(
			_motion_trace, "default_color:a", 0.0, 0.10
		)
		_gesture_tween.tween_callback(_hide_card_prop)
		_gesture_tween.tween_interval(0.025)
	_gesture_tween.tween_property(_cue, "modulate:a", REST_CUE_ALPHA, 0.14)
	_gesture_tween.finished.connect(_finish_gesture)


func play_reveal() -> void:
	last_gesture = &"reveal"
	_begin_gesture(Color("48c5d5"))
	if MotionPolicy.is_reduced():
		_play_reduced_cue()
		return
	_gesture_active = true
	_prime_reveal_card()
	_gesture_tween = create_tween()
	_gesture_tween.tween_property(_hand_anchor, "position", REVEAL_HAND_REST + Vector2(7, -3), 0.11).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_gesture_tween.parallel().tween_property(_sprite, "position", Vector2(1, -1), 0.11)
	_gesture_tween.parallel().tween_property(_sprite, "rotation", -0.004, 0.11)
	_gesture_tween.parallel().tween_property(_card_prop, "scale:x", 0.08, 0.11)
	_gesture_tween.tween_callback(func() -> void: _card_prop.set_face_down(false))
	_gesture_tween.tween_property(_card_prop, "scale:x", 1.0, 0.10).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_gesture_tween.tween_property(_hand_anchor, "position", REVEAL_HAND_REST, 0.14).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN_OUT)
	_gesture_tween.parallel().tween_property(_card_prop, "modulate:a", 0.0, 0.14)
	_gesture_tween.parallel().tween_property(_sprite, "position", Vector2.ZERO, 0.14)
	_gesture_tween.parallel().tween_property(_sprite, "rotation", 0.0, 0.14)
	_gesture_tween.parallel().tween_property(_cue, "modulate:a", REST_CUE_ALPHA, 0.14)
	_gesture_tween.tween_callback(_hide_card_prop)
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
	if _hand_anchor != null:
		_hand_anchor.position = DEAL_HAND_REST
	if _card_prop != null:
		_card_prop.position = Vector2.ZERO
		_card_prop.rotation = 0.0
		_card_prop.scale = Vector2.ONE
		_card_prop.modulate = Color.WHITE
		_card_prop.visible = false
	if _motion_trace != null:
		_motion_trace.default_color.a = 0.0


func _prime_deal_card() -> void:
	_hand_anchor.position = DEAL_HAND_REST
	_card_prop.position = Vector2.ZERO
	_card_prop.rotation = -0.045
	_card_prop.scale = Vector2.ONE
	_card_prop.modulate = Color.WHITE
	_card_prop.set_face_down(true)
	_card_prop.visible = true


func _prime_reveal_card() -> void:
	_hand_anchor.position = REVEAL_HAND_REST
	_card_prop.position = Vector2.ZERO
	_card_prop.rotation = -0.09
	_card_prop.scale = Vector2.ONE
	_card_prop.modulate = Color.WHITE
	_card_prop.set_face_down(true)
	_card_prop.visible = true


func _hide_card_prop() -> void:
	_card_prop.visible = false


func _apply_motion_preference(reduced: bool) -> void:
	set_process(not reduced)
	if reduced:
		_stop_gesture()
		_set_rest_pose()
		if _cue != null:
			_cue.modulate.a = REST_CUE_ALPHA
