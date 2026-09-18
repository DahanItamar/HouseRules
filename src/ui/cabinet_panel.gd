class_name CabinetPanel
extends CanvasLayer
## M1 functional presentation. Draft art is not marked as final production art.

var cabinet: MiniGame
var _title: Label
var _frame: ColorRect
var _shade: ColorRect
var _controls_backdrop: ColorRect
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
var _slot_total_offsets: Array[float] = [0.0, 0.0, 0.0]
var _slot_start_symbols: Array[int] = [2, 3, 4]
var _slot_spin_targets: Array[int] = [2, 3, 4]
var _slot_stop_times: Array[float] = [0.78, 0.98, 1.18]
var _slot_stopped: Array[bool] = [true, true, true]
var _slot_spin_elapsed: float = 0.0
var _slot_spinning: bool = false
var _slot_finish_callback: Callable
var _slot_lever: Node2D
var _slot_spin_label: Label
var _stake_selector: StakeSelector
var _help_button: Button
var _help_overlay: Control
var _help_title: Label
var _help_rules: Label
var _help_controls: Label
var help_open: bool = false
var _vault_tiles: Array[VaultTile] = []
var _vault_cursor: Node2D
var _art_id: StringName = &""
var _motion_tween: Tween
var _entrance_tween: Tween
var _cursor_tween: Tween
var _blackjack_dealt: bool = false
var _blackjack_input_locked_until: int = 0
var _blackjack_cards: Array[PlayingCard] = []
var _vault_revealed: Dictionary = {}

const SLOT_BODY := preload("res://assets/production/slot/symbols/slot_fullscreen_bezel.png")
const SLOT_SYMBOL_COUNT: int = 6
const SLOT_REEL_TOP: float = 151.0
const SLOT_REEL_BOUNCE_Y: float = 144.0
const SLOT_CELL_HEIGHT: float = 78.0
const SLOT_STRIP_HEIGHT: float = SLOT_CELL_HEIGHT * 5.0
const VAULT_GRID_ORIGIN := Vector2(354, 134)
const VAULT_GRID_PITCH: float = 56.0
const BLACKJACK_FELT := preload("res://assets/drafts/m2/felt_table.png")
const BLACKJACK_DEALER := preload("res://assets/drafts/m2/dealer.png")
const CARD_BACK := preload("res://assets/drafts/m2/card_back.png")
const VAULT_BACKDROP := preload("res://assets/production/vault/vault_backdrop.png")
const VAULT_TILE_HIDDEN := preload("res://assets/drafts/m2/tile_unrevealed.png")
const VAULT_TILE_SAFE := preload("res://assets/drafts/m2/tile_safe_revealed.png")
const VAULT_TILE_MINE := preload("res://assets/drafts/m2/tile_mine_revealed.png")


func _ready() -> void:
	layer = 5
	_shade = ColorRect.new()
	_shade.color = Color("0b0a12e8")
	_shade.size = Vector2(960, 540)
	add_child(_shade)
	_frame = ColorRect.new()
	_frame.color = Color("17161af2")
	_frame.position = Vector2(48, 76)
	_frame.size = Vector2(864, 396)
	add_child(_frame)
	_art_root = Node2D.new()
	_art_root.name = "CabinetArt"
	add_child(_art_root)
	_controls_backdrop = ColorRect.new()
	_controls_backdrop.position = Vector2(64, 400)
	_controls_backdrop.size = Vector2(832, 56)
	_controls_backdrop.color = Color("1a1826")
	add_child(_controls_backdrop)
	_title = _label(Vector2(80, 90), 24)
	_stake = _label(Vector2(80, 138), Typography.PROMINENT)
	_status = _label(Vector2(80, 184), 18)
	_status.size = Vector2(250, 54)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail = _label(Vector2(80, 230), Typography.PROMINENT)
	_detail.size = Vector2(250, 130)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_controls = _label(Vector2(80, 412), Typography.CRITICAL)
	_controls.hide()
	_controls_backdrop.hide()
	_stake_selector = StakeSelector.new()
	_stake_selector.name = "StakeSelector"
	_stake_selector.cabinet = cabinet
	add_child(_stake_selector)
	_build_help_ui()
	InputRouter.active_device_changed.connect(func(_device: int) -> void: refresh())
	refresh()


