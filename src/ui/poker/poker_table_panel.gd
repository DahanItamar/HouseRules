class_name PokerTablePanel
extends CabinetPanel
## Penthouse Hold'em table: owns the whole poker presentation.
##
## PokerMath has already resolved everything up to the player's decision (or the
## end of the hand) and recorded it as events. This panel replays those events at
## table pace: blinds, the deal from the dealer's hand, each NPC "thinking" on its
## seat plate before acting, streets turned by the dealer, showdown reveals and
## the pot pushed to the winner. It never changes game state; the cabinet only
## accepts the player's input once `presentation_idle()` is true, and settlement
## waits until the recorded hand has been shown (`_gates_result_on_reveal`).

const TABLE_TEXTURE := preload("res://assets/production/poker/poker_table_v1.png")
const PORTRAITS := {
	&"shark":
	[
		preload("res://assets/production/poker/npc/shark.png"),
		preload("res://assets/production/poker/npc/shark_react.png"),
	],
	&"rock":
	[
		preload("res://assets/production/poker/npc/rock.png"),
		preload("res://assets/production/poker/npc/rock_react.png"),
	],
	&"maniac":
	[
		preload("res://assets/production/poker/npc/maniac.png"),
		preload("res://assets/production/poker/npc/maniac_react.png"),
	],
	&"calling_station":
	[
		preload("res://assets/production/poker/npc/calling_station.png"),
		preload("res://assets/production/poker/npc/calling_station_react.png"),
	],
	&"tourist":
	[
		preload("res://assets/production/poker/npc/tourist.png"),
		preload("res://assets/production/poker/npc/tourist_react.png"),
	],
}
## Seconds each regular takes to act at full motion: the Shark deliberates, the
## Maniac snaps. Reduced motion uses REDUCED_THINK for everyone.
const THINK_SECONDS := {
	&"shark": 0.8,
	&"rock": 0.7,
	&"maniac": 0.35,
	&"calling_station": 0.45,
	&"tourist": 0.65,
}
const REDUCED_THINK: float = 0.12
## After the player folds the rest of the hand plays out faster.
const FOLDED_SPEED: float = 2.5

# Palette: sapphire and silver penthouse, flat near-black surfaces.
const INK := Color("f1ede4")
const MUTED := Color("9aa6b4")
const SILVER := Color("c9d3de")
const HAIRLINE := Color("4f5b6a")
const SURFACE := Color("0b0e14f5")
const SAPPHIRE := Color("14336a")
const SAPPHIRE_DEEP := Color("0e2247")
const BRASS := Color("d9b44a")
const FOCUS := Color("48c5d5")
const LOSS_INK := Color("d98c8c")
const DISABLED_INK := Color("5d6776")

# HUD layout (960x540 virtual canvas); felt layout lives in PokerFelt.
const POT_PLATE_RECT := Rect2(458, 300, 104, 28)
const RESULT_RECT := Rect2(300, 298, 360, 34)
const DECK_RECT := Rect2(48, 430, 864, 98)
const INFO_RECT := Rect2(184, 436, 344, 84)

var dealer: PokerDealerPresenter
var felt: PokerFelt
var plates: Array[PokerSeatPlate] = []
var fold_button: Button
var call_button: Button
var raise_button: Button
var last_status: String = ""

var _built: bool = false
var _cursor: int = 0
var _wait: float = 0.0
var _wait_total: float = 0.0
var _thought_index: int = -1
var _thinking_seat: int = -1
var _speed: float = 1.0
var _awaiting_shown: bool = false
var _pot_plate: Panel
var _pot_label: AnimatedNumberLabel
var _result_plate: Panel
var _result_label: Label
var _plaque: Panel
var _deck: Panel
var _credit_value: AnimatedNumberLabel
var _stake_caption: Label
var _stake_buttons: Array[Button] = []
var _info_cells: Dictionary = {}
var _info_root: Control
var _button_labels: Dictionary = {}
var _showdown_best: Dictionary = {}
var _last_winners: Array[int] = []
var _result_tween: Tween


func _math() -> PokerMath:
	return cabinet.get("math") as PokerMath if cabinet != null else null


func _npc_for(seat: int) -> PokerNpc:
	var math := _math()
	return math.npcs[seat - 1] if math != null and seat > 0 else null


func _seat_name(seat: int) -> String:
	if seat == PokerMath.PLAYER_SEAT:
		return tr("POKER_YOU")
	var npc := _npc_for(seat)
	return tr(npc.name_key) if npc != null else ""


# --- Base overrides -------------------------------------------------------------


