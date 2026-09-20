class_name QuickBetRow
extends Control
## The shared quick-bet row: one painted key per bet operation, identical in every
## game so the player learns it once.
##
##   MIN  10  25  X2  X5  ALL
##
## MIN drops to the table minimum, 10 and 25 add that many chips, X2 and X5
## multiply the current bet and ALL bets the most the wallet and the table allow.
##
## Presentation only. The row never changes the stake: it asks for an operation
## with `operation_requested` and the cabinet applies it through its own rules, so
## every wallet and table-limit clamp stays in one place (MiniGame.apply_bet).
## A key the wallet or the table would not allow is shown unavailable rather than
## hidden, and the deck's instruction rail says what it would need.

signal operation_requested(operation: int)
## The key the pointer or the controller is on changed (or left the row).
signal highlight_changed

## 44 px minimum target on both axes, inside the TV-safe deck band.
const KEY_SIZE := Vector2(44, 44)
const GAP: float = 4.0
## These keys are a third the size of an action key, so their painted plate is
## drawn smaller too: a 10 px corner frames a 44 px key without swallowing it.
const KEY_CORNER: float = 10.0
## The six operations in reading order, with the key each one prints.
const KEYS: Array[Dictionary] = [
	{"operation": MiniGame.BetOperation.MIN, "label": "MIN"},
	{"operation": MiniGame.BetOperation.ADD_10, "label": "10"},
	{"operation": MiniGame.BetOperation.ADD_25, "label": "25"},
	{"operation": MiniGame.BetOperation.MULTIPLY_2, "label": "X2"},
	{"operation": MiniGame.BetOperation.MULTIPLY_5, "label": "X5"},
	{"operation": MiniGame.BetOperation.MAX, "label": "ALL"},
]

var style: DeckStyle = DeckStyle.casino()
var _keys: Dictionary = {}
## The operation the pointer or the controller is on, or -1 for none.
var _highlighted: int = -1


func _init() -> void:
	name = "QuickBetRow"
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2(width_for(KEYS.size()), KEY_SIZE.y)


## Width this row needs for `count` keys, so a deck can budget its layout.
static func width_for(count: int) -> float:
	return KEY_SIZE.x * count + GAP * maxf(count - 1, 0)


## Builds the row for `deck_style`. Call once, before the first `set_states`.
func build(deck_style: DeckStyle) -> void:
	style = deck_style
	var x := 0.0
	for entry: Dictionary in KEYS:
		var key := PromptButton.new()
		key.name = "QuickBet_%s" % String(entry.label).to_lower()
		key.text = String(entry.label)
		# The glyph appears on the key the controller is sitting on, so it always
		# says which button commits the highlighted bet.
		key.action = &"interact"
		key.show_glyph = false
		key.glyph_scale = 0.95
		key.gap = 3.0
		key.focus_mode = Control.FOCUS_ALL
		key.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		key.add_theme_font_override("font", Typography.DISPLAY_FONT)
		key.add_theme_font_size_override("font_size", 17)
		style.skin_button(
			key,
			style.secondary_face,
			style.secondary_edge,
			false,
			UiKit.scale_for_corner(style.kit_theme, "button", KEY_CORNER)
		)
		key.position = Vector2(x, 0)
		key.size = KEY_SIZE
		var operation: int = entry.operation
		key.pressed.connect(func() -> void: operation_requested.emit(operation))
		key.focus_entered.connect(func() -> void: _highlight(operation, true))
		key.focus_exited.connect(func() -> void: _highlight(operation, false))
		key.mouse_entered.connect(func() -> void: _highlight(operation, true))
		key.mouse_exited.connect(func() -> void: _highlight(operation, false))
		add_child(key)
		ButtonFeedback.attach(key)
		_keys[operation] = key
		x += KEY_SIZE.x + GAP
	size = Vector2(x - GAP, KEY_SIZE.y)


func key(operation: int) -> PromptButton:
	return _keys.get(operation) as PromptButton


## Every key in reading order (tests, focus chains and previews).
func keys() -> Array[PromptButton]:
	var all: Array[PromptButton] = []
	for entry: Dictionary in KEYS:
		all.append(_keys[entry.operation] as PromptButton)
	return all


## Enables exactly the operations `cabinet` would accept right now. Nothing is
## hidden: an unavailable key stays in place so the row never moves under the
## player's thumb.
func set_states(cabinet: MiniGame) -> void:
	for entry: Dictionary in KEYS:
		var button := _keys[entry.operation] as PromptButton
		button.disabled = cabinet == null or not cabinet.can_apply_bet(entry.operation)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
		)
		button.queue_redraw()


## Why the key the player is pointing at or focused on cannot be used, e.g.
## "X5 needs 250 chips". Empty when nothing is highlighted or the key is fine, so
## the deck keeps showing its ordinary betting instruction and only explains a
## refusal at the moment the player reaches for it.
func unavailable_reason(cabinet: MiniGame) -> String:
	if cabinet == null or cabinet.context == null or _highlighted < 0:
		return ""
	if cabinet.can_apply_bet(_highlighted):
		return ""
	var label := _label_for(_highlighted)
	var candidate := cabinet.bet_candidate(_highlighted)
	if candidate <= cabinet.selected_stake:
		return ""
	if candidate > cabinet.context.balance:
		return tr("DECK_QUICK_NEEDS") % [label, candidate]
	return tr("DECK_QUICK_OVER_TABLE") % [label, cabinet.context.definition.max_bet]


## The key an operation prints, e.g. "X5".
static func _label_for(operation: int) -> String:
	for entry: Dictionary in KEYS:
		if int(entry.operation) == operation:
			return String(entry.label)
	return ""


func _highlight(operation: int, on: bool) -> void:
	var button := _keys.get(operation) as PromptButton
	if button != null:
		button.show_glyph = on and button.has_focus()
	if on:
		_highlighted = operation
	elif _highlighted == operation:
		_highlighted = -1
	highlight_changed.emit()
