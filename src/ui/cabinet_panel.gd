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
var _slot_stop_times: Array[float] = [1.05, 1.32, 1.59]
var _slot_stopped: Array[bool] = [true, true, true]
var _slot_spin_elapsed: float = 0.0
var _slot_spinning: bool = false
var _slot_finish_callback: Callable
var _slot_win_tween: Tween
var _slot_last_win_indices: Array[int] = []
var _slot_win_band: ColorRect
var _slot_anticipation_frame: Panel
var _slot_anticipating_third: bool = false
var _slot_cascade_clones: Array[Control] = []
var _slot_lever: Node2D
var _slot_hostess: Control
var _slot_spin_label: SlotSpinButton
var _slot_payline: ColorRect
var _slot_credit_value: AnimatedNumberLabel
var _slot_result_value: Label
var _slot_result_formula: Label
var _slot_result_tween: Tween
var _celebration: WinCelebration
var _win_flash: Control
var _stake_selector: StakeSelector
var _help_button: Button
var _help_overlay: Control
var _help_shade: ColorRect
var _help_modal: Panel
var _help_title: Label
var _help_rules: Label
var _help_controls: Label
var _help_reveal_items: Array[Control] = []
var _help_rest_positions: Dictionary = {}
var help_open: bool = false
var _focus_before_help: Control
var _help_tween: Tween
var _vault_tiles: Array[VaultTile] = []
var _vault_cursor: Node2D
var _art_id: StringName = &""
var _motion_tween: Tween
var _entrance_tween: Tween
var _cursor_tween: Tween
var _blackjack_dealt: bool = false
var _blackjack_pending_motions: int = 0
var _blackjack_preparing: bool = false
var _blackjack_cards: Array[PlayingCard] = []
var _blackjack_card_tweens: Dictionary = {}
var _blackjack_layout_targets: Dictionary = {}
var _blackjack_dealer_total: AnimatedNumberLabel
var _blackjack_player_total: AnimatedNumberLabel
var _blackjack_credit_value: AnimatedNumberLabel
var _blackjack_primary: Button
var _blackjack_stand: Button
var _blackjack_double: Button
var _blackjack_bet_stack: Control
var _blackjack_dealer_total_panel: Panel
var _blackjack_player_total_panel: Panel
var _blackjack_result_banner: Panel
var _blackjack_result_text: Label
var _blackjack_dealer_presenter: BlackjackDealerPresenter
var _blackjack_title_plaque: BlackjackConsole
var _blackjack_badge_tween: Tween
var _vault_credit_value: AnimatedNumberLabel
var _vault_open: Button
var _vault_cash_out: Button
var _vault_cashout_meter: VaultCashoutMeter
var _vault_attendant: Control
var _vault_revealed: Dictionary = {}
var _ambient: CasinoAmbient
var _lighting: CasinoLighting
var _blackjack_fx_tween: Tween
var _vault_fx_tween: Tween
var _result_reveal_callback: Callable
var _result_reveal_active: bool = false
var _result_reveal_beat: Tween
var _vault_pending_reveals: int = 0
var _result_impact_tween: Tween
var _last_result_impact_tier: ResultImpactTier = ResultImpactTier.NONE
var _state_feedback_tweens: Dictionary = {}
var _state_rest_positions: Dictionary = {}
var _state_text_cache: Dictionary = {}
var _state_controls: Dictionary = {}
var _action_enable_tweens: Dictionary = {}
var _action_disabled_cache: Dictionary = {}
var _action_controls: Dictionary = {}

const RESULT_READABLE_BEAT: float = 0.22
const BIG_WIN_MULTIPLE: float = 5.0

enum ResultImpactTier { NONE, WIN, BIG_WIN }

## Elven Court: the slot's own enchanted-forest cabinet, reel window cut to alpha.
const SLOT_BODY := preload("res://assets/production/slot/elven/elven_court_bezel.png")
const SLOT_ELVEN_NIGHT := Color("08130f")
const SLOT_ELVEN_REEL := Color("0f2119")
const SLOT_ELVEN_PANEL := Color("0c1a14")
const SLOT_ELVEN_PANEL_INSET := Color("112a20")
const SLOT_ELVEN_GOLD := Color("c9a646")
const SLOT_ELVEN_GOLD_DEEP := Color("8c7231")
const SLOT_ELVEN_GOLD_BRIGHT := Color("ecd27c")
const SLOT_ELVEN_SILVER := Color("d8d3c2")
const SLOT_ELVEN_EMERALD := Color("1f6b4a")
const SLOT_ELVEN_TEXT := Color("f4eddb")
const SLOT_ELVEN_MUTED := Color("a8bba9")
const SLOT_LEVER_PIVOT := Vector2(860, 316)
const SLOT_LEVER_SCRIPT := preload("res://src/ui/slot_lever.gd")
const SLOT_HOSTESS_SCRIPT := preload("res://src/ui/slot_hostess_presenter.gd")
const VAULT_ATTENDANT_SCRIPT := preload("res://src/ui/vault_attendant_presenter.gd")
const SLOT_SYMBOL_COUNT: int = 6
const SLOT_REEL_TOP: float = 151.0
const SLOT_REEL_BOUNCE_Y: float = 144.0
const SLOT_CELL_HEIGHT: float = 78.0
const SLOT_STRIP_HEIGHT: float = SLOT_CELL_HEIGHT * 5.0
const VAULT_GRID_ORIGIN := Vector2(342, 122)
const VAULT_GRID_PITCH: float = 60.0
const VAULT_TILE_SIZE: float = 56.0
## Left column, directly under the vault status panel (48,150 280x122), so the
## right side of the stage is free for the attendant standing on the floor.
const VAULT_CASHOUT_METER_POSITION := Vector2(48, 284)
const BLACKJACK_FELT := preload("res://assets/drafts/m2/felt_table.png")
const CARD_BACK := preload("res://assets/drafts/m2/card_back.png")
const BLACKJACK_TABLE := preload("res://assets/production/blackjack/blackjack_table_v2.png")
const VAULT_BACKDROP := preload(
	"res://assets/production/vault/witcher/witcher_vault_backdrop.png"
)
const VAULT_REVEAL_FX := preload("res://src/ui/vault_reveal_fx.gd")
const BLACKJACK_BET_STACK := preload("res://src/ui/blackjack_bet_stack.gd")
## Blackjack felt geometry (cabinet space). Cards are sized to the painted table:
## the dealer's hand sits inside the dealer arc in front of her, the player's
## hand sits below the arc, nearer the camera and a little larger.
const BLACKJACK_DEALER_CARD := Vector2(52, 73)
const BLACKJACK_PLAYER_CARD := Vector2(58, 81)
const BLACKJACK_HAND_CENTER_X: float = 480.0
const BLACKJACK_DEALER_CARD_Y: float = 227.0
const BLACKJACK_PLAYER_CARD_Y: float = 335.0
const BLACKJACK_HAND_MAX_WIDTH: float = 204.0
const BLACKJACK_BADGE_SIZE := Vector2(86, 24)
const BLACKJACK_BADGE_GAP: float = 10.0
const BLACKJACK_PLAQUE_RECT := Rect2(392, 305, 176, 28)
const BLACKJACK_DEAL_SECONDS: float = 0.30
const BLACKJACK_DEAL_STAGGER: float = 0.08
const BLACKJACK_SHOE_SCALE: float = 0.38
const BLACKJACK_SHOE_ROTATION: float = -0.42
const BLACKJACK_WIN_INK := Color("f2c84b")
const BLACKJACK_LOSS_INK := Color("c9b9a6")
const BLACKJACK_TEXT := Color("f1e8d8")
const CABINET_WIN_FLASH_SCRIPT := preload("res://src/ui/cabinet_win_flash.gd")


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
	_lighting = CasinoLighting.new()
	_lighting.name = "CabinetLighting"
	_lighting.size = Vector2(960, 540)
	_lighting.z_index = 3
	add_child(_lighting)
	_controls_backdrop = ColorRect.new()
	_controls_backdrop.position = Vector2(64, 400)
	_controls_backdrop.size = Vector2(832, 56)
	_controls_backdrop.color = Color("1a1826")
	add_child(_controls_backdrop)
	_title = _label(Vector2(80, 90), 24)
	_title.add_theme_font_override("font", Typography.DISPLAY_FONT)
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
	_celebration = WinCelebration.new()
	_celebration.name = "WinCelebration"
	_celebration.size = Vector2(960, 540)
	_celebration.z_index = 50
	add_child(_celebration)
	_win_flash = CABINET_WIN_FLASH_SCRIPT.new()
	_win_flash.name = "CabinetWinFlash"
	_win_flash.size = Vector2(960, 540)
	_win_flash.z_index = 45
	add_child(_win_flash)
	_build_help_ui()
	InputRouter.active_device_changed.connect(func(_device: int) -> void: refresh())
	MotionPolicy.motion_preference_changed.connect(_apply_live_feedback_motion_preference)
	refresh()


func refresh() -> void:
	if _title == null or cabinet.context == null:
		return
	_ensure_art()
	_title.text = tr(cabinet.context.definition.name_key)
	_stake.text = tr("CABINET_STAKE") % cabinet.selected_stake
	_stake.hide()
	_stake_selector.refresh_controls()
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
	var next_status := tr(_status_key)
	if id == &"minefield_vault":
		var vault_math: MinefieldMath = cabinet.get("math")
		if cabinet.is_round_active and not vault_math.revealed.is_empty():
			next_status = _detail.text
			# Hexbound Vault live readout: warm candle-lit parchment, not mint.
			_status.add_theme_color_override("font_color", Color("f0dcb0"))
	if cabinet.selected_stake == 0 and not cabinet.is_round_active:
		next_status = tr("BET_NEED_CASHIER") % cabinet.context.definition.min_bet
	_set_live_text(_status, next_status)
	_refresh_help()


func show_result(result: RoundResult) -> void:
	_stop_motion()
	_result = result
	_status_key = "ROUND_READY"
	refresh()
	_set_live_text(_status, tr("ROUND_RESULT") % [result.stake, result.payout])
	AudioService.play(_result_audio_cue(result))
	_play_result_impact(result)
	_win_flash.play(
		_result_flash_tint(result), _last_result_impact_tier == ResultImpactTier.BIG_WIN
	)
	if result.payout > result.stake:
		if cabinet.context.definition.id != &"blackjack":
			# Blackjack answers with its own composed plaque and chip settle instead
			# of free-flying coins across the table.
			var win_multiple := float(result.payout) / maxf(result.stake, 1.0)
			var burst_count := 32 if win_multiple >= 10.0 else (20 if win_multiple >= 5.0 else 12)
			_celebration.burst(Vector2(480, 300), burst_count)
		_pulse_slot_win(result)
	if cabinet.context.definition.id == &"slot_classic":
		_animate_slot_result(result.payout)
		if _slot_hostess != null:
			_slot_hostess.react_to_result(result.payout > result.stake)
	elif cabinet.context.definition.id == &"blackjack":
		_animate_blackjack_result(result)
	else:
		_animate_vault_result(result)
	if _ambient != null:
		_ambient.trigger_event(1.0 if result.payout > result.stake else 0.55)
	_status.add_theme_color_override(
		"font_color", Color("3fc276") if result.payout > result.stake else Color("d55353")
	)
	if cabinet.context.definition.id == &"slot_classic":
		# The status lives on the emerald plaque: gold for a win, pale silver
		# otherwise (red/green would vanish against the plaque).
		_status.add_theme_color_override(
			"font_color",
			SLOT_ELVEN_GOLD_BRIGHT if result.payout > result.stake else SLOT_ELVEN_SILVER
		)
	if cabinet.context.definition.id == &"minefield_vault":
		# Candle-amber for a banked cache, ember-red for a broken curse.
		_status.add_theme_color_override(
			"font_color", VaultRuneFrame.AMBER if result.payout > result.stake else Color("e0645a")
		)


func present_result_after_reveal(_result: RoundResult, on_ready: Callable) -> void:
	_result_reveal_active = true
	_result_reveal_callback = on_ready
	refresh()
	_try_complete_result_reveal()


func _result_audio_cue(result: RoundResult) -> StringName:
	match cabinet.context.definition.id:
		&"slot_classic":
			return &"slot_win" if result.payout > result.stake else &"loss"
		&"blackjack":
			if result.outcome == RoundResult.Outcome.PUSH:
				return &"blackjack_push"
			return &"blackjack_win" if result.payout > result.stake else &"blackjack_loss"
		&"minefield_vault":
			return &"vault_cashout" if result.payout > 0 else &"vault_bust"
	return &"win" if result.payout > result.stake else &"loss"


func _result_flash_tint(result: RoundResult) -> Color:
	if result.outcome == RoundResult.Outcome.PUSH:
		return Color("c8a34b")
	if result.payout <= result.stake:
		return Color("a53243")
	match cabinet.context.definition.id:
		&"blackjack":
			# Warm brass, matching the table's own light rather than a green wash.
			return Color("d9b44a")
		&"minefield_vault":
			return Color("48c5d5")
		_:
			return Color("f2c84b")


