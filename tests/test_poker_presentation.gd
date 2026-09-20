extends GutTest
## Hold'em table presentation: integration with the session, input gating,
## layout bounds, the unique dealer, reduced motion and the wallet boundary.

const POKER_DEFINITION: CabinetDefinition = preload("res://data/cabinets/poker.tres")
const TV_SAFE := Rect2(48, 27, 864, 486)
const DECK_TOP := 430.0
const HOW_TO_PLAY := Rect2(770, 28, 142, 38)

var _starting_balance: int
var _starting_test_mode: bool


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	Wallet.reset(2000)
	RNGService.reset(20260918)
	MotionPolicy.clear_test_override()


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.set_test_mode(false)
	Wallet.reset(_starting_balance)
	Wallet.set_test_mode(_starting_test_mode)


func _open(reduced: bool) -> CabinetSession:
	MotionPolicy.set_reduced_motion_for_tests(reduced)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(POKER_DEFINITION)
	return session


func _panel(session: CabinetSession) -> PokerTablePanel:
	return session.cabinet.panel as PokerTablePanel


## Plays the hand to its end, calling or checking every decision.
func _play_out(session: CabinetSession) -> void:
	var game := session.cabinet
	var panel := _panel(session)
	var guard := 0
	while (game.is_round_active or game.is_result_pending) and guard < 200:
		panel.finish_presentation()
		if game.call("input_ready"):
			game.call("request_primary")
		elif game.is_result_pending:
			panel._try_complete_result_reveal()
			await wait_seconds(0.4)
		guard += 1


func test_definition_and_scene_are_registered_for_the_vip_room() -> void:
	assert_true(POKER_DEFINITION.is_valid_definition())
	assert_eq(POKER_DEFINITION.id, &"poker")
	assert_eq(POKER_DEFINITION.tier, CabinetDefinition.Tier.VIP)
	assert_true(CabinetSceneRegistry.has_scene(&"poker"))
	var floor_data: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://data/floors/vip.json")
	)
	assert_true((floor_data.cabinets as Array).has("poker"), "The VIP penthouse lists the table")


func test_panel_is_the_poker_table_subclass_with_unique_dealer() -> void:
	var session := _open(true)
	var panel := _panel(session)
	assert_true(panel is PokerTablePanel)
	assert_not_null(panel.dealer)
	var dealer_path := panel.dealer.host().portrait_texture().resource_path
	assert_string_contains(dealer_path, "poker_dealer")
	for other: String in ["slot_", "blackjack_", "vault_"]:
		assert_false(dealer_path.get_file().begins_with(other), "Dealer is her own person")
	for pose: StringName in panel.dealer.host().pose_ids():
		var texture := panel.dealer.host().pose_texture(pose)
		assert_gte(texture.get_width(), 1024, "%s master width" % pose)
		assert_gte(texture.get_height(), 1536, "%s master height" % pose)
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		for corner: Vector2i in [
			Vector2i.ZERO,
			Vector2i(image.get_width() - 1, 0),
			Vector2i(0, image.get_height() - 1),
			Vector2i(image.get_width() - 1, image.get_height() - 1),
		]:
			assert_almost_eq(image.get_pixelv(corner).a, 0.0, 0.01, "%s alpha corner" % pose)


func test_dealer_stands_behind_the_rail_clear_of_the_board_and_plates() -> void:
	var session := _open(true)
	var panel := _panel(session)
	var visible := panel.dealer.visible_bounds()
	assert_almost_eq(visible.end.y, PokerDealerPresenter.RAIL_Y, 0.5, "Cut at the far rail")
	var occluder := panel.dealer.occluder_rect()
	assert_true(
		occluder.encloses(Rect2(visible.position.x, PokerDealerPresenter.RAIL_Y, visible.size.x, 1))
	)
	var full := panel.dealer.host().lane_bounds()
	assert_lte(full.end.y, occluder.end.y + 0.5, "Every pose's legs stay behind the occluder")
	var board := Rect2(PokerFelt.BOARD_ORIGIN, Vector2(5 * 58 - 8, 70))
	assert_false(visible.intersects(board))
	for plate: PokerSeatPlate in panel.plates:
		assert_false(visible.intersects(plate.get_rect()), "Dealer clear of %s" % plate.name)
	assert_false(visible.intersects(HOW_TO_PLAY))
	# The card release point is her dealing hand, above the rail.
	var release := PokerDealerPresenter.card_release_point()
	assert_true(visible.grow(4).has_point(release))


