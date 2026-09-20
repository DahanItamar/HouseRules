class_name StakeSelector
extends Control
## Shared casino wager console: the total bet, the table limit, what is left after
## the bet, and the quick-bet keys every game uses.
##
##   MIN  10  25  X2  X5  ALL
##
## The same six keys in the same order on every machine and table, so the player
## learns them once; only the painted skin changes from game to game (the cabinet's
## own kit plate, see UiKit). Each key names the button that presses it when the
## controller is on it, and the pointer works the same way.
##
## Presentation only. Nothing here decides what a bet may be: each key asks the
## cabinet for an operation and MiniGame.apply_bet applies every wallet and
## table-limit clamp, so an illegal bet is impossible from this console.

var cabinet: MiniGame
var style: DeckStyle = DeckStyle.casino()
## The quick-bet keys in reading order (layout, focus chains and tests).
var _buttons: Array[Button] = []
## The operation each key applies, parallel to `_buttons`.
var _button_operations: Array[int] = []
var _bet_flash: float = 0.0
var _stake_value: AnimatedNumberLabel
## The key the pointer or the controller is on, or -1 for none.
var _highlighted: int = -1

const KEY_HEIGHT: float = 44.0
const KEY_GAP: float = 4.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_stake_value = AnimatedNumberLabel.new()
	_stake_value.name = "AnimatedStakeValue"
	_stake_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stake_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stake_value.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_stake_value.add_theme_font_size_override("font_size", Typography.CONTROL)
	_stake_value.add_theme_color_override("font_color", Color("fff0d4"))
	add_child(_stake_value)
	_rebuild_buttons()
	_layout_buttons()
	refresh_controls()
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _rebuild_buttons() -> void:
	for button: Button in _buttons:
		button.queue_free()
	_buttons.clear()
	_button_operations.clear()
	for entry: Dictionary in QuickBetRow.KEYS:
		var operation: int = entry.operation
		var button := PromptButton.new()
		button.name = "BetKey%s" % String(entry.label).capitalize()
		button.text = String(entry.label)
		# The glyph shows on the key the controller is sitting on, so the player is
		# never left guessing which button commits the bet under the highlight.
		button.action = &"interact"
		button.show_glyph = false
		button.glyph_scale = 0.95
		button.gap = 3.0
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_override("font", Typography.DISPLAY_FONT)
		button.add_theme_font_size_override("font_size", Typography.CONTROL)
		_skin(button)
		button.pressed.connect(_apply_operation.bind(operation))
		button.focus_entered.connect(_highlight.bind(operation, true))
		button.focus_exited.connect(_highlight.bind(operation, false))
		button.mouse_entered.connect(_highlight.bind(operation, true))
		button.mouse_exited.connect(_highlight.bind(operation, false))
		add_child(button)
		ButtonFeedback.attach(button)
		_buttons.append(button)
		_button_operations.append(operation)


## Paints one key in the current theme, dropping the plate a previous theme left.
func _skin(button: Button) -> void:
	var stale := button.get_node_or_null("KitPlate")
	if stale != null:
		stale.queue_free()
		button.remove_child(stale)
	style.skin_button(
		button,
		style.secondary_face,
		style.secondary_edge,
		false,
		UiKit.scale_for_corner(style.kit_theme, "button", QuickBetRow.KEY_CORNER)
	)


## The cabinet is seated after this console is built, so the game's painted kit is
## adopted the first time a refresh finds a context to read it from.
func _adopt_theme() -> void:
	if not style.kit_theme.is_empty() or cabinet == null or cabinet.context == null:
		return
	var themed := DeckStyle.for_theme(cabinet.context.definition.id)
	if themed.kit_theme.is_empty():
		return
	style = themed
	for button: Button in _buttons:
		_skin(button)


func _process(delta: float) -> void:
	if _bet_flash > 0.0:
		_bet_flash = maxf(0.0, _bet_flash - delta * 4.5)
		queue_redraw()


func _apply_motion_preference(reduced: bool) -> void:
	set_process(not reduced)
	if reduced:
		_bet_flash = 0.0
		for button: Button in _buttons:
			button.modulate = Color.WHITE
	queue_redraw()