func _process(delta: float) -> void:
	if help_open or not _slot_spinning:
		return
	_slot_spin_elapsed += delta
	for reel_index: int in range(_slot_reels.size()):
		if _slot_stopped[reel_index]:
			continue
		var duration: float = _slot_stop_times[reel_index]
		var progress: float = clampf(_slot_spin_elapsed / duration, 0.0, 1.0)
		if reel_index == 2 and _slot_anticipating_third and _slot_anticipation_frame != null:
			var anticipation_started := _slot_stopped[0] and _slot_stopped[1]
			_slot_anticipation_frame.visible = anticipation_started
			if anticipation_started and not MotionPolicy.is_reduced():
				_slot_anticipation_frame.modulate.a = 0.72 + sin(_slot_spin_elapsed * 16.0) * 0.20
			if anticipation_started and _slot_hostess != null:
				_slot_hostess.anticipate()
		if not MotionPolicy.is_reduced():
			var eased := _slot_motion_progress(progress)
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
	if key == "ROUND_SPINNING":
		_reset_slot_result_ticker()
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
	_reset_slot_result_ticker()
	_reset_slot_win_feedback()
	_slot_spin_targets.clear()
	_slot_stop_times = [1.05, 1.32, 1.59]
	_slot_anticipating_third = false
	for index: int in range(3):
		_slot_spin_targets.append(int(symbols[index]))
		var center: SlotSymbol = _slot_reel_cells[index][2]
		_slot_start_symbols[index] = center.symbol_index
		var target_steps: int = 18 + index * 6 + posmod(
			_slot_start_symbols[index] - _slot_spin_targets[index], SLOT_SYMBOL_COUNT
		)
		_slot_total_offsets[index] = target_steps * SLOT_CELL_HEIGHT
	if int(symbols[0]) == int(symbols[1]):
		# A real outcome-driven anticipation beat, never a fabricated near miss.
		_slot_stop_times[2] = 2.05
		_slot_anticipating_third = true
	_slot_finish_callback = on_finished
	if _slot_payline != null:
		_slot_payline.color = Color("8a682f80")
	set_status("ROUND_SPINNING")


func toggle_help() -> void:
	set_help_open(not help_open)


func set_help_open(open: bool) -> void:
	if _help_tween != null:
		_help_tween.kill()
		_help_tween = null
	if open:
		_focus_before_help = get_viewport().gui_get_focus_owner()
	help_open = open
	if open and _help_overlay != null:
		_help_overlay.visible = true
		_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_reset_help_visual_state()
		if not MotionPolicy.is_reduced():
			_prepare_help_reveal()
			_help_tween = create_tween().set_parallel(true)
			_help_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			_help_tween.tween_property(_help_shade, "modulate:a", 1.0, 0.12)
			_help_tween.tween_property(_help_modal, "modulate:a", 1.0, 0.16)
			_help_tween.tween_property(_help_modal, "position:y", 64.0, 0.18)
			_help_tween.tween_property(_help_modal, "scale", Vector2.ONE, 0.18)
			for index: int in range(_help_reveal_items.size()):
				var item := _help_reveal_items[index]
				var delay := 0.02 + index * 0.012
				_help_tween.tween_property(item, "modulate:a", 1.0, 0.12).set_delay(delay)
				_help_tween.tween_property(
					item, "position:y", (_help_rest_positions[item] as Vector2).y, 0.14
				).set_delay(delay)
			_help_tween.finished.connect(func() -> void: _help_tween = null)
		var close_button := _help_overlay.find_child("HelpClose", true, false) as Button
		if close_button != null:
			close_button.grab_focus()
	elif not open and _help_overlay != null:
		if is_instance_valid(_focus_before_help):
			_focus_before_help.grab_focus()
		if MotionPolicy.is_reduced():
			_help_overlay.hide()
			_reset_help_visual_state()
		else:
			_help_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_help_tween = create_tween().set_parallel(true)
			_help_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			_help_tween.tween_property(_help_shade, "modulate:a", 0.0, 0.14)
			_help_tween.tween_property(_help_modal, "modulate:a", 0.0, 0.12)
			_help_tween.tween_property(_help_modal, "position:y", 70.0, 0.14)
			_help_tween.tween_property(_help_modal, "scale", Vector2(0.98, 0.98), 0.14)
			_help_tween.finished.connect(
				func() -> void:
					_help_overlay.hide()
					_reset_help_visual_state()
					_help_tween = null
			)
	if _slot_spin_label != null:
		_slot_spin_label.disabled = open or cabinet.is_round_active
		_slot_spin_label.queue_redraw()
	if _slot_lever != null:
		_slot_lever.disabled = open or cabinet.is_round_active
		_slot_lever.queue_redraw()
	_refresh_vault_pointer_interaction()


func _build_help_ui() -> void:
	_help_button = Button.new()
	_help_button.name = "HowToPlayButton"
	_help_button.position = Vector2(770, 28)
	_help_button.size = Vector2(142, 38)
	_help_button.text = tr("HELP_BUTTON")
	_help_button.add_theme_font_override("font", Typography.UI_FONT)
	_help_button.add_theme_font_size_override("font_size", 14)
	_help_button.z_index = 90
	_help_button.add_theme_stylebox_override("normal", _panel_style(Color("17161af2"), Color("c8a34b"), 6))
	_help_button.add_theme_stylebox_override("focus", _panel_style(Color("252126"), Color("48c5d5"), 6, 2))
	_help_button.pressed.connect(toggle_help)
	add_child(_help_button)
	ButtonFeedback.attach(_help_button)

	_help_overlay = Control.new()
	_help_overlay.name = "HelpOverlay"
	_help_overlay.size = Vector2(960, 540)
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.z_index = 100
	_help_overlay.visible = false
	add_child(_help_overlay)
	_help_shade = ColorRect.new()
	_help_shade.name = "HelpShade"
	_help_shade.size = Vector2(960, 540)
	_help_shade.color = Color("080708d9")
	_help_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_overlay.add_child(_help_shade)
	_help_modal = Panel.new()
	_help_modal.name = "HelpModal"
	_help_modal.position = Vector2(170, 64)
	_help_modal.size = Vector2(620, 412)
	_help_modal.pivot_offset = _help_modal.size * 0.5
	_help_modal.add_theme_stylebox_override("panel", _panel_style(Color("17161af7"), Color("c8a34b"), 8))
	_help_overlay.add_child(_help_modal)
	_help_title = _help_label(_help_modal, Vector2(32, 20), Vector2(470, 42), 28, Color("f1e8d8"))
	var rules_heading := _help_label(_help_modal, Vector2(32, 76), Vector2(326, 24), 14, Color("c8a34b"))
	rules_heading.text = tr("HELP_RULES")
	_help_rules = _help_label(_help_modal, Vector2(32, 108), Vector2(326, 238), 16, Color("f1e8d8"))
	_help_rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var controls_heading := _help_label(_help_modal, Vector2(388, 76), Vector2(194, 24), 14, Color("c8a34b"))
	controls_heading.text = tr("HELP_CONTROLS")
	_help_controls = _help_label(_help_modal, Vector2(388, 108), Vector2(194, 238), 15, Color("f1e8d8"))
	_help_controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var footer := _help_label(
		_help_modal, Vector2(32, 366), Vector2(420, 24), Typography.BODY_MIN, Color("b8ad9c")
	)
	footer.text = tr("HELP_CLOSE_HINT") % InputRouter.glyph("help")
	var close := Button.new()
	close.name = "HelpClose"
	close.position = Vector2(548, 16)
	close.size = Vector2(44, 44)
	close.text = String.chr(0x00D7)
	close.add_theme_font_override("font", Typography.UI_FONT)
	close.add_theme_font_size_override("font_size", 24)
	close.add_theme_stylebox_override("normal", _panel_style(Color("252126"), Color("6e5225"), 6))
	close.add_theme_stylebox_override("focus", _panel_style(Color("252126"), Color("48c5d5"), 6, 2))
	close.pressed.connect(func() -> void: set_help_open(false))
	_help_modal.add_child(close)
	ButtonFeedback.attach(close)
	_help_reveal_items.assign(
		[_help_title, rules_heading, _help_rules, controls_heading, _help_controls, footer, close]
	)
	for item: Control in _help_reveal_items:
		_help_rest_positions[item] = item.position


func _prepare_help_reveal() -> void:
	_help_shade.modulate.a = 0.0
	_help_modal.modulate.a = 0.0
	_help_modal.position.y = 70.0
	_help_modal.scale = Vector2(0.98, 0.98)
	for item: Control in _help_reveal_items:
		item.modulate.a = 0.0
		item.position = (_help_rest_positions[item] as Vector2) + Vector2(0, 6)


func _reset_help_visual_state() -> void:
	if _help_shade == null or _help_modal == null:
		return
	_help_overlay.modulate = Color.WHITE
	_help_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_shade.modulate = Color.WHITE
	_help_modal.modulate = Color.WHITE
	_help_modal.position = Vector2(170, 64)
	_help_modal.scale = Vector2.ONE
	for item: Control in _help_reveal_items:
		item.modulate = Color.WHITE
		item.position = _help_rest_positions[item] as Vector2


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
	_render_blackjack_hand(
		math.player, math.dealer, cabinet.is_round_active and not cabinet.is_result_pending
	)
	if _blackjack_dealer_presenter != null:
		# Presentation-only: the dealer looks up while Hit/Stand/Double is awaited.
		_blackjack_dealer_presenter.set_awaiting_decision(
			cabinet.is_round_active and not cabinet.is_result_pending
		)
	if _blackjack_player_total != null and not cabinet.is_result_pending:
		_blackjack_player_total.set_number(
			BlackjackMath.hand_value(math.player), tr("BLACKJACK_TOTAL")
		)
		if cabinet.is_round_active and not math.dealer.is_empty():
			_blackjack_dealer_total.set_number(
				BlackjackMath.hand_value([math.dealer[0]]), tr("BLACKJACK_SHOWING")
			)
		else:
			_blackjack_dealer_total.set_number(
				BlackjackMath.hand_value(math.dealer), tr("BLACKJACK_TOTAL")
			)
	if _blackjack_credit_value != null:
		if Wallet.test_mode_enabled:
			_blackjack_credit_value.set_infinity()
		else:
			_blackjack_credit_value.set_number(
				maxi(
					0,
					cabinet.context.balance
					- (cabinet.current_stake if cabinet.is_round_active else 0)
				)
			)
		_set_live_text(
			_blackjack_primary,
			tr("ACTION_HIT") if cabinet.is_round_active else tr("ACTION_DEAL")
		)
		_set_live_text(_blackjack_double, (
			tr("ACTION_DOUBLE_TO") % (cabinet.current_stake * 2)
			if cabinet.is_round_active
			else tr("ACTION_DOUBLE")
		))
		_set_action_disabled(_blackjack_primary, (
			cabinet.is_result_pending
			or (not cabinet.is_round_active and cabinet.selected_stake > cabinet.context.balance)
		))
		_set_action_disabled(
			_blackjack_stand, not cabinet.is_round_active or cabinet.is_result_pending
		)
		_set_action_disabled(_blackjack_double, (
			cabinet.is_result_pending or not math.can_double(cabinet.context.balance)
		))
	if _blackjack_bet_stack != null:
		var live_wager: int = cabinet.current_stake if cabinet.is_round_active else 0
		if live_wager > 0:
			_blackjack_bet_stack.place_wager(live_wager, not _blackjack_bet_stack.is_live)
		elif _result == null:
			_blackjack_bet_stack.clear_wager(false)
	if _blackjack_result_banner != null and _result == null:
		_blackjack_result_banner.hide()
	_style_blackjack_stake_buttons()