func _ensure_art() -> void:
	if _built:
		return
	_built = true
	_art_id = cabinet.context.definition.id
	# The painted penthouse carries the light: no shared beams over the table.
	_lighting.visible = false
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("070a10")
	_controls.hide()
	_controls_backdrop.hide()
	_stake.hide()
	_detail.hide()
	_stake_selector.hide()
	_stake_selector.process_mode = Node.PROCESS_MODE_DISABLED
	_art_root.add_child(_texture("PokerTableArt", TABLE_TEXTURE, Vector2.ZERO, Vector2(960, 540)))
	dealer = PokerDealerPresenter.new()
	dealer.name = "PokerDealerPresenter"
	dealer.z_index = 1
	_art_root.add_child(dealer)
	_build_felt_objects()
	_build_plates()
	_build_plaque()
	_build_deck()
	_restyle_help_button()
	_play_art_entrance()
	call_deferred("_focus_default_action")


func refresh() -> void:
	if _title == null or cabinet == null or cabinet.context == null:
		return
	_ensure_art()
	_title.text = tr(cabinet.context.definition.name_key)
	var math := _math()
	var live: bool = cabinet.is_round_active
	var ready: bool = live and cabinet.call("input_ready")
	var legal: Dictionary = math.legal_actions() if ready else {}
	var committed: int = cabinet.current_stake if live else 0
	if Wallet.test_mode_enabled:
		_credit_value.set_infinity()
	else:
		_credit_value.set_number(maxi(0, cabinet.context.balance - committed))
	if plates.size() > 0:
		plates[0].set_stack(maxi(0, cabinet.context.balance - committed))
		plates[0].set_caption(
			tr("HUD_TEST_BANK") if Wallet.test_mode_enabled else tr("HUD_CREDITS")
		)
	_refresh_stakes(live)
	if not live and math.hands_played == 0:
		# Before the first hand each regular sits with the table buy-in.
		for seat: int in range(1, plates.size()):
			plates[seat].set_stack(
				math.rules.npc_buy_in_stakes * maxi(cabinet.selected_stake, 1), false
			)
	_refresh_info(math, live)
	_refresh_actions(legal, live)
	_refresh_player_readout()
	if not live and _result == null and cabinet.selected_stake == 0:
		_set_status_text(tr("BET_NEED_CASHIER") % cabinet.context.definition.min_bet)
	elif not live and _result == null and last_status.is_empty():
		_set_status_text(tr("POKER_READY"))
	_refresh_help()


func _refresh_help() -> void:
	if _help_title == null or cabinet == null or cabinet.context == null:
		return
	_help_button.text = tr("HELP_BUTTON")
	_help_title.text = tr("HELP_TITLE") % tr(cabinet.context.definition.name_key)
	_help_rules.text = tr("HELP_POKER_RULES")
	_help_controls.text = (
		tr("HELP_POKER_CONTROLS")
		% [
			InputRouter.glyph("interact"),
			InputRouter.glyph("secondary"),
			InputRouter.glyph("tertiary"),
			InputRouter.glyph("move_horizontal"),
			InputRouter.glyph("back"),
		]
	)


func _focus_default_action() -> void:
	if help_open or not is_inside_tree() or call_button == null:
		return
	if not call_button.disabled:
		call_button.grab_focus()
	elif not _stake_buttons.is_empty():
		_stake_buttons[0].grab_focus()


func set_status(key: String) -> void:
	_set_status_text(tr(key))


func present_result_after_reveal(result: RoundResult, on_ready: Callable) -> void:
	super.present_result_after_reveal(result, on_ready)
	play_new_events()


func _try_complete_result_reveal() -> void:
	if not presentation_idle():
		return
	super._try_complete_result_reveal()


