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
var _slot_symbols: Array[Control] = []
var _slot_reels: Array[Control] = []
var _slot_reel_cells: Array = []
var _slot_offsets: Array[float] = [0.0, 0.0, 0.0]
var _slot_spin_targets: Array[int] = [0, 1, 2]
var _slot_stop_times: Array[float] = [0.78, 0.98, 1.18]
var _slot_stopped: Array[bool] = [true, true, true]
var _slot_spin_elapsed: float = 0.0
var _slot_spinning: bool = false
var _slot_finish_callback: Callable
var _slot_lever: Node2D
var _vault_tiles: Array[VaultTile] = []
var _vault_cursor: Node2D
var _art_id: StringName = &""
var _motion_tween: Tween
var _entrance_tween: Tween
var _cursor_tween: Tween
var _blackjack_dealt: bool = false
var _blackjack_cards: Array[PlayingCard] = []
var _vault_revealed: Dictionary = {}

const SLOT_BODY := preload("res://assets/production/slot/slot_classic_body.png")
const SLOT_SYMBOL_COUNT: int = 6
const BLACKJACK_FELT := preload("res://assets/drafts/m2/felt_table.png")
const BLACKJACK_DEALER := preload("res://assets/drafts/m2/dealer.png")
const CARD_BACK := preload("res://assets/drafts/m2/card_back.png")
const VAULT_BACKDROP := preload("res://assets/production/vault/vault_backdrop.png")
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
	_frame.color = Color("17161af2")
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
	_status.size = Vector2(250, 54)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail = _label(Vector2(80, 230), Typography.PROMINENT)
	_detail.size = Vector2(250, 130)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_status.add_theme_color_override(
		"font_color", Color("3fc276") if result.payout > result.stake else Color("d55353")
	)


func _process(delta: float) -> void:
	if not _slot_spinning:
		return
	_slot_spin_elapsed += delta
	for reel_index: int in range(_slot_reels.size()):
		if _slot_stopped[reel_index]:
			continue
		_slot_offsets[reel_index] += delta * (380.0 + reel_index * 55.0)
		_update_spinning_reel(reel_index)
		if _slot_spin_elapsed >= _slot_stop_times[reel_index]:
			_stop_reel(reel_index)
	if _slot_stopped.all(func(stopped: bool) -> bool: return stopped):
		_slot_spinning = false
		if _slot_finish_callback.is_valid():
			var callback := _slot_finish_callback
			_slot_finish_callback = Callable()
			callback.call()
func set_status(key: String) -> void:
	_status_key = key
	_result = null
	_detail.text = ""
	_status.add_theme_color_override("font_color", Color("b8ad9c"))
	if key == "VAULT_REVEAL":
		_vault_revealed.clear()
	refresh()
	if key == "ROUND_SPINNING":
		AudioService.play(&"spin")
		_start_slot_motion()


func begin_slot_spin(symbols: Array, on_finished: Callable) -> void:
	_slot_spin_targets.clear()
	for index: int in range(3):
		_slot_spin_targets.append(int(symbols[index]))
	_slot_finish_callback = on_finished
	set_status("ROUND_SPINNING")


func _refresh_blackjack() -> void:
	var math: BlackjackMath = cabinet.get("math")
	_detail.text = ""
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
	_render_blackjack_hand(math.player, math.dealer, cabinet.is_round_active)