## The keys' rectangles in this console's space, laid along the bottom of it.
func button_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var count := maxf(_buttons.size(), 1)
	var key_width := (size.x - KEY_GAP * (count - 1.0)) / count
	var top := maxf(size.y - KEY_HEIGHT, 0.0)
	for index: int in range(_buttons.size()):
		rects.append(
			Rect2(Vector2(index * (key_width + KEY_GAP), top), Vector2(key_width, KEY_HEIGHT))
		)
	return rects


func chip_rects() -> Array[Rect2]:
	return button_rects()


## The operation each key applies, parallel to `button_rects()`.
func operations() -> Array[int]:
	return _button_operations.duplicate()


func refresh_controls() -> void:
	if cabinet == null:
		return
	_adopt_theme()
	# A key the wallet or the table would refuse reads unavailable but keeps its
	# place, so the row never shifts under the player's thumb mid-bet.
	for index: int in range(_buttons.size()):
		var button := _buttons[index]
		button.disabled = not cabinet.can_apply_bet(_button_operations[index])
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		)
		button.modulate = Color.WHITE
	_stake_value.set_number(
		cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	)
	queue_redraw()


func focus_first_available() -> void:
	for button: Button in _buttons:
		if not button.disabled:
			button.grab_focus()
			return


## Why the key the player is reaching for cannot be used, e.g. "X5 needs 250
## chips"; empty when nothing is highlighted or that key is available.
func unavailable_reason() -> String:
	if cabinet == null or cabinet.context == null or _highlighted < 0:
		return ""
	if cabinet.can_apply_bet(_highlighted):
		return ""
	var candidate := cabinet.bet_candidate(_highlighted)
	if candidate <= cabinet.selected_stake:
		return ""
	var label := QuickBetRow._label_for(_highlighted)
	if candidate > cabinet.context.balance:
		return tr("DECK_QUICK_NEEDS") % [label, candidate]
	return tr("DECK_QUICK_OVER_TABLE") % [label, cabinet.context.definition.max_bet]


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_buttons()
		queue_redraw()


func _layout_buttons() -> void:
	var rects := button_rects()
	for index: int in range(mini(rects.size(), _buttons.size())):
		_buttons[index].position = rects[index].position
		_buttons[index].size = rects[index].size
	if _stake_value != null:
		_stake_value.position = Vector2(62.0, 1.0)
		_stake_value.size = Vector2(62.0, 32.0)


func _apply_operation(operation: int) -> void:
	if cabinet != null and cabinet.apply_bet(operation):
		_bet_flash = 1.0
	refresh_controls()


func _highlight(operation: int, on: bool) -> void:
	var index := _button_operations.find(operation)
	if index >= 0:
		_buttons[index].show_glyph = on and _buttons[index].has_focus()
	if on:
		_highlighted = operation
	elif _highlighted == operation:
		_highlighted = -1
	queue_redraw()


func _draw() -> void:
	if cabinet == null or cabinet.context == null:
		return
	var displayed_stake := (
		cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	)
	draw_string(
		Typography.UI_FONT,
		Vector2(8, 20),
		tr("BET_IN_PLAY") if cabinet.is_round_active else tr("BET_TOTAL"),
		HORIZONTAL_ALIGNMENT_LEFT,
		54,
		Typography.CAPTION,
		Color("b8aa97")
	)
	# Reaching for a refused key explains itself in place of the limit caption.
	var refusal := unavailable_reason()
	if refusal.is_empty():
		var limit_text := "%d-%d" % [cabinet.context.definition.min_bet, cabinet.bet_cap()]
		draw_string(
			Typography.UI_FONT,
			Vector2(128, 20),
			"LIMIT %s" % limit_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			88,
			Typography.MICRO,
			Color("b8aa97")
		)
		var after_bet := maxi(0, cabinet.context.balance - displayed_stake)
		var funds_text := (
			"DEV FUNDS  ∞" if Wallet.test_mode_enabled else tr("BET_AFTER") % after_bet
		)
		draw_string(
			Typography.UI_FONT,
			Vector2(218, 20),
			funds_text,
			HORIZONTAL_ALIGNMENT_RIGHT,
			size.x - 218,
			Typography.MICRO,
			Color("b8aa97")
		)
	else:
		draw_string(
			Typography.UI_FONT,
			Vector2(128, 20),
			refusal,
			HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 136,
			Typography.MICRO,
			Color("d3c3a6")
		)
	if _bet_flash > 0.0:
		draw_rect(Rect2(0, 34, size.x * _bet_flash, 2), Color("48c5d5"))
