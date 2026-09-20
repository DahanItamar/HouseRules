class_name CabinetDeck
extends Control
## The shared bottom control deck. One structure for every game, skinned per game
## by a DeckStyle:
##
##   instruction rail   one plain-language sentence for the current state, with
##                      inline glyphs ("Set your bet with (LB)(RB), then (A) Deal")
##   BALANCE plate      caption and value; the test bank shows ∞ with a TEST tag
##   BET control        YOUR BET, value, chip stack, table limit, − / + (LB/RB)
##   QUICK BET row      MIN 10 25 X2 X5 ALL, the same keys in the same order in
##                      every game; shown only while the bet can still change
##   ACTIONS            right-aligned, primary (largest) on the far right; only the
##                      actions valid now are shown, each naming its input
##
## Adopting it in a new cabinet: build(DeckStyle) once, add_action() for each key,
## then per refresh call bet.set_state(), quick_bets.set_states(cabinet),
## set_instruction() and show_actions(). Connect bet.step_requested and
## quick_bets.operation_requested to the cabinet's own bet rules; the deck never
## changes a stake itself.
##
## Presentation only: the owner decides which actions are valid and what each one
## does; the deck lays them out, animates the swap and forwards presses.

signal action_pressed(id: StringName)

## Bottom band inside TV-safe (48, 27, 864x486): y 422-513.
const DECK_RECT := Rect2(48, 422, 864, 91)
const INSTRUCTION_HEIGHT: float = 26.0
const ROW_TOP: float = 31.0
const ROW_HEIGHT: float = 56.0
const INSET: float = 8.0
## The instruction starts clear of the painted corner ornaments.
const INSTRUCTION_INSET: float = 28.0
const GAP: float = 8.0
const BALANCE_WIDTH: float = 124.0
const BET_WIDTH: float = 248.0
const PRIMARY_MIN_WIDTH: float = 168.0
const SECONDARY_MIN_WIDTH: float = 116.0
const PRIMARY_HEIGHT: float = 56.0
const SECONDARY_HEIGHT: float = 48.0
const SLIDE_SECONDS: float = 0.16

var style: DeckStyle = DeckStyle.casino()
var balance: InfoPlate
var bet: BetControl
## The shared MIN / 10 / 25 / X2 / X5 / ALL keys; shown only while a bet can change.
var quick_bets: QuickBetRow
var instruction: InputPromptLabel
var _actions: Dictionary = {}
var _order: Array[StringName] = []
var _primary_id: StringName = &""
var _shown: Array[StringName] = []
var _slide_tweens: Dictionary = {}
var _instruction_tween: Tween
var _instruction_tone: InfoPlate.Tone = InfoPlate.Tone.NEUTRAL
var _panel_plate: KitPlate


func _init() -> void:
	name = "CabinetDeck"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = DECK_RECT.position
	size = DECK_RECT.size


## Builds the deck's parts for `deck_style`. Call once, before adding actions.
func build(deck_style: DeckStyle) -> void:
	style = deck_style
	if UiKit.has_part(style.kit_theme, "panel"):
		# The painted deck frame; its flat centre carries the plates and keys.
		_panel_plate = KitPlate.new()
		_panel_plate.name = "DeckPlate"
		_panel_plate.configure(style.kit_theme, "panel", style.panel_scale)
		add_child(_panel_plate)
		_panel_plate.fit(Rect2(Vector2.ZERO, size))
	instruction = InputPromptLabel.new()
	instruction.name = "Instruction"
	instruction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	instruction.position = Vector2(INSTRUCTION_INSET, 1.0)
	instruction.size = Vector2(size.x - INSTRUCTION_INSET * 2.0, INSTRUCTION_HEIGHT)
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction.clip_text = true
	instruction.glyph_scale = 1.2
	instruction.add_theme_font_override("font", Typography.UI_FONT)
	instruction.add_theme_font_size_override("font_size", 15)
	instruction.add_theme_color_override("font_color", style.value)
	add_child(instruction)
	balance = InfoPlate.new()
	balance.name = "BalancePlate"
	balance.style = style
	balance.value_size = 24
	balance.position = Vector2(INSET, ROW_TOP)
	balance.size = Vector2(BALANCE_WIDTH, ROW_HEIGHT)
	add_child(balance)
	bet = BetControl.new()
	bet.style = style
	bet.position = Vector2(INSET + BALANCE_WIDTH + GAP, ROW_TOP)
	bet.size = Vector2(BET_WIDTH, ROW_HEIGHT)
	add_child(bet)
	quick_bets = QuickBetRow.new()
	quick_bets.position = Vector2(
		bet.position.x + BET_WIDTH + GAP, ROW_TOP + (ROW_HEIGHT - QuickBetRow.KEY_SIZE.y) * 0.5
	)
	quick_bets.build(style)
	add_child(quick_bets)
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	queue_redraw()


## Adds one action key. The primary action is the largest and sits far right.
func add_action(
	id: StringName, label: String, input_action: StringName, primary: bool = false
) -> PromptButton:
	var button := PromptButton.new()
	button.name = "DeckAction_%s" % String(id)
	button.text = label
	button.action = input_action
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Typography.DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 20 if primary else 17)
	button.glyph_scale = 1.15 if primary else 1.25
	style.skin_button(
		button,
		style.primary_face if primary else style.secondary_face,
		style.primary_edge if primary else style.secondary_edge,
		primary
	)
	button.size = Vector2(
		PRIMARY_MIN_WIDTH if primary else SECONDARY_MIN_WIDTH,
		PRIMARY_HEIGHT if primary else SECONDARY_HEIGHT
	)
	button.pressed.connect(func() -> void: action_pressed.emit(id))
	button.visible = false
	add_child(button)
	ButtonFeedback.attach(button)
	_actions[id] = button
	if primary:
		_primary_id = id
	else:
		_order.append(id)
	return button