func _refresh_vault() -> void:
	var math: MinefieldMath = cabinet.get("math")
	var cursor: int = (cabinet.get("snap_cursor") as SnapCursor).index
	for index: int in range(25):
		if index < _vault_tiles.size():
			var next_face := VaultTile.Face.HIDDEN
			if index in math.revealed:
				next_face = VaultTile.Face.MINE if index in math.mines else VaultTile.Face.SAFE
			if index in math.revealed and not _vault_revealed.has(index):
				_vault_revealed[index] = true
				AudioService.play(&"reveal")
				_vault_tiles[index].reveal(next_face)
			elif not _vault_tiles[index].is_flipping:
				_vault_tiles[index].set_face_immediate(next_face)
	if _vault_cursor != null:
		var cursor_target := Vector2(516 + (cursor % 5) * 52, 124 + (cursor / 5) * 52)
		if _cursor_tween != null:
			_cursor_tween.kill()
		_cursor_tween = create_tween()
		_cursor_tween.tween_property(_vault_cursor, "position", cursor_target, 0.09)
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
	var body := _texture("SlotCabinetArt", SLOT_BODY, Vector2(300, 34), Vector2(350, 450))
	body.material = _chroma_material(Color("2d2638"), 0.14)
	_art_root.add_child(body)
	var reel_back := ColorRect.new()
	reel_back.position = Vector2(374, 214)
	reel_back.size = Vector2(205, 158)
	reel_back.color = Color("f1e8d8")
	_art_root.add_child(reel_back)
	for index: int in range(3):
		var reel := Control.new()
		reel.name = "ReelColumn%d" % index
		reel.position = Vector2(381 + index * 65, 219)
		reel.size = Vector2(58, 148)
		reel.clip_contents = true
		var cells: Array[SlotSymbol] = []
		for cell_index: int in range(5):
			var cell := SlotSymbol.new()
			cell.name = "Reel%dCell%d" % [index, cell_index]
			cell.position = Vector2(3, (cell_index - 1) * 48)
			cell.size = Vector2(52, 44)
			cell.symbol_index = (cell_index + index) % SLOT_SYMBOL_COUNT
			reel.add_child(cell)
			cells.append(cell)
		_slot_reels.append(reel)
		_slot_reel_cells.append(cells)
		_slot_symbols.append(cells[2])
		_art_root.add_child(reel)
		_stop_reel(index)
	_slot_lever = Node2D.new()
	_slot_lever.name = "LeverArt"
	_slot_lever.position = Vector2(651, 218)
	var arm := ColorRect.new()
	arm.position = Vector2(-3, 0)
	arm.size = Vector2(7, 92)
	arm.color = Color("b8ad9c")
	_slot_lever.add_child(arm)
	var knob := ColorRect.new()
	knob.position = Vector2(-12, -10)
	knob.size = Vector2(24, 24)
	knob.color = Color("a53243")
	_slot_lever.add_child(knob)
	_art_root.add_child(_slot_lever)


func _build_blackjack_art() -> void:
	var felt := ColorRect.new()
	felt.name = "BlackjackTableArt"
	felt.position = Vector2(342, 126)
	felt.size = Vector2(542, 270)
	felt.color = Color("073b31")
	_art_root.add_child(felt)
	var rail := ColorRect.new()
	rail.position = Vector2(342, 126)
	rail.size = Vector2(542, 8)
	rail.color = Color("c8a34b")
	_art_root.add_child(rail)
	for label_data: Array in [
		["DealerHandLabel", "BLACKJACK_DEALER", Vector2(360, 154)],
		["PlayerHandLabel", "BLACKJACK_PLAYER", Vector2(360, 282)],
	]:
		var hand_label := Label.new()
		hand_label.name = label_data[0]
		hand_label.position = label_data[2]
		hand_label.text = tr(label_data[1])
		hand_label.add_theme_font_size_override("font_size", Typography.SUPPORTING)
		hand_label.add_theme_color_override("font_color", Color("c8a34b"))
		_art_root.add_child(hand_label)
	var shoe := ColorRect.new()
	shoe.name = "CardShoeArt"
	shoe.position = Vector2(796, 154)
	shoe.size = Vector2(54, 82)
	shoe.color = Color("252126")
	_art_root.add_child(shoe)
	var shoe_trim := ColorRect.new()
	shoe_trim.position = Vector2(801, 160)
	shoe_trim.size = Vector2(44, 5)
	shoe_trim.color = Color("c8a34b")
	_art_root.add_child(shoe_trim)


func _render_blackjack_hand(player_cards: Array[int], dealer_cards: Array[int], hide_hole: bool) -> void:
	for card: PlayingCard in _blackjack_cards:
		if is_instance_valid(card):
			card.queue_free()
	_blackjack_cards.clear()
	var deal_index: int = 0
	for index: int in range(dealer_cards.size()):
		_add_playing_card(dealer_cards[index], index, true, hide_hole and index == 1, deal_index)
		deal_index += 1
	for index: int in range(player_cards.size()):
		_add_playing_card(player_cards[index], index, false, false, deal_index)
		deal_index += 1


func _add_playing_card(
	rank: int, hand_index: int, dealer_hand: bool, hidden: bool, deal_index: int
) -> void:
	var card := PlayingCard.new()
	card.name = ("DealerCard" if dealer_hand else "PlayerCard") + str(hand_index)
	card.size = Vector2(68, 96)
	card.configure(rank, rank + hand_index + (0 if dealer_hand else 2), hidden)
	var destination := Vector2(408 + hand_index * 58, 150 if dealer_hand else 278)
	card.position = Vector2(800, 164)
	card.rotation = 0.08
	card.modulate.a = 0.0
	_art_root.add_child(card)
	_blackjack_cards.append(card)
	var deal := create_tween().set_parallel(true)
	deal.tween_property(card, "position", destination, 0.26).set_delay(deal_index * 0.08)
	deal.tween_property(card, "rotation", (hand_index - 1) * 0.025, 0.26).set_delay(
		deal_index * 0.08
	)
	deal.tween_property(card, "modulate:a", 1.0, 0.12).set_delay(deal_index * 0.08)
	if dealer_hand and not hidden and hand_index == 1:
		card.scale.x = 0.05
		create_tween().tween_property(card, "scale:x", 1.0, 0.14).set_delay(0.18)