func show_result(result: RoundResult) -> void:
	_stop_motion()
	_result = result
	_set_awaiting(false)
	refresh()
	var math := _math()
	var copy := _result_copy(result, math)
	_set_status_text(copy[0])
	_result_label.text = copy[0]
	_result_label.add_theme_color_override("font_color", copy[1])
	(_result_plate.get_theme_stylebox("panel") as StyleBoxFlat).border_color = copy[2]
	_result_plate.visible = result.outcome != RoundResult.Outcome.ABANDONED
	_pot_plate.visible = false
	felt.pot_chips.visible = false
	AudioService.play(_poker_result_cue(result))
	_play_result_impact(result)
	_win_flash.play(_poker_flash_tint(result), _last_result_impact_tier == ResultImpactTier.BIG_WIN)
	if result.outcome == RoundResult.Outcome.WIN and not MotionPolicy.is_reduced():
		_result_plate.pivot_offset = RESULT_RECT.size * 0.5
		_result_plate.scale = Vector2(0.94, 0.94)
		var pop := create_tween()
		pop.tween_property(_result_plate, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		pop.set_ease(Tween.EASE_OUT)
		_result_tween = pop
	call_deferred("_focus_default_action")


func has_active_motion() -> bool:
	return (
		super.has_active_motion()
		or (felt != null and felt.has_active_motion())
		or (_result_tween != null and _result_tween.is_running())
		or (dealer != null and dealer.has_active_gesture())
		or not presentation_idle()
	)


func _apply_live_feedback_motion_preference(reduced: bool) -> void:
	if reduced and felt != null:
		felt.settle()
	super._apply_live_feedback_motion_preference(reduced)


func _process(delta: float) -> void:
	super._process(delta)
	_advance_presentation(delta)


# --- Presentation queue ---------------------------------------------------------


## Clears the felt for a new hand; called by the cabinet before PokerMath.begin().
func prepare_hand() -> void:
	felt.clear()
	_showdown_best.clear()
	_last_winners.clear()
	for plate: PokerSeatPlate in plates:
		plate.reset_for_hand()
	_result = null
	_result_plate.hide()
	_pot_plate.show()
	_pot_label.set_number(0, tr("POKER_POT"), false)
	dealer.reset_feedback()
	_cursor = 0
	_wait = 0.0
	_wait_total = 0.0
	_thought_index = -1
	_thinking_seat = -1
	_speed = 1.0
	_awaiting_shown = false
	_set_status_text(tr("POKER_STATUS_BLINDS"))


## Called after every PokerMath step; events are consumed from `_process`.
func play_new_events() -> void:
	_awaiting_shown = false
	refresh()
	_advance_presentation(0.0)


## True once every recorded event has been shown and no hold is pending.
func presentation_idle() -> bool:
	var math := _math()
	return math == null or (_cursor >= math.events.size() and _wait <= 0.0)


## Test and capture hook: shows every pending event immediately.
func finish_presentation() -> void:
	var math := _math()
	if math == null:
		return
	var guard := 0
	while not presentation_idle() and guard < 2000:
		_wait = 0.0
		_advance_presentation(0.0)
		guard += 1
	felt.settle()


func _advance_presentation(delta: float) -> void:
	var math := _math()
	if math == null or help_open or not _built:
		return
	if _wait > 0.0:
		_wait -= delta * _speed
		if _thinking_seat >= 0 and _wait_total > 0.0:
			plates[_thinking_seat].set_thinking(1.0 - maxf(_wait, 0.0) / _wait_total)
		if _wait > 0.0:
			return
		_wait = 0.0
	while _cursor < math.events.size():
		var event: Dictionary = math.events[_cursor]
		if event.type == &"action" and int(event.seat) != 0 and _thought_index != _cursor:
			_thought_index = _cursor
			_begin_thinking(int(event.seat))
			return
		_cursor += 1
		var hold := _present_event(event)
		if hold > 0.0:
			_wait = hold
			_wait_total = 0.0
			return
	_on_presentation_drained()


func _on_presentation_drained() -> void:
	if _awaiting_shown:
		return
	_awaiting_shown = true
	if _result_reveal_active:
		_try_complete_result_reveal()
		return
	var math := _math()
	if cabinet.is_round_active and math.is_player_turn():
		_set_awaiting(true)
		var owed := math.to_call(PokerMath.PLAYER_SEAT)
		_set_status_text(
			tr("POKER_YOUR_TURN_CALL") % owed if owed > 0 else tr("POKER_YOUR_TURN_CHECK")
		)
		refresh()
		_focus_default_action()


func _begin_thinking(seat: int) -> void:
	var npc := _npc_for(seat)
	var think := REDUCED_THINK
	if not MotionPolicy.is_reduced():
		# Presentation-only variation from the event index; never the game stream.
		var jitter := float((_cursor * 37) % 17) / 17.0 * 0.3
		think = float(THINK_SECONDS.get(npc.id, 0.5)) + jitter - npc.tilt * 0.2
	for plate: PokerSeatPlate in plates:
		plate.set_active(plate.seat == seat)
	_thinking_seat = seat
	plates[seat].set_thinking(0.0)
	_set_status_text(tr("POKER_THINKING") % _seat_name(seat))
	_wait = maxf(think, 0.05)
	_wait_total = _wait


func _present_event(event: Dictionary) -> float:
	var reduced := MotionPolicy.is_reduced()
	match event.type:
		&"hand_start":
			var stacks: Array = event.stacks
			for seat: int in range(1, plates.size()):
				plates[seat].set_stack(int(stacks[seat]), false)
			felt.place_puck(int(event.button))
			return 0.05
		&"blind":
			var seat: int = event.seat
			var key := (
				"POKER_ACT_SMALL_BLIND"
				if seat == _math().small_blind_seat
				else "POKER_ACT_BIG_BLIND"
			)
			_apply_seat_money(seat, event)
			plates[seat].set_action(tr(key) % int(event.amount))
			AudioService.play(&"chip")
			return 0.12 if reduced else 0.22
		&"hole_cards":
			return _deal_hole_cards(event)
		&"action":
			return _present_action(event)
		&"player_turn":
			return 0.0
		&"board":
			return _present_board(event)
		&"showdown":
			return _present_showdown(event)
		&"award":
			return _present_award(event)
		&"hand_end":
			var stacks: Array = event.stacks
			for seat: int in range(1, plates.size()):
				plates[seat].set_stack(int(stacks[seat]))
			for plate: PokerSeatPlate in plates:
				plate.set_active(false)
			return 0.1
	return 0.0


func _present_action(event: Dictionary) -> float:
	var seat: int = event.seat
	var action: int = event.action
	var plate := plates[seat]
	_thinking_seat = -1
	plate.set_thinking(-1.0)
	plate.set_active(false)
	_apply_seat_money(seat, event)
	var text := _action_text(event)
	var emphasis := 0
	match action:
		PokerMath.Action.FOLD:
			emphasis = -1
			plate.set_folded(true)
			felt.muck(seat)
			AudioService.play(&"card")
		PokerMath.Action.CHECK:
			AudioService.play(&"tick")
		PokerMath.Action.CALL:
			AudioService.play(&"chip")
		_:
			emphasis = 1
			AudioService.play(&"chip")
			if seat != 0:
				plate.show_reaction(1.1)
	if seat == 0:
		_set_awaiting(false)
		if action == PokerMath.Action.FOLD:
			_speed = FOLDED_SPEED
	plate.set_action(text, emphasis)
	_set_status_text(tr("POKER_STATUS_ACTION") % [_seat_name(seat), text])
	return 0.14 if MotionPolicy.is_reduced() else 0.32


func _action_text(event: Dictionary) -> String:
	var action: int = event.action
	var total: int = event.street_total
	if bool(event.all_in) and action != PokerMath.Action.FOLD:
		return tr("POKER_ACT_ALL_IN") % total
	match action:
		PokerMath.Action.FOLD:
			return tr("POKER_ACT_FOLD")
		PokerMath.Action.CHECK:
			return tr("POKER_ACT_CHECK")
		PokerMath.Action.CALL:
			return tr("POKER_ACT_CALL") % int(event.amount)
		PokerMath.Action.BET:
			return tr("POKER_ACT_BET") % total
	return tr("POKER_ACT_RAISE") % total


func _deal_hole_cards(event: Dictionary) -> float:
	var flight := felt.deal_hole_cards(event.order, event.player)
	dealer.play_deal(flight)
	AudioService.play(&"card_deal")
	_set_status_text(tr("POKER_STATUS_DEAL"))
	_refresh_player_readout()
	return 0.2 if MotionPolicy.is_reduced() else flight + 0.34


func _present_board(event: Dictionary) -> float:
	felt.sweep_bets()
	var fresh: Array = event.cards
	var duration := felt.add_board_cards(fresh)
	var street: int = event.street
	var keys := {1: "POKER_STREET_FLOP", 2: "POKER_STREET_TURN", 3: "POKER_STREET_RIVER"}
	_set_status_text(tr(keys.get(street, "POKER_STREET_FLOP")))
	dealer.play_reveal(duration)
	AudioService.play(&"card_flip")
	_refresh_player_readout()
	return 0.24 if MotionPolicy.is_reduced() else duration + 0.3


func _present_showdown(event: Dictionary) -> float:
	felt.sweep_bets()
	var hands: Array = event.hands
	var step := 0.0
	for entry_value: Variant in hands:
		var entry: Dictionary = entry_value
		var seat: int = entry.seat
		_showdown_best[seat] = entry.best
		if seat == PokerMath.PLAYER_SEAT:
			continue
		felt.reveal_seat(seat, entry.cards, step)
		plates[seat].set_action(tr(PokerHandEval.category_key(int(entry.score))))
		step += 0.22
	_set_status_text(tr("POKER_STATUS_SHOWDOWN"))
	AudioService.play(&"reveal")
	return 0.3 if MotionPolicy.is_reduced() else step + 0.45


func _present_award(event: Dictionary) -> float:
	felt.sweep_bets()
	var shares: Dictionary = event.shares
	var winners: Array = event.winners
	var returned: bool = event.returned
	for seat_value: Variant in winners:
		var seat: int = seat_value
		if not returned:
			plates[seat].set_winner(true)
			if not _last_winners.has(seat):
				_last_winners.append(seat)
		felt.push_chips_to(seat)
	if not returned:
		_highlight(winners)
		dealer.play_push()
		AudioService.play(&"chip")
		var names: Array[String] = []
		for seat_value: Variant in winners:
			names.append(_seat_name(int(seat_value)))
		var amount: int = event.amount
		if winners.size() > 1:
			_set_status_text(tr("POKER_STATUS_SPLIT") % [" & ".join(names), amount])
		else:
			_set_status_text(tr("POKER_STATUS_WINS") % [names[0], int(shares[winners[0]])])
	return 0.25 if MotionPolicy.is_reduced() else 1.0


# --- Felt objects ---------------------------------------------------------------


func _apply_seat_money(seat: int, event: Dictionary) -> void:
	if seat == PokerMath.PLAYER_SEAT:
		refresh()
	else:
		plates[seat].set_stack(int(event.stack))
	felt.stake = _math().stake
	felt.set_street_bet(seat, int(event.street_total))
	_pot_label.set_number(int(event.pot), tr("POKER_POT"))
	felt.show_pot(int(event.pot))


func _highlight(winners: Array) -> void:
	var best: Array = []
	for seat_value: Variant in winners:
		best.append_array(_showdown_best.get(int(seat_value), []))
	var math := _math()
	felt.highlight(best, math.board, math.holes)


func _set_awaiting(waiting: bool) -> void:
	if dealer != null:
		dealer.set_awaiting_player(waiting)
	if plates.size() > 0:
		plates[0].set_active(waiting)


func _set_status_text(text: String) -> void:
	last_status = text
	_set_live_text(_status, text)


# --- HUD ------------------------------------------------------------------------


func _refresh_stakes(live: bool) -> void:
	for button: Button in _stake_buttons:
		button.visible = not live
	_stake_caption.visible = not live
	if _info_root != null:
		_info_root.visible = live
	if live:
		return
	var available: Array[int] = cabinet.available_stakes()
	for button: Button in _stake_buttons:
		var amount: int = button.get_meta("amount")
		var selected := amount == cabinet.selected_stake
		button.disabled = not available.has(amount)
		button.set_pressed_no_signal(selected)
		button.add_theme_stylebox_override(
			"normal",
			_style(
				SAPPHIRE if selected else Color("111722"),
				SILVER if selected else HAIRLINE,
				6,
				2 if selected else 1
			)
		)
	var stake := maxi(cabinet.selected_stake, 0)
	@warning_ignore("integer_division")
	_stake_caption.text = tr("POKER_STAKES_CAPTION") % [maxi(1, stake / 2), stake, stake, stake * 2]


func _refresh_info(math: PokerMath, live: bool) -> void:
	if not live or math == null or not math.active:
		if live and _info_cells.has("to_call"):
			(_info_cells["to_call"] as Label).text = str(0)
		return
	(_info_cells["to_call"] as Label).text = str(math.to_call(PokerMath.PLAYER_SEAT))
	(_info_cells["pot"] as Label).text = str(math.pot_total())
	(_info_cells["limit"] as Label).text = tr("POKER_LIMIT_VALUE") % [math.stake, math.stake * 2]
	(_info_cells["in_pot"] as Label).text = str(math.player_committed())


func _refresh_actions(legal: Dictionary, live: bool) -> void:
	if call_button == null:
		return
	if not live:
		_set_button_text(call_button, tr("POKER_BUTTON_DEAL"))
		_set_action_disabled(
			call_button,
			(
				cabinet.is_result_pending
				or cabinet.selected_stake <= 0
				or cabinet.selected_stake > cabinet.context.balance
			)
		)
		_set_button_text(fold_button, tr("POKER_BUTTON_FOLD"))
		_set_button_text(raise_button, tr("POKER_BUTTON_RAISE_IDLE"))
		_set_action_disabled(fold_button, true)
		_set_action_disabled(raise_button, true)
	elif legal.is_empty():
		# The table is still acting: neutral labels, nothing pressable.
		_set_button_text(call_button, tr("POKER_BUTTON_CALL_IDLE"))
		_set_button_text(fold_button, tr("POKER_BUTTON_FOLD"))
		_set_button_text(raise_button, tr("POKER_BUTTON_RAISE_IDLE"))
		_set_action_disabled(call_button, true)
		_set_action_disabled(fold_button, true)
		_set_action_disabled(raise_button, true)
	else:
		var owed: int = legal.call_amount
		_set_button_text(
			call_button,
			(
				tr("POKER_BUTTON_CHECK")
				if owed == 0
				else (
					tr("POKER_BUTTON_ALL_IN") % owed
					if legal.call_all_in
					else tr("POKER_BUTTON_CALL") % owed
				)
			)
		)
		_set_button_text(
			raise_button,
			(
				(tr("POKER_BUTTON_BET") if legal.raise_is_bet else tr("POKER_BUTTON_RAISE"))
				% int(legal.raise_to)
			)
		)
		_set_action_disabled(call_button, false)
		_set_action_disabled(fold_button, not bool(legal.can_fold))
		_set_action_disabled(raise_button, not bool(legal.can_raise))
	for button: Button in [fold_button, call_button, raise_button]:
		var labels: Array = _button_labels[button]
		# Ink, not modulate: the shared live-text beat animates label alpha.
		(labels[0] as Label).add_theme_color_override(
			"font_color", DISABLED_INK if button.disabled else INK
		)
		(labels[1] as Label).add_theme_color_override(
			"font_color", DISABLED_INK if button.disabled else MUTED
		)
	(_button_labels[fold_button][1] as Label).text = InputRouter.glyph("secondary")
	(_button_labels[call_button][1] as Label).text = InputRouter.glyph("interact")
	(_button_labels[raise_button][1] as Label).text = InputRouter.glyph("tertiary")


func _refresh_player_readout() -> void:
	if not plates.is_empty() and _math() != null:
		var shown := (_math().active or _result != null) and not _math().holes.is_empty()
		# The readout waits until the player's cards have actually landed.
		var dealt := felt.seat_cards.has(PokerMath.PLAYER_SEAT)
		plates[0].show_player_state(_math(), felt.board_cards.size(), shown, dealt)


func _set_button_text(button: Button, text: String) -> void:
	var main: Label = _button_labels[button][0]
	_set_live_text(main, text)


# --- Builders ---------------------------------------------------------------------


func _build_felt_objects() -> void:
	felt = PokerFelt.new()
	felt.name = "PokerFelt"
	_art_root.add_child(felt)
	_pot_plate = Panel.new()
	_pot_plate.name = "PotPlate"
	_pot_plate.position = POT_PLATE_RECT.position
	_pot_plate.size = POT_PLATE_RECT.size
	_pot_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pot_plate.z_index = 3
	_pot_plate.add_theme_stylebox_override("panel", _style(SURFACE, HAIRLINE, 5, 1))
	_art_root.add_child(_pot_plate)
	_pot_label = _help_number_label(
		_pot_plate, Vector2(6, 0), POT_PLATE_RECT.size - Vector2(12, 0), Typography.CRITICAL, INK
	)
	_pot_label.name = "PotValue"
	_pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pot_label.set_number(0, tr("POKER_POT"), false)
	_result_plate = Panel.new()
	_result_plate.name = "PokerResultPlate"
	_result_plate.position = RESULT_RECT.position
	_result_plate.size = RESULT_RECT.size
	_result_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_plate.z_index = 12
	_result_plate.add_theme_stylebox_override("panel", _style(SURFACE, SILVER, 6, 2))
	_result_plate.hide()
	add_child(_result_plate)
	_result_label = _help_label(
		_result_plate, Vector2(8, 0), RESULT_RECT.size - Vector2(16, 0), 18, INK
	)
	_result_label.name = "PokerResultText"
	_result_label.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _build_plates() -> void:
	var math := _math()
	for seat: int in range(math.seat_count()):
		var plate := PokerSeatPlate.new()
		plate.name = "SeatPlate%d" % seat
		plate.position = PokerFelt.PLATE_POSITIONS[seat]
		plate.z_index = 6
		if seat == PokerMath.PLAYER_SEAT:
			plate.configure(seat, tr("POKER_YOU"), null, null)
		else:
			var npc := math.npcs[seat - 1]
			var faces: Array = PORTRAITS[npc.id]
			plate.configure(seat, tr(npc.name_key), faces[0], faces[1])
		add_child(plate)
		plates.append(plate)
		if seat > 0:
			plate.set_stack(math.rules.npc_buy_in_stakes * maxi(cabinet.selected_stake, 1), false)


func _build_plaque() -> void:
	_plaque = Panel.new()
	_plaque.name = "PokerTitlePlaque"
	_plaque.position = Vector2(16, 14)
	_plaque.size = Vector2(262, 60)
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_theme_stylebox_override("panel", _style(SURFACE, HAIRLINE, 6, 1))
	add_child(_plaque)
	move_child(_plaque, _title.get_index())
	_title.position = Vector2(28, 16)
	_title.size = Vector2(240, 30)
	_title.add_theme_font_size_override("font_size", 23)
	_title.add_theme_color_override("font_color", INK)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.position = Vector2(28, 46)
	_status.size = Vector2(244, 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_color_override("font_color", SILVER)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.z_index = 1
	_title.z_index = 1


func _build_deck() -> void:
	_deck = Panel.new()
	_deck.name = "PokerControlDeck"
	_deck.position = DECK_RECT.position
	_deck.size = DECK_RECT.size
	_deck.z_index = 4
	_deck.add_theme_stylebox_override("panel", _style(SURFACE, HAIRLINE, 8, 1))
	add_child(_deck)
	# A single silver rule along the top edge: the penthouse's metalwork.
	var rule := ColorRect.new()
	rule.color = Color(SILVER, 0.55)
	rule.position = Vector2(14, 0)
	rule.size = Vector2(DECK_RECT.size.x - 28, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck.add_child(rule)
	_credit_value = _add_credit_meter(_deck, Vector2(8, 9), Vector2(122, 80))
	(_credit_value.get_parent() as Panel).add_theme_stylebox_override(
		"panel", _style(Color("0f141d"), HAIRLINE, 6, 1)
	)
	_credit_value.add_theme_color_override("font_color", SILVER)
	_stake_caption = _label(INFO_RECT.position + Vector2(4, 2), 13)
	_stake_caption.size = Vector2(INFO_RECT.size.x - 8, 18)
	_stake_caption.add_theme_color_override("font_color", MUTED)
	_stake_caption.name = "PokerStakeCaption"
	_stake_caption.z_index = 6
	var options: Array[int] = cabinet.stake_options()
	var gap := 6.0
	var width := (INFO_RECT.size.x - gap * float(options.size() - 1)) / maxf(options.size(), 1)
	for index: int in range(options.size()):
		var amount := options[index]
		var button := Button.new()
		button.name = "PokerStake%d" % amount
		button.set_meta("amount", amount)
		button.text = str(amount)
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_ALL
		button.position = INFO_RECT.position + Vector2(index * (width + gap), 26)
		button.size = Vector2(width, 48)
		button.z_index = 6
		button.add_theme_font_override("font", Typography.DISPLAY_FONT)
		button.add_theme_font_size_override("font_size", Typography.CONTROL)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_color_override("font_disabled_color", Color("596372"))
		button.add_theme_stylebox_override("normal", _style(Color("111722"), HAIRLINE, 6, 1))
		button.add_theme_stylebox_override("hover", _style(Color("172238"), SILVER, 6, 1))
		button.add_theme_stylebox_override("pressed", _style(SAPPHIRE, SILVER, 6, 2))
		button.add_theme_stylebox_override("focus", _style(Color("111722"), FOCUS, 6, 2))
		button.add_theme_stylebox_override(
			"disabled", _style(Color("0c1017"), Color("2a313b"), 6, 1)
		)
		button.pressed.connect(_on_stake_pressed.bind(amount))
		add_child(button)
		ButtonFeedback.attach(button)
		_stake_buttons.append(button)
	_info_root = Control.new()
	_info_root.name = "PokerHandInfo"
	_info_root.position = INFO_RECT.position
	_info_root.size = INFO_RECT.size
	_info_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_root.z_index = 6
	_info_root.hide()
	add_child(_info_root)
	var cells := [
		["to_call", "POKER_INFO_TO_CALL"],
		["pot", "POKER_INFO_POT"],
		["limit", "POKER_INFO_LIMIT"],
		["in_pot", "POKER_INFO_IN_POT"],
	]
	var cell_width := INFO_RECT.size.x / 4.0
	for index: int in range(cells.size()):
		var cell := Panel.new()
		cell.position = Vector2(index * cell_width + 3, 8)
		cell.size = Vector2(cell_width - 6, 68)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_theme_stylebox_override("panel", _style(Color("0f141d"), HAIRLINE, 6, 1))
		_info_root.add_child(cell)
		var caption := _help_label(cell, Vector2(4, 6), Vector2(cell.size.x - 8, 18), 13, MUTED)
		caption.text = tr(cells[index][1])
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var value := _help_label(cell, Vector2(4, 28), Vector2(cell.size.x - 8, 30), 22, INK)
		value.add_theme_font_override("font", Typography.DISPLAY_FONT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.name = "Info_%s" % cells[index][0]
		_info_cells[cells[index][0]] = value
	fold_button = _poker_action(
		"PokerFoldAction", Rect2(540, 446, 112, 64), Callable(cabinet, "request_fold"), false
	)
	call_button = _poker_action(
		"PokerCallAction", Rect2(660, 446, 124, 64), Callable(cabinet, "request_primary"), true
	)
	raise_button = _poker_action(
		"PokerRaiseAction", Rect2(792, 446, 112, 64), Callable(cabinet, "request_raise"), false
	)
	fold_button.focus_neighbor_right = fold_button.get_path_to(call_button)
	call_button.focus_neighbor_left = call_button.get_path_to(fold_button)
	call_button.focus_neighbor_right = call_button.get_path_to(raise_button)
	raise_button.focus_neighbor_left = raise_button.get_path_to(call_button)


func _poker_action(node_name: String, rect: Rect2, action: Callable, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.z_index = 6
	button.focus_mode = Control.FOCUS_ALL
	var face := SAPPHIRE if primary else SAPPHIRE_DEEP
	button.add_theme_stylebox_override("normal", _style(face, SILVER, 7, 2))
	button.add_theme_stylebox_override("hover", _style(face.lightened(0.1), Color("e6ecf2"), 7, 2))
	button.add_theme_stylebox_override("pressed", _style(face.darkened(0.3), Color("e6ecf2"), 7, 2))
	button.add_theme_stylebox_override("focus", _style(face, FOCUS, 7, 3))
	button.add_theme_stylebox_override("disabled", _style(Color("0c1017"), Color("2a313b"), 7, 1))
	button.pressed.connect(func() -> void: action.call())
	add_child(button)
	ButtonFeedback.attach(button)
	var main := _help_label(
		button, Vector2(4, 9), Vector2(rect.size.x - 8, 28), Typography.CONTROL, INK
	)
	main.add_theme_font_override("font", Typography.DISPLAY_FONT)
	main.add_theme_font_size_override("font_size", 18)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := _help_label(button, Vector2(4, 40), Vector2(rect.size.x - 8, 18), 13, MUTED)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button_labels[button] = [main, glyph]
	return button


func _restyle_help_button() -> void:
	_help_button.add_theme_stylebox_override("normal", _style(SURFACE, HAIRLINE, 6, 1))
	_help_button.add_theme_stylebox_override("hover", _style(Color("151b26"), SILVER, 6, 1))
	_help_button.add_theme_stylebox_override("focus", _style(SURFACE, FOCUS, 6, 2))
	_help_button.add_theme_color_override("font_color", INK)


func _on_stake_pressed(amount: int) -> void:
	if not cabinet.select_stake(amount):
		refresh()


func _style(fill: Color, border: Color, radius: int, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = true
	return style


# --- Result copy ----------------------------------------------------------------


func _result_copy(result: RoundResult, math: PokerMath) -> Array:
	if result.outcome == RoundResult.Outcome.ABANDONED:
		return [tr("POKER_RESULT_ABANDONED") % result.stake, LOSS_INK, HAIRLINE]
	var detail := result.detail
	var rake: int = detail.get("rake", 0)
	var rake_note := (tr("POKER_RESULT_RAKE") % rake) if rake > 0 else ""
	if bool(detail.get("folded", false)):
		if result.stake == 0:
			return [tr("POKER_RESULT_FOLDED_FREE"), MUTED, HAIRLINE]
		return [tr("POKER_RESULT_FOLDED") % result.stake, MUTED, HAIRLINE]
	var hand_name := ""
	if int(detail.get("player_score", -1)) >= 0:
		hand_name = tr(PokerHandEval.category_key(int(detail.player_score)))
	if result.payout > result.stake:
		var text := (
			tr("POKER_RESULT_WIN_HAND") % [result.payout, hand_name]
			if bool(detail.get("showdown", false))
			else tr("POKER_RESULT_WIN") % result.payout
		)
		return [text + rake_note, BRASS, BRASS]
	if result.payout > 0:
		return [tr("POKER_RESULT_SPLIT") % result.payout + rake_note, INK, SILVER]
	var winner := ""
	for seat: int in _last_winners:
		if seat != PokerMath.PLAYER_SEAT:
			winner = _seat_name(seat)
			break
	if not winner.is_empty() and bool(detail.get("showdown", false)):
		var best_score := -1
		for event: Dictionary in math.events:
			if event.type == &"showdown":
				for entry_value: Variant in event.hands:
					var entry: Dictionary = entry_value
					if _last_winners.has(int(entry.seat)):
						best_score = maxi(best_score, int(entry.score))
		return [
			tr("POKER_RESULT_LOSS_TO") % [winner, tr(PokerHandEval.category_key(best_score))],
			LOSS_INK,
			HAIRLINE,
		]
	return [tr("POKER_RESULT_LOSS") % result.stake, LOSS_INK, HAIRLINE]


func _poker_result_cue(result: RoundResult) -> StringName:
	if result.outcome == RoundResult.Outcome.PUSH:
		return &"blackjack_push"
	return &"blackjack_win" if result.payout > result.stake else &"blackjack_loss"


func _poker_flash_tint(result: RoundResult) -> Color:
	if result.payout > result.stake:
		return Color("c9d3de")
	if result.payout > 0:
		return Color("8aa2c4")
	return Color("6b2a3a")