func action_button(id: StringName) -> PromptButton:
	return _actions.get(id) as PromptButton


func primary_button() -> PromptButton:
	return action_button(_primary_id)


func visible_action_ids() -> Array[StringName]:
	return _shown.duplicate()


## Shows exactly `ids` (others are hidden, never greyed) and reflows them
## right-aligned. Newly shown keys slide up into place; the rest glide over.
func show_actions(ids: Array[StringName]) -> void:
	var next: Array[StringName] = []
	for id: StringName in _order:
		if id in ids:
			next.append(id)
	if _primary_id in ids:
		next.append(_primary_id)
	var focus_owner := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var lost_focus := false
	for id: StringName in _actions:
		var button: PromptButton = _actions[id]
		var keep := id in next
		if not keep and button.visible:
			if focus_owner == button:
				lost_focus = true
			button.visible = false
			_stop_slide(id)
	_fit_widths(next)
	var targets := _targets(next)
	for id: StringName in next:
		var button: PromptButton = _actions[id]
		var target: Vector2 = targets[id]
		var appearing := not button.visible
		button.visible = true
		if MotionPolicy.is_reduced() or not is_inside_tree():
			_stop_slide(id)
			button.position = target
			continue
		if appearing:
			button.position = target + Vector2(0, 8)
		if button.position != target:
			_slide(id, button, target)
	_shown = next
	if lost_focus and not next.is_empty():
		DialoguePanel.focus_when_ready(_actions[next[-1]])


## One plain-language sentence for the current state; it may carry glyph tokens.
func set_instruction(template: String, tone: InfoPlate.Tone = InfoPlate.Tone.NEUTRAL) -> void:
	var tone_changed := tone != _instruction_tone
	_instruction_tone = tone
	# The sentence stays warm ivory; the result's meaning is carried by the table
	# banner's accent, so the rail never turns into coloured text.
	instruction.add_theme_color_override("font_color", style.value)
	if instruction.template == template and not tone_changed:
		return
	var had_text := not instruction.template.is_empty()
	instruction.template = template
	if _instruction_tween != null and _instruction_tween.is_valid():
		_instruction_tween.kill()
	instruction.position.y = 1.0
	instruction.modulate.a = 1.0
	if not had_text or MotionPolicy.is_reduced() or not is_inside_tree():
		return
	instruction.position.y = 5.0
	instruction.modulate.a = 0.4
	_instruction_tween = create_tween().set_parallel(true)
	(
		_instruction_tween
		. tween_property(instruction, "position:y", 1.0, 0.16)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_instruction_tween.tween_property(instruction, "modulate:a", 1.0, 0.14)


func instruction_tone() -> InfoPlate.Tone:
	return _instruction_tone


func has_active_motion() -> bool:
	for tween: Tween in _slide_tweens.values():
		if tween != null and tween.is_valid():
			return true
	return (
		(_instruction_tween != null and _instruction_tween.is_valid())
		or (bet != null and bet.is_animating())
	)


## Every rectangle the deck occupies, in the deck's parent space.
func occupied_rect() -> Rect2:
	return Rect2(position, size)


func _fit_widths(ids: Array[StringName]) -> void:
	for id: StringName in ids:
		var button: PromptButton = _actions[id]
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		var label_width := (
			font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
		var glyph_width := InputGlyph.measure(
			button.glyph_spec(), roundf(font_size * button.glyph_scale)
		)
		var minimum := PRIMARY_MIN_WIDTH if id == _primary_id else SECONDARY_MIN_WIDTH
		button.size.x = maxf(minimum, ceilf(label_width + glyph_width + button.gap + 32.0))


func _targets(ids: Array[StringName]) -> Dictionary:
	var targets: Dictionary = {}
	var right := size.x - INSET
	for index: int in range(ids.size() - 1, -1, -1):
		var id := ids[index]
		var button: PromptButton = _actions[id]
		right -= button.size.x
		targets[id] = Vector2(right, ROW_TOP + (ROW_HEIGHT - button.size.y) * 0.5)
		right -= GAP
	return targets


func _slide(id: StringName, button: Control, target: Vector2) -> void:
	_stop_slide(id)
	var tween := create_tween()
	(
		tween
		. tween_property(button, "position", target, SLIDE_SECONDS)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_slide_tweens[id] = tween


func _stop_slide(id: StringName) -> void:
	var tween: Tween = _slide_tweens.get(id)
	if tween != null and tween.is_valid():
		tween.kill()
	_slide_tweens.erase(id)


func _on_motion_preference_changed(reduced: bool) -> void:
	if not reduced:
		return
	var targets := _targets(_shown)
	for id: StringName in _shown:
		_stop_slide(id)
		(_actions[id] as Control).position = targets[id]
	if _instruction_tween != null and _instruction_tween.is_valid():
		_instruction_tween.kill()
	_instruction_tween = null
	if instruction != null:
		instruction.position.y = 1.0
		instruction.modulate.a = 1.0


func _draw() -> void:
	if _panel_plate == null:
		draw_style_box(style.panel_box(style.surface, style.edge, 2), Rect2(Vector2.ZERO, size))
	# The instruction rail is part of the deck, divided by one brass hairline.
	draw_rect(
		Rect2(Vector2(INSET, INSTRUCTION_HEIGHT + 1.0), Vector2(size.x - INSET * 2.0, 1.0)),
		style.hairline
	)