func _build_vault_art() -> void:
	_art_root.add_child(
		_texture("VaultBackdropArt", VAULT_BACKDROP, Vector2(382, 94), Vector2(506, 290))
	)
	for index: int in range(25):
		var tile := VaultTile.new()
		tile.name = "VaultTile%02d" % index
		tile.position = Vector2(520 + (index % 5) * 52, 128 + (index / 5) * 52)
		tile.size = Vector2(44, 44)
		_vault_tiles.append(tile)
		_art_root.add_child(tile)
	_vault_cursor = Node2D.new()
	_vault_cursor.name = "SnapCursorArt"
	for border: Rect2 in [
		Rect2(0, 0, 52, 3),
		Rect2(0, 49, 52, 3),
		Rect2(0, 0, 3, 52),
		Rect2(49, 0, 3, 52),
	]:
		var edge := ColorRect.new()
		edge.position = border.position
		edge.size = border.size
		edge.color = Color("00e5ff")
		_vault_cursor.add_child(edge)
	_art_root.add_child(_vault_cursor)
	_vault_cursor.position = Vector2(516, 124)


func _refresh_slot() -> void:
	var symbols: Array = [0, 1, 2]
	if _result != null:
		symbols = _result.detail.get("symbols", symbols)
	var names: PackedStringArray = []
	for index: int in range(mini(symbols.size(), 3)):
		var symbol: int = symbols[index]
		if not _slot_spinning and index < _slot_reels.size():
			_slot_spin_targets[index] = symbol
			_stop_reel(index)
		names.append(tr("SYMBOL_" + str(symbol)))
	_detail.text = "  •  ".join(names)


func has_active_motion() -> bool:
	return (
		_slot_spinning
		or (_motion_tween != null and _motion_tween.is_running())
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
	if _slot_reels.is_empty():
		return
	_slot_spin_elapsed = 0.0
	_slot_offsets = [0.0, 0.0, 0.0]
	_slot_stopped = [false, false, false]
	_slot_spinning = true
	if _slot_lever != null:
		_slot_lever.rotation = 0.0
		_motion_tween = create_tween()
		_motion_tween.tween_property(_slot_lever, "rotation", 0.42, 0.16)
		_motion_tween.tween_property(_slot_lever, "rotation", 0.0, 0.18)


func _stop_motion() -> void:
	_slot_spinning = false
	if _motion_tween != null:
		_motion_tween.kill()
		_motion_tween = null


func _update_spinning_reel(reel_index: int) -> void:
	var cells: Array = _slot_reel_cells[reel_index]
	var step: int = int(_slot_offsets[reel_index] / 48.0)
	var remainder: float = fmod(_slot_offsets[reel_index], 48.0)
	for cell_index: int in range(cells.size()):
		var cell: SlotSymbol = cells[cell_index]
		cell.position.y = (cell_index - 1) * 48.0 + remainder
		if cell.position.y >= 192.0:
			cell.position.y -= 240.0
		cell.symbol_index = (cell_index - step + reel_index) % SLOT_SYMBOL_COUNT


func _stop_reel(reel_index: int) -> void:
	if reel_index >= _slot_reel_cells.size():
		return
	_slot_stopped[reel_index] = true
	var target: int = _slot_spin_targets[reel_index]
	var cells: Array = _slot_reel_cells[reel_index]
	for cell_index: int in range(cells.size()):
		var cell: SlotSymbol = cells[cell_index]
		cell.position.y = (cell_index - 1) * 48.0
		cell.symbol_index = posmod(target + cell_index - 2, SLOT_SYMBOL_COUNT)
	var reel: Control = _slot_reels[reel_index]
	reel.position.y = 214.0
	create_tween().tween_property(reel, "position:y", 219.0, 0.09).set_trans(Tween.TRANS_BACK)


func _chroma_material(key_color: Color, threshold: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = (
		"shader_type canvas_item;\n"
		+ "uniform vec4 key_color : source_color;\n"
		+ "uniform float threshold = 0.12;\n"
		+ "void fragment() {\n"
		+ "  vec4 sample_color = texture(TEXTURE, UV);\n"
		+ "  float distance_from_key = distance(sample_color.rgb, key_color.rgb);\n"
		+ "  sample_color.a *= smoothstep(threshold * 0.55, threshold, distance_from_key);\n"
		+ "  COLOR = sample_color;\n"
		+ "}\n"
	)
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("key_color", key_color)
	material.set_shader_parameter("threshold", threshold)
	return material


func _texture(node_name: String, texture: Texture2D, at: Vector2, dimensions: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.centered = false
	sprite.position = at
	sprite.scale = dimensions / Vector2(texture.get_width(), texture.get_height())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