func refresh() -> void:
	if _title == null or cabinet.context == null:
		return
	_ensure_art()
	_title.text = tr(cabinet.context.definition.name_key)
	_stake.text = tr("CABINET_STAKE") % cabinet.selected_stake
	_stake.hide()
	_stake_selector.queue_redraw()
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
	_refresh_help()


func show_result(result: RoundResult) -> void:
	_stop_motion()
	_result = result
	_status_key = "ROUND_READY"
	refresh()
	_status.text = tr("ROUND_RESULT") % [result.stake, result.payout]
	AudioService.play(&"win" if result.payout > result.stake else &"loss")
	_status.add_theme_color_override(
		"font_color", Color("3fc276") if result.payout > result.stake else Color("d55353")
	)


func _process(delta: float) -> void:
	if help_open or not _slot_spinning:
		return
	_slot_spin_elapsed += delta
	for reel_index: int in range(_slot_reels.size()):
		if _slot_stopped[reel_index]:
			continue
		var duration: float = _slot_stop_times[reel_index]
		var progress: float = clampf(_slot_spin_elapsed / duration, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		_slot_offsets[reel_index] = _slot_total_offsets[reel_index] * eased
		_update_spinning_reel(reel_index)
		if progress >= 1.0:
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
		var center: SlotSymbol = _slot_reel_cells[index][2]
		_slot_start_symbols[index] = center.symbol_index
		var target_steps: int = 18 + index * 6 + posmod(
			_slot_start_symbols[index] - _slot_spin_targets[index], SLOT_SYMBOL_COUNT
		)
		_slot_total_offsets[index] = target_steps * SLOT_CELL_HEIGHT
	_slot_finish_callback = on_finished
	set_status("ROUND_SPINNING")


func toggle_help() -> void:
	set_help_open(not help_open)


func set_help_open(open: bool) -> void:
	help_open = open
	if _help_overlay != null:
		_help_overlay.visible = open
	if open and _help_overlay != null:
		var close_button := _help_overlay.find_child("HelpClose", true, false) as Button
		if close_button != null:
			close_button.grab_focus()


func _build_help_ui() -> void:
	_help_button = Button.new()
	_help_button.name = "HowToPlayButton"
	_help_button.position = Vector2(790, 18)
	_help_button.size = Vector2(150, 38)
	_help_button.text = tr("HELP_BUTTON")
	_help_button.add_theme_font_size_override("font_size", 14)
	_help_button.add_theme_stylebox_override("normal", _panel_style(Color("17161af2"), Color("c8a34b"), 6))
	_help_button.add_theme_stylebox_override("focus", _panel_style(Color("252126"), Color("48c5d5"), 6, 2))
	_help_button.pressed.connect(toggle_help)
	add_child(_help_button)

	_help_overlay = Control.new()
	_help_overlay.name = "HelpOverlay"
	_help_overlay.size = Vector2(960, 540)
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.visible = false
	add_child(_help_overlay)
	var shade := ColorRect.new()
	shade.size = Vector2(960, 540)
	shade.color = Color("080708d9")
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.add_child(shade)
	var modal := Panel.new()
	modal.position = Vector2(170, 64)
	modal.size = Vector2(620, 412)
	modal.add_theme_stylebox_override("panel", _panel_style(Color("17161af7"), Color("c8a34b"), 8))
	_help_overlay.add_child(modal)
	_help_title = _help_label(modal, Vector2(32, 20), Vector2(470, 42), 28, Color("f1e8d8"))
	var rules_heading := _help_label(modal, Vector2(32, 76), Vector2(326, 24), 14, Color("c8a34b"))
	rules_heading.text = tr("HELP_RULES")
	_help_rules = _help_label(modal, Vector2(32, 108), Vector2(326, 238), 16, Color("f1e8d8"))
	_help_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var controls_heading := _help_label(modal, Vector2(388, 76), Vector2(194, 24), 14, Color("c8a34b"))
	controls_heading.text = tr("HELP_CONTROLS")
	_help_controls = _help_label(modal, Vector2(388, 108), Vector2(194, 238), 15, Color("f1e8d8"))
	_help_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := _help_label(
		modal, Vector2(32, 366), Vector2(420, 24), Typography.BODY_MIN, Color("b8ad9c")
	)
	footer.text = tr("HELP_CLOSE_HINT") % InputRouter.glyph("help")
	var close := Button.new()
	close.name = "HelpClose"
	close.position = Vector2(548, 16)
	close.size = Vector2(44, 44)
	close.text = "×"
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_stylebox_override("normal", _panel_style(Color("252126"), Color("6e5225"), 6))
	close.add_theme_stylebox_override("focus", _panel_style(Color("252126"), Color("48c5d5"), 6, 2))
	close.pressed.connect(func() -> void: set_help_open(false))
	modal.add_child(close)


func _refresh_help() -> void:
	if _help_title == null:
		return
	var id := String(cabinet.context.definition.id).to_upper()
	_help_button.text = tr("HELP_BUTTON")
	_help_title.text = tr("HELP_TITLE") % tr(cabinet.context.definition.name_key)
	_help_rules.text = tr("HELP_" + id + "_RULES")
	if cabinet.context.definition.id == &"slot_classic":
		_help_controls.text = (
			tr("HELP_SLOT_CLASSIC_CONTROLS")
			% [
				InputRouter.glyph("interact"),
				InputRouter.glyph("move_horizontal"),
				InputRouter.glyph("back"),
			]
		)
	elif cabinet.context.definition.id == &"blackjack":
		_help_controls.text = (
			tr("HELP_BLACKJACK_CONTROLS")
			% [
				InputRouter.glyph("interact"),
				InputRouter.glyph("secondary"),
				InputRouter.glyph("tertiary"),
				InputRouter.glyph("move_horizontal"),
				InputRouter.glyph("back"),
			]
		)
	else:
		_help_controls.text = (
			tr("HELP_MINEFIELD_VAULT_CONTROLS")
			% [
				InputRouter.glyph("interact"),
				InputRouter.glyph("secondary"),
				InputRouter.glyph("move_horizontal"),
				InputRouter.glyph("move_vertical"),
				InputRouter.glyph("back"),
			]
		)


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
		var cursor_target := (
			VAULT_GRID_ORIGIN
			- Vector2(4, 4)
			+ Vector2((cursor % 5) * VAULT_GRID_PITCH, (cursor / 5) * VAULT_GRID_PITCH)
		)
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
		_apply_slot_fullscreen_layout()
	elif id == &"blackjack":
		_build_blackjack_art()
		_apply_blackjack_fullscreen_layout()
	elif id == &"minefield_vault":
		_build_vault_art()
		_apply_vault_fullscreen_layout()
	_play_art_entrance()


func _build_slot_art() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "SlotBackdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(960, 540)
	backdrop.color = Color("13090b")
	_art_root.add_child(backdrop)
	var reel_shadow := ColorRect.new()
	reel_shadow.position = Vector2(158, 145)
	reel_shadow.size = Vector2(644, 252)
	reel_shadow.color = Color("080707")
	_art_root.add_child(reel_shadow)
	var reel_back := ColorRect.new()
	reel_back.position = Vector2(166, SLOT_REEL_TOP)
	reel_back.size = Vector2(628, SLOT_CELL_HEIGHT * 3.0)
	reel_back.color = Color("f3ead8")
	_art_root.add_child(reel_back)
	for index: int in range(3):
		var reel := Control.new()
		reel.name = "ReelColumn%d" % index
		reel.position = Vector2(171 + index * 207, SLOT_REEL_TOP)
		reel.size = Vector2(198, SLOT_CELL_HEIGHT * 3.0)
		reel.clip_contents = true
		var cells: Array[SlotSymbol] = []
		for cell_index: int in range(5):
			var cell := SlotSymbol.new()
			cell.name = "Reel%dCell%d" % [index, cell_index]
			cell.position = Vector2(4, (cell_index - 1) * SLOT_CELL_HEIGHT)
			cell.size = Vector2(190, SLOT_CELL_HEIGHT - 4.0)
			cell.symbol_index = (cell_index + index) % SLOT_SYMBOL_COUNT
			reel.add_child(cell)
			cells.append(cell)
		_slot_reels.append(reel)
		_slot_reel_cells.append(cells)
		_slot_symbols.append(cells[2])
		_art_root.add_child(reel)
		_stop_reel(index)
	for separator_x: float in [372.0, 579.0]:
		var separator := ColorRect.new()
		separator.position = Vector2(separator_x, SLOT_REEL_TOP)
		separator.size = Vector2(5, SLOT_CELL_HEIGHT * 3.0)
		separator.color = Color("8a682f")
		_art_root.add_child(separator)
	var body := _texture("SlotCabinetArt", SLOT_BODY, Vector2(20, 5), Vector2(920, 528))
	_art_root.add_child(body)
	var payline := ColorRect.new()
	payline.name = "WinningPayline"
	payline.position = Vector2(151, SLOT_REEL_TOP + SLOT_CELL_HEIGHT * 1.5 - 2.0)
	payline.size = Vector2(658, 4)
	payline.color = Color("d9b44a")
	_art_root.add_child(payline)


func _apply_slot_fullscreen_layout() -> void:
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("13090b")
	_controls_backdrop.position = Vector2(236, 496)
	_controls_backdrop.size = Vector2(488, 34)
	_controls_backdrop.color = Color("090708cc")
	_title.position = Vector2(248, 43)
	_title.size = Vector2(464, 54)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color("f5e6bd"))
	_stake.position = Vector2(83, 443)
	_stake.size = Vector2(280, 42)
	_stake.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stake.add_theme_font_size_override("font_size", 24)
	_status.position = Vector2(330, 99)
	_status.size = Vector2(300, 32)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 16)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail.position = Vector2(620, 439)
	_detail.size = Vector2(260, 46)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_controls.position = Vector2(248, 502)
	_controls.size = Vector2(464, 24)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_font_size_override("font_size", 16)
	_slot_spin_label = _slot_deck_label(Vector2(410, 433), Vector2(140, 48), 23)
	_slot_spin_label.name = "SlotSpinLabel"
	_slot_spin_label.text = tr("SLOT_SPIN")
	_stake_selector.position = Vector2(76, 433)
	_stake_selector.size = Vector2(306, 58)


