class_name PokerSeatPlate
extends Control
## One seat's integrated table plate: portrait, name, table stack, last action.
##
## Flat near-black plate with a silver hairline. The seat to act gets a silver
## top rule and a bounded "thinking" bar that fills over the decision time; a
## pot winner gets a warm brass edge and the NPC's painted reaction face; a folded
## seat dims. Cyan is never used here: it is reserved for keyboard/controller focus.

const PLATE := Color("0d1016f2")
const HAIRLINE := Color("5d6b7c")
const SILVER := Color("c9d3de")
const BRASS := Color("d9b44a")
const TEXT := Color("f1ede4")
const MUTED := Color("9aa6b4")
const RAISE_INK := Color("e8c872")
const FOLD_INK := Color("7d8793")
const PORTRAIT_SIZE: float = 52.0
const PLATE_SIZE := Vector2(172, 60)

var seat: int = 0
var is_player: bool = false
var folded: bool = false
var active: bool = false
var winner: bool = false
var thinking_progress: float = -1.0

var _portrait: TextureRect
var _base_face: Texture2D
var _react_face: Texture2D
var _name: Label
var _stack: AnimatedNumberLabel
var _stack_caption: Label
var _action: Label
var _react_tween: Tween
var _reacting: bool = false


func configure(
	seat_index: int, display_name: String, face: Texture2D, react_face: Texture2D
) -> void:
	seat = seat_index
	is_player = face == null
	_base_face = face
	_react_face = react_face
	if is_node_ready():
		_apply_identity(display_name)
	else:
		set_meta("pending_name", display_name)


func _ready() -> void:
	size = PLATE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var text_left := 8.0 if is_player else PORTRAIT_SIZE + 12.0
	var text_width := size.x - text_left - 6.0
	if not is_player:
		_portrait = TextureRect.new()
		_portrait.name = "Portrait"
		_portrait.position = Vector2(4, 4)
		_portrait.size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
		_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_portrait)
	_name = _make_label(Vector2(text_left, 2), Vector2(text_width, 18), 14, SILVER)
	_name.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stack_caption = _make_label(Vector2(text_left, 21), Vector2(40, 18), 12, MUTED)
	_stack = AnimatedNumberLabel.new()
	_stack.position = Vector2(text_left, 19)
	_stack.size = Vector2(text_width, 20)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_font_override("font", Typography.UI_FONT)
	_stack.add_theme_font_size_override("font_size", Typography.CRITICAL)
	_stack.add_theme_color_override("font_color", TEXT)
	_stack.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_stack)
	_action = _make_label(Vector2(text_left, 39), Vector2(text_width, 18), 14, TEXT)
	_action.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_action.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_identity(String(get_meta("pending_name", "")))
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)


func _apply_identity(display_name: String) -> void:
	if _name == null:
		return
	_name.text = display_name
	if _portrait != null:
		_portrait.texture = _base_face
	_stack_caption.text = tr("POKER_STACK_CAPTION")


func set_stack(amount: int, animate: bool = true) -> void:
	if _stack == null:
		return
	if Wallet.test_mode_enabled and is_player:
		_stack.set_infinity()
	else:
		_stack.set_number(amount, "%d", animate and not MotionPolicy.is_reduced())


func set_caption(text: String) -> void:
	if _stack_caption != null:
		_stack_caption.text = text
		_stack_caption.size.x = 80.0


## Last action line ("RAISE 20", "FOLD"); `emphasis` 1 = aggressive, -1 = folded.
func set_action(text: String, emphasis: int = 0) -> void:
	if _action == null:
		return
	_action.text = text
	var ink := TEXT
	if emphasis > 0:
		ink = RAISE_INK
	elif emphasis < 0:
		ink = FOLD_INK
	_action.add_theme_color_override("font_color", ink)


func action_text() -> String:
	return _action.text if _action != null else ""


func stack_text() -> String:
	return _stack.text if _stack != null else ""


func set_folded(value: bool) -> void:
	folded = value
	_refresh_tint()
	queue_redraw()


