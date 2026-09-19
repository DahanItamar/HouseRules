extends GutTest
## Match Point: exact binomial math for every risk table, the draw-to-path
## unranking, a board that only ever lands in the decided court, settlement
## after the landing, a unique clean hostess clear of the play surfaces, 44 px
## targets inside TV-safe, controller routes and reduced motion.

const DEFINITION_PATH := "res://data/cabinets/match_point.tres"
const TV_SAFE := Rect2(48, 27, 864, 486)
const MIN_TARGET: float = 44.0
const RISKS: Array[int] = [
	MatchPointMath.Risk.LOW, MatchPointMath.Risk.MEDIUM, MatchPointMath.Risk.HIGH
]
const OTHER_HOSTS: Array[String] = [
	"res://assets/production/characters/hosts/slot_elf_princess.png",
	"res://assets/production/characters/hosts/slot_hostess_v2.png",
	"res://assets/production/characters/hosts/blackjack_dealer_v2.png",
	"res://assets/production/characters/hosts/vault_witcher_sorceress.png",
	"res://assets/production/characters/hosts/vault_attendant_v2.png",
	"res://assets/production/characters/hosts/roulette_croupier.png",
	"res://assets/production/characters/hosts/poker_dealer.png",
]
var _starting_test_mode: bool
var _starting_balance: int


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	_starting_balance = Wallet.balance
	Wallet.test_mode_enabled = false
	Wallet.reset(1000)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.test_mode_enabled = _starting_test_mode
	Wallet.reset(_starting_balance)


func _open() -> CabinetSession:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(load(DEFINITION_PATH))
	return session


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_every_risk_table_is_symmetric_with_the_documented_exact_rtp() -> void:
	var math := MatchPointMath.new()
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	assert_eq(math.rows(), 12)
	assert_eq(math.slot_count(), 13)
	assert_eq(math.total_paths(), 4096)
	var ways_total: int = 0
	for court: int in range(13):
		ways_total += math.ways(court)
	assert_eq(ways_total, 4096, "The binomial weights cover every path once")
	for risk: int in RISKS:
		var table := math.tenths_for(risk)
		assert_eq(table.size(), 13, "Risk %d has 13 courts" % risk)
		for court: int in range(13):
			assert_eq(
				table[court], table[12 - court], "Risk %d court %d is symmetric" % [risk, court]
			)
			assert_gt(table[court], 0, "Every court returns something")
		assert_eq(
			math.return_numerator(risk),
			math.paytable.exact_return_numerator,
			"Risk %d returns exactly 39320 / 40960" % risk
		)
		assert_eq(math.exact_rtp(risk), 0.9599609375, "Risk %d exact RTP" % risk)
		assert_almost_eq(math.exact_rtp(risk), definition.target_rtp, 0.0005)
		# Edges pay the most and the centre the least.
		assert_eq(math.max_tenths(risk), table[0])
		assert_eq(Array(table).min(), table[6])
	assert_lt(math.max_tenths(MatchPointMath.Risk.LOW), math.max_tenths(MatchPointMath.Risk.MEDIUM))
	assert_lt(
		math.max_tenths(MatchPointMath.Risk.MEDIUM), math.max_tenths(MatchPointMath.Risk.HIGH)
	)


func test_legal_stakes_always_settle_to_whole_chips() -> void:
	var math := MatchPointMath.new()
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	assert_eq(definition.min_bet % math.paytable.stake_unit, 0)
	assert_eq(definition.max_bet % math.paytable.stake_unit, 0)
	for stake: int in [10, 20, 50, 100, 200]:
		assert_true(math.is_legal_stake(stake))
		for risk: int in RISKS:
			for court: int in range(13):
				var exact := stake * math.multiplier_tenths(risk, court)
				assert_eq(exact % 10, 0, "%d on %d/%d is a whole payout" % [stake, risk, court])
				assert_eq(math.payout_for(stake, risk, court), exact / 10)
	assert_false(math.is_legal_stake(15))
	assert_false(math.is_legal_stake(0))


