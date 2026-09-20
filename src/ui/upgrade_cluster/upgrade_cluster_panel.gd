class_name UpgradeClusterPanel
extends CabinetPanel
## Harlequin Masquerade: the whole presentation of the Upgrade Cluster cabinet.
##
## The maths for a round is finished before this panel is told anything. What it
## does is *replay* that script, one cascade at a time, in a strictly sequential
## timeline where no phase ever overlaps the next:
##
##   1. the winning cluster pulses
##   2. the round's own arithmetic pops over it ("0.32 x256"), holds, floats away
##   3. only then do the tiles shatter into gem shards
##   4. the board tumbles down with a bounce and one small landing shake
##   5. once every cascade is done, a win of 15x or more takes the screen for a
##      bounded celebration that morphs BIG -> SUPER -> MEGA as the counter climbs
##
## Each phase is awaited, so the ordering is a property of the code rather than a
## set of timers that happen to agree. Settlement waits for the whole replay:
## the panel calls the cabinet's reveal callback only after step 5.

const REVEAL_BEAT_SECONDS: float = 0.24
const NOTICE_SECONDS: float = 1.8

var grid: ClusterGrid
var bar: ClusterChargeBar
var popup: ClusterMathPopup
var celebration: ClusterCelebration
var company: HarlequinHost
var deck: CabinetDeck
var math: UpgradeClusterMath
var running_units: int = 0
var replay_cascade: int = -1
var replay_running: bool = false
var _built: bool = false
var _board_root: Control
var _round: RoundResult
var _replay_finished: bool = false
var _shake_tween: Tween
var _notice: Tween
var _notice_key: String = ""
var _win_value: Label
var _win_multiple: Label
var _cascade_line: Label
var _legend_rows: Array[Label] = []


func refresh() -> void:
	if _title == null or cabinet == null or cabinet.context == null:
		return
	if not _built:
		_build_stage()
	_title.text = tr("CLUSTER_THEME_TITLE")
	_refresh_status()
	_refresh_readout()
	_refresh_deck()
	_refresh_help()


# -- Stage --------------------------------------------------------------------


func _build_stage() -> void:
	_built = true
	math = cabinet.get("math")
	_art_id = cabinet.context.definition.id
	# The painted stage replaces the console's flat shade and frame entirely.
	for hidden: CanvasItem in [
		_shade, _frame, _stake, _detail, _controls, _controls_backdrop, _stake_selector
	]:
		hidden.hide()
	var backdrop := ClusterTheme.plate(
		ClusterTheme.BACKDROP, Rect2(0, 0, 960, 540), "HarlequinStage"
	)
	backdrop.z_index = -2
	add_child(backdrop)
	move_child(backdrop, 0)
	company = HarlequinHost.new()
	company.z_index = -1
	add_child(company)
	company.build()
	_board_root = Control.new()
	_board_root.name = "BoardRoot"
	_board_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_root.size = Vector2(960, 540)
	add_child(_board_root)
	# The painted frame is a sibling *behind* the board, never a parent of it: the
	# cells keep their exact geometry whatever the frame art does, and the board
	# fills the frame's own inner window, which is opaque theatre black.
	var frame_art := ClusterTheme.plate(
		ClusterTheme.GRID_FRAME, ClusterTheme.FRAME_RECT, "HarlequinGridFrame"
	)
	_board_root.add_child(frame_art)
	grid = ClusterGrid.new()
	_board_root.add_child(grid)
	grid.build(math.grid_size())
	bar = ClusterChargeBar.new()
	add_child(bar)
	bar.build(math.paytable)
	popup = ClusterMathPopup.new()
	add_child(popup)
	celebration = ClusterCelebration.new()
	add_child(celebration)
	_build_title_plate()
	_build_readout()
	_build_legend()
	_build_deck()
	_style_help_button()
	grid.show_grid(math.fill_grid(_preview_rng()))
	_play_art_entrance()
	call_deferred("_focus_default_action")


## An idle board to look at before the first round. It draws from its own stream
## so the cabinet's replayable sequence is untouched.
func _preview_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260918
	return rng