func _refresh_vault() -> void:
	var math: MinefieldMath = cabinet.get("math")
	var cursor: int = (cabinet.get("snap_cursor") as SnapCursor).index
	for index: int in range(25):
		if index < _vault_tiles.size():
			_vault_tiles[index].set_selected(index == cursor)
			var next_face := VaultTile.Face.HIDDEN
			if index in math.revealed:
				next_face = VaultTile.Face.MINE if index in math.mines else VaultTile.Face.SAFE
			if index in math.revealed and not _vault_revealed.has(index):
				_vault_revealed[index] = true
				_vault_pending_reveals += 1
				_vault_tiles[index].reveal(next_face)
			elif not _vault_tiles[index].is_flipping:
				_vault_tiles[index].set_face_immediate(next_face)
	_refresh_vault_pointer_interaction()
	if _vault_attendant != null:
		_vault_attendant.set_round_active(cabinet.is_round_active and not cabinet.is_result_pending)
	if _vault_cursor != null:
		var cursor_target := (
			VAULT_GRID_ORIGIN
			- Vector2(2, 2)
			+ Vector2((cursor % 5) * VAULT_GRID_PITCH, (cursor / 5) * VAULT_GRID_PITCH)
		)
		if _cursor_tween != null:
			_cursor_tween.kill()
		if MotionPolicy.is_reduced():
			_vault_cursor.position = cursor_target
		else:
			_cursor_tween = create_tween()
			_cursor_tween.tween_property(_vault_cursor, "position", cursor_target, 0.09)
	var cash_out := (
		MinefieldMath.payout_for(cabinet.current_stake, cabinet.get("mine_count"), math.safe_reveals)
		if cabinet.is_round_active and math.safe_reveals > 0
		else 0
	)
	_detail.text = tr("VAULT_GRID") % [cabinet.get("mine_count"), math.multiplier(), cash_out]
	if _vault_cashout_meter != null:
		var can_cash_out := cabinet.is_round_active and math.safe_reveals > 0
		var safe_target := maxi(1, 25 - cabinet.get("mine_count"))
		_vault_cashout_meter.set_ready(can_cash_out)
		_vault_cashout_meter.set_values(
			cash_out,
			math.multiplier(),
			float(math.safe_reveals) / float(safe_target),
			true
		)
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
	if _vault_credit_value != null:
		if Wallet.test_mode_enabled:
			_vault_credit_value.set_infinity()
		else:
			_vault_credit_value.set_number(
				maxi(
					0,
					cabinet.context.balance
					- (cabinet.current_stake if cabinet.is_round_active else 0)
				)
			)
		_set_live_text(
			_vault_open,
			tr("ACTION_OPEN") if cabinet.is_round_active else tr("ACTION_ENTER")
		)
		_set_action_disabled(_vault_open, (
			cabinet.is_result_pending
			or (not cabinet.is_round_active and cabinet.selected_stake > cabinet.context.balance)
		))
		_set_action_disabled(_vault_cash_out, (
			cabinet.is_result_pending or not cabinet.is_round_active or math.revealed.is_empty()
		))
	_title.text = tr("VAULT_WITCHER_TITLE")
	_style_vault_stake_buttons()


func _ensure_art() -> void:
	var id: StringName = cabinet.context.definition.id
	if id == _art_id:
		return
	_art_id = id
	_lighting.mode = {
		&"slot_classic": CasinoLighting.Mode.SLOT,
		&"blackjack": CasinoLighting.Mode.BLACKJACK,
		&"minefield_vault": CasinoLighting.Mode.VAULT,
	}.get(id, CasinoLighting.Mode.MENU)
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
	call_deferred("_focus_default_action")


func _focus_default_action() -> void:
	if help_open or not is_inside_tree():
		return
	if cabinet.context.definition.id == &"slot_classic" and _slot_spin_label != null:
		_slot_spin_label.grab_focus()
	elif cabinet.context.definition.id == &"blackjack" and _blackjack_primary != null:
		_blackjack_primary.grab_focus()
	elif cabinet.context.definition.id == &"minefield_vault" and _vault_open != null:
		_vault_open.grab_focus()


func _build_slot_art() -> void:
	_add_ambient(SLOT_ELVEN_GOLD)
	var backdrop := ColorRect.new()
	backdrop.name = "SlotBackdrop"
	backdrop.position = Vector2.ZERO
	backdrop.size = Vector2(960, 540)
	backdrop.color = SLOT_ELVEN_NIGHT
	_art_root.add_child(backdrop)
	var reel_shadow := ColorRect.new()
	reel_shadow.position = Vector2(158, 145)
	reel_shadow.size = Vector2(644, 252)
	reel_shadow.color = Color("050b08")
	_art_root.add_child(reel_shadow)
	# Elven Court reels run on a deep moonlit-emerald strip so ruby, gold,
	# silver and crystal icons all read with strong value contrast.
	var reel_back := ColorRect.new()
	reel_back.name = "SlotReelStrip"
	reel_back.position = Vector2(166, SLOT_REEL_TOP)
	reel_back.size = Vector2(628, SLOT_CELL_HEIGHT * 3.0)
	reel_back.color = SLOT_ELVEN_REEL
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
		_stop_reel(index, false)
	for separator_x: float in [372.0, 579.0]:
		var separator := ColorRect.new()
		separator.position = Vector2(separator_x, SLOT_REEL_TOP)
		separator.size = Vector2(5, SLOT_CELL_HEIGHT * 3.0)
		separator.color = SLOT_ELVEN_GOLD_DEEP
		_art_root.add_child(separator)
	var body := _texture("SlotCabinetArt", SLOT_BODY, Vector2.ZERO, Vector2(960, 540))
	_art_root.add_child(body)
	# The hostess owns her lane geometry: left of the reel window, above the
	# credits meter, turned toward the reels.
	_slot_hostess = SLOT_HOSTESS_SCRIPT.new()
	_slot_hostess.z_index = 1
	_art_root.add_child(_slot_hostess)
	_slot_payline = ColorRect.new()
	_slot_payline.name = "WinningPayline"
	_slot_payline.position = Vector2(151, SLOT_REEL_TOP + SLOT_CELL_HEIGHT * 1.5 - 2.0)
	_slot_payline.size = Vector2(658, 4)
	_slot_payline.color = Color("d9b44a")
	_art_root.add_child(_slot_payline)
	_slot_win_band = ColorRect.new()
	_slot_win_band.name = "WinningRowBand"
	_slot_win_band.position = Vector2(166, SLOT_REEL_TOP + SLOT_CELL_HEIGHT)
	_slot_win_band.size = Vector2(628, SLOT_CELL_HEIGHT)
	_slot_win_band.color = Color("d9b44a24")
	_slot_win_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_win_band.visible = false
	_slot_win_band.z_index = 3
	_art_root.add_child(_slot_win_band)
	_slot_anticipation_frame = Panel.new()
	_slot_anticipation_frame.name = "ThirdReelAnticipationFrame"
	_slot_anticipation_frame.position = Vector2(581, SLOT_REEL_TOP - 4.0)
	_slot_anticipation_frame.size = Vector2(206, SLOT_CELL_HEIGHT * 3.0 + 8.0)
	_slot_anticipation_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot_anticipation_frame.add_theme_stylebox_override(
		"panel", _panel_style(Color("00000000"), Color("f2c84b"), 8, 4)
	)
	_slot_anticipation_frame.visible = false
	_slot_anticipation_frame.z_index = 4
	_art_root.add_child(_slot_anticipation_frame)
	_build_slot_lever()
	_build_slot_deck()


func _build_slot_lever() -> void:
	_slot_lever = SLOT_LEVER_SCRIPT.new()
	_slot_lever.name = "SlotLever"
	# Pivot sits in the carved silver mount painted on the cabinet's right flank.
	_slot_lever.position = SLOT_LEVER_PIVOT
	_slot_lever.z_index = 6
	_slot_lever.pressed.connect(
		func() -> void:
			if cabinet.has_method("request_spin"):
				cabinet.call("request_spin")
	)
	_art_root.add_child(_slot_lever)


func _apply_slot_fullscreen_layout() -> void:
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = SLOT_ELVEN_NIGHT
	_controls_backdrop.hide()
	# Title and status share the painted emerald plaque (inner ~x272-688, y42-96);
	# the carved pale wood around it never carries text.
	_title.position = Vector2(280, 41)
	_title.size = Vector2(400, 34)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", SLOT_ELVEN_GOLD_BRIGHT)
	_stake.hide()
	_status.position = Vector2(290, 72)
	_status.size = Vector2(380, 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 16)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail.hide()
	_controls.hide()
	# Inset inside the SlotBetTray inlay so chips and captions never touch the
	# gold border (six 50 px chips, above the 44 px minimum target).
	_stake_selector.position = Vector2(192, 433)
	_stake_selector.size = Vector2(324, 80)
	_stake_selector.z_index = 6


func _build_slot_deck() -> void:
	# Elven Court deck: flat emerald-black inlays set into the carved pale-wood
	# ledge, gold filigree border with leaf-cut corners and a silver inner line.
	var credits_panel := _slot_elven_panel("SlotCreditsMeter", Rect2(48, 430, 128, 94))
	var credit_caption := _help_label(
		credits_panel, Vector2(10, 14), Vector2(110, 18), 14, SLOT_ELVEN_MUTED
	)
	credit_caption.text = tr("HUD_TEST_BANK") if Wallet.test_mode_enabled else tr("HUD_CREDITS")
	credit_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_credit_value = _help_number_label(
		credits_panel, Vector2(10, 38), Vector2(110, 38), 30, SLOT_ELVEN_GOLD_BRIGHT
	)
	_slot_credit_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_slot_elven_panel("SlotBetTray", Rect2(184, 430, 340, 94))

	_slot_spin_label = SlotSpinButton.new()
	_slot_spin_label.name = "SlotSpinButton"
	_slot_spin_label.position = Vector2(530, 416)
	_slot_spin_label.size = Vector2(140, 110)
	_slot_spin_label.z_index = 5
	_slot_spin_label.pressed.connect(
		func() -> void:
			if cabinet.has_method("request_spin"):
				cabinet.call("request_spin")
	)
	add_child(_slot_spin_label)
	ButtonFeedback.attach(_slot_spin_label)

	var result_panel := _slot_elven_panel("SlotResultMeter", Rect2(678, 430, 234, 94))
	_slot_result_value = _help_label(
		result_panel, Vector2(10, 15), Vector2(214, 30), 24, SLOT_ELVEN_TEXT
	)
	_slot_result_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_result_formula = _help_label(
		result_panel, Vector2(10, 53), Vector2(214, 24), 14, SLOT_ELVEN_MUTED
	)
	_slot_result_formula.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## One Elven Court HUD inlay: flat fill, gold border, leaf-cut corners (two
## rounded, two nearly square) and a one-pixel silver inner line. No gradients.
func _slot_elven_panel(node_name: String, rect: Rect2) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = rect.position
	panel.size = rect.size
	panel.z_index = 4
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _slot_elven_style(SLOT_ELVEN_PANEL, SLOT_ELVEN_GOLD, 2))
	add_child(panel)
	var inset := Panel.new()
	inset.name = "ElvenInlayLine"
	inset.position = Vector2(5, 5)
	inset.size = rect.size - Vector2(10, 10)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := _slot_elven_style(Color(0, 0, 0, 0), Color(SLOT_ELVEN_SILVER, 0.34), 1)
	line.corner_radius_top_left = 12
	line.corner_radius_bottom_right = 12
	inset.add_theme_stylebox_override("panel", line)
	panel.add_child(inset)
	return panel


func _slot_elven_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.corner_radius_top_left = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.anti_aliasing = true
	return style


## Per-game restyle of the shared StakeSelector, applied only from the slot path
## (Blackjack and Vault keep the default casino console). Focus stays cyan.
func _apply_slot_elven_stake_theme() -> void:
	if _stake_selector == null:
		return
	var displayed := cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	for child: Node in _stake_selector.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := button.text == str(displayed)
		button.add_theme_color_override("font_color", SLOT_ELVEN_TEXT)
		button.add_theme_color_override("font_pressed_color", SLOT_ELVEN_NIGHT)
		button.add_theme_color_override("font_hover_pressed_color", SLOT_ELVEN_NIGHT)
		button.add_theme_color_override("font_focus_color", SLOT_ELVEN_TEXT)
		button.add_theme_color_override("font_disabled_color", Color("6f7d72"))
		button.add_theme_stylebox_override(
			"normal",
			_slot_elven_style(
				SLOT_ELVEN_GOLD if selected else SLOT_ELVEN_PANEL_INSET,
				SLOT_ELVEN_GOLD_BRIGHT if selected else Color("3f5a4a"),
				2 if selected else 1
			)
		)
		button.add_theme_stylebox_override(
			"hover", _slot_elven_style(Color("1a3a2c"), SLOT_ELVEN_GOLD, 2)
		)
		button.add_theme_stylebox_override(
			"pressed", _slot_elven_style(SLOT_ELVEN_GOLD, SLOT_ELVEN_GOLD_BRIGHT, 2)
		)
		button.add_theme_stylebox_override(
			"focus", _slot_elven_style(Color(0, 0, 0, 0), Color("48c5d5"), 2)
		)
		button.add_theme_stylebox_override(
			"disabled",
			_slot_elven_style(
				Color("6f5d2c") if selected else Color("0d1813"), Color("2c3a32"), 1
			)
		)


func _build_blackjack_deck() -> void:
	# Walnut rail console with a felt-green wager inset: the salon's own HUD.
	var deck := BlackjackConsole.new()
	deck.name = "BlackjackControlDeck"
	deck.position = Vector2(48, 430)
	deck.size = Vector2(864, 98)
	deck.z_index = 4
	deck.felt_insets = [Rect2(130, 6, 346, 86)]
	add_child(deck)
	_blackjack_credit_value = _add_credit_meter(deck, Vector2(8, 9), Vector2(118, 80))
	(_blackjack_credit_value.get_parent() as Panel).add_theme_stylebox_override(
		"panel", _panel_style(Color("1d110b"), Color("8a682f"), 6, 1)
	)
	_blackjack_primary = _action_button(
		tr("ACTION_DEAL"), Vector2(526, 444), Vector2(116, 68), Callable(cabinet, "request_primary")
	)
	_blackjack_stand = _action_button(
		tr("ACTION_STAND"), Vector2(652, 444), Vector2(116, 68), Callable(cabinet, "request_stand")
	)
	_blackjack_double = _action_button(
		tr("ACTION_DOUBLE"), Vector2(778, 444), Vector2(130, 68), Callable(cabinet, "request_double")
	)
	_blackjack_primary.name = "BlackjackPrimaryAction"
	_blackjack_stand.name = "BlackjackStandAction"
	_blackjack_double.name = "BlackjackDoubleAction"
	for button: Button in [_blackjack_primary, _blackjack_stand, _blackjack_double]:
		_style_blackjack_action(button, button == _blackjack_primary)


