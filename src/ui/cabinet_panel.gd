class_name CabinetPanel
extends CanvasLayer
## M1 functional presentation. Draft art is not marked as final production art.

var cabinet: MiniGame
var _title: Label
var _frame: ColorRect
var _stake: Label
var _status: Label
var _detail: Label
var _controls: Label
var _status_key: String = "ROUND_READY"
var _result: RoundResult
var _art_root: Node2D
var _slot_symbols: Array[Sprite2D] = []
var _vault_tiles: Array[Sprite2D] = []
var _vault_cursor: Node2D
var _art_id: StringName = &""
var _motion_tween: Tween
var _entrance_tween: Tween
var _cursor_tween: Tween
var _blackjack_dealt: bool = false
var _vault_revealed: Dictionary = {}

const SLOT_BODY := preload("res://assets/drafts/slot_classic_body.png")
const SLOT_SYMBOLS: Array[Texture2D] = [
	preload("res://assets/drafts/sym_cherry.png"),
	preload("res://assets/drafts/sym_lemon.png"),
	preload("res://assets/drafts/sym_bell.png"),
	preload("res://assets/drafts/sym_bar.png"),
	preload("res://assets/drafts/sym_seven.png"),
	preload("res://assets/drafts/sym_diamond.png"),
]
const BLACKJACK_FELT := preload("res://assets/drafts/m2/felt_table.png")
const BLACKJACK_DEALER := preload("res://assets/drafts/m2/dealer.png")
const CARD_BACK := preload("res://assets/drafts/m2/card_back.png")
const VAULT_BACKDROP := preload("res://assets/drafts/vault_backdrop.png")
const VAULT_TILE_HIDDEN := preload("res://assets/drafts/m2/tile_unrevealed.png")
const VAULT_TILE_SAFE := preload("res://assets/drafts/m2/tile_safe_revealed.png")
const VAULT_TILE_MINE := preload("res://assets/drafts/m2/tile_mine_revealed.png")


func _ready() -> void:
	layer = 5
	var shade := ColorRect.new()
	shade.color = Color("0b0a12e8")
	shade.size = Vector2(960, 540)
	add_child(shade)
	_frame = ColorRect.new()
	_frame.color = Color("2d2a3e")
	_frame.position = Vector2(48, 76)
	_frame.size = Vector2(864, 396)
	add_child(_frame)
	_art_root = Node2D.new()
	_art_root.name = "CabinetArt"
	add_child(_art_root)
	var controls_backdrop := ColorRect.new()
	controls_backdrop.position = Vector2(64, 400)
	controls_backdrop.size = Vector2(832, 56)
	controls_backdrop.color = Color("1a1826")
	add_child(controls_backdrop)
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
	_ensure_art()
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
	else:
		_refresh_slot()


func show_result(result: RoundResult) -> void:
	_stop_motion()
	_blackjack_dealt = false
	_result = result
	_status_key = "ROUND_READY"
	refresh()
	_status.text = tr("ROUND_RESULT") % [result.stake, result.payout]
	AudioService.play(&"win" if result.payout > result.stake else &"loss")
	_frame.color = Color("ffd23f")
	create_tween().tween_property(_frame, "color", Color("2d2a3e"), 0.3)


func set_status(key: String) -> void:
	_status_key = key
	_result = null
	_detail.text = ""
	if key == "VAULT_REVEAL":
		_vault_revealed.clear()
	refresh()
	if key == "ROUND_SPINNING":
		AudioService.play(&"spin")
		_start_slot_motion()


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
	if cabinet.is_round_active and not _blackjack_dealt:
		_blackjack_dealt = true
		var card := _art_root.get_node_or_null("CardBackArt") as Sprite2D
		if card != null:
			card.position.y = 154
			card.modulate.a = 0.0
			var deal := create_tween().set_parallel(true)
			deal.tween_property(card, "position:y", 194.0, 0.24)
			deal.tween_property(card, "modulate:a", 1.0, 0.18)


func _refresh_vault() -> void:
	var math: MinefieldMath = cabinet.get("math")
	var cursor: int = (cabinet.get("snap_cursor") as SnapCursor).index
	for index: int in range(25):
		if index < _vault_tiles.size():
			_vault_tiles[index].texture = (
				VAULT_TILE_MINE
				if index in math.revealed and index in math.mines
				else VAULT_TILE_SAFE if index in math.revealed else VAULT_TILE_HIDDEN
			)
			if index in math.revealed and not _vault_revealed.has(index):
				_vault_revealed[index] = true
				AudioService.play(&"reveal")
				_vault_tiles[index].modulate.a = 0.0
				create_tween().tween_property(_vault_tiles[index], "modulate:a", 1.0, 0.18)
	if _vault_cursor != null:
		_vault_cursor.position = Vector2(583 + (cursor % 5) * 49, 138 + (cursor / 5) * 49)
	_detail.text = tr("VAULT_GRID") % [cabinet.get("mine_count"), math.multiplier(), ""]
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