func _slot_deck_label(at: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f5e6bd"))
	add_child(label)
	return label


func _build_blackjack_art() -> void:
	var room := ColorRect.new()
	room.position = Vector2.ZERO
	room.size = Vector2(960, 540)
	room.color = Color("160b0b")
	_art_root.add_child(room)
	var wood_header := ColorRect.new()
	wood_header.position = Vector2(0, 0)
	wood_header.size = Vector2(960, 92)
	wood_header.color = Color("351914")
	_art_root.add_child(wood_header)
	var felt := ColorRect.new()
	felt.name = "BlackjackTableArt"
	felt.position = Vector2(64, 94)
	felt.size = Vector2(832, 372)
	felt.color = Color("06483a")
	_art_root.add_child(felt)
	var rail := ColorRect.new()
	rail.position = Vector2(64, 94)
	rail.size = Vector2(832, 9)
	rail.color = Color("c8a34b")
	_art_root.add_child(rail)
	var lower_rail := ColorRect.new()
	lower_rail.position = Vector2(64, 457)
	lower_rail.size = Vector2(832, 9)
	lower_rail.color = Color("c8a34b")
	_art_root.add_child(lower_rail)
	for label_data: Array in [
		["DealerHandLabel", "BLACKJACK_DEALER", Vector2(104, 141)],
		["PlayerHandLabel", "BLACKJACK_PLAYER", Vector2(104, 310)],
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
	shoe.position = Vector2(792, 137)
	shoe.size = Vector2(64, 96)
	shoe.color = Color("252126")
	_art_root.add_child(shoe)
	var shoe_trim := ColorRect.new()
	shoe_trim.position = Vector2(798, 144)
	shoe_trim.size = Vector2(52, 6)
	shoe_trim.color = Color("c8a34b")
	_art_root.add_child(shoe_trim)


func _apply_blackjack_fullscreen_layout() -> void:
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("160b0b")
	_title.position = Vector2(310, 24)
	_title.size = Vector2(340, 52)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color("f5e6bd"))
	_stake.position = Vector2(82, 469)
	_stake.size = Vector2(210, 44)
	_stake.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(330, 103)
	_status.size = Vector2(300, 30)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_detail.position = Vector2(328, 469)
	_detail.size = Vector2(304, 32)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_OFF
	_controls_backdrop.position = Vector2(72, 501)
	_controls_backdrop.size = Vector2(816, 32)
	_controls.position = Vector2(82, 505)
	_controls.size = Vector2(796, 24)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_font_size_override("font_size", 16)
	_stake_selector.position = Vector2(78, 456)
	_stake_selector.size = Vector2(334, 58)


func _render_blackjack_hand(player_cards: Array[int], dealer_cards: Array[int], hide_hole: bool) -> void:
	if not _blackjack_dealt and not player_cards.is_empty():
		_clear_blackjack_cards()
		_blackjack_dealt = true
	var deal_index: int = 0
	for index: int in range(dealer_cards.size()):
		_sync_playing_card(dealer_cards[index], index, true, hide_hole and index == 1, deal_index)
		deal_index += 1
	for index: int in range(player_cards.size()):
		_sync_playing_card(player_cards[index], index, false, false, deal_index)
		deal_index += 1


func prepare_blackjack_round() -> void:
	_blackjack_dealt = false
	_blackjack_input_locked_until = Time.get_ticks_msec() + 620


func blackjack_input_ready() -> bool:
	return Time.get_ticks_msec() >= _blackjack_input_locked_until


func _clear_blackjack_cards() -> void:
	for card: PlayingCard in _blackjack_cards:
		if is_instance_valid(card):
			card.queue_free()
	_blackjack_cards.clear()


func _sync_playing_card(
	rank: int, hand_index: int, dealer_hand: bool, hidden: bool, deal_index: int
) -> void:
	var card_name := ("DealerCard" if dealer_hand else "PlayerCard") + str(hand_index)
	for card: PlayingCard in _blackjack_cards:
		if card.name == card_name:
			card.set_face_down(hidden, card.face_down and not hidden)
			return
	_add_playing_card(rank, hand_index, dealer_hand, hidden, deal_index)
	_blackjack_input_locked_until = maxi(
		_blackjack_input_locked_until, Time.get_ticks_msec() + 360
	)


func _add_playing_card(
	rank: int, hand_index: int, dealer_hand: bool, hidden: bool, deal_index: int
) -> void:
	var card := PlayingCard.new()
	card.name = ("DealerCard" if dealer_hand else "PlayerCard") + str(hand_index)
	card.size = Vector2(88, 124)
	card.configure(rank, rank + hand_index + (0 if dealer_hand else 2), hidden)
	var destination := Vector2(286 + hand_index * 76, 132 if dealer_hand else 301)
	card.position = Vector2(804, 144)
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
		_texture("VaultBackdropArt", VAULT_BACKDROP, Vector2.ZERO, Vector2(960, 540))
	)
	var veil := ColorRect.new()
	veil.position = Vector2.ZERO
	veil.size = Vector2(960, 540)
	veil.color = Color("09051555")
	_art_root.add_child(veil)
	for index: int in range(25):
		var tile := VaultTile.new()
		tile.name = "VaultTile%02d" % index
		tile.position = VAULT_GRID_ORIGIN + Vector2(
			(index % 5) * VAULT_GRID_PITCH, (index / 5) * VAULT_GRID_PITCH
		)
		tile.size = Vector2(48, 48)
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
	_vault_cursor.position = VAULT_GRID_ORIGIN - Vector2(4, 4)


