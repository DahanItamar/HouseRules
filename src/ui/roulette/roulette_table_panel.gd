class_name RouletteTablePanel
extends CabinetPanel
## Ruby Salon roulette table. Owns its whole presentation: the painted salon,
## the croupier behind the wheel end, the code-drawn wheel ring and betting
## layout, three seated guests, and the mahogany-and-brass HUD. Game state is
## read from the cabinet; the panel never decides an outcome.

const BACKDROP := preload("res://assets/production/roulette/roulette_salon_backdrop.png")
const CHIP_TEXTURES := {
	1: preload("res://assets/production/roulette/roulette_chip_1.png"),
	5: preload("res://assets/production/roulette/roulette_chip_5.png"),
	10: preload("res://assets/production/roulette/roulette_chip_10.png"),
	25: preload("res://assets/production/roulette/roulette_chip_25.png"),
	50: preload("res://assets/production/roulette/roulette_chip_50.png"),
}
const BOARD_ORIGIN := Vector2(296, 212)
const WHEEL_CENTER := Vector2(137, 245)
const WHEEL_RADIUS: float = 130.0
const WHEEL_SQUASH: float = 0.56
## The croupier's lane; its bottom edge is the far rail that hides her legs.
const CROUPIER_LANE := Rect2(22, 0, 236, 209)
const TITLE_RECT := Rect2(296, 27, 262, 60)
const SEAT_ORIGIN := Vector2(296, 96)
const SEAT_GAP: float = 11.0
const RESULT_RECT := Rect2(48, 324, 242, 104)
const DECK_ORIGIN := Vector2(48, 436)
const REVEAL_BEAT_SECONDS: float = 0.5
const SWEEP_SECONDS: float = 2.6
const NOTICE_SECONDS: float = 1.8

var table_math: RouletteMath
var board: RouletteBoard
var wheel: RouletteWheel
var croupier: RouletteCroupier
var guests: RouletteTableGuests
var deck: RouletteDeck
var result_plaque: RouletteResultPlaque
var seat_plates: Array[RouletteSeatPlate] = []
var _built: bool = false
var _spin_result: RoundResult
var _ball_landed: bool = false
var _reveal_beat: Tween
var _sweep: Tween
var _notice: Tween
var _notice_key: String = ""


func refresh() -> void:
	if _title == null or cabinet == null or cabinet.context == null:
		return
	if not _built:
		_build_table()
	_title.text = tr("ROULETTE_THEME_TITLE")
	_refresh_status()
	_refresh_deck()
	board.betting_open = _is_betting_open()
	board.queue_redraw()
	_refresh_help()


func _is_betting_open() -> bool:
	return not cabinet.is_round_active and not cabinet.is_result_pending and not help_open


func _build_table() -> void:
	_built = true
	table_math = cabinet.get("math")
	_art_id = cabinet.context.definition.id
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("0b0607")
	for hidden: CanvasItem in [_stake, _detail, _controls, _controls_backdrop, _stake_selector]:
		hidden.hide()
	_art_root.add_child(_texture("RouletteSalonArt", BACKDROP, Vector2.ZERO, Vector2(960, 540)))
	_build_croupier()
	_build_wheel()
	_build_board()
	_build_title_plaque()
	_build_seats()
	result_plaque = RouletteResultPlaque.new(table_math)
	result_plaque.position = RESULT_RECT.position
	result_plaque.z_index = 4
	add_child(result_plaque)
	deck = RouletteDeck.new()
	deck.position = DECK_ORIGIN
	deck.z_index = 6
	add_child(deck)
	deck.build(CHIP_TEXTURES, cabinet.stake_options())
	deck.chip_chosen.connect(func(amount: int) -> void: cabinet.select_stake(amount))
	deck.clear_pressed.connect(func() -> void: cabinet.call("request_clear"))
	deck.rebet_pressed.connect(func() -> void: cabinet.call("request_rebet"))
	deck.spin_pressed.connect(func() -> void: cabinet.call("request_spin"))
	_style_help_button()
	_open_betting(false)
	_play_art_entrance()
	call_deferred("_focus_default_action")


func _build_croupier() -> void:
	var lane := Control.new()
	lane.name = "CroupierLane"
	lane.position = CROUPIER_LANE.position
	lane.size = CROUPIER_LANE.size
	lane.clip_contents = true
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.add_child(lane)
	croupier = RouletteCroupier.new()
	croupier.place_on_rail(
		Vector2(WHEEL_CENTER.x - CROUPIER_LANE.position.x, CROUPIER_LANE.size.y), CROUPIER_LANE.size
	)
	lane.add_child(croupier)


func _build_wheel() -> void:
	wheel = RouletteWheel.new()
	wheel.name = "RouletteWheel"
	wheel.position = WHEEL_CENTER
	wheel.scale = Vector2(1.0, WHEEL_SQUASH)
	_art_root.add_child(wheel)
	wheel.setup(table_math, WHEEL_RADIUS)
	wheel.ball_landed.connect(_on_ball_landed)


