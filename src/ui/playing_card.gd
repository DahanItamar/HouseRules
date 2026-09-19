class_name PlayingCard
extends Control
## Reusable premium playing card for every House Rules card game.
##
## Art comes from the generated deck in assets/production/cards/ (ivory stock,
## point-symmetric burgundy/brass back, suit pip art, an ornate ace of spades and
## twelve double-headed court panels). Everything that must be exact is laid out
## in code: corner indices (rank + suit, mirrored bottom-right), the standard pip
## layouts for 2-10, and the court frame. Presentation only: `face_down` is the
## logical state, `_visual_face_down` the side painted while a flip is in flight.

signal flip_completed

const SUITS: Array[String] = ["\u2660", "\u2665", "\u2666", "\u2663"]
const FACE_TEXTURE := preload("res://assets/production/cards/card_face.png")
const BACK_TEXTURE := preload("res://assets/production/cards/card_back.png")
const ACE_OF_SPADES := preload("res://assets/production/cards/ace_spades.png")
## Pip art indexed by suit: spade, heart, diamond, club.
const SUIT_TEXTURES: Array[Texture2D] = [
	preload("res://assets/production/cards/suit_spade.png"),
	preload("res://assets/production/cards/suit_heart.png"),
	preload("res://assets/production/cards/suit_diamond.png"),
	preload("res://assets/production/cards/suit_club.png"),
]
## Court panels indexed [suit][rank - 11] for J, Q, K.
const COURT_TEXTURES: Array = [
	[
		preload("res://assets/production/cards/court_J_spade.png"),
		preload("res://assets/production/cards/court_Q_spade.png"),
		preload("res://assets/production/cards/court_K_spade.png"),
	],
	[
		preload("res://assets/production/cards/court_J_heart.png"),
		preload("res://assets/production/cards/court_Q_heart.png"),
		preload("res://assets/production/cards/court_K_heart.png"),
	],
	[
		preload("res://assets/production/cards/court_J_diamond.png"),
		preload("res://assets/production/cards/court_Q_diamond.png"),
		preload("res://assets/production/cards/court_K_diamond.png"),
	],
	[
		preload("res://assets/production/cards/court_J_club.png"),
		preload("res://assets/production/cards/court_Q_club.png"),
		preload("res://assets/production/cards/court_K_club.png"),
	],
]
## Standard pip layouts for 2-10 as (column, row) card fractions. Pips below the
## centre line are printed upside down, as on a real deck.
const PIP_LAYOUTS := {
	2: [Vector2(0.5, 0.2), Vector2(0.5, 0.8)],
	3: [Vector2(0.5, 0.2), Vector2(0.5, 0.5), Vector2(0.5, 0.8)],
	4: [Vector2(0.335, 0.2), Vector2(0.665, 0.2), Vector2(0.335, 0.8), Vector2(0.665, 0.8)],
	5:
	[
		Vector2(0.335, 0.2),
		Vector2(0.665, 0.2),
		Vector2(0.5, 0.5),
		Vector2(0.335, 0.8),
		Vector2(0.665, 0.8),
	],
	6:
	[
		Vector2(0.335, 0.2),
		Vector2(0.665, 0.2),
		Vector2(0.335, 0.5),
		Vector2(0.665, 0.5),
		Vector2(0.335, 0.8),
		Vector2(0.665, 0.8),
	],
	7:
	[
		Vector2(0.335, 0.2),
		Vector2(0.665, 0.2),
		Vector2(0.5, 0.35),
		Vector2(0.335, 0.5),
		Vector2(0.665, 0.5),
		Vector2(0.335, 0.8),
		Vector2(0.665, 0.8),
	],
	8:
	[
		Vector2(0.335, 0.2),
		Vector2(0.665, 0.2),
		Vector2(0.5, 0.35),
		Vector2(0.335, 0.5),
		Vector2(0.665, 0.5),
		Vector2(0.5, 0.65),
		Vector2(0.335, 0.8),
		Vector2(0.665, 0.8),
	],
	9:
	[
		Vector2(0.335, 0.2),
		Vector2(0.665, 0.2),
		Vector2(0.335, 0.4),
		Vector2(0.665, 0.4),
		Vector2(0.5, 0.5),
		Vector2(0.335, 0.6),
		Vector2(0.665, 0.6),
		Vector2(0.335, 0.8),
		Vector2(0.665, 0.8),
	],
	10:
	[
		Vector2(0.335, 0.2),
		Vector2(0.665, 0.2),
		Vector2(0.5, 0.3),
		Vector2(0.335, 0.4),
		Vector2(0.665, 0.4),
		Vector2(0.335, 0.6),
		Vector2(0.665, 0.6),
		Vector2(0.5, 0.7),
		Vector2(0.335, 0.8),
		Vector2(0.665, 0.8),
	],
}
## Court frame inside the card (fractions); indices sit outside it at the corners.
const COURT_FRAME := Rect2(0.19, 0.085, 0.62, 0.83)
const PIP_HEIGHT: float = 0.13
const RED := Color("a3182b")
const BLACK := Color("15141a")
const FRAME_INK := Color(0.08, 0.08, 0.1, 0.85)
const SHADOW := Color(0.02, 0.03, 0.02, 0.30)
const SHEEN_DURATION := 0.46
const CORNER_RADIUS := 3

