class_name MatchPointDeck
extends Control
## Match Point scoreboard deck under the board: credits, the stake keys, the
## bet / top-prize readout with the control hint, and the SERVE key. Every
## control is a real focusable button at least 44 px on both axes.

signal serve_pressed
signal stake_chosen(amount: int)

const DECK_SIZE := Vector2(864, 72)
const CREDIT_RECT := Rect2(0, 0, 120, 72)
const RACK_RECT := Rect2(128, 0, 308, 72)
const INFO_RECT := Rect2(444, 0, 240, 72)
const SERVE_RECT := Rect2(692, 4, 172, 64)
const KEY_SIZE := Vector2(52, 52)
const KEY_GAP: float = 6.0

var stake_keys: Array[Button] = []
var serve_button: Button
var credit_value: AnimatedNumberLabel
var _credit_caption: Label
var _bet_line: Label
var _prize_line: Label
var _hint_line: Label


func _init() -> void:
	name = "MatchPointDeck"
	size = DECK_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(values: Array[int]) -> void:
	for rect: Rect2 in [CREDIT_RECT, RACK_RECT, INFO_RECT]:
		add_child(MatchPointPlate.new("DeckPlate", rect))
	var strip := MatchPointStrip.new("CreditStrip", Rect2(8, 26, 104, 38))
	add_child(strip)
	_credit_caption = MatchPointStyle.label(
		self, Rect2(8, 5, 104, 18), 13, MatchPointStyle.CREAM_MUTED
	)
	_credit_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_value = AnimatedNumberLabel.new()
	credit_value.name = "MatchPointCredits"
	credit_value.position = Vector2(8, 26)
	credit_value.size = Vector2(104, 38)
	credit_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	credit_value.add_theme_font_override("font", Typography.DISPLAY_FONT)
	credit_value.add_theme_font_size_override("font_size", 26)
	credit_value.add_theme_color_override("font_color", MatchPointStyle.CREAM_INK)
	credit_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(credit_value)
	for index: int in range(values.size()):
		var value := values[index]
		var key := Button.new()
		key.name = "MatchPointStake%d" % value
		key.position = Vector2(RACK_RECT.position.x + 10 + index * (KEY_SIZE.x + KEY_GAP), 10)
		key.size = KEY_SIZE
		key.focus_mode = Control.FOCUS_ALL
		key.text = str(value)
		key.set_meta("amount", value)
		MatchPointStyle.style_button(key)
		key.pressed.connect(func() -> void: stake_chosen.emit(value))
		add_child(key)
		ButtonFeedback.attach(key)
		stake_keys.append(key)
	var info := INFO_RECT.position
	_bet_line = MatchPointStyle.label(self, Rect2(info + Vector2(12, 5), Vector2(216, 22)), 17)
	_bet_line.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_prize_line = MatchPointStyle.label(
		self, Rect2(info + Vector2(12, 28), Vector2(216, 20)), 14, MatchPointStyle.BRASS_BRIGHT
	)
	_hint_line = MatchPointStyle.label(
		self, Rect2(info + Vector2(12, 49), Vector2(216, 18)), 12, MatchPointStyle.CREAM_MUTED
	)
	serve_button = Button.new()
	serve_button.name = "MatchPointServe"
	serve_button.position = SERVE_RECT.position
	serve_button.size = SERVE_RECT.size
	serve_button.focus_mode = Control.FOCUS_ALL
	serve_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	MatchPointStyle.style_button(serve_button, true)
	serve_button.add_theme_font_size_override("font_size", 24)
	serve_button.pressed.connect(func() -> void: serve_pressed.emit())
	add_child(serve_button)
	ButtonFeedback.attach(serve_button)
	_link_focus()


func _link_focus() -> void:
	var row: Array[Button] = stake_keys.duplicate()
	row.append(serve_button)
	for index: int in range(row.size()):
		var here := row[index]
		var left := row[maxi(index - 1, 0)]
		var right := row[mini(index + 1, row.size() - 1)]
		here.focus_neighbor_left = here.get_path_to(left)
		here.focus_neighbor_right = here.get_path_to(right)
		here.focus_neighbor_bottom = here.get_path_to(here)


## `state`: balance, selected, cap, open, can_serve, max_tenths, risk_key,
## test_bank.
func refresh_state(state: Dictionary) -> void:
	if credit_value == null:
		return
	_credit_caption.text = tr("HUD_TEST_BANK") if state.test_bank else tr("HUD_CREDITS")
	if state.test_bank:
		credit_value.set_infinity()
	else:
		credit_value.set_number(maxi(0, int(state.balance)))
	var open: bool = state.open
	for key: Button in stake_keys:
		var amount: int = key.get_meta("amount")
		key.disabled = not open or amount > int(state.cap)
		MatchPointStyle.style_toggle(key, amount == int(state.selected))
	serve_button.text = tr("MATCH_POINT_SERVE")
	serve_button.disabled = not state.can_serve
	_bet_line.text = tr("MATCH_POINT_BET_LINE") % [int(state.selected), tr(state.risk_key)]
	var top := int(state.selected) * int(state.max_tenths) / 10
	_prize_line.text = tr("MATCH_POINT_TOP_PRIZE") % top
	_hint_line.text = (
		tr("MATCH_POINT_DECK_HINT")
		% [InputRouter.glyph("tertiary"), InputRouter.glyph("secondary")]
	)


func focus_stake(selected: int) -> void:
	for key: Button in stake_keys:
		if int(key.get_meta("amount")) == selected and not key.disabled:
			key.grab_focus()
			return
	for key: Button in stake_keys:
		if not key.disabled:
			key.grab_focus()
			return
	if not serve_button.disabled:
		serve_button.grab_focus()


func focus_serve() -> void:
	if not serve_button.disabled:
		serve_button.grab_focus()
	else:
		focus_stake(-1)


func owns_focus(control: Control) -> bool:
	return control != null and control.get_parent() == self
