class_name BaccaratDeck
extends Control
## Velvet Baccarat control deck on the near rail: credits, the pearl chip rack,
## the wager and focused-spot readout, then CLEAR, REBET and DEAL. Every control
## is a real focusable button at least 44 px on both axes.

signal clear_pressed
signal rebet_pressed
signal deal_pressed
signal chip_chosen(amount: int)

const DECK_SIZE := Vector2(864, 72)
const CREDIT_RECT := Rect2(0, 0, 112, 72)
const RACK_RECT := Rect2(120, 0, 244, 72)
const INFO_RECT := Rect2(372, 0, 236, 72)
const CLEAR_RECT := Rect2(616, 8, 76, 56)
const REBET_RECT := Rect2(700, 8, 76, 56)
const DEAL_RECT := Rect2(784, 4, 80, 64)

var chip_buttons: Array[BaccaratChipButton] = []
var clear_button: Button
var rebet_button: Button
var deal_button: Button
var credit_value: AnimatedNumberLabel
var _credit_caption: Label
var _bet_line: Label
var _spot_line: Label
var _hint_line: Label


func _init() -> void:
	name = "BaccaratDeck"
	size = DECK_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build(chip_textures: Dictionary, chip_values: Array[int]) -> void:
	for rect: Rect2 in [CREDIT_RECT, RACK_RECT, INFO_RECT]:
		add_child(BaccaratPlate.new("DeckPlate", rect))
	_credit_caption = BaccaratStyle.label(self, Rect2(8, 6, 96, 18), 13, BaccaratStyle.PEARL_MUTED)
	_credit_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_value = AnimatedNumberLabel.new()
	credit_value.name = "BaccaratCredits"
	credit_value.position = Vector2(8, 26)
	credit_value.size = Vector2(96, 40)
	credit_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit_value.add_theme_font_override("font", Typography.DISPLAY_FONT)
	credit_value.add_theme_font_size_override("font_size", 28)
	credit_value.add_theme_color_override("font_color", BaccaratStyle.BRASS_BRIGHT)
	credit_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(credit_value)
	for index: int in range(chip_values.size()):
		var value := chip_values[index]
		var chip := BaccaratChipButton.new(value, chip_textures.get(value))
		chip.position = Vector2(RACK_RECT.position.x + 10 + index * 58, 10)
		chip.pressed.connect(func() -> void: chip_chosen.emit(value))
		add_child(chip)
		chip_buttons.append(chip)
	var info := INFO_RECT.position
	_bet_line = BaccaratStyle.label(self, Rect2(info + Vector2(10, 4), Vector2(216, 22)), 17)
	_bet_line.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_spot_line = BaccaratStyle.label(
		self, Rect2(info + Vector2(10, 27), Vector2(216, 20)), 14, BaccaratStyle.BRASS_BRIGHT
	)
	_hint_line = BaccaratStyle.label(
		self, Rect2(info + Vector2(10, 48), Vector2(216, 18)), 12, BaccaratStyle.PEARL_MUTED
	)
	clear_button = _key("BaccaratClear", CLEAR_RECT, false, clear_pressed)
	rebet_button = _key("BaccaratRebet", REBET_RECT, false, rebet_pressed)
	deal_button = _key("BaccaratDeal", DEAL_RECT, true, deal_pressed)
	deal_button.add_theme_font_size_override("font_size", 22)


func _key(node_name: String, rect: Rect2, primary: bool, relay: Signal) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	BaccaratStyle.style_button(button, primary)
	button.pressed.connect(func() -> void: relay.emit())
	add_child(button)
	ButtonFeedback.attach(button)
	return button


## Every focusable control in left-to-right order.
func focus_row() -> Array[Control]:
	var row: Array[Control] = []
	for chip: BaccaratChipButton in chip_buttons:
		row.append(chip)
	row.append_array([clear_button, rebet_button, deal_button])
	return row


## `state`: balance, selected, total, cap, betting_open, can_rebet, test_bank.
func refresh_state(state: Dictionary) -> void:
	if credit_value == null:
		return
	_credit_caption.text = tr("HUD_TEST_BANK") if state.test_bank else tr("HUD_CREDITS")
	if state.test_bank:
		credit_value.set_infinity()
	else:
		credit_value.set_number(maxi(0, int(state.balance) - int(state.total)))
	var open: bool = state.betting_open
	for chip: BaccaratChipButton in chip_buttons:
		chip.set_selected(chip.amount == int(state.selected))
		chip.disabled = not open or chip.amount > int(state.cap)
		chip.queue_redraw()
	clear_button.text = tr("BACCARAT_CLEAR")
	rebet_button.text = tr("BACCARAT_REBET")
	deal_button.text = tr("BACCARAT_DEAL")
	clear_button.disabled = not open or int(state.total) <= 0
	rebet_button.disabled = not open or not state.can_rebet
	deal_button.disabled = not open or int(state.total) <= 0
	_bet_line.text = tr("BACCARAT_BET_TOTAL") % [int(state.total), int(state.cap)]
	_hint_line.text = (
		tr("BACCARAT_DECK_HINT")
		% [
			InputRouter.glyph("interact"),
			InputRouter.glyph("secondary"),
			InputRouter.glyph("tertiary"),
		]
	)


func set_spot_text(text: String) -> void:
	if _spot_line != null:
		_spot_line.text = text


func focus_selected_chip(selected: int) -> void:
	for chip: BaccaratChipButton in chip_buttons:
		if chip.amount == selected and not chip.disabled:
			chip.grab_focus()
			return
	if not deal_button.disabled:
		deal_button.grab_focus()
	elif not chip_buttons.is_empty():
		chip_buttons[0].grab_focus()


func owns_focus(control: Control) -> bool:
	return control != null and control.get_parent() == self