func test_layout_stays_tv_safe_and_never_overlaps() -> void:
	var session := _open(true)
	var panel := _panel(session)
	var rects: Array[Rect2] = []
	for plate: PokerSeatPlate in panel.plates:
		assert_true(TV_SAFE.encloses(plate.get_rect()) or plate.get_rect().position.x >= 16.0)
		assert_lte(plate.get_rect().end.y, DECK_TOP)
		rects.append(plate.get_rect())
	for index: int in range(rects.size()):
		for other: int in range(index + 1, rects.size()):
			assert_false(
				rects[index].intersects(rects[other]), "Plates %d/%d overlap" % [index, other]
			)
	for seat: int in range(1, 6):
		var hole := Rect2(PokerFelt.HOLE_ORIGINS[seat], Vector2(48, 44))
		var show := Rect2(PokerFelt.SHOWDOWN_ORIGINS[seat], Vector2(80, 53))
		for plate_index: int in range(rects.size()):
			assert_false(hole.intersects(rects[plate_index]), "seat %d cards cover a plate" % seat)
			assert_false(
				show.intersects(rects[plate_index]), "seat %d showdown covers a plate" % seat
			)
		var board := Rect2(PokerFelt.BOARD_ORIGIN, Vector2(5 * 58 - 8, 70))
		assert_false(show.intersects(board), "seat %d showdown clear of the board" % seat)
	for button: Button in [panel.fold_button, panel.call_button, panel.raise_button]:
		assert_gte(button.size.x, 44.0)
		assert_gte(button.size.y, 44.0)
		assert_eq(button.focus_mode, Control.FOCUS_ALL)
		assert_true(TV_SAFE.encloses(button.get_rect()))
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		assert_eq(focus.border_color, Color("48c5d5"), "Cyan only as the focus ring")
		var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
		assert_ne(normal.border_color, Color("48c5d5"))
	for button: Button in panel._stake_buttons:
		assert_gte(button.size.y, 44.0)
		assert_true(TV_SAFE.encloses(button.get_rect()))


func test_labels_respect_the_text_floor() -> void:
	var session := _open(true)
	var panel := _panel(session)
	for node: Node in panel.find_children("*", "Label", true, false):
		var label := node as Label
		assert_gte(label.get_theme_font_size("font_size"), Typography.BODY_MIN, label.name)


func test_input_waits_for_the_table_then_actions_resolve_through_the_session() -> void:
	var session := _open(false)
	var game := session.cabinet
	var panel := _panel(session)
	game.select_stake(10)
	var before := Wallet.balance
	assert_true(game.call("start_round", 10))
	assert_eq(Wallet.balance, before, "Nothing settles mid-hand")
	if game.call("input_ready"):
		pass
	else:
		assert_false(game.call("request_raise"), "No input while NPCs are still acting")
	panel.finish_presentation()
	var math: PokerMath = game.get("math")
	if math.is_player_turn():
		assert_true(game.call("input_ready"))
		assert_eq(game.current_stake, math.player_committed())
	await _play_out(session)
	assert_false(game.is_round_active)
	var result := math.last_result
	assert_not_null(result)
	assert_eq(Wallet.balance, before - result.stake + result.payout, "Wallet moved once")