func _build_title_plate() -> void:
	var plate := Panel.new()
	plate.name = "TitlePlate"
	plate.position = ClusterTheme.TITLE_RECT.position
	plate.size = ClusterTheme.TITLE_RECT.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override(
		"panel", ClusterTheme.box(Color(ClusterTheme.VOID, 0.80), ClusterTheme.EDGE, 2, 7)
	)
	add_child(plate)
	move_child(plate, _title.get_index())
	_title.position = ClusterTheme.TITLE_RECT.position + Vector2(12, 2)
	_title.size = ClusterTheme.TITLE_RECT.size - Vector2(24, 4)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 23)
	_title.add_theme_color_override("font_color", ClusterTheme.TEXT)
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


func _build_readout() -> void:
	var rect := ClusterTheme.READOUT_RECT
	var plate := Panel.new()
	plate.name = "RoundReadout"
	plate.position = rect.position
	plate.size = rect.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override(
		"panel", ClusterTheme.box(Color(ClusterTheme.SURFACE, 0.88), ClusterTheme.EDGE, 2, 7)
	)
	add_child(plate)
	var caption := ClusterTheme.label(
		plate, Rect2(12, 8, 216, 16), Typography.MICRO, ClusterTheme.TEXT_MUTED
	)
	caption.text = tr("CLUSTER_ROUND_WIN")
	_win_value = ClusterTheme.label(plate, Rect2(12, 24, 216, 40), 34, ClusterTheme.WIN)
	_win_value.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_win_multiple = ClusterTheme.label(plate, Rect2(12, 62, 216, 20), 15, ClusterTheme.TEXT)
	_cascade_line = ClusterTheme.label(plate, Rect2(12, 84, 216, 20), 14, ClusterTheme.TEXT_MUTED)
	# The status sentence gets its own row at the foot of the plate, clear of the
	# tumble count above it.
	_status.position = rect.position + Vector2(12, rect.size.y - 26)
	_status.size = Vector2(rect.size.x - 24, 22)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.add_theme_font_size_override("font_size", 14)
	_status.z_index = 2


## The eight symbols and what a smallest cluster of each pays, so the board can
## be read without opening the guide.
func _build_legend() -> void:
	var rect := ClusterTheme.LEGEND_RECT
	var plate := Panel.new()
	plate.name = "ClusterLegend"
	plate.position = rect.position
	plate.size = rect.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override(
		"panel", ClusterTheme.box(Color(ClusterTheme.SURFACE, 0.88), ClusterTheme.EDGE, 2, 7)
	)
	add_child(plate)
	var caption := ClusterTheme.label(
		plate, Rect2(12, 6, 216, 16), Typography.MICRO, ClusterTheme.TEXT_MUTED
	)
	caption.text = tr("CLUSTER_LEGEND_CAPTION") % math.paytable.minimum_cluster
	var columns := 2
	var cell := Vector2((rect.size.x - 20.0) / float(columns), 30.0)
	for index: int in range(ClusterTheme.symbol_count()):
		var column := index % columns
		var row := index / columns
		var origin := Vector2(10.0 + cell.x * float(column), 26.0 + cell.y * float(row))
		var icon := ClusterTheme.plate(
			ClusterTheme.symbol_texture(index),
			Rect2(origin, Vector2(26, 26)),
			"LegendIcon_%d" % index,
			TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		)
		plate.add_child(icon)
		var value := ClusterTheme.label(
			plate, Rect2(origin + Vector2(30, 5), Vector2(cell.x - 36.0, 18)), 14, ClusterTheme.TEXT
		)
		value.text = ClusterTheme.bet_text(
			math.paytable.pay_units(index, math.paytable.minimum_cluster)
		)
		_legend_rows.append(value)


func _build_deck() -> void:
	deck = CabinetDeck.new()
	deck.name = "ClusterDeck"
	deck.build(ClusterTheme.deck_style())
	add_child(deck)
	deck.add_action(&"play", tr("CLUSTER_PLAY"), &"interact", true)
	deck.action_pressed.connect(_on_deck_action)
	deck.bet.step_requested.connect(_on_deck_bet_step)
	deck.quick_bets.operation_requested.connect(_on_deck_quick_bet)


func _style_help_button() -> void:
	if _help_button == null:
		return
	_help_button.position = ClusterTheme.HELP_RECT.position
	_help_button.size = ClusterTheme.HELP_RECT.size


