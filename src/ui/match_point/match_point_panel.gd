class_name MatchPointPanel
extends CabinetPanel
## Match Point cabinet presentation. Owns the painted clubhouse backdrop, the
## hostess in the window alcove, the code-drawn peg field and courts, and the
## racing-green scoreboard HUD. Game state is read from the cabinet; the panel
## never decides an outcome.

const BACKDROP := preload("res://assets/production/match_point/match_point_backdrop.png")
## The hostess lane: left of the peg field, its bottom edge is the deck top.
const HOST_LANE := Rect2(0, 27, 280, 413)
## Screen point of the hostess's eye line, then down to the cut line.
const HOST_EYE_X: float = 122.0
const HELP_RECT := Rect2(704, 27, 208, 44)
const TITLE_RECT := Rect2(704, 79, 208, 70)
const RESULT_ORIGIN := Vector2(704, 157)
const RISK_RECT := Rect2(704, 329, 208, 103)
const RISK_KEY_SIZE := Vector2(62, 48)
const DECK_ORIGIN := Vector2(48, 440)
const REVEAL_BEAT_SECONDS: float = 0.5
const NOTICE_SECONDS: float = 1.8

var board_math: MatchPointMath
var board: MatchPointBoard
var hostess: MatchPointHostess
var deck: MatchPointDeck
var result_plaque: MatchPointResultPlaque
var risk_buttons: Array[Button] = []
var _risk_caption: Label
var _risk_detail: Label
var _built: bool = false
var _drop_result: RoundResult
var _ball_landed: bool = false
var _reveal_beat: Tween
var _notice: Tween
var _notice_key: String = ""


func refresh() -> void:
	if _title == null or cabinet == null or cabinet.context == null:
		return
	if not _built:
		_build_cabinet()
	_title.text = tr("MATCH_POINT_THEME_TITLE")
	_refresh_status()
	_refresh_deck()
	_refresh_risk()
	_refresh_help()


func _is_open() -> bool:
	return not cabinet.is_round_active and not cabinet.is_result_pending and not help_open


func _build_cabinet() -> void:
	_built = true
	board_math = cabinet.get("math")
	_art_id = cabinet.context.definition.id
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = Color("0a1a11")
	for hidden: CanvasItem in [_stake, _detail, _controls, _controls_backdrop, _stake_selector]:
		hidden.hide()
	_art_root.add_child(_texture("MatchPointClubhouse", BACKDROP, Vector2.ZERO, Vector2(960, 540)))
	_build_hostess()
	board = MatchPointBoard.new()
	board.z_index = 4
	add_child(board)
	board.setup(board_math)
	board.set_risk(cabinet.get("risk"))
	board.ball_landed.connect(_on_ball_landed)
	board.peg_hit.connect(func(_row: int) -> void: AudioService.play(&"move"))
	_build_title_plaque()
	result_plaque = MatchPointResultPlaque.new()
	result_plaque.position = RESULT_ORIGIN
	result_plaque.z_index = 4
	add_child(result_plaque)
	_build_risk_selector()
	deck = MatchPointDeck.new()
	deck.position = DECK_ORIGIN
	deck.z_index = 6
	add_child(deck)
	deck.build(cabinet.stake_options())
	deck.stake_chosen.connect(func(amount: int) -> void: cabinet.select_stake(amount))
	deck.serve_pressed.connect(func() -> void: cabinet.call("request_serve"))
	_link_rows()
	_style_help_button()
	_play_art_entrance()
	call_deferred("_focus_default_action")


func _build_hostess() -> void:
	var lane := Control.new()
	lane.name = "HostessLane"
	lane.position = HOST_LANE.position
	lane.size = HOST_LANE.size
	lane.clip_contents = true
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.add_child(lane)
	hostess = MatchPointHostess.new()
	hostess.place_on_cut(
		Vector2(HOST_EYE_X - HOST_LANE.position.x, HOST_LANE.size.y), HOST_LANE.size
	)
	lane.add_child(hostess)