## Felt-green action keys framed in brass; cyan appears only as the focus ring.
func _style_blackjack_action(button: Button, primary: bool) -> void:
	var face := Color("155a41") if primary else Color("12402f")
	button.add_theme_stylebox_override("normal", _panel_style(face, Color("c8a34b"), 7, 2))
	button.add_theme_stylebox_override(
		"hover", _panel_style(face.lightened(0.08), Color("f0c45e"), 7, 2)
	)
	button.add_theme_stylebox_override(
		"pressed", _panel_style(face.darkened(0.25), Color("f0c45e"), 7, 2)
	)
	button.add_theme_stylebox_override("focus", _panel_style(face, Color("48c5d5"), 7, 3))
	button.add_theme_stylebox_override(
		"disabled", _panel_style(Color("1d140e"), Color("4b3a2a"), 7, 1)
	)
	button.add_theme_color_override("font_color", Color("f5ecd9"))
	button.add_theme_color_override("font_disabled_color", Color("6f6254"))


## The shared StakeSelector keeps its behaviour; Blackjack only re-skins its keys
## as walnut chips with a felt-green selected state. Re-applied after the selector
## refreshes itself, so the shared defaults never flash through.
func _style_blackjack_stake_buttons() -> void:
	if _stake_selector == null:
		return
	var displayed := cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	for child: Node in _stake_selector.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := button.text == str(displayed)
		button.add_theme_stylebox_override(
			"normal",
			_stake_chip_style(
				Color("155a41") if selected else Color("24160f"),
				Color("f2c84b") if selected else Color("7a5c2a"),
				2 if selected else 1
			)
		)
		for entry: Array in [
			["hover", Color("2f1d13"), Color("c8a34b"), 2],
			["pressed", Color("155a41"), Color("f2c84b"), 2],
			["focus", Color("24160f"), Color("48c5d5"), 2],
			["disabled", Color("1d140e"), Color("3e3025"), 1],
		]:
			button.add_theme_stylebox_override(
				entry[0], _stake_chip_style(entry[1], entry[2], entry[3])
			)
		if not button.pressed.is_connected(_style_blackjack_stake_buttons):
			button.pressed.connect(_style_blackjack_stake_buttons)


func _stake_chip_style(face: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = face
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(8)
	style.anti_aliasing = true
	return style

func _build_vault_deck() -> void:
	# Hexbound Vault HUD: carved-slate plates with silver rules and rivets, so
	# the vault never borrows the Slot or Blackjack chrome.
	var status_panel := VaultRuneFrame.new()
	status_panel.name = "VaultStatusPanel"
	status_panel.position = Vector2(48, 150)
	status_panel.size = Vector2(280, 122)
	status_panel.z_index = 4
	status_panel.fill = Color(VaultRuneFrame.STONE, 0.92)
	add_child(status_panel)
	_vault_cashout_meter = VaultCashoutMeter.new()
	_vault_cashout_meter.name = "VaultCashoutMeter"
	_vault_cashout_meter.position = VAULT_CASHOUT_METER_POSITION
	_vault_cashout_meter.size = Vector2(262, 76)
	_vault_cashout_meter.z_index = 4
	add_child(_vault_cashout_meter)
	var deck := VaultRuneFrame.new()
	deck.name = "VaultControlDeck"
	deck.position = Vector2(48, 426)
	deck.size = Vector2(864, 102)
	deck.z_index = 4
	deck.fill = Color(VaultRuneFrame.STONE, 0.95)
	deck.border = VaultRuneFrame.SILVER
	add_child(deck)
	_vault_credit_value = _add_credit_meter(deck, Vector2(10, 11), Vector2(122, 80))
	_style_vault_credit_meter(_vault_credit_value)
	_vault_open = _action_button(
		tr("ACTION_ENTER"), Vector2(526, 442), Vector2(150, 70), Callable(cabinet, "request_open")
	)
	_vault_cash_out = _action_button(
		tr("ACTION_CASH_OUT"), Vector2(688, 442), Vector2(210, 70), Callable(cabinet, "request_cash_out")
	)
	# Break Seal burns candle-amber; Cash Out is moon-silver. Cyan stays reserved
	# for keyboard/controller focus.
	_style_vault_action(_vault_open, VaultRuneFrame.UMBER, VaultRuneFrame.AMBER, Color("f3e2c0"))
	_style_vault_action(_vault_cash_out, Color("1a1d23"), VaultRuneFrame.SILVER, Color("eef1f5"))


func _style_vault_action(button: Button, face: Color, edge: Color, text: Color) -> void:
	for state: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		button.add_theme_color_override(state, text)
	button.add_theme_color_override("font_disabled_color", Color("6f6c68"))
	button.add_theme_stylebox_override("normal", VaultRuneFrame.button_style(face, edge, 2))
	button.add_theme_stylebox_override(
		"hover", VaultRuneFrame.button_style(face.lightened(0.08), edge.lightened(0.25), 2)
	)
	button.add_theme_stylebox_override(
		"pressed", VaultRuneFrame.button_style(face.darkened(0.3), edge.lightened(0.25), 2)
	)
	button.add_theme_stylebox_override(
		"focus", VaultRuneFrame.button_style(face, Color("48c5d5"), 3)
	)
	button.add_theme_stylebox_override(
		"disabled", VaultRuneFrame.button_style(Color("16161a"), Color("3a3d44"), 1)
	)


func _style_vault_credit_meter(value: AnimatedNumberLabel) -> void:
	var plate := value.get_parent() as Panel
	if plate == null:
		return
	plate.add_theme_stylebox_override(
		"panel",
		VaultRuneFrame.button_style(VaultRuneFrame.STONE_RAISED, VaultRuneFrame.SILVER_DIM, 1)
	)
	value.add_theme_color_override("font_color", VaultRuneFrame.AMBER)
	for child: Node in plate.get_children():
		if child != value and child is Label:
			(child as Label).add_theme_color_override("font_color", VaultRuneFrame.MUTED_TEXT)


func _style_vault_stake_buttons() -> void:
	## Per-game override of the shared StakeSelector from the vault path only:
	## squared slate chips, amber for the chosen stake, cyan only on focus.
	if _stake_selector == null:
		return
	var displayed := cabinet.current_stake if cabinet.is_round_active else cabinet.selected_stake
	for child: Node in _stake_selector.get_children():
		var button := child as Button
		if button == null:
			continue
		var selected := button.text == str(displayed)
		button.add_theme_color_override("font_color", Color("ece6da"))
		button.add_theme_stylebox_override(
			"normal",
			VaultRuneFrame.button_style(
				VaultRuneFrame.UMBER if selected else VaultRuneFrame.STONE_RAISED,
				VaultRuneFrame.AMBER if selected else VaultRuneFrame.SILVER_DIM,
				2 if selected else 1
			)
		)
		button.add_theme_stylebox_override(
			"hover", VaultRuneFrame.button_style(Color("24242b"), VaultRuneFrame.SILVER, 2)
		)
		button.add_theme_stylebox_override(
			"pressed", VaultRuneFrame.button_style(VaultRuneFrame.UMBER, VaultRuneFrame.AMBER, 2)
		)
		button.add_theme_stylebox_override(
			"focus", VaultRuneFrame.button_style(VaultRuneFrame.STONE_RAISED, Color("48c5d5"), 2)
		)
		button.add_theme_stylebox_override(
			"disabled", VaultRuneFrame.button_style(Color("141418"), Color("34363c"), 1)
		)
		if not button.pressed.is_connected(_style_vault_stake_buttons):
			button.pressed.connect(_style_vault_stake_buttons)


func _add_credit_meter(parent: Control, at: Vector2, dimensions: Vector2) -> AnimatedNumberLabel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	panel.add_theme_stylebox_override(
		"panel", _panel_style(Color("17161a"), Color("6e5225"), 6, 1)
	)
	parent.add_child(panel)
	var caption := _help_label(panel, Vector2(8, 4), Vector2(dimensions.x - 16, 18), 14, Color("b8ad9c"))
	caption.text = tr("HUD_TEST_BANK") if Wallet.test_mode_enabled else tr("HUD_CREDITS")
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var value := _help_number_label(
		panel, Vector2(8, 30), Vector2(dimensions.x - 16, 38), 28, Color("f2c84b")
	)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return value


func _action_button(label: String, at: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.position = at
	button.size = dimensions
	button.z_index = 6
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", Typography.DISPLAY_FONT)
	button.add_theme_font_size_override("font_size", 16)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_color_override("font_color", Color("f1e8d8"))
	button.add_theme_color_override("font_disabled_color", Color("756d62"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("5a111c"), Color("c8a34b"), 7, 2))
	button.add_theme_stylebox_override("hover", _panel_style(Color("731827"), Color("f0c45e"), 7, 2))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("351016"), Color("f0c45e"), 7, 2))
	button.add_theme_stylebox_override("focus", _panel_style(Color("5a111c"), Color("48c5d5"), 7, 2))
	button.add_theme_stylebox_override("disabled", _panel_style(Color("252126"), Color("4b443c"), 7, 1))
	button.pressed.connect(func() -> void: action.call())
	add_child(button)
	ButtonFeedback.attach(button)
	return button



func _build_blackjack_art() -> void:
	_add_ambient(Color("e6c36a"))
	# The painted table and room carry the light; no attract arc is drawn over it.
	_ambient.visible = false
	_art_root.add_child(
		_texture("BlackjackTableArt", BLACKJACK_TABLE, Vector2.ZERO, Vector2(960, 540))
	)
	_blackjack_dealer_presenter = BlackjackDealerPresenter.new()
	_blackjack_dealer_presenter.name = "BlackjackDealerPresenter"
	# The presenter works in cabinet space: she stands centred behind the far rail,
	# the table's own rail and felt hide her from the belt down, and her hands and
	# the shoe sit in front of the rail on the felt.
	_blackjack_dealer_presenter.position = Vector2.ZERO
	_blackjack_dealer_presenter.z_index = 1
	_art_root.add_child(_blackjack_dealer_presenter)
	# Walnut-and-brass rail plate with a row of brass suit pips: Blackjack's own
	# salon identity, distinct from the other cabinets.
	_blackjack_title_plaque = BlackjackConsole.new()
	_blackjack_title_plaque.name = "BlackjackTitlePlaque"
	_blackjack_title_plaque.position = Vector2(48, 24)
	_blackjack_title_plaque.size = Vector2(252, 82)
	_blackjack_title_plaque.corner_radius = 6
	_blackjack_title_plaque.suit_row_origin = Vector2(184, 25)
	add_child(_blackjack_title_plaque)
	move_child(_blackjack_title_plaque, _title.get_index())
	_blackjack_dealer_total_panel = _blackjack_total_badge("DealerTotalBadge")
	_blackjack_dealer_total = _blackjack_badge_label(_blackjack_dealer_total_panel, "DealerTotal")
	_blackjack_player_total_panel = _blackjack_total_badge("PlayerTotalBadge")
	_blackjack_player_total = _blackjack_badge_label(_blackjack_player_total_panel, "PlayerTotal")
	_blackjack_bet_stack = BLACKJACK_BET_STACK.new()
	_blackjack_bet_stack.name = "BlackjackBetStack"
	_blackjack_bet_stack.position = BlackjackBetStack.TABLE_POSITION
	_blackjack_bet_stack.size = BlackjackBetStack.STACK_SIZE
	_blackjack_bet_stack.z_index = 8
	_blackjack_bet_stack.hide()
	_art_root.add_child(_blackjack_bet_stack)
	_blackjack_result_banner = Panel.new()
	_blackjack_result_banner.name = "BlackjackResultBanner"
	_blackjack_result_banner.position = BLACKJACK_PLAQUE_RECT.position
	_blackjack_result_banner.size = BLACKJACK_PLAQUE_RECT.size
	_blackjack_result_banner.pivot_offset = BLACKJACK_PLAQUE_RECT.size * 0.5
	_blackjack_result_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackjack_result_banner.z_index = 12
	_blackjack_result_banner.add_theme_stylebox_override(
		"panel", _panel_style(Color("17161af2"), Color("c8a34b"), 5, 2)
	)
	_blackjack_result_banner.hide()
	add_child(_blackjack_result_banner)
	_blackjack_result_text = _help_label(
		_blackjack_result_banner,
		Vector2(6, 1),
		BLACKJACK_PLAQUE_RECT.size - Vector2(12, 2),
		18,
		BLACKJACK_TEXT
	)
	_blackjack_result_text.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_blackjack_result_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blackjack_result_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_build_blackjack_deck()