func _focus_default_action() -> void:
	if help_open or not is_inside_tree() or deck == null:
		return
	var primary := deck.primary_button()
	if primary != null and primary.visible:
		primary.grab_focus()


# -- Readouts -----------------------------------------------------------------


func _refresh_status() -> void:
	var text := ""
	if not _notice_key.is_empty():
		text = tr(_notice_key)
	elif replay_running:
		text = tr("CLUSTER_TUMBLING")
	elif _result != null:
		text = (
			tr("CLUSTER_RESULT_WIN") % [_result.payout, _result.stake]
			if _result.payout > 0
			else tr("CLUSTER_RESULT_LOSS") % _result.stake
		)
	elif cabinet.selected_stake == 0:
		text = tr("BET_NEED_CASHIER") % cabinet.context.definition.min_bet
	else:
		text = tr("CLUSTER_READY")
	_set_live_text(_status, text)
	_status.add_theme_color_override(
		"font_color",
		(
			ClusterTheme.WIN
			if _result != null and _result.payout > _result.stake
			else ClusterTheme.TEXT_MUTED
		)
	)


func _refresh_readout() -> void:
	if _win_value == null:
		return
	var stake := maxi(cabinet.current_stake if replay_running else cabinet.selected_stake, 1)
	var chips := UpgradeClusterMath.settle(running_units, stake)
	_win_value.text = str(chips)
	_win_multiple.text = tr("CLUSTER_WIN_MULTIPLE") % ClusterTheme.bet_text(running_units)
	var total := (_round.detail.cascades as Array).size() if _round != null else 0
	if replay_running and total > 0:
		_cascade_line.text = tr("CLUSTER_TUMBLE_COUNT") % [replay_cascade + 1, total]
	elif total == 1:
		_cascade_line.text = tr("CLUSTER_TUMBLE_TOTAL_ONE")
	elif total > 0:
		_cascade_line.text = tr("CLUSTER_TUMBLE_TOTAL") % total
	else:
		_cascade_line.text = tr("CLUSTER_NO_TUMBLES")


func _refresh_deck() -> void:
	if deck == null:
		return
	var idle: bool = cabinet.call("is_idle")
	deck.balance.caption = tr("HUD_TEST_BANK") if Wallet.test_mode_enabled else tr("DECK_BALANCE")
	deck.balance.tag = tr("DECK_TEST_TAG") if Wallet.test_mode_enabled else ""
	if Wallet.test_mode_enabled:
		deck.balance.set_infinite()
	else:
		deck.balance.set_value(cabinet.context.balance)
	var stakes: Array[int] = cabinet.available_stakes()
	deck.bet.set_state(
		cabinet.selected_stake,
		idle,
		idle and not stakes.is_empty() and cabinet.selected_stake > stakes[0],
		idle and not stakes.is_empty() and cabinet.selected_stake < stakes[-1],
		tr("DECK_YOUR_BET") if idle else tr("DECK_IN_PLAY"),
		tr("DECK_TABLE_LIMIT") % [cabinet.context.definition.min_bet, cabinet.bet_cap()],
		stakes
	)
	deck.quick_bets.set_states(cabinet)
	var actions: Array[StringName] = []
	if idle and cabinet.call("can_play"):
		actions.append(&"play")
	deck.show_actions(actions)
	deck.set_instruction(_instruction(idle), _instruction_tone())


func _instruction(idle: bool) -> String:
	if not idle:
		return tr("CLUSTER_DECK_TUMBLING")
	if cabinet.selected_stake <= 0 or cabinet.selected_stake > cabinet.bet_cap():
		return tr("DECK_NEED_FUNDS") % cabinet.context.definition.min_bet
	if _result == null:
		return tr("CLUSTER_DECK_READY")
	if _result.payout > _result.stake:
		return tr("CLUSTER_DECK_RESULT_WIN") % _result.payout
	return tr("CLUSTER_DECK_RESULT_LOSS")


func _instruction_tone() -> InfoPlate.Tone:
	if _result == null:
		return InfoPlate.Tone.NEUTRAL
	if _result.payout > _result.stake:
		return InfoPlate.Tone.WIN
	return InfoPlate.Tone.LOSS if _result.payout < _result.stake else InfoPlate.Tone.PUSH


