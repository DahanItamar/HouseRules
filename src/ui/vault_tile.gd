class_name VaultTile
extends Control
## Physical deposit-box tile with a press-and-flip reveal.

signal reveal_effect_requested(face_value: int, local_origin: Vector2)
signal reveal_completed(face_value: int)

enum Face { HIDDEN, SAFE, MINE }
var face: Face = Face.HIDDEN
var is_flipping: bool = false
var is_selected: bool = false
var _pulse_time: float = 0.0
var _warning_remaining: float = 0.0
var _flash_remaining: float = 0.0
var _reveal_tween: Tween
var _idle_time: float = 0.0
var _idle_phase: float = 0.0
var _pending_face: Face = Face.HIDDEN


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	var needs_redraw := false
	if MotionPolicy.allows_continuous_motion():
		_idle_time = fmod(_idle_time + delta, 12.0)
	if is_selected and MotionPolicy.allows_continuous_motion():
		_pulse_time += delta
		needs_redraw = true
	if _warning_remaining > 0.0:
		_warning_remaining = maxf(_warning_remaining - delta, 0.0)
		needs_redraw = true
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(_flash_remaining - delta, 0.0)
		needs_redraw = true
	if face == Face.SAFE and MotionPolicy.allows_continuous_motion() and fmod(_idle_time + _idle_phase, 3.8) < 0.48:
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func set_selected(selected: bool) -> void:
	is_selected = selected
	if not selected:
		_pulse_time = 0.0
	queue_redraw()


func reveal(next_face: Face) -> void:
	if face == next_face and not is_flipping:
		return
	is_flipping = true
	_pending_face = next_face
	_idle_phase = fmod(float(get_index() * 13) * 0.17, 3.8)
	pivot_offset = size * 0.5
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_warning_remaining = MotionPolicy.finite_duration(0.16) if next_face == Face.MINE else 0.0
	_reveal_tween = create_tween()
	if next_face == Face.MINE:
		_reveal_tween.tween_interval(MotionPolicy.finite_duration(0.08))
	if MotionPolicy.is_reduced():
		# Preserve anticipation and the exact completion callback with no tile flip/pop.
		_reveal_tween.tween_property(
			self, "modulate:a", 0.60, MotionPolicy.finite_duration(0.09)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_reveal_tween.tween_callback(
			func() -> void:
				face = next_face
				_flash_remaining = MotionPolicy.finite_duration(
					0.30 if next_face == Face.MINE else 0.18
				)
				reveal_effect_requested.emit(next_face, size * 0.5)
				queue_redraw()
		)
		_reveal_tween.tween_property(
			self, "modulate:a", 1.0, MotionPolicy.finite_duration(0.11)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_reveal_tween.tween_callback(
			func() -> void:
				is_flipping = false
				reveal_completed.emit(next_face)
		)
		return
	_reveal_tween.tween_property(self, "scale:x", 0.06, MotionPolicy.finite_duration(0.10)).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_reveal_tween.tween_callback(
		func() -> void:
			face = next_face
			_flash_remaining = MotionPolicy.finite_duration(0.30 if next_face == Face.MINE else 0.18)
			reveal_effect_requested.emit(next_face, size * 0.5)
			queue_redraw()
	)
	_reveal_tween.tween_property(self, "scale:x", 1.0, MotionPolicy.finite_duration(0.12)).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	if next_face == Face.SAFE:
		_reveal_tween.tween_property(self, "scale", Vector2(1.12, 1.12), MotionPolicy.finite_duration(0.07)).set_trans(Tween.TRANS_QUAD)
		_reveal_tween.tween_property(self, "scale", Vector2.ONE, MotionPolicy.finite_duration(0.11)).set_trans(Tween.TRANS_BACK)
	_reveal_tween.tween_callback(
		func() -> void:
			is_flipping = false
			reveal_completed.emit(next_face)
	)


func set_face_immediate(next_face: Face) -> void:
	face = next_face
	scale = Vector2.ONE
	modulate.a = 1.0
	is_flipping = false
	_warning_remaining = 0.0
	_flash_remaining = 0.0
	queue_redraw()


func _apply_motion_preference(reduced: bool) -> void:
	if reduced:
		_pulse_time = 0.0
		_idle_time = 1.0
		if _reveal_tween != null and _reveal_tween.is_valid() and _reveal_tween.is_running():
			_reveal_tween.kill()
			face = _pending_face
			scale = Vector2.ONE
			modulate.a = 1.0
			is_flipping = false
			_flash_remaining = MotionPolicy.finite_duration(
				0.30 if face == Face.MINE else 0.18
			)
			reveal_effect_requested.emit(face, size * 0.5)
			reveal_completed.emit(face)
	queue_redraw()


func _draw() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("252126")
	style.border_color = Color("48c5d5") if is_selected else Color("c8a34b")
	style.set_border_width_all(3 if is_selected else 2)
	style.set_corner_radius_all(4)
	draw_style_box(style, Rect2(Vector2.ZERO, size))
	if _warning_remaining > 0.0:
		var warning_alpha := 0.35 + sin(_warning_remaining * 70.0) * 0.22
		draw_rect(
			Rect2(Vector2(2, 2), size - Vector2(4, 4)),
			Color(0.92, 0.16, 0.18, warning_alpha),
			false,
			3.0
		)
	if _flash_remaining > 0.0:
		var flash_color := Color("ff394d") if face == Face.MINE else Color("68f0a4")
		flash_color.a = (_flash_remaining / 0.30) * 0.55
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), flash_color, false, 4.0)
	if is_selected:
		var pulse := (sin(_pulse_time * 4.5) + 1.0) * 0.5 if MotionPolicy.allows_continuous_motion() else 0.0
		draw_arc(size * 0.5, 20.0 + pulse * 2.0, 0, TAU, 32, Color("48c5d5", 0.28 + pulse * 0.22), 2.0)
	if face == Face.HIDDEN:
		draw_circle(size * 0.5, 5.0, Color("6e5225"), true, -1.0, true)
		draw_line(size * 0.5 + Vector2(-8, 0), size * 0.5 + Vector2(8, 0), Color("b8ad9c"), 2.0)
	elif face == Face.SAFE:
		draw_circle(size * 0.5, 15.0, Color("073b31"), true, -1.0, true)
		draw_circle(size * 0.5, 11.0, Color("3fc276"), false, 3.0, true)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(0, size.y * 0.5 + 6),
			"$",
			HORIZONTAL_ALIGNMENT_CENTER,
			size.x,
			18,
			Color("f1e8d8")
		)
		var idle_pass := fmod(_idle_time + _idle_phase, 3.8)
		if MotionPolicy.allows_continuous_motion() and idle_pass < 0.48:
			var glint_alpha := sin(idle_pass / 0.48 * PI) * 0.55
			draw_circle(
				size * 0.5 + Vector2(-5.0 + idle_pass * 20.0, -7.0),
				2.2,
				Color(0.95, 0.92, 0.62, glint_alpha)
			)
	else:
		var center := size * 0.5
		draw_circle(center, 10.0, Color("d55353"), true, -1.0, true)
		for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			draw_line(center + direction * 10.0, center + direction * 18.0, Color("d55353"), 3.0, true)