## Small near-black total badge with a brass hairline, attached beside a hand.
func _blackjack_total_badge(node_name: String) -> Panel:
	var badge := Panel.new()
	badge.name = node_name
	badge.size = BLACKJACK_BADGE_SIZE
	badge.z_index = 5
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override("panel", _panel_style(Color("17161aee"), Color("c8a34b"), 5, 1))
	badge.hide()
	add_child(badge)
	return badge


func _blackjack_badge_label(badge: Panel, node_name: String) -> AnimatedNumberLabel:
	var label := _help_number_label(
		badge, Vector2(4, 0), BLACKJACK_BADGE_SIZE - Vector2(8, 0), 15, BLACKJACK_TEXT
	)
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", BLACKJACK_TEXT)
	return label



func _apply_blackjack_fullscreen_layout() -> void:
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("160b0b")
	# Title and live status share one brass-framed plaque in the top-left corner so
	# the dealer stands clear in the centre of the room.
	_title.position = Vector2(62, 29)
	_title.size = Vector2(170, 40)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color("f5e6bd"))
	_stake.position = Vector2(82, 469)
	_stake.size = Vector2(210, 44)
	_stake.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(62, 68)
	_status.size = Vector2(226, 36)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.max_lines_visible = 2
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
	_stake_selector.position = Vector2(184, 438)
	_stake_selector.size = Vector2(340, 80)
	_stake_selector.z_index = 6



func _render_blackjack_hand(player_cards: Array[int], dealer_cards: Array[int], hide_hole: bool) -> void:
	if not _blackjack_dealt and not player_cards.is_empty():
		_clear_blackjack_cards()
		_blackjack_dealt = true
	var cards_before := _blackjack_cards.size()
	var deal_index: int = 0
	var initial_deal := cards_before == 0
	# Keep the stable dealer-then-player node order used by result presentation,
	# while assigning initial travel delays in physical P/D/P/D order.
	for index: int in range(dealer_cards.size()):
		var dealer_stagger := index * 2 + 1 if initial_deal else deal_index
		if _sync_playing_card(
			dealer_cards[index],
			index,
			dealer_cards.size(),
			true,
			hide_hole and index == 1,
			dealer_stagger
		) and not initial_deal:
			deal_index += 1
	for index: int in range(player_cards.size()):
		var player_stagger := index * 2 if initial_deal else deal_index
		if _sync_playing_card(
			player_cards[index], index, player_cards.size(), false, false, player_stagger
		) and not initial_deal:
			deal_index += 1
	var newly_dealt := _blackjack_cards.size() - cards_before
	if newly_dealt > 0 and _blackjack_dealer_presenter != null:
		_blackjack_dealer_presenter.play_deal(newly_dealt)
	_place_blackjack_badges(dealer_cards.size(), player_cards.size())
	if _blackjack_preparing:
		_blackjack_preparing = false
		_complete_blackjack_motion()


## Total badges ride beside the right edge of each hand, vertically centred on it.
func _blackjack_badge_position(hand_size: int, dealer_hand: bool) -> Vector2:
	var first: Dictionary = _blackjack_card_layout(0, maxi(hand_size, 1), dealer_hand)
	var last: Dictionary = _blackjack_card_layout(
		maxi(hand_size, 1) - 1, maxi(hand_size, 1), dealer_hand
	)
	var card_size: Vector2 = first.size
	var right := (last.position as Vector2).x + card_size.x
	var base_y := BLACKJACK_DEALER_CARD_Y if dealer_hand else BLACKJACK_PLAYER_CARD_Y
	return Vector2(
		right + BLACKJACK_BADGE_GAP,
		base_y + card_size.y * 0.5 - BLACKJACK_BADGE_SIZE.y * 0.5
	)


func _place_blackjack_badges(dealer_count: int, player_count: int) -> void:
	if _blackjack_dealer_total_panel == null:
		return
	if _blackjack_badge_tween != null and _blackjack_badge_tween.is_valid():
		_blackjack_badge_tween.kill()
	_blackjack_badge_tween = null
	var animate := not MotionPolicy.is_reduced()
	for entry: Array in [
		[_blackjack_dealer_total_panel, dealer_count, true],
		[_blackjack_player_total_panel, player_count, false],
	]:
		var badge: Panel = entry[0]
		var count: int = entry[1]
		var target := _blackjack_badge_position(count, entry[2])
		if count <= 0:
			badge.hide()
			continue
		if not badge.visible or not animate:
			badge.position = target
			badge.show()
			continue
		if badge.position == target:
			continue
		if _blackjack_badge_tween == null:
			_blackjack_badge_tween = create_tween().set_parallel(true)
		_blackjack_badge_tween.tween_property(badge, "position", target, 0.20).set_trans(
			Tween.TRANS_CUBIC
		).set_ease(Tween.EASE_OUT)


func prepare_blackjack_round() -> void:
	_reset_blackjack_result_feedback_for_round()
	_settle_blackjack_card_motions()
	_blackjack_dealt = false
	_blackjack_preparing = true
	_blackjack_pending_motions = 1


func blackjack_input_ready() -> bool:
	return _blackjack_pending_motions == 0 and not _result_reveal_active


func _clear_blackjack_cards() -> void:
	for card_id: int in _blackjack_card_tweens.keys():
		_cancel_blackjack_card_motion(card_id)
	for card: PlayingCard in _blackjack_cards:
		if is_instance_valid(card):
			# Detach now so the next deal can reuse the DealerCardN / PlayerCardN
			# names; a queued node would force a renamed duplicate on re-sync.
			if card.get_parent() != null:
				card.get_parent().remove_child(card)
			card.queue_free()
	_blackjack_cards.clear()
	_blackjack_layout_targets.clear()


func _sync_playing_card(
	rank: int, hand_index: int, hand_size: int, dealer_hand: bool, hidden: bool, deal_index: int
) -> bool:
	var card_name := ("DealerCard" if dealer_hand else "PlayerCard") + str(hand_index)
	for card: PlayingCard in _blackjack_cards:
		if card.name == card_name:
			_reflow_blackjack_card(card, _blackjack_card_layout(hand_index, hand_size, dealer_hand))
			var tracks_flip := card.face_down and not hidden and card.is_inside_tree()
			if tracks_flip:
				_blackjack_pending_motions += 1
				card.flip_completed.connect(
					_on_blackjack_flip_completed.bind(card.get_instance_id()), CONNECT_ONE_SHOT
				)
				AudioService.play(&"card_flip")
				if _blackjack_dealer_presenter != null:
					_blackjack_dealer_presenter.play_reveal()
			card.set_face_down(hidden, card.face_down and not hidden)
			return false
	_add_playing_card(rank, hand_index, hand_size, dealer_hand, hidden, deal_index)
	return true



func _blackjack_card_layout(hand_index: int, hand_size: int, dealer_hand: bool) -> Dictionary:
	var safe_hand_size := maxi(hand_size, 1)
	var card_size := BLACKJACK_DEALER_CARD if dealer_hand else BLACKJACK_PLAYER_CARD
	# Cards overlap like a real layout: every rank index stays visible, and even a
	# long hand stays inside the felt lane between the wager and the total badge.
	var card_pitch := minf(
		card_size.x * 0.5, (BLACKJACK_HAND_MAX_WIDTH - card_size.x) / maxf(safe_hand_size - 1, 1)
	)
	var hand_width := card_size.x + maxi(safe_hand_size - 1, 0) * card_pitch
	var fan := float(hand_index) - float(safe_hand_size - 1) * 0.5
	var base_y := BLACKJACK_DEALER_CARD_Y if dealer_hand else BLACKJACK_PLAYER_CARD_Y
	return {
		"size": card_size,
		# Half-pixel snapping keeps Control offsets exact, so size never drifts.
		"position": Vector2(
			snappedf(BLACKJACK_HAND_CENTER_X - hand_width * 0.5 + hand_index * card_pitch, 0.5),
			snappedf(base_y + absf(fan) * 0.6, 0.5)
		),
		"rotation": fan * 0.018,
	}


func _reflow_blackjack_card(card: PlayingCard, layout: Dictionary) -> void:
	var card_id := card.get_instance_id()
	var previous: Dictionary = _blackjack_layout_targets.get(card_id, {})
	_blackjack_layout_targets[card_id] = layout
	if (
		previous.get("size", Vector2.ZERO) == layout.size
		and previous.get("position", Vector2.ZERO) == layout.position
		and is_equal_approx(float(previous.get("rotation", INF)), float(layout.rotation))
	):
		return
	_cancel_blackjack_card_motion(card_id)
	if MotionPolicy.is_reduced() or not card.is_inside_tree():
		_apply_blackjack_card_layout(card, layout)
		return
	_blackjack_pending_motions += 1
	var reflow := create_tween().set_parallel(true)
	_blackjack_card_tweens[card_id] = reflow
	reflow.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	reflow.tween_property(card, "position", layout.position, 0.20)
	reflow.tween_property(card, "size", layout.size, 0.20)
	reflow.tween_property(card, "rotation", layout.rotation, 0.20)
	reflow.tween_property(card, "scale", Vector2.ONE, 0.20)
	reflow.tween_property(card, "modulate:a", 1.0, 0.12)
	reflow.finished.connect(_finish_blackjack_card_motion.bind(card_id))



func _apply_blackjack_card_layout(card: PlayingCard, layout: Dictionary) -> void:
	card.position = layout.position
	card.size = layout.size
	card.rotation = layout.rotation
	card.scale = Vector2.ONE
	card.pivot_offset = card.size * 0.5


func _cancel_blackjack_card_motion(card_id: int) -> void:
	var motion: Tween = _blackjack_card_tweens.get(card_id)
	if motion == null:
		return
	if motion.is_valid():
		motion.kill()
	_blackjack_card_tweens.erase(card_id)
	_complete_blackjack_motion()


func _finish_blackjack_card_motion(card_id: int) -> void:
	var card := _blackjack_card_for_id(card_id)
	var layout: Dictionary = _blackjack_layout_targets.get(card_id, {})
	if is_instance_valid(card) and not layout.is_empty():
		_apply_blackjack_card_layout(card, layout)
		card.modulate.a = 1.0
	_blackjack_card_tweens.erase(card_id)
	_complete_blackjack_motion()


func _blackjack_card_for_id(card_id: int) -> PlayingCard:
	for card: PlayingCard in _blackjack_cards:
		if card.get_instance_id() == card_id:
			return card
	return null


func _settle_blackjack_card_motions() -> void:
	for card_id: int in _blackjack_card_tweens.keys():
		var card := _blackjack_card_for_id(card_id)
		var layout: Dictionary = _blackjack_layout_targets.get(card_id, {})
		_cancel_blackjack_card_motion(card_id)
		if is_instance_valid(card) and not layout.is_empty():
			_apply_blackjack_card_layout(card, layout)
			card.modulate.a = 1.0