func _on_deck_action(id: StringName) -> void:
	if id == &"play":
		cabinet.call("request_play")


func _on_deck_bet_step(direction: int) -> void:
	if cabinet.adjust_stake(direction):
		AudioService.play(&"chip")
	refresh()


## MIN / 10 / 25 / X2 / X5 / ALL. The cabinet applies the change under its own
## limits; the deck only asks.
func _on_deck_quick_bet(operation: int) -> void:
	cabinet.apply_bet(operation)
	refresh()


## Transient machine message (no bet placed, bankroll too low).
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


# -- The replay ---------------------------------------------------------------


## The round is already decided. This shows it, and nothing here can change it.
func begin_round(result: RoundResult) -> void:
	_cancel_replay()
	_round = result
	_result = null
	running_units = 0
	replay_cascade = -1
	_replay_finished = false
	bar.reset()
	grid.show_grid(result.detail.grid as PackedByteArray)
	company.set_beat(HarlequinHost.Beat.MASK)
	AudioService.play(&"spin")
	refresh()
	_run_replay()


func present_result_after_reveal(_result_to_show: RoundResult, on_ready: Callable) -> void:
	_result_reveal_active = true
	_result_reveal_callback = on_ready
	refresh()
	_try_finish_reveal()


func _run_replay() -> void:
	replay_running = true
	var round_result := _round
	var cascades: Array = round_result.detail.cascades
	for index: int in range(cascades.size()):
		if round_result != _round:
			return
		replay_cascade = index
		var cascade: Dictionary = cascades[index]
		var cells: PackedInt32Array = cascade.destroyed
		# 1. The winning cluster pulses. Nothing else moves.
		company.set_beat(HarlequinHost.Beat.PRESENT)
		grid.pulse(cells)
		await _beat(ClusterTheme.PULSE_SECONDS)
		if round_result != _round:
			return
		# 2. The bar takes its charge, then the arithmetic pops over the cluster
		#    and is read before anything is destroyed.
		bar.set_charge(int(cascade.charge), int(cascade.multiplier))
		await popup.play(int(cascade.base_units), int(cascade.multiplier), _cluster_centre(cells))
		if round_result != _round:
			return
		running_units += int(cascade.win_units)
		_refresh_readout()
		# 3. Only now do the tiles shatter.
		AudioService.play(&"reel_stop")
		grid.shatter(cells)
		await _beat(ClusterTheme.SHATTER_SECONDS)
		if round_result != _round:
			return
		# 4. The board tumbles down and lands with one small shake.
		grid.tumble_to(cascade.grid_after as PackedByteArray, cells)
		await grid.landed
		if round_result != _round:
			return
		_shake()
	replay_running = false
	replay_cascade = cascades.size() - 1
	# 5. The celebration, once the board has finished moving.
	if round_result.payout > round_result.stake:
		company.set_beat(HarlequinHost.Beat.CHEER)
	elif round_result.payout <= 0:
		company.set_beat(HarlequinHost.Beat.POUT)
	else:
		company.set_beat(HarlequinHost.Beat.IDLE)
	_refresh_readout()
	refresh()
	if ClusterCelebration.earns_celebration(round_result.payout, round_result.stake):
		await celebration.play(round_result.payout, round_result.stake)
		if round_result != _round:
			return
	_replay_finished = true
	_try_finish_reveal()


func _beat(full_motion_seconds: float) -> void:
	var wait := create_tween()
	wait.tween_interval(ClusterTheme.phase(full_motion_seconds))
	await wait.finished


func _cluster_centre(cells: PackedInt32Array) -> Vector2:
	if cells.is_empty():
		return ClusterTheme.GRID_RECT.get_center()
	var sum := Vector2.ZERO
	var columns := math.grid_size()
	for cell: int in cells:
		sum += ClusterTheme.cell_center(cell % columns, cell / columns)
	return sum / float(cells.size())