func test_each_draw_unranks_to_a_unique_path_that_ends_in_its_court() -> void:
	var math := MatchPointMath.new()
	var seen: Dictionary = {}
	var per_court: Array[int] = []
	per_court.resize(13)
	for value: int in range(math.total_paths()):
		var court := math.slot_for_draw(value)
		var path := math.path_for_draw(value)
		assert_eq(path.size(), 12)
		var rights: int = 0
		for hop: int in path:
			assert_true(hop == 0 or hop == 1)
			rights += hop
		if rights != court:
			fail_test("Draw %d: path has %d rights but court %d" % [value, rights, court])
			return
		var key := str(path)
		if seen.has(key):
			fail_test("Draw %d repeats the path of draw %d" % [value, seen[key]])
			return
		seen[key] = value
		per_court[court] += 1
	assert_eq(seen.size(), 4096, "All 4096 left/right sequences appear exactly once")
	for court: int in range(13):
		assert_eq(per_court[court], MatchPointMath.choose(12, court), "Court %d weight" % court)


func test_one_drop_uses_exactly_one_draw_from_the_cabinet_stream() -> void:
	var math := MatchPointMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260919
	var expected := RandomNumberGenerator.new()
	expected.seed = 20260919
	for round_index: int in range(200):
		var risk: int = RISKS[round_index % 3]
		var result := math.drop(50, risk, rng)
		var value := expected.randi_range(0, 4095)
		assert_eq(result.detail.draw, value, "One uniform draw per drop")
		assert_eq(result.detail.slot, math.slot_for_draw(value))
		assert_eq(result.detail.path, math.path_for_draw(value))
		assert_eq(result.detail.risk, risk)
		assert_eq(result.stake, 50)
		assert_eq(result.payout, math.payout_for(50, risk, result.detail.slot))
		var outcome := RoundResult.Outcome.LOSS
		if result.payout > 50:
			outcome = RoundResult.Outcome.WIN
		elif result.payout == 50:
			outcome = RoundResult.Outcome.PUSH
		assert_eq(result.outcome, outcome)
	assert_eq(rng.state, expected.state, "No hidden extra draws")


func test_board_travel_ends_in_the_decided_court_for_every_path() -> void:
	var math := MatchPointMath.new()
	for value: int in range(math.total_paths()):
		var path := math.path_for_draw(value)
		var points := MatchPointBoard.waypoints_for(path)
		assert_eq(points.size(), 14, "Hatch, 12 posts, court")
		var court := math.slot_for_draw(value)
		if points[-1] != MatchPointBoard.court_rest(court):
			fail_test("Draw %d ends away from court %d" % [value, court])
			return
		for row: int in range(12):
			var step := points[row + 2].x - points[row + 1].x if row < 11 else 0.0
			if row < 11 and absf(absf(step) - MatchPointBoard.PITCH * 0.5) > 4.1:
				fail_test("Draw %d hops more than one gap at row %d" % [value, row])
				return
	pass_test("Every path is a chain of single-gap hops into its own court")


func test_animated_drop_lands_in_the_decided_court() -> void:
	var math := MatchPointMath.new()
	var board := MatchPointBoard.new()
	add_child_autofree(board)
	board.setup(math)
	var landed: Array[int] = []
	board.ball_landed.connect(func(court: int) -> void: landed.append(court))
	for value: int in [0, 4095, 2047, 1234]:
		var court := math.slot_for_draw(value)
		board.drop(math.path_for_draw(value), court)
		assert_true(board.dropping)
		var guard: int = 0
		while board.dropping and guard < 2000:
			board._process(1.0 / 60.0)
			guard += 1
		assert_false(board.dropping, "The drop finishes")
		assert_eq(board.landed_court, court)
		assert_eq(landed[-1], court)
		assert_eq(board.hit_rows, 12, "The ball touched one post in every row")
		assert_lt(guard * (1.0 / 60.0), 3.2, "A drop stays short enough to read")


func test_drop_settles_only_after_the_ball_lands() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var panel: MatchPointPanel = game.panel
	game.select_stake(50)
	assert_true(game.call("request_risk", MatchPointMath.Risk.HIGH))
	assert_true(game.call("request_serve"))
	var result: RoundResult = panel._drop_result
	assert_true(game.is_result_pending, "Settlement waits for the ball")
	assert_eq(Wallet.balance, 1000, "Wallet untouched while the ball is in play")
	assert_true(panel.board.dropping)
	assert_false(game.call("request_risk", MatchPointMath.Risk.LOW), "Risk is locked mid-drop")
	assert_false(game.call("request_serve"), "One ball at a time")
	await wait_seconds(0.4)
	assert_eq(Wallet.balance, 1000, "Still untouched mid-drop")
	panel.board.settle()
	assert_eq(panel.board.landed_court, result.detail.slot, "Board marks the decided court")
	await wait_seconds(MatchPointPanel.REVEAL_BEAT_SECONDS + 0.2)
	assert_false(game.is_round_active)
	assert_eq(Wallet.balance, 1000 - 50 + result.payout, "One settlement after landing")
	assert_eq(panel.result_plaque.last_tenths(), result.detail.multiplier_tenths)


