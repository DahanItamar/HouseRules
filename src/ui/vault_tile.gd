class_name VaultTile
extends Control
## Hexbound Vault rune-sealed stone tile with a press-and-flip reveal: sealed
## slate, a cache of silver moon coins (safe) or a burning curse sigil (mine).

signal reveal_effect_requested(face_value: int, local_origin: Vector2)
signal reveal_completed(face_value: int)
signal pointer_focused
signal pointer_activated

enum Face { HIDDEN, SAFE, MINE }
const FACE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/production/vault/witcher/tile_sealed.png"),
	preload("res://assets/production/vault/witcher/tile_safe_coins.png"),
	preload("res://assets/production/vault/witcher/tile_cursed_rune.png"),
]
var face: Face = Face.HIDDEN
var is_flipping: bool = false
var is_selected: bool = false
var _pulse_time: float = 0.0
var _warning_remaining: float = 0.0
var _flash_remaining: float = 0.0
var _press_depth: float = 0.0
var _impact_strength: float = 0.0
var _reveal_tween: Tween
var _idle_time: float = 0.0
var _idle_phase: float = 0.0
var _pending_face: Face = Face.HIDDEN
var _interaction_enabled: bool = false
var _pointer_hovered: bool = false
var _pointer_pressed: bool = false


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
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
	if _impact_strength > 0.0:
		needs_redraw = true
	if (
		face == Face.SAFE
		and MotionPolicy.allows_continuous_motion()
		and fmod(_idle_time + _idle_phase, 3.8) < 0.48
	):
		needs_redraw = true
	if needs_redraw:
		queue_redraw()


func set_selected(selected: bool) -> void:
	is_selected = selected
	if not selected:
		_pulse_time = 0.0
	queue_redraw()


func set_interaction_enabled(enabled: bool) -> void:
	_interaction_enabled = enabled
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_ARROW
	)
	if not enabled:
		_pointer_hovered = false
		_pointer_pressed = false
	queue_redraw()


func _on_mouse_entered() -> void:
	if not _interaction_enabled:
		return
	_pointer_hovered = true
	pointer_focused.emit()
	queue_redraw()


func _on_mouse_exited() -> void:
	_pointer_hovered = false
	_pointer_pressed = false
	queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	if not _interaction_enabled or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	_pointer_pressed = mouse_event.pressed
	queue_redraw()
	accept_event()
	if mouse_event.pressed:
		pointer_activated.emit()