func test_abandon_mid_hand_forfeits_committed_chips() -> void:
	var session := _open(true)
	var game := session.cabinet
	var panel := _panel(session)
	var before := Wallet.balance
	var math: PokerMath = game.get("math")
	var attempts := 0
	while attempts < 10:
		attempts += 1
		assert_true(game.call("start_round", 10))
		panel.finish_presentation()
		if game.is_round_active and not game.is_result_pending:
			break
		await _play_out(session)
		before = Wallet.balance
	assert_true(game.is_round_active, "A live hand awaits the player")
	game.call("request_primary")
	panel.finish_presentation()
	var committed := math.player_committed()
	if game.is_round_active and not game.is_result_pending:
		session.close()
		assert_eq(Wallet.balance, before - committed, "Leaving forfeits exactly the chips in")


func test_reduced_motion_shortens_thinking_and_deals_instantly() -> void:
	var session := _open(true)
	var game := session.cabinet
	var panel := _panel(session)
	assert_true(game.call("start_round", 10))
	var elapsed := 0.0
	while not panel.presentation_idle() and elapsed < 6.0:
		await wait_seconds(0.1)
		elapsed += 0.1
	assert_true(panel.presentation_idle(), "Reduced-motion hand catches up quickly")
	for seat: int in panel.felt.seat_cards:
		for card: PlayingCard in panel.felt.seat_cards[seat]:
			assert_eq(card.scale, Vector2.ONE, "Cards are placed, not flying")
			assert_almost_eq(card.modulate.a, 1.0, 0.01)
	if panel.felt.seat_cards.has(0):
		for card: PlayingCard in panel.felt.seat_cards[0]:
			assert_false(card.face_down, "The player's cards are face up at once")
	assert_eq(panel.dealer.current_pose(), &"rest", "Reduced motion holds the master pose")


func test_seat_plates_show_names_stacks_and_last_actions() -> void:
	var session := _open(true)
	var game := session.cabinet
	var panel := _panel(session)
	assert_true(game.call("start_round", 10))
	panel.finish_presentation()
	var math: PokerMath = game.get("math")
	var acted_seen := false
	for event: Dictionary in math.events:
		if event.type in [&"blind", &"action"] and int(event.seat) != 0:
			acted_seen = true
	assert_true(acted_seen)
	for seat: int in range(1, 6):
		var plate := panel.plates[seat]
		assert_eq(plate.display_name(), tr(math.npcs[seat - 1].name_key))
		assert_not_null(plate.portrait_texture())
	var last_by_seat: Dictionary = {}
	for event: Dictionary in math.events:
		if event.type == &"action" and int(event.seat) != 0:
			last_by_seat[int(event.seat)] = event
	for seat: int in last_by_seat:
		var expected := panel._action_text(last_by_seat[seat])
		assert_eq(
			panel.plates[seat].action_text(), expected, "Plate %d shows its last action" % seat
		)


func test_npc_portraits_are_unique_people() -> void:
	var paths: Dictionary = {}
	for entry: Array in PokerTablePanel.PORTRAITS.values():
		for texture: Texture2D in entry:
			assert_false(paths.has(texture.resource_path))
			paths[texture.resource_path] = true
			assert_gte(texture.get_width(), 512)
	assert_eq(paths.size(), 10, "Five regulars, each with a reaction face")


func test_showdown_reveals_and_highlights_the_winner() -> void:
	var session := _open(true)
	var game := session.cabinet
	var panel := _panel(session)
	var math: PokerMath = game.get("math")
	var found := false
	for hand: int in range(30):
		assert_true(game.call("start_round", 10))
		await _play_out(session)
		var showdown := false
		for event: Dictionary in math.events:
			if event.type == &"showdown":
				showdown = true
		if showdown:
			found = true
			var any_winner := false
			for plate: PokerSeatPlate in panel.plates:
				any_winner = any_winner or plate.winner
			var award_to_player := false
			for event: Dictionary in math.events:
				if event.type == &"award" and (event.winners as Array).has(0):
					award_to_player = true
			assert_true(any_winner or award_to_player, "A winner is marked on the table")
			assert_true(panel._result_plate.visible, "The result plaque names the outcome")
			break
	assert_true(found, "A showdown occurred within 30 called-down hands")