func _ensure_art() -> void:
	var id: StringName = cabinet.context.definition.id
	if id == _art_id:
		return
	_art_id = id
	if id == &"slot_classic":
		_build_slot_art()
	elif id == &"blackjack":
		_build_blackjack_art()
	elif id == &"minefield_vault":
		_build_vault_art()
	_play_art_entrance()


func _build_slot_art() -> void:
	_art_root.add_child(_texture("SlotCabinetArt", SLOT_BODY, Vector2(600, 92), Vector2(288, 360)))
	for index: int in range(3):
		var symbol := _texture(
			"ReelSymbol%d" % index,
			SLOT_SYMBOLS[index],
			Vector2(676 + index * 47, 222),
			Vector2(48, 48)
		)
		_slot_symbols.append(symbol)
		_art_root.add_child(symbol)


func _build_blackjack_art() -> void:
	_art_root.add_child(
		_texture("BlackjackTableArt", BLACKJACK_FELT, Vector2(390, 250), Vector2(500, 146))
	)
	_art_root.add_child(
		_texture("DealerArt", BLACKJACK_DEALER, Vector2(676, 90), Vector2(128, 160))
	)
	_art_root.add_child(_texture("CardBackArt", CARD_BACK, Vector2(570, 194), Vector2(56, 80)))


func _build_vault_art() -> void:
	_art_root.add_child(
		_texture("VaultBackdropArt", VAULT_BACKDROP, Vector2(470, 96), Vector2(428, 241))
	)
	for index: int in range(25):
		var tile := _texture(
			"VaultTile%02d" % index,
			VAULT_TILE_HIDDEN,
			Vector2(587 + (index % 5) * 49, 142 + (index / 5) * 49),
			Vector2(42, 42)
		)
		_vault_tiles.append(tile)
		_art_root.add_child(tile)
	_vault_cursor = Node2D.new()
	_vault_cursor.name = "SnapCursorArt"
	for border: Rect2 in [
		Rect2(0, 0, 50, 4),
		Rect2(0, 46, 50, 4),
		Rect2(0, 0, 4, 50),
		Rect2(46, 0, 4, 50),
	]:
		var edge := ColorRect.new()
		edge.position = border.position
		edge.size = border.size
		edge.color = Color("00e5ff")
		_vault_cursor.add_child(edge)
	_art_root.add_child(_vault_cursor)
	_cursor_tween = create_tween().set_loops()
	_cursor_tween.tween_property(_vault_cursor, "modulate:a", 0.45, 0.35)
	_cursor_tween.tween_property(_vault_cursor, "modulate:a", 1.0, 0.35)


func _refresh_slot() -> void:
	var symbols: Array = [0, 1, 2]
	if _result != null:
		symbols = _result.detail.get("symbols", symbols)
	var names: PackedStringArray = []
	for index: int in range(mini(symbols.size(), _slot_symbols.size())):
		var symbol: int = symbols[index]
		_slot_symbols[index].texture = SLOT_SYMBOLS[symbol]
		names.append(tr("SYMBOL_" + str(symbol)))
	_detail.text = "   |   ".join(names)


func has_active_motion() -> bool:
	return (
		(_motion_tween != null and _motion_tween.is_running())
		or (_entrance_tween != null and _entrance_tween.is_running())
		or (_cursor_tween != null and _cursor_tween.is_running())
	)


func _play_art_entrance() -> void:
	_art_root.modulate.a = 0.0
	_art_root.position.y = 8.0
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(_art_root, "modulate:a", 1.0, 0.2)
	_entrance_tween.tween_property(_art_root, "position:y", 0.0, 0.2)


func _start_slot_motion() -> void:
	_stop_motion()
	if _slot_symbols.is_empty():
		return
	_motion_tween = create_tween().set_loops()
	_motion_tween.tween_property(_slot_symbols[0], "position:y", 230.0, 0.08)
	for index: int in range(1, _slot_symbols.size()):
		_motion_tween.parallel().tween_property(_slot_symbols[index], "position:y", 230.0, 0.08)
	_motion_tween.tween_property(_slot_symbols[0], "position:y", 214.0, 0.08)
	for index: int in range(1, _slot_symbols.size()):
		_motion_tween.parallel().tween_property(_slot_symbols[index], "position:y", 214.0, 0.08)


func _stop_motion() -> void:
	if _motion_tween != null:
		_motion_tween.kill()
		_motion_tween = null
	for symbol: Sprite2D in _slot_symbols:
		symbol.position.y = 222.0


func _texture(node_name: String, texture: Texture2D, at: Vector2, dimensions: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	sprite.scale = dimensions / Vector2(texture.get_width(), texture.get_height())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


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