func reveal(next_face: Face) -> void:
	if face == next_face and not is_flipping:
		return
	is_flipping = true
	_pending_face = next_face
	_idle_phase = fmod(float(get_index() * 13) * 0.17, 3.8)
	pivot_offset = size * 0.5
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_warning_remaining = MotionPolicy.finite_duration(0.24) if next_face == Face.MINE else 0.0
	_press_depth = 0.0
	_impact_strength = 0.0
	_reveal_tween = create_tween()
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
	# A short key-travel press makes the deposit box feel operated rather than swapped.
	_reveal_tween.tween_method(
		_set_press_depth, 0.0, 1.0, MotionPolicy.finite_duration(0.04)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_reveal_tween.tween_method(
		_set_press_depth, 1.0, 0.30, MotionPolicy.finite_duration(0.03)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_property(self, "scale:x", 0.06, MotionPolicy.finite_duration(0.08)).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_reveal_tween.tween_callback(
		func() -> void:
			face = next_face
			_impact_strength = 1.0
			_flash_remaining = MotionPolicy.finite_duration(0.30 if next_face == Face.MINE else 0.18)
			reveal_effect_requested.emit(next_face, size * 0.5)
			queue_redraw()
	)
	_reveal_tween.tween_property(self, "scale:x", 1.0, MotionPolicy.finite_duration(0.10)).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	if next_face == Face.SAFE:
		_reveal_tween.tween_property(
			self, "scale", Vector2(1.12, 1.12), MotionPolicy.finite_duration(0.06)
		).set_trans(Tween.TRANS_QUAD)
		_reveal_tween.tween_property(
			self, "scale", Vector2.ONE, MotionPolicy.finite_duration(0.10)
		).set_trans(Tween.TRANS_BACK)
	else:
		_reveal_tween.tween_property(
			self, "scale", Vector2(1.08, 0.94), MotionPolicy.finite_duration(0.045)
		).set_trans(Tween.TRANS_QUAD)
		_reveal_tween.tween_property(
			self, "scale", Vector2.ONE, MotionPolicy.finite_duration(0.12)
		).set_trans(Tween.TRANS_BACK)
	_reveal_tween.parallel().tween_method(
		_set_impact_strength, 1.0, 0.0, MotionPolicy.finite_duration(0.12)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reveal_tween.tween_callback(
		func() -> void:
			_set_press_depth(0.0)
			_set_impact_strength(0.0)
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
	_press_depth = 0.0
	_impact_strength = 0.0
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
			_press_depth = 0.0
			_impact_strength = 0.0
			_flash_remaining = MotionPolicy.finite_duration(
				0.30 if face == Face.MINE else 0.18
			)
			reveal_effect_requested.emit(face, size * 0.5)
			reveal_completed.emit(face)
	queue_redraw()


func _set_press_depth(value: float) -> void:
	_press_depth = clampf(value, 0.0, 1.0)
	queue_redraw()


func _set_impact_strength(value: float) -> void:
	_impact_strength = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var pointer_depth := 1.0 if _pointer_pressed and not MotionPolicy.is_reduced() else 0.0
	var physical_offset := Vector2(0.0, roundf(_press_depth * 2.0 + pointer_depth))
	if _press_depth > 0.01:
		draw_rect(
			Rect2(Vector2(4.0, size.y - 3.0), Vector2(maxf(size.x - 8.0, 0.0), 3.0)),
			Color(0.06, 0.05, 0.06, 0.30 * _press_depth),
			true
		)
	draw_texture_rect(FACE_TEXTURES[face], Rect2(physical_offset, size), false)
	var visual_center := size * 0.5 + physical_offset
	if _pointer_hovered and face == Face.HIDDEN:
		draw_rect(
			Rect2(Vector2(3, 3) + physical_offset, size - Vector2(6, 6)),
			Color("e8edf5", 0.14),
			true
		)
		draw_rect(
			Rect2(Vector2(2, 2) + physical_offset, size - Vector2(4, 4)),
			Color("c9d2dc", 0.86),
			false,
			2.0
		)
	if _warning_remaining > 0.0:
		var warning_alpha := 0.35 + sin(_warning_remaining * 70.0) * 0.22
		draw_rect(
			Rect2(Vector2(2, 2), size - Vector2(4, 4)),
			Color(0.92, 0.16, 0.18, warning_alpha),
			false,
			3.0
		)
		var warning_progress := 1.0 - clampf(_warning_remaining / 0.24, 0.0, 1.0)
		draw_arc(
			visual_center,
			10.0 + warning_progress * 13.0,
			0.0,
			TAU,
			28,
			Color(1.0, 0.34, 0.28, (1.0 - warning_progress) * 0.82),
			2.0
		)
		# A solid hazard marker survives peripheral vision and color-vision differences.
		var marker_center := visual_center + Vector2(0.0, -1.0)
		draw_colored_polygon(
			PackedVector2Array([
				marker_center + Vector2(0.0, -9.0),
				marker_center + Vector2(9.0, 8.0),
				marker_center + Vector2(-9.0, 8.0),
			]),
			Color(0.20, 0.06, 0.07, 0.78)
		)
		draw_line(
			marker_center + Vector2(0.0, -4.0),
			marker_center + Vector2(0.0, 3.0),
			Color("ffd8c7"),
			2.0
		)
		draw_circle(marker_center + Vector2(0.0, 5.5), 1.2, Color("ffd8c7"))
	if _flash_remaining > 0.0:
		var flash_color := Color("ff394d") if face == Face.MINE else Color("e3eaf4")
		flash_color.a = (_flash_remaining / 0.30) * 0.55
		draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), flash_color, false, 4.0)
	if is_selected:
		var pulse := (sin(_pulse_time * 4.5) + 1.0) * 0.5 if MotionPolicy.allows_continuous_motion() else 0.0
		draw_arc(
			size * 0.5,
			24.0 + pulse * 2.0,
			0,
			TAU,
			32,
			Color("48c5d5", 0.28 + pulse * 0.22),
			2.0
		)
	if face == Face.SAFE:
		var idle_pass := fmod(_idle_time + _idle_phase, 3.8)
		if MotionPolicy.allows_continuous_motion() and idle_pass < 0.48:
			var shine_progress := idle_pass / 0.48
			var glint_alpha := sin(shine_progress * PI) * 0.62
			var shine_x := lerpf(-9.0, 9.0, shine_progress)
			# Three clipped-looking facet strokes read as a turning diamond, not a dot.
			draw_line(
				visual_center + Vector2(shine_x - 3.0, -8.0),
				visual_center + Vector2(shine_x + 2.0, 7.0),
				Color(0.95, 0.96, 0.76, glint_alpha),
				2.0
			)
			draw_line(
				visual_center + Vector2(shine_x, -7.0),
				visual_center + Vector2(shine_x + 4.0, 3.0),
				Color(0.92, 1.0, 0.96, glint_alpha * 0.72),
				1.0
			)
			draw_circle(
				visual_center + Vector2(shine_x - 2.0, -8.0),
				1.8,
				Color(0.98, 1.0, 0.88, glint_alpha)
			)
	if _impact_strength > 0.01:
		var impact_color := Color("ef5350") if face == Face.MINE else Color("e9fff9")
		draw_arc(
			visual_center,
			19.0 + (1.0 - _impact_strength) * 9.0,
			0.0,
			TAU,
			24,
			Color(impact_color, _impact_strength * 0.72),
			2.0
		)