func _apply_vault_fullscreen_layout() -> void:
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("090515")
	_title.position = Vector2(300, 22)
	_title.size = Vector2(360, 54)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", Color("f1e8d8"))
	_stake.position = Vector2(64, 444)
	_stake.size = Vector2(250, 44)
	_stake.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(65, 98)
	_status.size = Vector2(250, 88)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("f1e8d8"))
	_detail.position = Vector2(646, 434)
	_detail.size = Vector2(250, 58)
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_controls_backdrop.position = Vector2(72, 501)
	_controls_backdrop.size = Vector2(816, 32)
	_controls.position = Vector2(82, 505)
	_controls.size = Vector2(796, 24)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_font_size_override("font_size", 16)
	_stake_selector.position = Vector2(44, 430)
	_stake_selector.size = Vector2(300, 58)


func _refresh_slot() -> void:
	_detail.text = (
		tr("SLOT_LAST_WIN") % _result.payout if _result != null else tr("SLOT_CENTER_PAYLINE")
	)


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
	elif _slot_spin_label != null:
		_slot_spin_label.scale = Vector2.ONE
		_slot_spin_label.pivot_offset = _slot_spin_label.size * 0.5
		_motion_tween = create_tween()
		_motion_tween.tween_property(_slot_spin_label, "scale", Vector2(0.88, 0.88), 0.12)
		_motion_tween.tween_property(_slot_spin_label, "scale", Vector2.ONE, 0.16).set_trans(
			Tween.TRANS_BACK
		)