func test_wallet_guards_refuse_a_serve_the_bankroll_cannot_cover() -> void:
	Wallet.reset(5)
	var game: MiniGame = _open().cabinet
	assert_eq(game.selected_stake, 0, "No stake below the 10-credit minimum")
	assert_false(game.call("can_serve"))
	assert_false(game.call("request_serve"))
	assert_false(game.is_round_active)
	assert_true((game.panel as MatchPointPanel).deck.serve_button.disabled)
	Wallet.reset(60)
	var rich: MiniGame = _open().cabinet
	assert_eq(rich.available_stakes(), [10, 20, 50] as Array[int], "Keys above the bankroll lock")
	assert_false(rich.select_stake(100))


func test_hostess_is_unique_clean_and_registered() -> void:
	var panel: MatchPointPanel = _open().cabinet.panel
	var hostess := panel.hostess
	assert_eq(hostess.pose_ids(), [&"idle", &"serve", &"watch", &"celebrate"] as Array[StringName])
	for id: StringName in hostess.pose_ids():
		var texture := hostess.pose_texture(id)
		var path := texture.resource_path
		assert_true(
			path.begins_with("res://assets/production/characters/hosts/match_point_hostess"), path
		)
		assert_false(OTHER_HOSTS.has(path), "%s is not another game's person" % path)
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		assert_eq(image.get_size(), Vector2i(1392, 2080), path)
		var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner %s is clear" % [path, corner])
		assert_lt(_grey_rim_fraction(image), 0.08, "%s has no grey matte rim" % path)


## Share of soft-edge texels that are still the grey edit backdrop.
func _grey_rim_fraction(image: Image) -> float:
	var rim: int = 0
	var grey: int = 0
	for y: int in range(0, image.get_height(), 3):
		for x: int in range(0, image.get_width(), 3):
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.07 or pixel.a >= 0.94:
				continue
			rim += 1
			var spread := maxf(absf(pixel.r - pixel.g), absf(pixel.g - pixel.b))
			if spread < 0.03 and pixel.r > 0.45 and pixel.r < 0.67:
				grey += 1
	return float(grey) / float(maxi(rim, 1))


func test_hostess_and_hud_stay_clear_of_the_play_surfaces() -> void:
	var panel: MatchPointPanel = _open().cabinet.panel
	var lane := panel.hostess.get_parent() as Control
	assert_true(lane.clip_contents, "The deck hides her below mid-thigh")
	var lane_rect := Rect2(lane.position, lane.size)
	var field := MatchPointBoard.field_rect()
	var deck_rect := Rect2(panel.deck.position, panel.deck.size)
	var protected: Array[Rect2] = [
		field,
		deck_rect,
		MatchPointPanel.TITLE_RECT,
		MatchPointPanel.RISK_RECT,
		Rect2(panel.result_plaque.position, panel.result_plaque.size),
		panel._help_button.get_global_rect(),
	]
	for rect: Rect2 in protected:
		assert_false(lane_rect.intersects(rect), "Hostess lane stays clear of %s" % rect)
	for id: StringName in panel.hostess.pose_ids():
		var bounds := panel.hostess.pose_bounds(id)
		assert_gte(bounds.position.x, 0.0, "%s is not cut on the left" % id)
		assert_lte(bounds.end.x, lane.size.x, "%s is not cut on the right" % id)
		assert_gte(bounds.position.y, 0.0, "%s is not cut at the top" % id)
		assert_gte(bounds.end.y, lane.size.y, "%s reaches the deck (no floating gap)" % id)
	for court: int in range(13):
		assert_true(field.encloses(MatchPointBoard.court_rect(court)))
	for rect: Rect2 in protected.slice(1):
		assert_false(field.intersects(rect), "HUD %s stays off the board" % rect)