## One short landing bump on the board only. Bounded, and never under reduced
## motion.
func _shake() -> void:
	AudioService.play(&"move")
	if MotionPolicy.is_reduced() or _board_root == null:
		return
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	var steps: Array[Vector2] = [
		Vector2(0, ClusterTheme.SHAKE_PIXELS),
		Vector2(0, -ClusterTheme.SHAKE_PIXELS * 0.5),
		Vector2.ZERO,
	]
	for step: Vector2 in steps:
		(
			_shake_tween
			. tween_property(
				_board_root, "position", step, ClusterTheme.SHAKE_SECONDS / float(steps.size())
			)
			. set_trans(Tween.TRANS_QUAD)
		)


func _try_finish_reveal() -> void:
	if not _result_reveal_active or not _replay_finished:
		return
	if _result_reveal_beat != null and _result_reveal_beat.is_running():
		return
	_result_reveal_beat = create_tween()
	_result_reveal_beat.tween_interval(ClusterTheme.phase(REVEAL_BEAT_SECONDS))
	_result_reveal_beat.tween_callback(_finish_reveal)


func _finish_reveal() -> void:
	if not _result_reveal_active:
		return
	_result_reveal_active = false
	var callback := _result_reveal_callback
	_result_reveal_callback = Callable()
	if callback.is_valid():
		callback.call()


## Ends the replay wherever it is and leaves the final board readable. Used when
## the round is abandoned or the panel goes away mid-tumble.
func _cancel_replay() -> void:
	replay_running = false
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = null
	if _board_root != null:
		_board_root.position = Vector2.ZERO
	if popup != null:
		popup.settle()
	if celebration != null:
		celebration.settle()
	if grid != null:
		grid.settle()
	if bar != null:
		bar.settle()
	if company != null:
		company.settle()


## Called by MiniGame once CabinetSession has settled the round.
func show_result(result: RoundResult) -> void:
	_result = result
	_status_key = "ROUND_READY"
	var won := result.payout > result.stake
	AudioService.play(&"win" if won else &"loss")
	_play_result_impact(result)
	_win_flash.play(
		ClusterTheme.WIN if won else ClusterTheme.LOSS,
		_last_result_impact_tier == ResultImpactTier.BIG_WIN
	)
	refresh()
	call_deferred("_focus_default_action")


func has_active_motion() -> bool:
	if replay_running:
		return true
	for part: Node in [grid, bar, company, celebration]:
		if part != null and part.call("has_active_motion"):
			return true
	return (_shake_tween != null and _shake_tween.is_valid()) or super.has_active_motion()


# -- Help ---------------------------------------------------------------------


func _refresh_help() -> void:
	if _help_title == null:
		return
	_help_button.text = tr("HELP_BUTTON")
	_help_title.text = tr("HELP_TITLE") % tr(cabinet.context.definition.name_key)
	_help_rules.text = tr("HELP_UPGRADE_CLUSTER_GOAL")
	_help_controls.text = ""


func _help_content() -> Dictionary:
	var payouts: Array = []
	var minimum := math.paytable.minimum_cluster
	for index: int in range(ClusterTheme.symbol_count() - 1, -1, -1):
		(
			payouts
			. append(
				[
					tr("CLUSTER_PAY_CLUSTER_OF") % [minimum, ClusterTheme.symbol_name(index)],
					ClusterTheme.bet_text(math.paytable.pay_units(index, minimum)),
				]
			)
		)
	return {
		"goal": tr("HELP_UPGRADE_CLUSTER_GOAL"),
		"steps": Array(tr("HELP_UPGRADE_CLUSTER_STEPS").split("\n")),
		"controls":
		[
			"{interact} " + tr("HELP_CONTROL_CLUSTER_PLAY"),
			"{bet_down}{bet_up} " + tr("HELP_CONTROL_BET"),
			"{bet_max} " + tr("HELP_CONTROL_BET_MAX"),
			"{help} " + tr("HELP_CONTROL_GUIDE"),
			"{back} " + tr("HELP_CONTROL_LEAVE"),
		],
		"payouts": payouts,
		"payout_caption": tr("CLUSTER_LEGEND_CAPTION") % minimum,
		"notes": [tr("HELP_UPGRADE_CLUSTER_NOTE")],
	}


func set_help_open(open: bool) -> void:
	super.set_help_open(open)
	if grid != null:
		refresh()


func _exit_tree() -> void:
	_cancel_replay()