func _stop_motion() -> void:
	_slot_spinning = false
	if _motion_tween != null:
		_motion_tween.kill()
		_motion_tween = null


func _update_spinning_reel(reel_index: int) -> void:
	var cells: Array = _slot_reel_cells[reel_index]
	var step: int = int(_slot_offsets[reel_index] / SLOT_CELL_HEIGHT)
	var remainder: float = fmod(_slot_offsets[reel_index], SLOT_CELL_HEIGHT)
	for cell_index: int in range(cells.size()):
		var cell: SlotSymbol = cells[cell_index]
		cell.position.y = (cell_index - 1) * SLOT_CELL_HEIGHT + remainder
		if cell.position.y >= SLOT_CELL_HEIGHT * 4.0:
			cell.position.y -= SLOT_STRIP_HEIGHT
		cell.symbol_index = posmod(
			_slot_start_symbols[reel_index] + cell_index - 2 - step, SLOT_SYMBOL_COUNT
		)


func _stop_reel(reel_index: int) -> void:
	if reel_index >= _slot_reel_cells.size():
		return
	_slot_offsets[reel_index] = _slot_total_offsets[reel_index]
	_update_spinning_reel(reel_index)
	_slot_stopped[reel_index] = true
	var reel: Control = _slot_reels[reel_index]
	reel.position.y = SLOT_REEL_BOUNCE_Y
	create_tween().tween_property(reel, "position:y", SLOT_REEL_TOP, 0.11).set_trans(
		Tween.TRANS_BACK
	)


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


func _help_label(
	parent: Control, at: Vector2, dimensions: Vector2, font_size: int, color: Color
) -> Label:
	var label := Label.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _panel_style(
	fill: Color, border: Color, radius: int, border_width: int = 1
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _card_names(cards: Array[int]) -> String:
	var names: PackedStringArray = []
	for card: int in cards:
		names.append(tr("CARD_" + str(card)) if card == 1 or card > 10 else str(card))
	return "  ".join(names)
