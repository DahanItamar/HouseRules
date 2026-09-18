class_name PlayingCard
extends Control
## Sharp resolution-independent blackjack card with a real face/back state.

signal flip_completed

const SUITS: Array[String] = ["\u2660", "\u2665", "\u2666", "\u2663"]
const RED := Color("a53243")
const BLACK := Color("17161a")
const SHEEN_DURATION := 0.46
var rank: int = 1
var suit: int = 0
var face_down: bool = false
var _visual_face_down: bool = false
var _sheen_remaining: float = 0.0
var _flip_tween: Tween
var _idle_time: float = 0.0
var _idle_phase: float = 0.0
var _active_sheen_duration: float = SHEEN_DURATION


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if MotionPolicy.allows_continuous_motion():
		_idle_time = fmod(_idle_time + delta, 12.0)
	if _sheen_remaining > 0.0:
		_sheen_remaining = maxf(_sheen_remaining - delta, 0.0)
	var idle_pass := fmod(_idle_time + _idle_phase, 4.6)
	if _sheen_remaining > 0.0 or (MotionPolicy.allows_continuous_motion() and idle_pass < 0.56):
		queue_redraw()


func configure(card_rank: int, card_suit: int, hidden: bool) -> void:
	rank = card_rank
	suit = posmod(card_suit, SUITS.size())
	_idle_phase = fmod(float(rank * 7 + suit * 11) * 0.19, 4.6)
	face_down = hidden
	_visual_face_down = hidden
	_trigger_sheen()
	queue_redraw()


func reveal() -> void:
	set_face_down(false, true)


func set_face_down(hidden: bool, animated: bool = false) -> void:
	if face_down == hidden:
		return
	face_down = hidden
	if not animated or not is_inside_tree():
		_visual_face_down = hidden
		_trigger_sheen()
		queue_redraw()
		return
	if _flip_tween and _flip_tween.is_valid():
		_flip_tween.kill()
	pivot_offset = size * 0.5
	var resting_rotation := rotation
	_flip_tween = create_tween()
	_flip_tween.set_parallel(true)
	var close_duration := MotionPolicy.finite_duration(0.11)
	var open_duration := MotionPolicy.finite_duration(0.15)
	_flip_tween.tween_property(self, "scale:x", 0.04, close_duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_flip_tween.tween_property(self, "scale:y", 1.06, close_duration).set_trans(Tween.TRANS_QUAD)
	_flip_tween.tween_property(self, "rotation", resting_rotation + 0.025, close_duration)
	_flip_tween.chain().tween_callback(
		func() -> void:
			_visual_face_down = hidden
			_trigger_sheen()
			queue_redraw()
	)
	_flip_tween.set_parallel(true)
	_flip_tween.tween_property(self, "scale:x", 1.0, open_duration).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_flip_tween.tween_property(self, "scale:y", 1.0, open_duration).set_trans(Tween.TRANS_QUAD)
	_flip_tween.tween_property(self, "rotation", resting_rotation, open_duration).set_trans(Tween.TRANS_QUAD)
	_flip_tween.chain().tween_callback(func() -> void: flip_completed.emit())


func _trigger_sheen() -> void:
	_active_sheen_duration = MotionPolicy.finite_duration(SHEEN_DURATION)
	_sheen_remaining = _active_sheen_duration
	set_process(true)


func _apply_motion_preference(reduced: bool) -> void:
	if reduced:
		_idle_time = 1.0
	queue_redraw()


func _draw() -> void:
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("5a111c") if _visual_face_down else Color("f1e8d8")
	card_style.border_color = Color("c8a34b") if _visual_face_down else Color("b8ad9c")
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(7)
	draw_style_box(card_style, Rect2(Vector2.ZERO, size))
	if _sheen_remaining > 0.0:
		var normalized := _sheen_remaining / _active_sheen_duration
		var flash_alpha := sin(normalized * PI) * 0.68
		draw_rect(
			Rect2(Vector2.ONE, size - Vector2(2, 2)),
			Color(1.0, 0.89, 0.56, flash_alpha),
			false,
			2.0
		)
	elif not _visual_face_down and MotionPolicy.allows_continuous_motion():
		var idle_pass := fmod(_idle_time + _idle_phase, 4.6)
		if idle_pass < 0.56:
			var idle_alpha := sin(idle_pass / 0.56 * PI) * 0.28
			var edge_x := lerpf(8.0, size.x - 8.0, idle_pass / 0.56)
			draw_line(
				Vector2(edge_x, 4.0),
				Vector2(minf(edge_x + 18.0, size.x - 4.0), 4.0),
				Color(0.95, 0.78, 0.36, idle_alpha),
				2.0,
				true
			)
	if _visual_face_down:
		for inset: int in [8, 14, 20]:
			draw_rect(
				Rect2(Vector2(inset, inset), size - Vector2(inset * 2, inset * 2)),
				Color("c8a34b"),
				false,
				1.0
			)
		return
	var rank_text := tr("CARD_" + str(rank)) if rank == 1 or rank > 10 else str(rank)
	var ink := RED if suit == 1 or suit == 2 else BLACK
	draw_string(ThemeDB.fallback_font, Vector2(8, 25), rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	draw_string(ThemeDB.fallback_font, Vector2(8, 48), SUITS[suit], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, ink)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(0, 72),
		SUITS[suit],
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		34,
		ink
	)
