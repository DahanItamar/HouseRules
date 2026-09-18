class_name CabinetPanel
extends CanvasLayer
## M1 functional presentation. Draft art is not marked as final production art.

var cabinet: MiniGame
var _title: Label
var _stake: Label
var _status: Label
var _detail: Label
var _controls: Label
var _status_key: String = "ROUND_READY"
var _result: RoundResult


func _ready() -> void:
	layer = 5
	var shade := ColorRect.new()
	shade.color = Color("0b0a12e8")
	shade.size = Vector2(960, 540)
	add_child(shade)
	var frame := ColorRect.new()
	frame.color = Color("2d2a3e")
	frame.position = Vector2(48, 76)
	frame.size = Vector2(864, 396)
	add_child(frame)
	_title = _label(Vector2(80, 90), 24)
	_stake = _label(Vector2(80, 138), Typography.PROMINENT)
	_status = _label(Vector2(80, 184), 18)
	_detail = _label(Vector2(80, 230), Typography.PROMINENT)
	_controls = _label(Vector2(80, 412), Typography.CRITICAL)
	InputRouter.active_device_changed.connect(func(_device: int) -> void: refresh())
	refresh()


func refresh() -> void:
	if _title == null or cabinet.context == null:
		return
	_title.text = tr(cabinet.context.definition.name_key)
	_stake.text = tr("CABINET_STAKE") % cabinet.selected_stake
	_status.text = tr(_status_key)
	_controls.text = (
		tr("CABINET_CONTROLS")
		% [
			InputRouter.glyph("interact"),
			InputRouter.glyph("move_horizontal"),
			InputRouter.glyph("back")
		]
	)
	var id: StringName = cabinet.context.definition.id
	if id == &"blackjack":
		_refresh_blackjack()
	elif id == &"minefield_vault":
		_refresh_vault()
	elif _result != null:
		var symbols: Array = _result.detail.get("symbols", [])
		var names: PackedStringArray = []
		for symbol: int in symbols:
			names.append(tr("SYMBOL_" + str(symbol)))
		_detail.text = "   |   ".join(names)


func show_result(result: RoundResult) -> void:
	_result = result
	_status_key = "ROUND_READY"
	refresh()
	_status.text = tr("ROUND_RESULT") % [result.stake, result.payout]


func set_status(key: String) -> void:
	_status_key = key
	_result = null
	_detail.text = ""
	refresh()


func _refresh_blackjack() -> void:
	var math: BlackjackMath = cabinet.get("math")
	var dealer_text: String = _card_names(math.dealer)
	if cabinet.is_round_active and not math.dealer.is_empty():
		dealer_text = _card_names([math.dealer[0]]) + "  ?"
	_detail.text = tr("BLACKJACK_HANDS") % [_card_names(math.player), dealer_text]
	_controls.text = (
		tr("BLACKJACK_CONTROLS")
		% [
			InputRouter.glyph("interact"),
			InputRouter.glyph("secondary"),
			InputRouter.glyph("tertiary"),
			InputRouter.glyph("move_horizontal"),
			InputRouter.glyph("back")
		]
	)


func _refresh_vault() -> void:
	var math: MinefieldMath = cabinet.get("math")
	var cursor: int = (cabinet.get("snap_cursor") as SnapCursor).index
	var grid: String = ""
	for index: int in range(25):
		var tile: String = "#"
		if index in math.revealed:
			tile = "X" if index in math.mines else "+"
		grid += ("[%s] " if cursor == index else " %s  ") % tile
		if index % 5 == 4:
			grid += "\n"
	_detail.text = tr("VAULT_GRID") % [cabinet.get("mine_count"), math.multiplier(), grid]
	_detail.add_theme_font_size_override("font_size", Typography.CRITICAL)
	_controls.text = (
		tr("VAULT_CONTROLS")
		% [
			InputRouter.glyph("interact"),
			InputRouter.glyph("secondary"),
			InputRouter.glyph("move_horizontal"),
			InputRouter.glyph("move_vertical"),
			InputRouter.glyph("back")
		]
	)


func _label(at: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e8e6f0"))
	add_child(label)
	return label


func _card_names(cards: Array[int]) -> String:
	var names: PackedStringArray = []
	for card: int in cards:
		names.append(tr("CARD_" + str(card)) if card == 1 or card > 10 else str(card))
	return "  ".join(names)