var rank: int = 1
var suit: int = 0
var face_down: bool = false
var _visual_face_down: bool = false
var _sheen_remaining: float = 0.0
var _flip_tween: Tween
var _idle_phase: float = 0.0
var _active_sheen_duration: float = SHEEN_DURATION


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if _sheen_remaining <= 0.0:
		set_process(false)
		return
	_sheen_remaining = maxf(_sheen_remaining - delta, 0.0)
	queue_redraw()


func configure(card_rank: int, card_suit: int, hidden: bool) -> void:
	rank = card_rank
	suit = posmod(card_suit, SUITS.size())
	# Kept distinct per card so any future per-card accent never pulses in unison.
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
	if MotionPolicy.is_reduced():
		# A local crossfade communicates the face change without a card-collapse effect.
		(
			_flip_tween
			. tween_property(self, "modulate:a", 0.58, MotionPolicy.finite_duration(0.09))
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_IN)
		)
		_flip_tween.tween_callback(_show_side.bind(hidden))
		(
			_flip_tween
			. tween_property(self, "modulate:a", 1.0, MotionPolicy.finite_duration(0.11))
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
		_flip_tween.tween_callback(func() -> void: flip_completed.emit())
		return
	# Turn the card over on its long axis: it narrows to an edge while lifting a
	# hair off the felt (scale.y), then opens on the other side and settles.
	_flip_tween.set_parallel(true)
	var close_duration := MotionPolicy.finite_duration(0.12)
	var open_duration := MotionPolicy.finite_duration(0.16)
	(
		_flip_tween
		. tween_property(self, "scale:x", 0.03, close_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN)
	)
	_flip_tween.tween_property(self, "scale:y", 1.05, close_duration).set_trans(Tween.TRANS_SINE)
	_flip_tween.tween_property(self, "rotation", resting_rotation - 0.02, close_duration)
	_flip_tween.chain().tween_callback(_show_side.bind(hidden))
	_flip_tween.set_parallel(true)
	(
		_flip_tween
		. tween_property(self, "scale:x", 1.0, open_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	_flip_tween.tween_property(self, "scale:y", 1.0, open_duration).set_trans(Tween.TRANS_SINE)
	_flip_tween.tween_property(self, "rotation", resting_rotation, open_duration).set_trans(
		Tween.TRANS_SINE
	)
	_flip_tween.chain().tween_callback(func() -> void: flip_completed.emit())


func is_flipping() -> bool:
	return _flip_tween != null and _flip_tween.is_valid() and _flip_tween.is_running()


func _show_side(hidden: bool) -> void:
	_visual_face_down = hidden
	_trigger_sheen()
	queue_redraw()


func _trigger_sheen() -> void:
	_active_sheen_duration = MotionPolicy.finite_duration(SHEEN_DURATION)
	_sheen_remaining = _active_sheen_duration
	set_process(true)


func _apply_motion_preference(reduced: bool) -> void:
	if reduced and is_flipping():
		_flip_tween.kill()
		_visual_face_down = face_down
		scale = Vector2.ONE
		modulate.a = 1.0
		_trigger_sheen()
		flip_completed.emit()
	queue_redraw()


func _draw() -> void:
	var card_rect := Rect2(Vector2.ZERO, size)
	# Flat contact shadow: the card rests on the felt, it does not glow.
	var shadow := StyleBoxFlat.new()
	shadow.bg_color = SHADOW
	shadow.set_corner_radius_all(CORNER_RADIUS + 1)
	shadow.anti_aliasing = true
	draw_style_box(shadow, Rect2(Vector2(0.6, 1.8), size + Vector2(0.4, 0.4)))
	draw_texture_rect(BACK_TEXTURE if _visual_face_down else FACE_TEXTURE, card_rect, false)
	if _sheen_remaining > 0.0 and _active_sheen_duration > 0.0:
		# One finite brass hairline acknowledges a new card or a turned hole card.
		var normalized := _sheen_remaining / _active_sheen_duration
		var edge := StyleBoxFlat.new()
		edge.draw_center = false
		edge.border_color = Color(0.95, 0.80, 0.42, sin(normalized * PI) * 0.55)
		edge.set_border_width_all(1)
		edge.set_corner_radius_all(CORNER_RADIUS)
		edge.anti_aliasing = true
		draw_style_box(edge, card_rect.grow(-0.5))
	if _visual_face_down:
		return
	if rank > 10:
		_draw_court()
	elif rank == 1:
		_draw_ace()
	else:
		for pip: Vector2 in pip_layout(rank):
			draw_pip(self, suit, pip * size, size.y * PIP_HEIGHT, pip.y > 0.5)
	var ink := ink_color()
	_draw_index(ink, Transform2D.IDENTITY)
	_draw_index(ink, Transform2D(PI, size))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func rank_text() -> String:
	return tr("CARD_" + str(rank)) if rank == 1 or rank > 10 else str(rank)


func ink_color() -> Color:
	return RED if suit == 1 or suit == 2 else BLACK


## Standard pip positions (card fractions) for a number card, empty otherwise.
static func pip_layout(card_rank: int) -> Array:
	return PIP_LAYOUTS.get(card_rank, [])


static func court_texture(card_rank: int, card_suit: int) -> Texture2D:
	if card_rank < 11 or card_rank > 13:
		return null
	return COURT_TEXTURES[posmod(card_suit, 4)][card_rank - 11]


## Draws the generated suit art centred on `at`, `height` tall; `inverted` prints
## it upside down like the lower pips of a real card. Leaves an identity transform.
static func draw_pip(
	canvas: CanvasItem,
	suit_index: int,
	at: Vector2,
	height: float,
	inverted: bool = false,
	base: Transform2D = Transform2D.IDENTITY
) -> void:
	var texture: Texture2D = SUIT_TEXTURES[posmod(suit_index, 4)]
	var local := Transform2D(PI if inverted else 0.0, at)
	canvas.draw_set_transform_matrix(base * local)
	canvas.draw_texture_rect(
		texture, Rect2(Vector2(-height, -height) * 0.5, Vector2(height, height)), false
	)
	canvas.draw_set_transform_matrix(base)


func _draw_ace() -> void:
	var centre := size * 0.5
	if suit == 0:
		var side := size.x * 0.78
		draw_texture_rect(
			ACE_OF_SPADES, Rect2(centre - Vector2(side, side) * 0.5, Vector2(side, side)), false
		)
		return
	draw_pip(self, suit, centre, size.y * 0.34)


func _draw_court() -> void:
	var frame := Rect2(COURT_FRAME.position * size, COURT_FRAME.size * size)
	var texture := court_texture(rank, suit)
	if texture != null:
		# Aspect-fill the frame, trimming the panel's outer sleeves evenly.
		var source := Vector2(texture.get_width(), texture.get_height())
		var wanted := frame.size.x / frame.size.y
		var region := Rect2(Vector2.ZERO, source)
		if source.x / source.y > wanted:
			region.size.x = source.y * wanted
			region.position.x = (source.x - region.size.x) * 0.5
		else:
			region.size.y = source.x / wanted
			region.position.y = (source.y - region.size.y) * 0.5
		draw_texture_rect_region(texture, frame, region)
	draw_rect(frame, FRAME_INK, false, 0.75)
	var pip_height := size.y * 0.07
	var inset := Vector2(pip_height * 0.75, pip_height * 0.75)
	draw_pip(self, suit, frame.position + inset, pip_height)
	draw_pip(self, suit, frame.end - inset, pip_height, true)


## Corner index: rank over suit in the card's ink, in the top-left column. `base`
## rotates the whole index 180 degrees for the matching bottom-right corner.
func _draw_index(ink: Color, base: Transform2D) -> void:
	var font := Typography.DISPLAY_FONT
	var font_size := int(round(size.y * 0.19))
	var text := rank_text()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var column_x := size.x * 0.105
	# "10" is condensed horizontally so it stays inside the index column.
	var squeeze := minf(1.0, size.x * 0.17 / maxf(text_width, 0.01))
	var baseline := size.y * 0.045 + font.get_ascent(font_size) * 0.82
	draw_set_transform_matrix(
		base * Transform2D(0.0, Vector2(squeeze, 1.0), 0.0, Vector2(column_x, baseline))
	)
	draw_string(
		font, Vector2(-text_width * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink
	)
	draw_set_transform_matrix(base)
	draw_pip(self, suit, Vector2(column_x, baseline + size.y * 0.085), size.y * 0.1, false, base)


## Crisp vector suit pip centred on `at`, `height` tall. Fill plus an
## antialiased outline so the edge stays clean at every output resolution.
static func draw_suit(
	canvas: CanvasItem, suit_index: int, at: Vector2, height: float, ink: Color
) -> void:
	var half := height * 0.5
	match posmod(suit_index, 4):
		2:
			var diamond := PackedVector2Array(
				[
					at + Vector2(0, -half),
					at + Vector2(half * 0.74, 0),
					at + Vector2(0, half),
					at + Vector2(-half * 0.74, 0),
				]
			)
			_fill(canvas, diamond, ink)
		1:
			_fill(canvas, _heart(at, height, false), ink)
		0:
			_fill(canvas, _heart(at + Vector2(0, -height * 0.08), height * 0.84, true), ink)
			_fill(canvas, _stem(at, height), ink)
		3:
			var lobe := height * 0.235
			for offset: Vector2 in [
				Vector2(0, -height * 0.23),
				Vector2(-height * 0.235, height * 0.06),
				Vector2(height * 0.235, height * 0.06),
			]:
				canvas.draw_circle(at + offset, lobe, ink, true, -1.0, true)
			canvas.draw_circle(at + Vector2(0, -height * 0.02), lobe * 0.7, ink, true, -1.0, true)
			_fill(canvas, _stem(at, height), ink)


static func _heart(at: Vector2, height: float, inverted: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var unit := height / 32.0
	var flip := -1.0 if inverted else 1.0
	for step: int in range(48):
		var t := TAU * float(step) / 48.0
		var x := 16.0 * pow(sin(t), 3.0)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		points.append(at + Vector2(x * unit, (y - 2.5) * unit * flip))
	return points


static func _stem(at: Vector2, height: float) -> PackedVector2Array:
	return PackedVector2Array(
		[
			at + Vector2(-height * 0.05, height * 0.05),
			at + Vector2(height * 0.05, height * 0.05),
			at + Vector2(height * 0.2, height * 0.5),
			at + Vector2(-height * 0.2, height * 0.5),
		]
	)


static func _fill(canvas: CanvasItem, points: PackedVector2Array, ink: Color) -> void:
	canvas.draw_colored_polygon(points, ink)
	var outline := points.duplicate()
	outline.append(points[0])
	canvas.draw_polyline(outline, ink, 0.6, true)