func _add_playing_card(
	rank: int, hand_index: int, hand_size: int, dealer_hand: bool, hidden: bool, deal_index: int
) -> void:
	var card := PlayingCard.new()
	card.name = ("DealerCard" if dealer_hand else "PlayerCard") + str(hand_index)
	card.z_index = 2
	var layout := _blackjack_card_layout(hand_index, hand_size, dealer_hand)
	card.size = layout.size
	card.pivot_offset = card.size * 0.5
	card.configure(rank, rank + hand_index + (0 if dealer_hand else 2), hidden)
	# Every card leaves the shoe's finger slot small (it is further from the
	# camera), slides past the dealer's dealing hand and settles onto its spot.
	var release := (
		_blackjack_dealer_presenter.card_release_point()
		if _blackjack_dealer_presenter != null
		else BlackjackDealerPresenter.SHOE_MOUTH
	)
	var via := (
		_blackjack_dealer_presenter.card_via_point()
		if _blackjack_dealer_presenter != null
		else release
	)
	card.position = release - card.size * 0.5
	card.rotation = BLACKJACK_SHOE_ROTATION
	card.scale = Vector2.ONE * BLACKJACK_SHOE_SCALE
	card.modulate.a = 0.0
	if MotionPolicy.is_reduced():
		_apply_blackjack_card_layout(card, layout)
		card.modulate.a = 1.0
	_art_root.add_child(card)
	_blackjack_cards.append(card)
	_blackjack_layout_targets[card.get_instance_id()] = layout
	AudioService.play(&"card_deal")
	if MotionPolicy.is_reduced():
		return
	_blackjack_pending_motions += 1
	var deal := create_tween()
	deal.tween_interval(deal_index * BLACKJACK_DEAL_STAGGER)
	deal.tween_property(card, "modulate:a", 1.0, 0.05)
	(
		deal
		. parallel()
		. tween_method(
			_move_blackjack_card_along_deal.bind(card, release, via, layout),
			0.0,
			1.0,
			BLACKJACK_DEAL_SECONDS
		)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	var card_id := card.get_instance_id()
	_blackjack_card_tweens[card_id] = deal
	deal.finished.connect(_finish_blackjack_card_motion.bind(card_id))


## One deal step: a short curved slide from the shoe past the dealing hand, the
## card growing to full size as it nears the player and rotating into place.
func _move_blackjack_card_along_deal(
	progress: float, card: PlayingCard, release: Vector2, via: Vector2, layout: Dictionary
) -> void:
	if not is_instance_valid(card):
		return
	var card_size: Vector2 = layout.size
	var target: Vector2 = (layout.position as Vector2) + card_size * 0.5
	var inverse := 1.0 - progress
	var centre := (
		release * inverse * inverse + via * 2.0 * inverse * progress + target * progress * progress
	)
	card.position = centre - card_size * 0.5
	card.scale = Vector2.ONE * lerpf(BLACKJACK_SHOE_SCALE, 1.0, progress)
	card.rotation = lerpf(BLACKJACK_SHOE_ROTATION, float(layout.rotation), progress)


func _complete_blackjack_motion() -> void:
	_blackjack_pending_motions = maxi(0, _blackjack_pending_motions - 1)
	_try_complete_result_reveal()


func _on_blackjack_flip_completed(card_id: int) -> void:
	var card := _blackjack_card_for_id(card_id)
	var layout: Dictionary = _blackjack_layout_targets.get(card_id, {})
	if is_instance_valid(card) and not layout.is_empty():
		_apply_blackjack_card_layout(card, layout)
	_complete_blackjack_motion()


func _try_complete_result_reveal() -> void:
	if not _result_reveal_active:
		return
	if _blackjack_pending_motions > 0 or _vault_pending_reveals > 0:
		return
	if _result_reveal_beat != null and _result_reveal_beat.is_running():
		return
	_result_reveal_beat = create_tween()
	_result_reveal_beat.tween_interval(MotionPolicy.finite_duration(RESULT_READABLE_BEAT))
	_result_reveal_beat.tween_callback(_complete_result_reveal)


func _complete_result_reveal() -> void:
	if not _result_reveal_active:
		return
	_result_reveal_active = false
	var callback := _result_reveal_callback
	_result_reveal_callback = Callable()
	if callback.is_valid():
		callback.call()


func _build_vault_art() -> void:
	_add_ambient(VaultRuneFrame.AMBER)
	# The painted candles carry the light; the sci-fi scan/ring attract is off-theme.
	_ambient.visible = false
	_art_root.add_child(
		_texture("VaultBackdropArt", VAULT_BACKDROP, Vector2.ZERO, Vector2(960, 540))
	)
	var veil := ColorRect.new()
	veil.position = Vector2.ZERO
	veil.size = Vector2(960, 540)
	veil.color = Color("05060833")
	_art_root.add_child(veil)
	# A flat slate bed seats the 5x5 rune tiles inside the crypt alcove.
	var grid_span := 4.0 * VAULT_GRID_PITCH + VAULT_TILE_SIZE
	var grid_bed := VaultRuneFrame.new()
	grid_bed.name = "VaultGridBed"
	grid_bed.position = VAULT_GRID_ORIGIN - Vector2(10, 10)
	grid_bed.size = Vector2(grid_span + 20.0, grid_span + 20.0)
	grid_bed.fill = Color("0a0a0dcc")
	_art_root.add_child(grid_bed)
	# Right lane: the sorceress stands on the crypt flagstones, turned to the grid.
	_vault_attendant = VAULT_ATTENDANT_SCRIPT.new()
	_vault_attendant.z_index = 1
	_art_root.add_child(_vault_attendant)
	for index: int in range(25):
		var tile := VaultTile.new()
		tile.name = "VaultTile%02d" % index
		tile.position = VAULT_GRID_ORIGIN + Vector2(
			(index % 5) * VAULT_GRID_PITCH, (index / 5) * VAULT_GRID_PITCH
		)
		tile.size = Vector2.ONE * VAULT_TILE_SIZE
		tile.reveal_effect_requested.connect(_on_vault_reveal_effect.bind(tile))
		tile.reveal_completed.connect(_on_vault_reveal_completed)
		tile.pointer_focused.connect(_on_vault_tile_pointer_focused.bind(index))
		tile.pointer_activated.connect(_on_vault_tile_pointer_activated.bind(index))
		_vault_tiles.append(tile)
		_art_root.add_child(tile)
	_vault_cursor = Node2D.new()
	_vault_cursor.name = "SnapCursorArt"
	for border: Rect2 in [
		Rect2(0, 0, 60, 3),
		Rect2(0, 57, 60, 3),
		Rect2(0, 0, 3, 60),
		Rect2(57, 0, 3, 60),
	]:
		var edge := ColorRect.new()
		edge.position = border.position
		edge.size = border.size
		edge.color = Color("00e5ff")
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vault_cursor.add_child(edge)
	_art_root.add_child(_vault_cursor)
	_vault_cursor.position = VAULT_GRID_ORIGIN - Vector2(2, 2)
	_build_vault_deck()


func _vault_pointer_can_target(index: int) -> bool:
	if (
		cabinet == null
		or cabinet.context == null
		or cabinet.context.definition.id != &"minefield_vault"
		or not cabinet.is_round_active
		or cabinet.is_result_pending
		or help_open
		or _vault_pending_reveals > 0
		or index < 0
		or index >= _vault_tiles.size()
	):
		return false
	var math: MinefieldMath = cabinet.get("math")
	return not math.revealed.has(index) and not _vault_tiles[index].is_flipping


func _refresh_vault_pointer_interaction() -> void:
	for index: int in range(_vault_tiles.size()):
		_vault_tiles[index].set_interaction_enabled(_vault_pointer_can_target(index))


func _on_vault_tile_pointer_focused(index: int) -> void:
	if not _vault_pointer_can_target(index):
		return
	cabinet.call("request_select_tile", index)


func _on_vault_tile_pointer_activated(index: int) -> void:
	if not _vault_pointer_can_target(index):
		return
	cabinet.call("request_open_tile", index)


func _on_vault_reveal_effect(face_value: int, local_origin: Vector2, tile: VaultTile) -> void:
	var mine_hit := face_value == VaultTile.Face.MINE
	if not mine_hit:
		AudioService.play(&"vault_safe")
	if _vault_attendant != null:
		if mine_hit:
			_vault_attendant.warn_mine()
		else:
			_vault_attendant.acknowledge_safe()
	VAULT_REVEAL_FX.spawn(
		_art_root,
		tile.position + local_origin,
		VAULT_REVEAL_FX.Kind.MINE if mine_hit else VAULT_REVEAL_FX.Kind.SAFE
	)
	if mine_hit:
		_shake_stage(5.0, 0.22)


func _on_vault_reveal_completed(_face_value: int) -> void:
	_vault_pending_reveals = maxi(0, _vault_pending_reveals - 1)
	if _vault_pending_reveals == 0:
		_refresh_vault_pointer_interaction()
	_try_complete_result_reveal()


func _apply_vault_fullscreen_layout() -> void:
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("08080b")
	_title.position = Vector2(300, 22)
	_title.size = Vector2(360, 54)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 32)
	_title.add_theme_color_override("font_color", VaultRuneFrame.SILVER_TEXT)
	if _help_button != null:
		_help_button.add_theme_stylebox_override(
			"normal", VaultRuneFrame.button_style(Color("111115f0"), VaultRuneFrame.SILVER_DIM, 1)
		)
		_help_button.add_theme_stylebox_override(
			"hover", VaultRuneFrame.button_style(Color("1d1d24"), VaultRuneFrame.SILVER, 1)
		)
		_help_button.add_theme_stylebox_override(
			"focus", VaultRuneFrame.button_style(Color("1d1d24"), Color("48c5d5"), 2)
		)
		_help_button.add_theme_color_override("font_color", VaultRuneFrame.SILVER_TEXT)
	_stake.position = Vector2(64, 444)
	_stake.size = Vector2(250, 44)
	_stake.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.position = Vector2(62, 164)
	_status.size = Vector2(252, 94)
	_status.z_index = 6
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color("ece6da"))
	_detail.position = Vector2(676, 342)
	_detail.size = Vector2(220, 58)
	_detail.z_index = 6
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_detail.hide()
	_controls_backdrop.position = Vector2(72, 501)
	_controls_backdrop.size = Vector2(816, 32)
	_controls.position = Vector2(82, 505)
	_controls.size = Vector2(796, 24)
	_controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_controls.add_theme_font_size_override("font_size", 16)
	_stake_selector.position = Vector2(184, 434)
	_stake_selector.size = Vector2(340, 80)
	_stake_selector.z_index = 6


func _refresh_slot() -> void:
	if _slot_credit_value == null:
		return
	# The slot presents its Elven Court theme name on the painted plaque.
	_title.text = tr("SLOT_THEME_TITLE")
	_apply_slot_elven_stake_theme()
	var displayed_credit: int = cabinet.context.balance
	if cabinet.is_round_active:
		displayed_credit = maxi(0, displayed_credit - cabinet.current_stake)
	if Wallet.test_mode_enabled:
		_slot_credit_value.set_infinity()
	else:
		_slot_credit_value.set_number(displayed_credit)
	if _result != null:
		var multiplier: int = _result.payout / maxi(_result.stake, 1)
		_set_live_text(_slot_result_value, tr("SLOT_RETURNED") % _result.payout)
		_set_live_text(_slot_result_formula, (
			tr("SLOT_RESULT_FORMULA") % [_result.stake, multiplier, _result.payout]
		))
	elif cabinet.is_round_active:
		_set_live_text(_slot_result_value, tr("ROUND_SPINNING"))
		_set_live_text(_slot_result_formula, tr("SLOT_BET_IN_PLAY") % cabinet.current_stake)
	else:
		_set_live_text(_slot_result_value, tr("SLOT_RETURNED") % 0)
		_set_live_text(_slot_result_formula, tr("SLOT_IDLE_FORMULA") % cabinet.selected_stake)
	_set_action_disabled(_slot_spin_label, (
		cabinet.is_round_active
		or help_open
		or cabinet.selected_stake > cabinet.context.balance
	))
	if _slot_lever != null:
		_slot_lever.disabled = _slot_spin_label.disabled
		_slot_lever.queue_redraw()
	_slot_spin_label.queue_redraw()


func _set_live_text(control: Control, next_text: String) -> void:
	## Presentation-only semantic handoff. Gameplay state is already authoritative
	## before this method is called; this only makes the new state readable.
	if control == null:
		return
	var control_id := control.get_instance_id()
	_state_controls[control_id] = control
	if not _state_rest_positions.has(control_id):
		_state_rest_positions[control_id] = control.position
	var previous_text := String(control.get("text"))
	var has_previous_state := _state_text_cache.has(control_id)
	_state_text_cache[control_id] = next_text
	if previous_text == next_text:
		return
	control.set("text", next_text)
	_stop_state_feedback(control_id)
	_settle_state_control(control)
	if not has_previous_state or MotionPolicy.is_reduced() or not control.is_inside_tree():
		return
	var rest_position: Vector2 = _state_rest_positions[control_id]
	control.position = rest_position + Vector2(0.0, 4.0)
	control.modulate.a = 0.56
	var tween := create_tween().set_parallel(true)
	_state_feedback_tweens[control_id] = tween
	tween.tween_property(control, "position", rest_position, 0.18).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(_finish_state_feedback.bind(control_id))


func _set_action_disabled(button: BaseButton, disabled: bool) -> void:
	if button == null:
		return
	var control_id := button.get_instance_id()
	_action_controls[control_id] = button
	var had_previous_state := _action_disabled_cache.has(control_id)
	var was_disabled := bool(_action_disabled_cache.get(control_id, button.disabled))
	_action_disabled_cache[control_id] = disabled
	button.disabled = disabled
	if not had_previous_state or was_disabled == disabled:
		return
	_stop_action_enable_feedback(control_id)
	_settle_action_control(button)
	if disabled or MotionPolicy.is_reduced() or not button.is_inside_tree():
		return
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2(0.955, 0.955)
	button.modulate = Color("fff0cf")
	var tween := create_tween().set_parallel(true)
	_action_enable_tweens[control_id] = tween
	tween.tween_property(button, "scale", Vector2.ONE, 0.22).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_QUAD)
	tween.finished.connect(_finish_action_enable_feedback.bind(control_id))


func _stop_state_feedback(control_id: int) -> void:
	var tween: Tween = _state_feedback_tweens.get(control_id)
	if tween != null and tween.is_valid():
		tween.kill()
	_state_feedback_tweens.erase(control_id)


func _finish_state_feedback(control_id: int) -> void:
	var control: Control = _state_controls.get(control_id)
	if is_instance_valid(control):
		_settle_state_control(control)
	_state_feedback_tweens.erase(control_id)


func _settle_state_control(control: Control) -> void:
	var control_id := control.get_instance_id()
	if _state_rest_positions.has(control_id):
		control.position = _state_rest_positions[control_id]
	control.modulate.a = 1.0


func _stop_action_enable_feedback(control_id: int) -> void:
	var tween: Tween = _action_enable_tweens.get(control_id)
	if tween != null and tween.is_valid():
		tween.kill()
	_action_enable_tweens.erase(control_id)


func _finish_action_enable_feedback(control_id: int) -> void:
	var control: BaseButton = _action_controls.get(control_id)
	if is_instance_valid(control):
		_settle_action_control(control)
	_action_enable_tweens.erase(control_id)