func _build_board() -> void:
	board = RouletteBoard.new()
	board.name = "RouletteBoard"
	board.position = BOARD_ORIGIN
	board.z_index = 4
	add_child(board)
	board.setup(table_math, CHIP_TEXTURES)
	board.place_requested.connect(func(id: String) -> void: cabinet.call("request_place", id))
	board.remove_requested.connect(func(id: String) -> void: cabinet.call("request_remove", id))
	board.cursor_changed.connect(func(_id: String) -> void: _refresh_spot_text())
	board.exit_requested.connect(
		func(_direction: Vector2i) -> void: deck.focus_selected_chip(cabinet.selected_stake)
	)


func _build_title_plaque() -> void:
	var plaque := RoulettePlate.new("RouletteTitlePlaque", TITLE_RECT)
	plaque.fill = Color(RouletteStyle.MAHOGANY, 0.94)
	add_child(plaque)
	move_child(plaque, _title.get_index())
	_title.position = TITLE_RECT.position + Vector2(14, 4)
	_title.size = Vector2(TITLE_RECT.size.x - 28, 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", RouletteStyle.IVORY)
	_status.position = TITLE_RECT.position + Vector2(14, 34)
	_status.size = Vector2(TITLE_RECT.size.x - 28, 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.add_theme_font_size_override("font_size", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.z_index = 1


func _build_seats() -> void:
	guests = RouletteTableGuests.new(table_math)
	for index: int in range(guests.guests.size()):
		var plate := RouletteSeatPlate.new(guests.guests[index])
		plate.position = (
			SEAT_ORIGIN + Vector2(index * (RouletteSeatPlate.PLATE_SIZE.x + SEAT_GAP), 0)
		)
		plate.z_index = 4
		add_child(plate)
		seat_plates.append(plate)


func _style_help_button() -> void:
	if _help_button == null:
		return
	RouletteStyle.style_button(_help_button)
	_help_button.position = Vector2(770, 27)
	_help_button.size = Vector2(142, 44)
	_help_button.add_theme_font_override("font", Typography.UI_FONT)
	_help_button.add_theme_font_size_override("font_size", 14)


func _focus_default_action() -> void:
	if help_open or not is_inside_tree() or board == null:
		return
	board.grab_focus()


func _refresh_help() -> void:
	if _help_title == null:
		return
	_help_button.text = tr("HELP_BUTTON")
	_help_title.text = tr("HELP_TITLE") % tr(cabinet.context.definition.name_key)
	_help_rules.text = tr("HELP_ROULETTE_RULES")
	_help_controls.text = (
		tr("HELP_ROULETTE_CONTROLS")
		% [
			InputRouter.glyph("move"),
			InputRouter.glyph("interact"),
			InputRouter.glyph("secondary"),
			InputRouter.glyph("tertiary"),
			InputRouter.glyph("back"),
		]
	)


func _refresh_deck() -> void:
	var math: RouletteMath = table_math
	var open := _is_betting_open()
	var total := math.total_bet() if open else cabinet.current_stake
	(
		deck
		. refresh_state(
			{
				"balance": cabinet.context.balance,
				"selected": cabinet.selected_stake,
				"total": total,
				"cap": cabinet.bet_cap(),
				"betting_open": open,
				"can_rebet": math.can_rebet(cabinet.bet_cap()),
				"test_bank": Wallet.test_mode_enabled,
			}
		)
	)
	_refresh_spot_text()


func _refresh_spot_text() -> void:
	if deck == null or board == null:
		return
	var id := board.cursor_spot_id()
	var spot := table_math.spot(id)
	if spot.is_empty():
		return
	var pays := tr("ROULETTE_PAYS") % table_math.pays_to_one(spot.kind)
	deck.set_spot_text("%s · %s" % [RouletteSpotNames.describe(spot, self), pays])


func _refresh_status() -> void:
	var text := ""
	if not _notice_key.is_empty():
		text = tr(_notice_key)
	elif cabinet.is_round_active or cabinet.is_result_pending:
		text = tr("ROULETTE_NO_MORE_BETS") if not _ball_landed else _landed_status()
	elif _result != null:
		text = _result_status(_result)
	elif cabinet.selected_stake == 0:
		text = tr("BET_NEED_CASHIER") % cabinet.context.definition.min_bet
	else:
		text = tr("ROULETTE_PLACE_BETS")
	_set_live_text(_status, text)


func _landed_status() -> String:
	return result_plaque.pocket_name(_spin_result.detail.get("pocket", 0))


func _result_status(result: RoundResult) -> String:
	var pocket_text := result_plaque.pocket_name(int(result.detail.get("pocket", 0)))
	if result.payout > 0:
		return tr("ROULETTE_RESULT_WIN") % [pocket_text, result.payout, result.stake]
	return tr("ROULETTE_RESULT_LOSS") % [pocket_text, result.stake]


## Transient table message (limit reached, nothing to rebet, no chips yet).
func show_notice(key: String) -> void:
	_notice_key = key
	if _notice != null and _notice.is_valid():
		_notice.kill()
	_notice = create_tween()
	_notice.tween_interval(NOTICE_SECONDS)
	_notice.tween_callback(
		func() -> void:
			_notice_key = ""
			refresh()
	)
	refresh()


## The cabinet changed the chips on the layout.
func bets_changed() -> void:
	if _result != null or board.result_pocket >= 0:
		_sweep_table()
	refresh()


func remove_at_cursor() -> void:
	cabinet.call("request_remove", board.cursor_spot_id())


## WASD/D-pad from the deck: up returns to the layout, sideways walks the deck.
func navigate_from_deck(direction: Vector2i) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == board:
		return false
	if focused == null or not deck.owns_focus(focused) or direction == Vector2i.UP:
		board.grab_focus()
		return true
	var side := SIDE_LEFT if direction == Vector2i.LEFT else SIDE_RIGHT
	if direction == Vector2i.DOWN:
		return true
	var next := focused.find_valid_focus_neighbor(side)
	if next != null:
		next.grab_focus()
		AudioService.play(&"move")
	return true


## The pocket is already decided; this only presents the wheel reaching it.
func begin_spin(result: RoundResult) -> void:
	_cancel_sweep()
	_spin_result = result
	_ball_landed = false
	_result = null
	board.clear_result()
	board.result_bets = (result.detail.get("bets", {}) as Dictionary).duplicate()
	board.betting_open = false
	if croupier != null:
		croupier.launch_spin()
	AudioService.play(&"spin")
	refresh()
	wheel.spin_to(int(result.detail.get("pocket", 0)))


func present_result_after_reveal(_result_to_show: RoundResult, on_ready: Callable) -> void:
	_result_reveal_active = true
	_result_reveal_callback = on_ready
	refresh()
	_try_finish_reveal()


func _on_ball_landed(pocket: int) -> void:
	if _spin_result == null:
		return
	_ball_landed = true
	AudioService.play(&"reel_stop")
	board.show_result(pocket, _spin_result.detail.get("bets", {}), true)
	guests.settle(pocket)
	for plate: RouletteSeatPlate in seat_plates:
		plate.refresh()
	result_plaque.push(pocket)
	croupier.announce_result()
	refresh()
	_try_finish_reveal()


func _try_finish_reveal() -> void:
	if not _result_reveal_active or not _ball_landed:
		return
	if _reveal_beat != null and _reveal_beat.is_running():
		return
	_reveal_beat = create_tween()
	_reveal_beat.tween_interval(MotionPolicy.finite_duration(REVEAL_BEAT_SECONDS))
	_reveal_beat.tween_callback(_finish_reveal)


func _finish_reveal() -> void:
	if not _result_reveal_active:
		return
	_result_reveal_active = false
	var callback := _result_reveal_callback
	_result_reveal_callback = Callable()
	if callback.is_valid():
		callback.call()


## Called by MiniGame after CabinetSession has settled the round.
func show_result(result: RoundResult) -> void:
	_result = result
	_status_key = "ROUND_READY"
	var won := result.payout > result.stake
	AudioService.play(&"win" if won else &"loss")
	_play_result_impact(result)
	_win_flash.play(
		_result_flash_tint(result), _last_result_impact_tier == ResultImpactTier.BIG_WIN
	)
	if won:
		var multiple := float(result.payout) / maxf(result.stake, 1.0)
		_celebration.burst(_win_origin(result), 24 if multiple >= 5.0 else 12)
	refresh()
	_status.add_theme_color_override(
		"font_color", RouletteStyle.WIN_INK if result.payout > 0 else RouletteStyle.LOSS_INK
	)
	_schedule_sweep()


func _win_origin(result: RoundResult) -> Vector2:
	var winners: Dictionary = result.detail.get("winners", {})
	for id: String in winners:
		return BOARD_ORIGIN + board.geometry.chip_position(id)
	return BOARD_ORIGIN + RouletteBoardGeometry.SIZE * 0.5


func _schedule_sweep() -> void:
	_cancel_sweep()
	_sweep = create_tween()
	_sweep.tween_interval(SWEEP_SECONDS)
	_sweep.tween_callback(_sweep_table)


func _cancel_sweep() -> void:
	if _sweep != null and _sweep.is_valid():
		_sweep.kill()
	_sweep = null


## Losing chips leave, the dolly lifts and the guests bet again.
func _sweep_table() -> void:
	_cancel_sweep()
	_result = null
	_spin_result = null
	_ball_landed = false
	board.clear_result()
	_open_betting(true)
	refresh()


func _open_betting(animate: bool) -> void:
	_status.add_theme_color_override("font_color", RouletteStyle.IVORY_MUTED)
	guests.place_bets()
	board.guest_bets = guests.board_entries()
	for plate: RouletteSeatPlate in seat_plates:
		plate.refresh(animate)
	if croupier != null:
		croupier.open_betting()
	board.queue_redraw()


func set_help_open(open: bool) -> void:
	super.set_help_open(open)
	if board != null:
		refresh()
