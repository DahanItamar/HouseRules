class_name WinCelebration
extends Control
## Higgsfield-authored chip/coin atlas animated by Godot for deterministic win bursts.

const SHEET := preload("res://assets/production/effects/casino_win_burst_integer.png")
const CELL_SIZE := Vector2i(256, 344)
var _rng := RandomNumberGenerator.new()
var _active_tweens: Array[Tween] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 20260918
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)


func burst(origin: Vector2, count: int = 12) -> void:
	var token_count := mini(count, 3) if MotionPolicy.is_reduced() else count
	for index: int in range(token_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = SHEET
		var cell := index % 12
		atlas.region = Rect2(Vector2i(cell % 4, cell / 4) * CELL_SIZE, Vector2(CELL_SIZE))
		var token := TextureRect.new()
		token.texture = atlas
		token.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		token.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		token.size = Vector2(54, 54)
		token.pivot_offset = token.size * 0.5
		token.position = origin - token.pivot_offset
		token.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(token)
		if MotionPolicy.is_reduced():
			# A compact acknowledgement retains win feedback without viewport-crossing motion.
			token.position += Vector2((index - 1) * 22.0, 0.0)
			var reduced_feedback := create_tween().set_parallel(true)
			_active_tweens.append(reduced_feedback)
			reduced_feedback.tween_property(
				token, "scale", Vector2(0.88, 0.88), MotionPolicy.finite_duration(0.24)
			)
			reduced_feedback.tween_property(
				token, "modulate:a", 0.0, MotionPolicy.finite_duration(0.24)
			)
			reduced_feedback.chain().tween_callback(token.queue_free)
			continue
		var direction := -1.0 if index % 2 == 0 else 1.0
		var vertical_exit := (
			_rng.randf_range(260.0, 420.0) if index % 3 == 0 else -_rng.randf_range(180.0, 450.0)
		)
		var destination := (
			origin + Vector2(direction * _rng.randf_range(170.0, 520.0), vertical_exit)
		)
		var duration := _rng.randf_range(0.72, 1.05)
		var motion := create_tween().set_parallel(true)
		_active_tweens.append(motion)
		(
			motion
			. tween_property(token, "position", destination, duration)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
		motion.tween_property(token, "rotation", direction * _rng.randf_range(2.8, 7.2), duration)
		motion.tween_property(token, "scale", Vector2(0.55, 0.55), duration)
		motion.tween_property(token, "modulate:a", 0.0, duration * 0.42).set_delay(duration * 0.58)
		motion.chain().tween_callback(token.queue_free)


func _apply_motion_preference(reduced: bool) -> void:
	if not reduced:
		return
	for tween: Tween in _active_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	for token: Node in get_children():
		token.queue_free()