func _settle_action_control(button: BaseButton) -> void:
	button.scale = Vector2.ONE
	button.modulate = Color.WHITE


func _apply_live_feedback_motion_preference(reduced: bool) -> void:
	if not reduced:
		return
	_settle_slot_spin_motion()
	_settle_blackjack_card_motions()
	_settle_slot_lever_motion()
	if _help_tween != null and _help_tween.is_valid():
		set_help_open(help_open)
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
	_entrance_tween = null
	if _art_root != null:
		_art_root.position = Vector2.ZERO
		_art_root.modulate.a = 1.0
	if _cursor_tween != null and _cursor_tween.is_valid():
		_cursor_tween.kill()
	_cursor_tween = null
	if _blackjack_fx_tween != null and _blackjack_fx_tween.is_valid():
		_blackjack_fx_tween.kill()
	_blackjack_fx_tween = null
	if _blackjack_result_banner != null:
		_blackjack_result_banner.position = BLACKJACK_PLAQUE_RECT.position
		_blackjack_result_banner.modulate.a = 1.0
		_blackjack_result_banner.scale = Vector2.ONE
	for label: Label in [_blackjack_player_total, _blackjack_dealer_total]:
		if label != null:
			label.scale = Vector2.ONE
	if _blackjack_badge_tween != null and _blackjack_badge_tween.is_valid():
		_blackjack_badge_tween.kill()
		_blackjack_badge_tween = null
		var math: BlackjackMath = cabinet.get("math") if cabinet != null else null
		if math != null:
			_place_blackjack_badges(math.dealer.size(), math.player.size())
	if _vault_fx_tween != null and _vault_fx_tween.is_valid():
		_vault_fx_tween.kill()
	_vault_fx_tween = null
	if _vault_cursor != null:
		_vault_cursor.scale = Vector2.ONE
	if _result_impact_tween != null and _result_impact_tween.is_valid():
		_result_impact_tween.kill()
	_result_impact_tween = null
	_reset_slot_win_feedback()
	_reset_slot_result_ticker()
	if _result != null and _slot_result_value != null:
		_slot_result_value.text = tr("SLOT_RETURNED") % _result.payout
	for control_id: int in _state_feedback_tweens.keys():
		_stop_state_feedback(control_id)
	for control: Control in _state_controls.values():
		if is_instance_valid(control):
			_settle_state_control(control)
	for control_id: int in _action_enable_tweens.keys():
		_stop_action_enable_feedback(control_id)
	for button: BaseButton in _action_controls.values():
		if is_instance_valid(button):
			_settle_action_control(button)
	refresh()


func _settle_slot_spin_motion() -> void:
	if not _slot_spinning:
		return
	for reel_index: int in range(_slot_reel_cells.size()):
		_slot_offsets[reel_index] = _slot_total_offsets[reel_index]
		_update_spinning_reel(reel_index)
		_slot_reels[reel_index].position.y = SLOT_REEL_TOP
		for cell: SlotSymbol in _slot_reel_cells[reel_index]:
			cell.set_spin_strength(0.0)
	_slot_anticipating_third = false
	if _slot_anticipation_frame != null:
		_slot_anticipation_frame.visible = false
		_slot_anticipation_frame.modulate.a = 1.0


func has_live_state_feedback() -> bool:
	return not _state_feedback_tweens.is_empty() or not _action_enable_tweens.is_empty()


func has_active_motion() -> bool:
	return (
		_slot_spinning
		or (_motion_tween != null and _motion_tween.is_running())
		or (_entrance_tween != null and _entrance_tween.is_running())
		or (_cursor_tween != null and _cursor_tween.is_running())
		or (_blackjack_fx_tween != null and _blackjack_fx_tween.is_running())
		or (_vault_fx_tween != null and _vault_fx_tween.is_running())
		or (_result_impact_tween != null and _result_impact_tween.is_running())
		or (_win_flash != null and _win_flash.is_playing())
		or has_live_state_feedback()
		or _result_reveal_active
	)


func _play_art_entrance() -> void:
	_art_root.modulate.a = 0.0
	_art_root.position.y = 0.0 if MotionPolicy.is_reduced() else 8.0
	_entrance_tween = create_tween().set_parallel(true)
	_entrance_tween.tween_property(
		_art_root, "modulate:a", 1.0, MotionPolicy.finite_duration(0.2)
	)
	if not MotionPolicy.is_reduced():
		_entrance_tween.tween_property(_art_root, "position:y", 0.0, 0.2)


func _start_slot_motion() -> void:
	_stop_motion()
	if _slot_reels.is_empty():
		return
	if _slot_hostess != null:
		_slot_hostess.watch_spin()
	_slot_spin_elapsed = 0.0
	var duration_scale := MotionPolicy.REDUCED_DURATION_SCALE if MotionPolicy.is_reduced() else 1.0
	for index: int in range(_slot_stop_times.size()):
		_slot_stop_times[index] *= duration_scale
	_slot_offsets = [0.0, 0.0, 0.0]
	_slot_stopped = [false, false, false]
	_slot_spinning = true
	for reel_cells: Array in _slot_reel_cells:
		for cell: SlotSymbol in reel_cells:
			cell.set_spin_strength(0.18 if MotionPolicy.is_reduced() else 1.0)
	if _slot_lever != null and not MotionPolicy.is_reduced():
		_slot_lever.rotation = 0.0
		_motion_tween = create_tween()
		_motion_tween.tween_property(_slot_lever, "rotation", 2.15, 0.14).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN)
		_motion_tween.tween_property(_slot_lever, "rotation", 0.0, 0.22).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
		_motion_tween.finished.connect(_settle_slot_lever_motion)
	elif _slot_lever != null:
		_settle_slot_lever_motion()
	elif _slot_spin_label != null and not MotionPolicy.is_reduced():
		_slot_spin_label.scale = Vector2.ONE
		_slot_spin_label.pivot_offset = _slot_spin_label.size * 0.5
		_motion_tween = create_tween()
		_motion_tween.tween_property(_slot_spin_label, "scale", Vector2(0.88, 0.88), 0.12)
		_motion_tween.tween_property(_slot_spin_label, "scale", Vector2.ONE, 0.16).set_trans(
			Tween.TRANS_BACK
		)


func _stop_motion() -> void:
	_slot_spinning = false
	if _slot_anticipation_frame != null:
		_slot_anticipation_frame.visible = false
		_slot_anticipation_frame.modulate.a = 1.0
	if _motion_tween != null:
		_motion_tween.kill()
		_motion_tween = null
	_settle_slot_lever_motion()


func _settle_slot_lever_motion() -> void:
	if _motion_tween != null and _motion_tween.is_valid():
		_motion_tween.kill()
	_motion_tween = null
	if _slot_lever != null:
		_slot_lever.settle()


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


func _slot_motion_progress(linear_progress: float) -> float:
	var progress := clampf(linear_progress, 0.0, 1.0)
	if progress < 0.18:
		var acceleration := progress / 0.18
		return 0.12 * acceleration * acceleration
	if progress < 0.72:
		return 0.12 + (progress - 0.18) * (0.68 / 0.54)
	var braking := (progress - 0.72) / 0.28
	return 0.80 + 0.20 * (1.0 - pow(1.0 - braking, 2.0))