func test_controls_are_large_enough_and_inside_tv_safe() -> void:
	var panel: MatchPointPanel = _open().cabinet.panel
	var controls: Array[Control] = [panel._help_button, panel.deck.serve_button]
	controls.append_array(panel.deck.stake_keys)
	controls.append_array(panel.risk_buttons)
	assert_eq(controls.size(), 10, "Help, Serve, five stakes, three risks")
	var field := MatchPointBoard.field_rect()
	for control: Control in controls:
		var rect := control.get_global_rect()
		assert_gte(rect.size.x, MIN_TARGET, "%s width" % control.name)
		assert_gte(rect.size.y, MIN_TARGET, "%s height" % control.name)
		assert_true(TV_SAFE.encloses(rect), "%s %s is inside TV-safe" % [control.name, rect])
		assert_false(rect.intersects(field), "%s stays off the board" % control.name)
		assert_eq(control.focus_mode, Control.FOCUS_ALL, "%s takes focus" % control.name)


func test_reduced_motion_lands_at_once_with_one_bounded_cue() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var game: MiniGame = _open().cabinet
	var panel: MatchPointPanel = game.panel
	assert_true(game.call("request_serve"))
	assert_true(panel._ball_landed, "The ball is already in its court")
	assert_false(panel.board.dropping)
	assert_eq(panel.board.landed_court, panel._drop_result.detail.slot)
	assert_eq(panel.board.ball_position, MatchPointBoard.court_rest(panel.board.landed_court))
	assert_gt(panel.board._cue_left, 0.0)
	assert_lte(panel.board._cue_left, MatchPointBoard.REDUCED_CUE_SECONDS)
	assert_eq(panel.hostess.current_pose, &"idle", "Host keeps the static master pose")
	await wait_seconds(0.7)
	assert_false(game.is_round_active)
	assert_eq(panel.board._cue_left, 0.0, "The cue is finite")
	assert_eq(panel.hostess.current_pose, &"idle")


func test_reduced_motion_switch_mid_drop_snaps_to_the_decided_court() -> void:
	var game: MiniGame = _open().cabinet
	var panel: MatchPointPanel = game.panel
	assert_true(game.call("request_serve"))
	assert_true(panel.board.dropping)
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(panel.board.dropping)
	assert_eq(panel.board.landed_court, panel._drop_result.detail.slot)
	await wait_seconds(0.6)
	assert_false(game.is_round_active)


func test_back_mid_drop_asks_before_leaving() -> void:
	var game: MiniGame = _open().cabinet
	assert_true(game.call("request_serve"))
	game._unhandled_input(_action("back"))
	assert_true(game.exit_confirmation.is_open, "Live stake needs the exit confirmation")


func test_controller_serves_changes_risk_and_walks_the_keys() -> void:
	var game: MiniGame = _open().cabinet
	var panel: MatchPointPanel = game.panel
	await wait_process_frames(2)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.deck.serve_button, "Serve has focus")
	var risk_before: int = game.get("risk")
	game._unhandled_input(_action("secondary"))
	assert_eq(game.get("risk"), (risk_before + 1) % 3, "X cycles the risk table")
	assert_eq(panel.board.risk, game.get("risk"), "The courts show the new table")
	game._unhandled_input(_action("move_left"))
	assert_eq(
		get_viewport().gui_get_focus_owner(), panel.deck.stake_keys[-1], "Left walks the deck"
	)
	game._unhandled_input(_action("move_up"))
	assert_true(panel.risk_buttons.has(get_viewport().gui_get_focus_owner()), "Up reaches risk")
	game._unhandled_input(_action("move_down"))
	assert_eq(get_viewport().gui_get_focus_owner(), panel.deck.serve_button, "Down returns")
	game._unhandled_input(_action("tertiary"))
	assert_true(game.is_round_active, "Y serves")
	game._unhandled_input(_action("secondary"))
	assert_eq(game.get("risk"), (risk_before + 1) % 3, "Risk is locked while the ball is live")


func test_every_match_point_label_is_translated() -> void:
	var keys: Array[String] = [
		"CABINET_MATCH_POINT_NAME",
		"HELP_MATCH_POINT_RULES",
		"HELP_MATCH_POINT_CONTROLS",
		"MATCH_POINT_RESULT_WIN",
		"MATCH_POINT_RESULT_OUT",
		"MATCH_POINT_RESULT_LET",
	]
	for risk_key: String in MatchPointMath.RISK_KEYS:
		keys.append("MATCH_POINT_RISK_" + risk_key)
	for key: String in keys:
		assert_ne(tr(key), key, "%s is translated" % key)