func set_active(value: bool) -> void:
	active = value
	if not value:
		thinking_progress = -1.0
	queue_redraw()


func set_thinking(progress: float) -> void:
	thinking_progress = progress
	queue_redraw()


func set_winner(value: bool) -> void:
	winner = value
	if value:
		show_reaction(-1.0)
	queue_redraw()


## Swaps in the painted reaction face; a negative hold keeps it until reset.
func show_reaction(hold_seconds: float) -> void:
	if _portrait == null or _react_face == null:
		return
	if _react_tween != null and _react_tween.is_valid():
		_react_tween.kill()
	_reacting = true
	_portrait.texture = _react_face
	if hold_seconds < 0.0:
		return
	_react_tween = create_tween()
	_react_tween.tween_interval(MotionPolicy.finite_duration(hold_seconds))
	_react_tween.tween_callback(_end_reaction)


func is_reacting() -> bool:
	return _reacting


func reset_for_hand() -> void:
	folded = false
	active = false
	winner = false
	thinking_progress = -1.0
	_end_reaction()
	set_action("")
	_refresh_tint()
	queue_redraw()


## The player's own plate: seat position in the name line and the best hand
## made with only the board cards already on the felt (or FOLD).
func show_player_state(
	math: PokerMath, visible_board: int, show_position: bool, cards_shown: bool
) -> void:
	if _name == null:
		return
	var position_key := ""
	if show_position:
		if math.button == 0:
			position_key = "POKER_POSITION_BUTTON"
		elif math.small_blind_seat == 0:
			position_key = "POKER_POSITION_SMALL_BLIND"
		elif math.big_blind_seat == 0:
			position_key = "POKER_POSITION_BIG_BLIND"
	_name.text = tr("POKER_YOU")
	if not position_key.is_empty():
		_name.text = tr("POKER_YOU_AT") % tr(position_key)
	var hole := math.player_hole()
	if hole.size() < 2 or not cards_shown:
		set_action("")
		return
	if not math.folded.is_empty() and math.folded[0]:
		set_action(tr("POKER_ACT_FOLD"), -1)
		return
	var visible: Array[int] = hole.duplicate()
	for index: int in range(mini(visible_board, math.board.size())):
		visible.append(math.board[index])
	set_action(tr(PokerHandEval.category_key(PokerHandEval.evaluate(visible))))


func display_name() -> String:
	return _name.text if _name != null else ""


func portrait_texture() -> Texture2D:
	return _portrait.texture if _portrait != null else null


func _end_reaction() -> void:
	if _react_tween != null and _react_tween.is_valid():
		_react_tween.kill()
	_react_tween = null
	_reacting = false
	if _portrait != null:
		_portrait.texture = _base_face


func _refresh_tint() -> void:
	var dim := Color(0.52, 0.54, 0.58, 1.0) if folded else Color.WHITE
	if _portrait != null:
		_portrait.modulate = dim
	if _name != null:
		_name.modulate = dim
		_stack.modulate = dim


func _apply_motion_preference(_reduced: bool) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE
	style.border_color = BRASS if winner else HAIRLINE
	style.set_border_width_all(2 if winner else 1)
	style.set_corner_radius_all(5)
	style.anti_aliasing = true
	draw_style_box(style, rect)
	if _portrait != null:
		# Hairline frame around the painted bust.
		var frame := StyleBoxFlat.new()
		frame.draw_center = false
		frame.border_color = BRASS if winner else Color(SILVER, 0.55)
		frame.set_border_width_all(1)
		frame.set_corner_radius_all(3)
		draw_style_box(frame, Rect2(_portrait.position, _portrait.size).grow(1.0))
	if active and not folded:
		draw_rect(Rect2(6, 0, size.x - 12, 2), SILVER)
	if thinking_progress >= 0.0:
		var width := (size.x - 12.0) * clampf(thinking_progress, 0.0, 1.0)
		draw_rect(Rect2(6, size.y - 3, size.x - 12, 1), Color(HAIRLINE, 0.8))
		draw_rect(Rect2(6, size.y - 3, width, 1), SILVER)


func _make_label(at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Typography.UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