func _build_title_plaque() -> void:
	var plaque := MatchPointPlate.new("MatchPointTitlePlaque", TITLE_RECT)
	add_child(plaque)
	move_child(plaque, _title.get_index())
	_title.position = TITLE_RECT.position + Vector2(12, 5)
	_title.size = Vector2(TITLE_RECT.size.x - 24, 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", MatchPointStyle.CREAM)
	_status.position = TITLE_RECT.position + Vector2(12, 38)
	_status.size = Vector2(TITLE_RECT.size.x - 24, 24)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.add_theme_font_size_override("font_size", 15)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.add_theme_color_override("font_color", MatchPointStyle.CREAM_MUTED)
	_status.z_index = 1


func _build_risk_selector() -> void:
	var plate := MatchPointPlate.new("MatchPointRiskPlate", RISK_RECT)
	plate.z_index = 4
	add_child(plate)
	_risk_caption = MatchPointStyle.label(
		plate, Rect2(10, 5, 188, 18), 13, MatchPointStyle.CREAM_MUTED
	)
	for index: int in range(MatchPointMath.RISK_KEYS.size()):
		var key := Button.new()
		key.name = "MatchPointRisk%s" % MatchPointMath.RISK_KEYS[index].capitalize()
		key.position = Vector2(8 + index * (RISK_KEY_SIZE.x + 4.0), 26)
		key.size = RISK_KEY_SIZE
		key.focus_mode = Control.FOCUS_ALL
		key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var risk := index as MatchPointMath.Risk
		key.pressed.connect(func() -> void: cabinet.call("request_risk", risk))
		plate.add_child(key)
		ButtonFeedback.attach(key)
		risk_buttons.append(key)
	_risk_detail = MatchPointStyle.label(
		plate, Rect2(10, 78, 188, 18), 13, MatchPointStyle.BRASS_BRIGHT
	)


## Controller focus: the risk row sits above the deck row; left/right walk a row.
func _link_rows() -> void:
	for index: int in range(risk_buttons.size()):
		var key := risk_buttons[index]
		var left := risk_buttons[maxi(index - 1, 0)]
		var right := risk_buttons[mini(index + 1, risk_buttons.size() - 1)]
		key.focus_neighbor_left = key.get_path_to(left)
		key.focus_neighbor_right = key.get_path_to(right)
		key.focus_neighbor_bottom = key.get_path_to(deck.serve_button)
		key.focus_neighbor_top = key.get_path_to(_help_button)
	var deck_keys: Array[Button] = deck.stake_keys.duplicate()
	deck_keys.append(deck.serve_button)
	for key: Button in deck_keys:
		key.focus_neighbor_top = key.get_path_to(risk_buttons[MatchPointMath.Risk.MEDIUM])
	_help_button.focus_neighbor_bottom = _help_button.get_path_to(
		risk_buttons[MatchPointMath.Risk.MEDIUM]
	)


func _style_help_button() -> void:
	if _help_button == null:
		return
	MatchPointStyle.style_button(_help_button)
	_help_button.position = HELP_RECT.position
	_help_button.size = HELP_RECT.size
	_help_button.add_theme_font_override("font", Typography.UI_FONT)
	_help_button.add_theme_font_size_override("font_size", 15)


func _focus_default_action() -> void:
	if help_open or not is_inside_tree() or deck == null:
		return
	deck.focus_serve()


func _refresh_help() -> void:
	if _help_title == null:
		return
	_help_button.text = tr("HELP_BUTTON")
	_help_title.text = tr("HELP_TITLE") % tr(cabinet.context.definition.name_key)
	_help_rules.text = tr("HELP_MATCH_POINT_RULES")
	_help_controls.text = (
		tr("HELP_MATCH_POINT_CONTROLS")
		% [
			InputRouter.glyph("move"),
			InputRouter.glyph("interact"),
			InputRouter.glyph("tertiary"),
			InputRouter.glyph("secondary"),
			InputRouter.glyph("back"),
		]
	)


func _risk() -> MatchPointMath.Risk:
	return cabinet.get("risk")


func _refresh_deck() -> void:
	var open := _is_open()
	var balance: int = cabinet.context.balance
	if cabinet.is_round_active or cabinet.is_result_pending:
		# The live stake is in play until the ball lands and the round settles.
		balance -= cabinet.current_stake
	(
		deck
		. refresh_state(
			{
				"balance": balance,
				"selected": cabinet.selected_stake,
				"cap": cabinet.bet_cap(),
				"open": open,
				"can_serve": open and cabinet.call("can_serve"),
				"max_tenths": board_math.max_tenths(_risk()),
				"risk_key": "MATCH_POINT_RISK_" + MatchPointMath.RISK_KEYS[_risk()],
				"test_bank": Wallet.test_mode_enabled,
			}
		)
	)


func _refresh_risk() -> void:
	var open := _is_open()
	_risk_caption.text = tr("MATCH_POINT_RISK")
	for index: int in range(risk_buttons.size()):
		var key := risk_buttons[index]
		key.text = tr("MATCH_POINT_RISK_" + MatchPointMath.RISK_KEYS[index])
		MatchPointStyle.style_toggle(key, index == _risk())
		key.add_theme_font_size_override("font_size", 16)
		key.disabled = not open
	var table := board_math.tenths_for(_risk())
	_risk_detail.text = (
		tr("MATCH_POINT_RISK_RANGE")
		% [
			MatchPointMath.multiplier_text(table[table.size() / 2]),
			MatchPointMath.multiplier_text(board_math.max_tenths(_risk())),
		]
	)


func _refresh_status() -> void:
	var text := ""
	if not _notice_key.is_empty():
		text = tr(_notice_key)
	elif cabinet.is_round_active or cabinet.is_result_pending:
		text = tr("MATCH_POINT_IN_PLAY") if not _ball_landed else _landed_status()
	elif _result != null:
		text = _result_status(_result)
	elif cabinet.selected_stake == 0:
		text = tr("BET_NEED_CASHIER") % cabinet.context.definition.min_bet
	else:
		text = tr("MATCH_POINT_READY_STATUS")
	_set_live_text(_status, text)


func _landed_status() -> String:
	var tenths: int = _drop_result.detail.get("multiplier_tenths", 0)
	return tr("MATCH_POINT_LANDED") % MatchPointMath.multiplier_text(tenths)


func _result_status(result: RoundResult) -> String:
	var tenths: int = result.detail.get("multiplier_tenths", 0)
	return (
		tr("MATCH_POINT_RESULT_STATUS")
		% [MatchPointMath.multiplier_text(tenths), result.payout, result.stake]
	)


## Transient message (for example: no stake the bankroll can cover).
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


func risk_changed() -> void:
	board.set_risk(_risk())
	if _result != null:
		_result = null
		board.reset_for_serve()
	refresh()


## WASD/D-pad focus walk between the risk row, the deck row and Help.
func navigate(direction: Vector2i) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not _owns_control(focused):
		deck.focus_serve()
		return true
	var side := SIDE_LEFT
	match direction:
		Vector2i.RIGHT:
			side = SIDE_RIGHT
		Vector2i.UP:
			side = SIDE_TOP
		Vector2i.DOWN:
			side = SIDE_BOTTOM
	var next := focused.find_valid_focus_neighbor(side)
	if next != null and next != focused:
		next.grab_focus()
		AudioService.play(&"move")
	return true


func _owns_control(control: Control) -> bool:
	return deck.owns_focus(control) or risk_buttons.has(control) or control == _help_button


## The court and path are already decided; this only presents the serve and
## the ball hopping down that path.
func begin_drop(result: RoundResult) -> void:
	_drop_result = result
	_ball_landed = false
	_result = null
	_status.add_theme_color_override("font_color", MatchPointStyle.CREAM_MUTED)
	board.set_risk(result.detail.get("risk", _risk()))
	if hostess != null:
		hostess.serve()
	AudioService.play(&"chip")
	refresh()
	var path: Array[int] = []
	path.assign(result.detail.get("path", []))
	board.drop(path, int(result.detail.get("slot", 0)))


func present_result_after_reveal(_result_to_show: RoundResult, on_ready: Callable) -> void:
	_result_reveal_active = true
	_result_reveal_callback = on_ready
	refresh()
	_try_finish_reveal()


func _on_ball_landed(_court: int) -> void:
	if _drop_result == null:
		return
	_ball_landed = true
	AudioService.play(&"reel_stop")
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
	var tenths: int = result.detail.get("multiplier_tenths", 0)
	AudioService.play(&"win" if won else &"loss")
	_play_result_impact(result)
	_win_flash.play(
		_result_flash_tint(result), _last_result_impact_tier == ResultImpactTier.BIG_WIN
	)
	if won:
		var court: int = result.detail.get("slot", 6)
		var multiple := float(result.payout) / maxf(result.stake, 1.0)
		_celebration.burst(MatchPointBoard.court_rest(court), 24 if multiple >= 5.0 else 12)
	if hostess != null:
		hostess.react_to_result(won)
	result_plaque.push(tenths, won, _return_line(result))
	refresh()
	_status.add_theme_color_override(
		"font_color", MatchPointStyle.WIN_INK if won else MatchPointStyle.LOSS_INK
	)
	call_deferred("_focus_default_action")


func _return_line(result: RoundResult) -> String:
	var court: int = result.detail.get("slot", 0)
	return tr("MATCH_POINT_RETURN_LINE") % [court + 1, result.payout]


func set_help_open(open: bool) -> void:
	super.set_help_open(open)
	if deck != null:
		refresh()