func _stop_reel(reel_index: int, emit_impact: bool = true) -> void:
	if reel_index >= _slot_reel_cells.size():
		return
	_slot_offsets[reel_index] = _slot_total_offsets[reel_index]
	_update_spinning_reel(reel_index)
	_slot_stopped[reel_index] = true
	if reel_index == 2:
		_slot_anticipating_third = false
		if _slot_anticipation_frame != null:
			_slot_anticipation_frame.visible = false
			_slot_anticipation_frame.modulate.a = 1.0
	for cell: SlotSymbol in _slot_reel_cells[reel_index]:
		create_tween().tween_method(
			cell.set_spin_strength, cell.spin_strength, 0.0, MotionPolicy.finite_duration(0.18)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var reel: Control = _slot_reels[reel_index]
	if emit_impact:
		AudioService.play(&"reel_stop")
	if emit_impact and not MotionPolicy.is_reduced():
		ImpactBurst.spawn(
			_art_root,
			reel.position + Vector2(reel.size.x * 0.5, reel.size.y * 0.5),
			Color("f2c84b"),
			false
		)
	if MotionPolicy.is_reduced():
		reel.position.y = SLOT_REEL_TOP
	else:
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
	label.add_theme_font_override("font", Typography.UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e8e6f0"))
	add_child(label)
	return label


func _number_label(at: Vector2, font_size: int) -> AnimatedNumberLabel:
	var label := AnimatedNumberLabel.new()
	label.position = at
	label.add_theme_font_override("font", Typography.UI_FONT)
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
	label.add_theme_font_override("font", Typography.UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _help_number_label(
	parent: Control, at: Vector2, dimensions: Vector2, font_size: int, color: Color
) -> AnimatedNumberLabel:
	var label := AnimatedNumberLabel.new()
	label.position = at
	label.size = dimensions
	label.add_theme_font_override("font", Typography.UI_FONT)
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
	style.shadow_color = Color("05040566")
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	return style


func _add_ambient(color: Color) -> void:
	_ambient = CasinoAmbient.new()
	_ambient.name = "CasinoAmbient"
	_ambient.size = Vector2(960, 110)
	_ambient.accent = color
	_ambient.mode = {
		&"slot_classic": CasinoAmbient.Mode.SLOT,
		&"blackjack": CasinoAmbient.Mode.BLACKJACK,
		&"minefield_vault": CasinoAmbient.Mode.VAULT,
	}.get(cabinet.context.definition.id, CasinoAmbient.Mode.LOBBY)
	_ambient.z_index = 10
	_art_root.add_child(_ambient)



func _animate_blackjack_result(result: RoundResult) -> void:
	if _blackjack_fx_tween != null and _blackjack_fx_tween.is_valid():
		_blackjack_fx_tween.kill()
	_blackjack_fx_tween = null
	var copy := _blackjack_result_copy(result)
	var ink: Color = copy[1]
	if _blackjack_result_banner != null:
		_blackjack_result_text.text = copy[0]
		_blackjack_result_text.add_theme_color_override("font_color", ink)
		_blackjack_result_banner.show()
		_blackjack_result_banner.position = BLACKJACK_PLAQUE_RECT.position
		_blackjack_result_banner.modulate.a = 1.0
		_blackjack_result_banner.scale = Vector2.ONE
	if _blackjack_bet_stack != null:
		_blackjack_bet_stack.settle(copy[2], result.stake, result.payout)
	if _blackjack_dealer_presenter != null:
		_blackjack_dealer_presenter.play_result(ink, result.payout > result.stake)
	if _blackjack_player_total != null:
		_blackjack_player_total.add_theme_color_override(
			"font_color", ink if result.payout != result.stake else BLACKJACK_TEXT
		)
	if MotionPolicy.is_reduced():
		return
	# One composed beat: the plaque settles onto the felt between the hands.
	_blackjack_fx_tween = create_tween().set_parallel(true)
	_blackjack_result_banner.modulate.a = 0.0
	_blackjack_result_banner.position = BLACKJACK_PLAQUE_RECT.position + Vector2(0, 6)
	_blackjack_result_banner.scale = Vector2(0.97, 0.97)
	_blackjack_fx_tween.tween_property(_blackjack_result_banner, "modulate:a", 1.0, 0.18).set_delay(
		0.08
	)
	_blackjack_fx_tween.tween_property(
		_blackjack_result_banner, "position", BLACKJACK_PLAQUE_RECT.position, 0.24
	).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_blackjack_fx_tween.tween_property(
		_blackjack_result_banner, "scale", Vector2.ONE, 0.24
	).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Plaque copy, ink and chip settle for a result. Reads the result only.
func _blackjack_result_copy(result: RoundResult) -> Array:
	var player: Array[int] = []
	var dealer: Array[int] = []
	player.assign(result.detail.get("player", []))
	dealer.assign(result.detail.get("dealer", []))
	var net := result.payout - result.stake
	if result.outcome == RoundResult.Outcome.ABANDONED:
		return [tr("BLACKJACK_RESULT_CLOSED"), BLACKJACK_LOSS_INK, BlackjackBetStack.Settle.LOSS]
	if result.outcome == RoundResult.Outcome.PUSH or net == 0:
		return [tr("BLACKJACK_RESULT_PUSH"), BLACKJACK_TEXT, BlackjackBetStack.Settle.PUSH]
	if net > 0:
		var key := "BLACKJACK_RESULT_WIN"
		if player.size() == 2 and BlackjackMath.hand_value(player) == 21:
			key = "BLACKJACK_RESULT_NATURAL"
		elif BlackjackMath.hand_value(dealer) > 21:
			key = "BLACKJACK_RESULT_DEALER_BUST"
		return [tr(key) % net, BLACKJACK_WIN_INK, BlackjackBetStack.Settle.WIN]
	var loss_key := (
		"BLACKJACK_RESULT_BUST" if BlackjackMath.hand_value(player) > 21 else "BLACKJACK_RESULT_LOSS"
	)
	return [tr(loss_key), BLACKJACK_LOSS_INK, BlackjackBetStack.Settle.LOSS]



func _reset_blackjack_result_feedback_for_round() -> void:
	if _blackjack_fx_tween != null and _blackjack_fx_tween.is_valid():
		_blackjack_fx_tween.kill()
	_blackjack_fx_tween = null
	if _blackjack_result_banner != null:
		_blackjack_result_banner.hide()
		_blackjack_result_banner.position = BLACKJACK_PLAQUE_RECT.position
		_blackjack_result_banner.modulate.a = 1.0
		_blackjack_result_banner.scale = Vector2.ONE
	for label: Label in [_blackjack_player_total, _blackjack_dealer_total]:
		if label != null:
			label.scale = Vector2.ONE
			label.add_theme_color_override("font_color", BLACKJACK_TEXT)
	for badge: Panel in [_blackjack_dealer_total_panel, _blackjack_player_total_panel]:
		if badge != null:
			badge.hide()
	if _blackjack_bet_stack != null:
		_blackjack_bet_stack.clear_wager(false)
	if _blackjack_dealer_presenter != null:
		_blackjack_dealer_presenter.reset_feedback()


func _animate_vault_result(result: RoundResult) -> void:
	if _vault_attendant != null:
		if result.payout > 0:
			_vault_attendant.present_cash_out()
		else:
			_vault_attendant.warn_mine()
	if _vault_cursor == null:
		return
	var color := VaultRuneFrame.AMBER if result.payout > 0 else Color("d9483e")
	for edge: ColorRect in _vault_cursor.get_children():
		edge.color = color
	_vault_cursor.scale = Vector2.ONE if MotionPolicy.is_reduced() else Vector2(1.14, 1.14)
	if MotionPolicy.is_reduced():
		return
	_vault_fx_tween = create_tween().set_parallel(true)
	_vault_fx_tween.tween_property(_vault_cursor, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK)


func _result_impact_tier(result: RoundResult) -> ResultImpactTier:
	if result == null or result.payout <= result.stake:
		return ResultImpactTier.NONE
	var win_multiple := float(result.payout) / maxf(float(result.stake), 1.0)
	return ResultImpactTier.BIG_WIN if win_multiple >= BIG_WIN_MULTIPLE else ResultImpactTier.WIN


func _play_result_impact(result: RoundResult) -> void:
	## Starts on the same frame as the semantic result cue in show_result(). This is
	## presentation-only: payout classification is read, never fed back into gameplay.
	_last_result_impact_tier = _result_impact_tier(result)
	if _result_impact_tween != null and _result_impact_tween.is_valid():
		_result_impact_tween.kill()
	_result_impact_tween = null
	if _art_root == null:
		return
	_art_root.position = Vector2.ZERO
	if _last_result_impact_tier == ResultImpactTier.NONE or not MotionPolicy.allows_camera_emphasis():
		return
	_result_impact_tween = create_tween()
	if _last_result_impact_tier == ResultImpactTier.WIN:
		# One compact cabinet-weight beat for ordinary wins, including blackjack's
		# natural 2x ceiling. It reads as contact without becoming camera shake.
		_result_impact_tween.tween_property(_art_root, "position", Vector2(0, 1.5), 0.045)
		_result_impact_tween.tween_property(_art_root, "position", Vector2(0, -0.75), 0.045)
		_result_impact_tween.tween_property(_art_root, "position", Vector2.ZERO, 0.08).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_OUT)
		return
	var impact_offsets: Array[Vector2] = [
		Vector2(-6.0, -1.5),
		Vector2(4.5, 1.0),
		Vector2(-3.0, 0.75),
		Vector2(1.5, -0.5),
	]
	for offset: Vector2 in impact_offsets:
		_result_impact_tween.tween_property(_art_root, "position", offset, 0.045)
	_result_impact_tween.tween_property(_art_root, "position", Vector2.ZERO, 0.08).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)


func _shake_stage(intensity: float, duration: float) -> void:
	## Mine reveals use the same tracked stage channel so overlapping impacts cannot
	## leave the cabinet offset. Result impacts use _play_result_impact() above.
	if _art_root == null or not MotionPolicy.allows_camera_emphasis():
		return
	if _result_impact_tween != null and _result_impact_tween.is_valid():
		_result_impact_tween.kill()
	_art_root.position = Vector2.ZERO
	_result_impact_tween = create_tween()
	var beats := maxi(2, int(duration / 0.045))
	for index: int in range(beats):
		var falloff := 1.0 - float(index) / float(beats)
		var direction := -1.0 if index % 2 == 0 else 1.0
		_result_impact_tween.tween_property(
			_art_root,
			"position",
			Vector2(direction * intensity * falloff, 0),
			duration / float(beats)
		)
	_result_impact_tween.tween_property(
		_art_root, "position", Vector2.ZERO, 0.05
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _pulse_slot_win(result: RoundResult) -> void:
	if cabinet.context.definition.id != &"slot_classic" or _slot_payline == null:
		return
	_reset_slot_win_feedback()
	_slot_last_win_indices = _slot_win_indices(result)
	if _slot_last_win_indices.is_empty():
		return
	_slot_payline.color = Color("fff0a0")
	_slot_payline.pivot_offset = _slot_payline.size * 0.5
	_slot_payline.scale = Vector2(1.0, 2.0 if MotionPolicy.is_reduced() else 2.5)
	if _slot_win_band != null:
		_slot_win_band.visible = true
		_slot_win_band.modulate.a = 0.75 if MotionPolicy.is_reduced() else 1.0
	_slot_win_tween = create_tween().set_parallel(true)
	var payline_duration := MotionPolicy.finite_duration(0.22)
	_slot_win_tween.tween_property(
		_slot_payline, "scale", Vector2.ONE, payline_duration
	).set_trans(Tween.TRANS_BACK)
	_slot_win_tween.tween_property(
		_slot_payline, "color", Color("d9b44a"), payline_duration
	)
	if _slot_win_band != null and not MotionPolicy.is_reduced():
		_slot_win_tween.tween_property(
			_slot_win_band, "modulate:a", 0.30, MotionPolicy.finite_duration(0.44)
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var beat_delay := MotionPolicy.finite_duration(0.09)
	var rise_duration := MotionPolicy.finite_duration(0.10)
	var settle_duration := MotionPolicy.finite_duration(0.16)
	var peak_scale := Vector2(1.04, 1.04) if MotionPolicy.is_reduced() else Vector2(1.13, 1.13)
	for sequence_index: int in range(_slot_last_win_indices.size()):
		var reel_index: int = _slot_last_win_indices[sequence_index]
		var symbol: Control = _slot_symbols[reel_index]
		symbol.pivot_offset = symbol.size * 0.5
		var delay := beat_delay * sequence_index
		_slot_win_tween.tween_property(
			symbol, "scale", peak_scale, rise_duration
		).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_slot_win_tween.tween_property(
			symbol, "scale", Vector2.ONE, settle_duration
		).set_delay(delay + rise_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if not MotionPolicy.is_reduced():
			_queue_slot_symbol_tumble(reel_index, delay)
			_slot_win_tween.tween_callback(
				func() -> void: _emit_slot_win_impact(reel_index)
			).set_delay(delay + rise_duration * 0.65)
	if _slot_win_band != null and not MotionPolicy.is_reduced():
		_slot_win_tween.tween_callback(
			func() -> void: _slot_win_band.visible = false
		).set_delay(MotionPolicy.finite_duration(0.50))


func _queue_slot_symbol_tumble(reel_index: int, delay: float) -> void:
	if reel_index < 0 or reel_index >= _slot_reels.size() or MotionPolicy.is_reduced():
		return
	var reel: Control = _slot_reels[reel_index]
	var source: SlotSymbol = _slot_symbols[reel_index]
	var outgoing := SlotSymbol.new()
	outgoing.name = "WinCascadeOut%d" % reel_index
	outgoing.position = source.position
	outgoing.size = source.size
	outgoing.symbol_index = source.symbol_index
	outgoing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outgoing.z_index = 12
	reel.add_child(outgoing)
	var incoming := SlotSymbol.new()
	incoming.name = "WinCascadeIn%d" % reel_index
	incoming.position = source.position - Vector2(0, SLOT_CELL_HEIGHT * 0.72)
	incoming.size = source.size
	incoming.symbol_index = source.symbol_index
	incoming.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incoming.modulate.a = 0.18
	incoming.scale = Vector2(0.94, 0.94)
	incoming.pivot_offset = incoming.size * 0.5
	incoming.z_index = 13
	reel.add_child(incoming)
	_slot_cascade_clones.append(outgoing)
	_slot_cascade_clones.append(incoming)
	var tumble_duration := MotionPolicy.finite_duration(0.20)
	_slot_win_tween.tween_callback(
		Callable(self, "_begin_slot_symbol_tumble").bind(source)
	).set_delay(delay)
	_slot_win_tween.tween_property(
		outgoing, "position:y", source.position.y + SLOT_CELL_HEIGHT * 0.78, tumble_duration
	).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_slot_win_tween.tween_property(
		outgoing, "rotation", 0.10 if reel_index % 2 == 0 else -0.10, tumble_duration
	).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_slot_win_tween.tween_property(
		outgoing, "modulate:a", 0.0, tumble_duration
	).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_slot_win_tween.tween_property(
		incoming, "position", source.position, tumble_duration
	).set_delay(delay + MotionPolicy.finite_duration(0.035)).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_slot_win_tween.tween_property(
		incoming, "modulate:a", 1.0, tumble_duration
	).set_delay(delay + MotionPolicy.finite_duration(0.035)).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_OUT)
	_slot_win_tween.tween_property(
		incoming, "scale", Vector2.ONE, tumble_duration
	).set_delay(delay + MotionPolicy.finite_duration(0.035)).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	_slot_win_tween.tween_callback(
		Callable(self, "_finish_slot_symbol_tumble").bind(source, outgoing, incoming)
	).set_delay(delay + tumble_duration + MotionPolicy.finite_duration(0.05))


func _begin_slot_symbol_tumble(source: SlotSymbol) -> void:
	if is_instance_valid(source):
		source.modulate.a = 0.0


func _finish_slot_symbol_tumble(
	source: SlotSymbol, outgoing: SlotSymbol, incoming: SlotSymbol
) -> void:
	if is_instance_valid(source):
		source.modulate.a = 1.0
	for clone: SlotSymbol in [outgoing, incoming]:
		_slot_cascade_clones.erase(clone)
		if is_instance_valid(clone):
			clone.queue_free()


func _slot_win_indices(result: RoundResult) -> Array[int]:
	var indices: Array[int] = []
	var symbols: Variant = result.detail.get("symbols", [])
	if not symbols is Array or symbols.size() != 3:
		return indices
	if int(symbols[0]) == int(symbols[1]) and int(symbols[1]) == int(symbols[2]):
		return [0, 1, 2]
	for index: int in range(symbols.size()):
		if int(symbols[index]) == SlotMachineMath.Symbol.CHERRY:
			indices.append(index)
	return indices if indices.size() == 2 else []


func _emit_slot_win_impact(reel_index: int) -> void:
	if reel_index < 0 or reel_index >= _slot_reels.size():
		return
	var reel: Control = _slot_reels[reel_index]
	var symbol: Control = _slot_symbols[reel_index]
	ImpactBurst.spawn(
		_art_root,
		reel.position + symbol.position + symbol.size * 0.5,
		Color("f2c84b"),
		false
	)


func _reset_slot_win_feedback() -> void:
	if _slot_win_tween != null and _slot_win_tween.is_valid():
		_slot_win_tween.kill()
	_slot_win_tween = null
	_slot_last_win_indices.clear()
	for clone: Control in _slot_cascade_clones:
		if is_instance_valid(clone):
			clone.queue_free()
	_slot_cascade_clones.clear()
	if _slot_payline != null:
		_slot_payline.scale = Vector2.ONE
		_slot_payline.color = Color("d9b44a")
	if _slot_win_band != null:
		_slot_win_band.visible = false
		_slot_win_band.modulate.a = 1.0
	for symbol: Control in _slot_symbols:
		symbol.scale = Vector2.ONE
		symbol.modulate.a = 1.0


func _animate_slot_result(payout: int) -> void:
	if _slot_result_value == null:
		return
	_reset_slot_result_ticker()
	if MotionPolicy.is_reduced():
		_slot_result_value.text = tr("SLOT_RETURNED") % payout
		return
	_slot_result_value.text = tr("SLOT_RETURNED") % 0
	_slot_result_tween = create_tween()
	_slot_result_tween.tween_method(
		func(value: float) -> void:
			_slot_result_value.text = tr("SLOT_RETURNED") % int(round(value)),
		0.0,
		float(payout),
		clampf(0.35 + payout * 0.002, 0.35, 0.8)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _reset_slot_result_ticker() -> void:
	if _slot_result_tween != null and _slot_result_tween.is_valid():
		_slot_result_tween.kill()
	_slot_result_tween = null


func _card_names(cards: Array[int]) -> String:
	var names: PackedStringArray = []
	for card: int in cards:
		names.append(tr("CARD_" + str(card)) if card == 1 or card > 10 else str(card))
	return "  ".join(names)
