extends GutTest

const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
## Top of the blackjack control deck; nothing on the felt may reach it.
const DECK_TOP := 424.0
const HOW_TO_PLAY := Rect2(770, 28, 142, 38)
const TV_SAFE := Rect2(48, 27, 864, 486)

var _starting_balance: int
var _starting_test_mode: bool


func before_each() -> void:
	_starting_balance = Wallet.balance
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.test_mode_enabled = false
	Wallet.reset(200)
	MotionPolicy.clear_test_override()


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.test_mode_enabled = _starting_test_mode
	Wallet.reset(_starting_balance)


func _open(reduced: bool) -> CabinetPanel:
	MotionPolicy.set_reduced_motion_for_tests(reduced)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	return session.cabinet.panel


## Card rect grown by the corner sweep of its small fan rotation.
func _card_bounds(card: PlayingCard) -> Rect2:
	var sweep := absf(sin(card.rotation)) * card.size.y * 0.5 + 1.0
	return Rect2(card.position, card.size).grow(sweep)


func test_totals_are_badged_beside_each_hand_and_actions_stay_controller_ready() -> void:
	var panel := _open(true)
	panel._clear_blackjack_cards()
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	var dealer_badge := panel.find_child("DealerTotalBadge", true, false) as Panel
	var player_badge := panel.find_child("PlayerTotalBadge", true, false) as Panel
	assert_not_null(dealer_badge)
	assert_not_null(player_badge)
	assert_true(dealer_badge.visible and player_badge.visible)
	for entry: Array in [[dealer_badge, "DealerCard"], [player_badge, "PlayerCard"]]:
		var badge: Panel = entry[0]
		var last := panel.find_child("%s1" % entry[1], true, false) as PlayingCard
		var card_rect := _card_bounds(last)
		var badge_rect := badge.get_rect()
		assert_between(
			badge_rect.position.x - card_rect.end.x,
			0.0,
			16.0,
			"%s rides beside its hand" % badge.name
		)
		assert_between(
			badge_rect.get_center().y,
			card_rect.position.y,
			card_rect.end.y,
			"%s is level with its hand" % badge.name
		)
		assert_false(badge_rect.intersects(card_rect), "%s never covers a card" % badge.name)
		assert_lte(badge_rect.size.y, 28.0, "Compact badge, not a side panel")
		assert_true(TV_SAFE.encloses(badge_rect))
		var label := badge.get_child(0) as Label
		assert_gte(label.get_theme_font_size("font_size"), 14, "Readable at FHD")
	assert_eq(panel._blackjack_primary.focus_mode, Control.FOCUS_ALL)
	assert_eq(panel._blackjack_stand.focus_mode, Control.FOCUS_ALL)
	assert_eq(panel._blackjack_double.focus_mode, Control.FOCUS_ALL)
	assert_gte(panel._blackjack_primary.size.x, 44.0)
	assert_gte(panel._blackjack_primary.size.y, 44.0)
	assert_null(panel.find_child("DealerHandLabel", true, false), "No detached side captions")
	assert_null(panel.find_child("PlayerHandLabel", true, false))


func test_badges_hide_until_a_hand_is_dealt() -> void:
	var panel := _open(true)
	panel.prepare_blackjack_round()
	assert_false(panel._blackjack_dealer_total_panel.visible)
	assert_false(panel._blackjack_player_total_panel.visible)


func test_dealer_is_centred_behind_the_rail_on_the_new_table() -> void:
	var panel := _open(false)
	var dealer := panel._blackjack_dealer_presenter
	var figure := dealer.host()
	assert_not_null(figure)
	for id: StringName in [&"cards", &"deal", &"reveal", &"player"]:
		var texture := figure.pose_texture(id)
		assert_not_null(texture, "Dealer has the %s pose master" % id)
		assert_true(texture.resource_path.contains("blackjack_dealer_v2"))
		assert_gte(texture.get_width(), 1024, "Dealer uses the sharp production master")
		assert_gte(texture.get_height(), 1536)
		assert_ne(texture.get_image().detect_alpha(), Image.ALPHA_NONE)
		var hands := dealer.hands_host().pose_texture(id)
		assert_not_null(hands, "%s pose has a front-of-rail hands layer" % id)
		assert_eq(hands.get_size(), texture.get_size(), "Hands layer shares the pose canvas")
	for sprite: Sprite2D in figure._sprites.values():
		assert_null(sprite.material, "Transparent production art needs no chroma-key shader")
	var table := panel.find_child("BlackjackTableArt", true, false) as Sprite2D
	assert_eq(
		table.texture, BlackjackDealerPresenter.TABLE_TEXTURE, "Occluder samples the drawn table"
	)
	assert_true(table.texture.resource_path.ends_with("blackjack_table_v2.png"))
	var visible := dealer.visible_bounds()
	# Centred: she stands in the middle of the far rail, not in a corner lane.
	assert_almost_eq(visible.get_center().x, 480.0, 12.0)
	assert_almost_eq(visible.end.y, BlackjackDealerPresenter.RAIL_Y, 0.5)
	# Full presence: head near the top of the room, shoulders wider than a card.
	assert_between(visible.position.y, 4.0, 24.0)
	assert_gte(visible.size.x, 100.0)
	assert_false(visible.intersects(HOW_TO_PLAY), "Dealer clears How to play")
	assert_false(
		visible.intersects(panel._blackjack_title_plaque.get_rect()), "Dealer clears the title"
	)
	for id: StringName in figure.pose_ids():
		assert_lte(figure.pose_bounds(id).end.y, DECK_TOP, "%s never reaches the deck" % id)


func test_dealer_stands_behind_the_far_rail() -> void:
	var panel := _open(false)
	var dealer := panel._blackjack_dealer_presenter
	var occluder := dealer.find_child("TableRailOccluder", true, false) as Polygon2D
	assert_not_null(occluder, "The table rail and felt hide the lower body")
	assert_eq(occluder.texture, BlackjackDealerPresenter.TABLE_TEXTURE)
	assert_gt(occluder.get_index(), dealer.host().get_index(), "Rail draws in front of the dealer")
	assert_gt(
		dealer.hands_host().get_index(), occluder.get_index(), "Hands rest in front of the rail"
	)
	var shoe := dealer.find_child("CardShoe", true, false) as Sprite2D
	assert_not_null(shoe)
	assert_gt(shoe.get_index(), occluder.get_index(), "The shoe sits on the felt, in front")
	var bounds := dealer.visual_bounds()
	var visible := dealer.visible_bounds()
	assert_lt(visible.end.y, bounds.end.y, "Her lower body is hidden by the table")
	# The occluder covers everything any pose paints below the rail.
	var occluded := Rect2(occluder.polygon[0], occluder.polygon[2] - occluder.polygon[0])
	for id: StringName in dealer.host().pose_ids():
		var pose := dealer.host().pose_bounds(id)
		var below := Rect2(
			Vector2(pose.position.x, BlackjackDealerPresenter.RAIL_Y),
			Vector2(pose.size.x, pose.end.y - BlackjackDealerPresenter.RAIL_Y)
		)
		assert_true(occluded.encloses(below), "%s lower body is fully behind the table" % id)
	# The occluder UVs sample the table exactly where it is drawn (960x540 canvas).
	for index: int in range(occluder.polygon.size()):
		assert_eq(occluder.uv[index], occluder.polygon[index] * 4.0)
	# Hands at felt height: resting hands sit just in front of the rail edge.
	var rest_hand := BlackjackDealerPresenter.rest_hand_point()
	assert_between(rest_hand.y - BlackjackDealerPresenter.RAIL_Y, 0.0, 24.0)
	# The dealing hand reaches toward the shoe side, onto the felt.
	var deal_hand := BlackjackDealerPresenter.deal_hand_point()
	assert_gt(deal_hand.x, rest_hand.x)
	assert_gt(deal_hand.y, BlackjackDealerPresenter.RAIL_Y)


func test_dealer_idle_and_deal_gesture_are_presentation_only() -> void:
	var panel := _open(false)
	var dealer := panel._blackjack_dealer_presenter
	var math: BlackjackMath = panel.cabinet.get("math")
	var player_before := math.player.duplicate()
	var dealer_before := math.dealer.duplicate()
	dealer.host()._process(0.9)
	assert_gt(dealer.host().breath_offset_pixels(), 0.0, "Dealer has a restrained breath")
	assert_lte(dealer.host().breath_offset_pixels(), 1.001)
	assert_eq(dealer.current_pose(), &"cards", "Rest: eyes on the cards")
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	assert_true(dealer.has_active_gesture())
	assert_eq(dealer.current_pose(), &"deal", "Crisp snap to the dealing pose")
	assert_eq(dealer.hands_pose(), &"deal", "Hands layer follows the body pose")
	assert_eq(dealer.cue_color(), BlackjackDealerPresenter.BRASS)
	assert_eq(dealer._cue.modulate.a, 0.0, "No rail line is drawn in full motion")
	assert_not_null(panel.find_child("DealerCard0", true, false))
	assert_eq(math.player, player_before, "Presentation never mutates the hand")
	assert_eq(math.dealer, dealer_before)
	await wait_seconds(0.9)
	assert_false(dealer.has_active_gesture())
	assert_eq(dealer.current_pose(), &"cards")
	assert_eq(dealer.hands_pose(), &"cards")


func test_real_cards_are_dealt_from_the_shoe_past_the_dealing_hand() -> void:
	var panel := _open(false)
	var dealer := panel._blackjack_dealer_presenter
	panel._clear_blackjack_cards()
	panel._add_playing_card(9, 0, 1, true, false, 0)
	var card := panel._blackjack_cards[0]
	var mouth := dealer.card_release_point()
	assert_true(dealer.shoe_bounds().has_point(mouth), "Cards leave the painted shoe")
	assert_eq(card.position + card.size * 0.5, mouth, "Real card starts in the shoe mouth")
	assert_lt(card.scale.x, 0.5, "Starts small, further from the camera")
	assert_ne(card.rotation, 0.0)
	assert_lt(
		dealer.card_via_point().distance_to(BlackjackDealerPresenter.deal_hand_point()),
		0.01,
		"The travel curve passes the painted dealing hand"
	)
	assert_lt(mouth.distance_to(dealer.card_via_point()), 60.0)
	await wait_seconds(0.16)
	assert_gt(card.scale.x, 0.5, "Grows as it slides toward the player")
	var expected: Dictionary = panel._blackjack_card_layout(0, 1, true)
	await wait_seconds(0.3)
	assert_eq(card.position, expected.position)
	assert_eq(card.scale, Vector2.ONE)
	assert_almost_eq(card.rotation, float(expected.rotation), 0.001)


func test_cards_are_table_sized_and_sit_in_their_lanes() -> void:
	var panel := _open(true)
	panel._clear_blackjack_cards()
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	var dealer := panel._blackjack_dealer_presenter
	for card: PlayingCard in panel._blackjack_cards:
		assert_between(card.size.x, 50.0, 62.0, "%s is table-sized" % card.name)
		assert_almost_eq(card.size.y / card.size.x, 1.4, 0.02, "Poker card proportion")
		var bounds := _card_bounds(card)
		assert_lte(bounds.end.y, DECK_TOP, "%s never overlaps the deck" % card.name)
		assert_true(TV_SAFE.encloses(bounds))
		assert_false(bounds.intersects(HOW_TO_PLAY))
		assert_false(
			bounds.intersects(dealer.visible_bounds()), "%s stays off the dealer" % card.name
		)
		assert_eq(card.z_index, 2, "Cards draw above the rail occluder")
	var dealer_card := panel.find_child("DealerCard0", true, false) as PlayingCard
	var player_card := panel.find_child("PlayerCard0", true, false) as PlayingCard
	assert_lt(dealer_card.size.x, player_card.size.x, "Nearer player cards read slightly larger")
	assert_gt(
		dealer_card.position.y,
		BlackjackDealerPresenter.RAIL_Y + 30.0,
		"Dealer hand in front of her"
	)
	assert_gt(player_card.position.y, dealer_card.position.y + dealer_card.size.y)
	var plaque := CabinetPanel.BLACKJACK_PLAQUE_RECT
	assert_gte(plaque.position.y, _card_bounds(dealer_card).end.y - 1.0, "Plaque between hands")
	assert_lte(plaque.end.y, player_card.position.y)
	for texture: Texture2D in [PlayingCard.FACE_TEXTURE, PlayingCard.BACK_TEXTURE]:
		var image := texture.get_image()
		assert_gte(image.get_height(), 1024, "Painted card master is sharp at UHD")
		assert_eq(image.get_pixel(0, 0).a, 0.0, "Rounded corners carry real alpha")
		assert_eq(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a, 0.0)


func test_every_rank_and_suit_draws_on_the_face_template() -> void:
	var panel := _open(true)
	panel._clear_blackjack_cards()
	for rank: int in range(1, 14):
		var card := PlayingCard.new()
		card.size = CabinetPanel.BLACKJACK_PLAYER_CARD
		add_child_autofree(card)
		card.configure(rank, rank, false)
		assert_eq(
			card.rank_text(), tr("CARD_" + str(rank)) if rank == 1 or rank > 10 else str(rank)
		)
		assert_false(card._visual_face_down)
		card.queue_redraw()
	await wait_frames(2)


func test_dealer_looks_at_the_player_while_a_decision_is_awaited() -> void:
	var panel := _open(false)
	var game: MiniGame = panel.cabinet
	var dealer: BlackjackDealerPresenter = panel._blackjack_dealer_presenter
	game.is_round_active = true
	panel.refresh()
	await wait_seconds(1.2)
	assert_true(dealer.awaiting_decision)
	assert_eq(dealer.current_pose(), &"player", "Waiting on Hit/Stand/Double")
	game.is_round_active = false
	panel.refresh()
	await wait_seconds(0.2)
	assert_eq(dealer.current_pose(), &"cards")


func test_dealer_marks_the_hole_card_reveal_with_a_distinct_gesture() -> void:
	var panel := _open(false)
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	await wait_seconds(0.82)
	panel._render_blackjack_hand([10, 7], [9, 8], false)
	var dealer := panel._blackjack_dealer_presenter
	assert_eq(dealer.last_gesture, &"reveal")
	assert_true(dealer.has_active_gesture())
	assert_eq(dealer.current_pose(), &"reveal", "Her own painted card turn marks the reveal")
	var hole := panel.find_child("DealerCard1", true, false) as PlayingCard
	assert_true(hole.is_flipping(), "The table hole card turns over at the same time")
	await wait_seconds(0.08)
	assert_lt(hole.scale.x, 0.9, "Hole card narrows on its long axis mid-turn")
	await wait_seconds(0.6)
	assert_eq(dealer.current_pose(), &"cards", "Reset to the cards after the reveal")
	assert_eq(hole.scale, Vector2.ONE)


func test_dealer_acknowledges_the_result_with_a_small_nod_then_resets() -> void:
	var panel := _open(false)
	var dealer: BlackjackDealerPresenter = panel._blackjack_dealer_presenter
	dealer.play_result(Color("f2c84b"), true)
	assert_eq(dealer.last_gesture, &"result_win")
	assert_eq(dealer.current_pose(), &"player", "Win/loss is acknowledged toward the player")
	await wait_seconds(0.16)
	assert_between(dealer.host().scale.y, 1.0 - BlackjackDealerPresenter.NOD_DEPTH - 0.001, 0.9999)
	assert_eq(dealer.host().scale, dealer.hands_host().scale, "Hands move with the nod")
	await wait_seconds(1.3)
	assert_eq(dealer.current_pose(), &"cards")
	assert_eq(dealer.host().scale, Vector2.ONE)
	dealer.reset_feedback()
	assert_eq(dealer.last_gesture, &"idle")
	assert_eq(dealer.current_pose(), &"cards")


func test_reduced_dealer_uses_a_bounded_static_cue_and_stable_pose() -> void:
	var panel := _open(true)
	var dealer := panel._blackjack_dealer_presenter
	assert_false(dealer.host().is_processing())
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	assert_eq(dealer.current_pose(), &"cards", "Static master pose")
	assert_eq(dealer.hands_pose(), &"cards")
	assert_eq(dealer.host()._figure.scale, Vector2.ONE)
	assert_eq(dealer.host()._figure.skew, 0.0)
	assert_eq(dealer._cue.modulate.a, 1.0, "One brass cue acknowledges the deal")
	await wait_seconds(0.24)
	assert_almost_eq(
		dealer._cue.modulate.a,
		BlackjackDealerPresenter.REST_CUE_ALPHA,
		0.02,
		"Reduced cue settles instead of looping"
	)
	assert_eq(dealer.current_pose(), &"cards")


func test_enabling_reduced_motion_settles_an_active_deal_and_nod() -> void:
	var panel := _open(false)
	var dealer: BlackjackDealerPresenter = panel._blackjack_dealer_presenter
	dealer.play_result(Color("f2c84b"), true)
	await wait_seconds(0.08)
	dealer.play_deal(2)
	await wait_seconds(0.04)
	assert_true(dealer.has_active_gesture())

	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(dealer.has_active_gesture())
	assert_eq(dealer.current_pose(), &"cards")
	assert_eq(dealer.hands_pose(), &"cards")
	assert_eq(dealer.host().scale, Vector2.ONE)
	assert_eq(dealer.host()._figure.scale, Vector2.ONE)
	for id: StringName in dealer.host().pose_ids():
		assert_eq((dealer.host()._sprites[id] as Sprite2D).visible, id == &"cards")


func test_live_stake_places_a_painted_wager_stack_on_the_felt() -> void:
	var panel := _open(true)
	var game: MiniGame = panel.cabinet
	var math: BlackjackMath = game.get("math")
	math.player.assign([10, 7])
	math.dealer.assign([9, 8])
	math.stake = 25
	math.active = true
	game.current_stake = 25
	game.is_round_active = true
	panel.refresh()
	var stack: BlackjackBetStack = panel._blackjack_bet_stack
	assert_true(stack.visible)
	assert_true(stack.is_live)
	assert_eq(stack.wager, 25)
	assert_eq(
		stack.position,
		BlackjackBetStack.TABLE_POSITION,
		"Reduced motion lands directly at the final spot"
	)
	assert_eq(stack.scale, Vector2.ONE)
	assert_true(BlackjackBetStack.CHIP_TEXTURE.resource_path.contains("chip_stack_v2"))
	var stack_rect := Rect2(stack.position, stack.size)
	assert_lte(stack_rect.end.y, DECK_TOP, "Wager stays on the felt above the deck")
	assert_true(TV_SAFE.encloses(stack_rect))


func test_result_is_one_composed_plaque_with_a_static_reduced_end_state() -> void:
	var panel := _open(true)
	var result := RoundResult.create(
		10, 20, RoundResult.Outcome.WIN, {"player": [10, 9], "dealer": [10, 8]}
	)
	panel._animate_blackjack_result(result)
	var plaque := panel._blackjack_result_banner
	assert_true(plaque.visible)
	assert_eq(plaque.modulate.a, 1.0)
	assert_eq(plaque.scale, Vector2.ONE)
	assert_eq(plaque.get_rect(), CabinetPanel.BLACKJACK_PLAQUE_RECT, "Centred on the felt")
	assert_almost_eq(plaque.get_rect().get_center().x, 480.0, 0.5)
	assert_eq(panel._blackjack_result_text.text, tr("BLACKJACK_RESULT_WIN") % 10)
	assert_eq(panel._blackjack_bet_stack.wager, 10)
	assert_eq(panel._blackjack_bet_stack.settle_kind, BlackjackBetStack.Settle.WIN)
	assert_true(panel._blackjack_bet_stack.payout_visible, "Payout sits beside the bet")
	assert_eq(panel._blackjack_bet_stack.payout_offset, BlackjackBetStack.PAYOUT_OFFSET)
	assert_eq(panel._blackjack_dealer_presenter.current_pose(), &"cards", "Static pose")
	assert_eq(panel._blackjack_dealer_presenter._cue.modulate.a, 1.0, "One bounded cue")
	assert_false(panel._blackjack_fx_tween != null and panel._blackjack_fx_tween.is_running())


func test_result_copy_names_the_outcome() -> void:
	var panel := _open(true)
	var cases: Array = [
		[
			RoundResult.create(
				10, 25, RoundResult.Outcome.WIN, {"player": [1, 13], "dealer": [9, 8]}
			),
			tr("BLACKJACK_RESULT_NATURAL") % 15,
			BlackjackBetStack.Settle.WIN
		],
		[
			RoundResult.create(
				10, 20, RoundResult.Outcome.WIN, {"player": [10, 7], "dealer": [10, 6, 9]}
			),
			tr("BLACKJACK_RESULT_DEALER_BUST") % 10,
			BlackjackBetStack.Settle.WIN
		],
		[
			RoundResult.create(
				10, 10, RoundResult.Outcome.PUSH, {"player": [10, 8], "dealer": [10, 8]}
			),
			tr("BLACKJACK_RESULT_PUSH"),
			BlackjackBetStack.Settle.PUSH
		],
		[
			RoundResult.create(
				10, 0, RoundResult.Outcome.LOSS, {"player": [10, 8, 9], "dealer": [10, 8]}
			),
			tr("BLACKJACK_RESULT_BUST"),
			BlackjackBetStack.Settle.LOSS
		],
		[
			RoundResult.create(
				10, 0, RoundResult.Outcome.LOSS, {"player": [10, 7], "dealer": [10, 8]}
			),
			tr("BLACKJACK_RESULT_LOSS"),
			BlackjackBetStack.Settle.LOSS
		],
	]
	for entry: Array in cases:
		var copy := panel._blackjack_result_copy(entry[0])
		assert_eq(copy[0], entry[1])
		assert_eq(copy[2], entry[2])


func test_blackjack_result_has_no_free_flying_coins_or_rail_line() -> void:
	var panel := _open(false)
	var celebration: WinCelebration = panel._celebration
	var result := RoundResult.create(
		10, 20, RoundResult.Outcome.WIN, {"player": [10, 9], "dealer": [10, 8]}
	)
	panel.show_result(result)
	assert_eq(celebration.get_child_count(), 0, "No coin or chip burst over the table")
	assert_false(panel._ambient.visible, "No attract arc over the painted room")
	assert_eq(panel._blackjack_dealer_presenter._cue.modulate.a, 0.0, "No rail line in full motion")
	assert_true(panel._blackjack_fx_tween.is_running(), "The plaque settles in one beat")
	assert_true(panel._blackjack_bet_stack.is_settling(), "Payout slides out from the dealer")
	assert_eq(panel._blackjack_dealer_presenter.current_pose(), &"player")
	await wait_seconds(0.7)
	assert_false(panel._blackjack_bet_stack.is_settling())
	assert_eq(panel._blackjack_bet_stack.payout_offset, BlackjackBetStack.PAYOUT_OFFSET)


func test_lost_bet_is_collected_toward_the_dealer() -> void:
	var panel := _open(false)
	panel._blackjack_bet_stack.place_wager(10, false)
	panel._animate_blackjack_result(
		RoundResult.create(10, 0, RoundResult.Outcome.LOSS, {"player": [10, 7], "dealer": [10, 8]})
	)
	var stack: BlackjackBetStack = panel._blackjack_bet_stack
	var start := stack.position
	await wait_seconds(0.4)
	assert_lt(
		stack.position.distance_to(BlackjackBetStack.DEALER_POSITION),
		start.distance_to(BlackjackBetStack.DEALER_POSITION),
		"The bet slides across the felt to the dealer"
	)
	await wait_seconds(0.4)
	assert_eq(stack.modulate.a, 0.0, "Collected")
	assert_eq(stack.wager, 10, "Presentation never rewrites the stake")


func test_preparing_next_round_clears_result_fx_and_replays_wager_placement() -> void:
	var panel := _open(false)
	var game: MiniGame = panel.cabinet
	panel._blackjack_bet_stack.place_wager(10, false)
	panel._animate_blackjack_result(RoundResult.create(10, 20, RoundResult.Outcome.WIN))
	assert_true(panel._blackjack_fx_tween.is_running())

	panel.prepare_blackjack_round()
	assert_null(panel._blackjack_fx_tween)
	assert_false(panel._blackjack_bet_stack.is_live)
	assert_false(panel._blackjack_bet_stack.visible)
	assert_false(panel._blackjack_bet_stack.payout_visible)
	assert_false(panel._blackjack_result_banner.visible)

	game.current_stake = 25
	game.is_round_active = true
	panel.refresh()
	assert_true(panel._blackjack_bet_stack.is_live)
	assert_true(panel._blackjack_bet_stack._placement_tween.is_running())
	assert_eq(panel._blackjack_bet_stack.position, BlackjackBetStack.SOURCE_POSITION)


func test_long_hands_keep_cards_clear_of_wager_and_total_badges() -> void:
	var panel := _open(true)
	panel._clear_blackjack_cards()
	panel._blackjack_bet_stack.place_wager(25, false)
	var hand: Array[int] = []
	for index: int in range(8):
		hand.append(2 + index % 4)
	panel._render_blackjack_hand(hand, hand, false)
	var wager_bounds := Rect2(panel._blackjack_bet_stack.position, panel._blackjack_bet_stack.size)
	for badge: Panel in [panel._blackjack_player_total_panel, panel._blackjack_dealer_total_panel]:
		assert_true(TV_SAFE.encloses(badge.get_rect()), "%s stays TV-safe" % badge.name)
	for card: PlayingCard in panel._blackjack_cards:
		var card_bounds := _card_bounds(card)
		assert_false(card_bounds.intersects(wager_bounds), "Long hands keep the wager lane clear")
		for badge: Panel in [
			panel._blackjack_player_total_panel, panel._blackjack_dealer_total_panel
		]:
			assert_false(
				card_bounds.intersects(badge.get_rect()), "Long hands keep totals readable"
			)
		assert_lte(card_bounds.end.y, DECK_TOP)


func test_player_hit_reflows_every_player_card_and_locks_input_until_settled() -> void:
	var panel := _open(false)
	panel._clear_blackjack_cards()
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	await wait_seconds(0.62)
	assert_eq(panel._blackjack_pending_motions, 0)

	var player_zero := panel.find_child("PlayerCard0", true, false) as PlayingCard
	var player_one := panel.find_child("PlayerCard1", true, false) as PlayingCard
	var previous_zero_position := player_zero.position
	var previous_one_position := player_one.position
	var badge_before := panel._blackjack_player_total_panel.position
	panel._render_blackjack_hand([10, 7, 2], [9, 8], true)

	var player_two := panel.find_child("PlayerCard2", true, false) as PlayingCard
	assert_not_null(player_two)
	assert_gt(panel._blackjack_pending_motions, 0, "Hit deal and hand reflow lock decisions")
	assert_false(panel.blackjack_input_ready())
	await wait_seconds(0.05)
	assert_ne(
		player_zero.position, previous_zero_position, "First card begins moving into the wider fan"
	)
	assert_ne(
		player_one.position, previous_one_position, "Second card begins moving into the wider fan"
	)

	await wait_seconds(0.62)
	for index: int in range(3):
		var card := panel.find_child("PlayerCard%d" % index, true, false) as PlayingCard
		var expected: Dictionary = panel._blackjack_card_layout(index, 3, false)
		assert_eq(card.position, expected.position, "Player card reaches its exact fan position")
		assert_eq(card.size, expected.size, "Player card reaches its exact fan size")
		assert_eq(card.scale, Vector2.ONE)
		assert_almost_eq(card.rotation, float(expected.rotation), 0.001)
	assert_gt(
		panel._blackjack_player_total_panel.position.x,
		badge_before.x,
		"Total badge follows the hand"
	)
	assert_eq(panel._blackjack_pending_motions, 0)
	assert_true(panel.blackjack_input_ready())


func test_dealer_multi_card_draw_reflows_the_complete_dealer_hand() -> void:
	var panel := _open(false)
	panel._clear_blackjack_cards()
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	await wait_seconds(0.62)
	var previous_first_position := (
		(panel.find_child("DealerCard0", true, false) as PlayingCard).position
	)

	panel._render_blackjack_hand([10, 7], [9, 8, 2, 3], false)
	assert_gt(panel._blackjack_pending_motions, 0)
	assert_false(panel.blackjack_input_ready())
	await wait_seconds(0.05)
	assert_ne(
		(panel.find_child("DealerCard0", true, false) as PlayingCard).position,
		previous_first_position,
		"Existing dealer cards visibly reflow for the larger hand"
	)

	await wait_seconds(0.82)
	for index: int in range(4):
		var card := panel.find_child("DealerCard%d" % index, true, false) as PlayingCard
		var expected: Dictionary = panel._blackjack_card_layout(index, 4, true)
		assert_eq(card.position, expected.position, "Dealer card reaches its exact fan position")
		assert_eq(card.size, expected.size, "Dealer card reaches its exact fan size")
		assert_almost_eq(card.rotation, float(expected.rotation), 0.001)
	assert_eq(panel._blackjack_pending_motions, 0)
	assert_true(panel.blackjack_input_ready())


func test_reduced_motion_snaps_blackjack_reflow_without_pending_motion() -> void:
	var panel := _open(true)
	panel._clear_blackjack_cards()

	panel._render_blackjack_hand([10, 7], [9, 8], true)
	panel._render_blackjack_hand([10, 7, 2], [9, 8], true)
	for index: int in range(3):
		var card := panel.find_child("PlayerCard%d" % index, true, false) as PlayingCard
		var expected: Dictionary = panel._blackjack_card_layout(index, 3, false)
		assert_eq(card.position, expected.position)
		assert_eq(card.size, expected.size)
		assert_eq(card.scale, Vector2.ONE)
		assert_almost_eq(card.rotation, float(expected.rotation), 0.001)
	assert_eq(
		panel._blackjack_pending_motions,
		0,
		"Reduced motion reaches the exact final fan without a lingering input lock"
	)
	assert_true(panel.blackjack_input_ready())


func test_enabling_reduced_motion_settles_an_active_hand_reflow_exactly() -> void:
	var panel := _open(false)
	panel._clear_blackjack_cards()
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	await wait_seconds(0.62)

	panel._render_blackjack_hand([10, 7, 2], [9, 8], true)
	await wait_seconds(0.05)
	assert_gt(panel._blackjack_card_tweens.size(), 0)
	assert_false(panel.blackjack_input_ready())
	MotionPolicy.set_reduced_motion_for_tests(true)

	assert_true(panel._blackjack_card_tweens.is_empty())
	assert_eq(panel._blackjack_pending_motions, 0)
	for index: int in range(3):
		var card := panel.find_child("PlayerCard%d" % index, true, false) as PlayingCard
		var expected: Dictionary = panel._blackjack_card_layout(index, 3, false)
		assert_eq(card.position, expected.position)
		assert_eq(card.size, expected.size)
		assert_eq(card.scale, Vector2.ONE)
		assert_almost_eq(card.rotation, float(expected.rotation), 0.001)


func test_redealing_after_a_clear_never_duplicates_cards() -> void:
	var panel := _open(false)
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	panel._clear_blackjack_cards()
	panel._blackjack_dealt = false
	panel._render_blackjack_hand([10, 7], [9, 8], true)
	panel._render_blackjack_hand([10, 7], [9, 8], false)
	assert_eq(panel._blackjack_cards.size(), 4, "A re-sync finds every re-dealt card by name")
	for card: PlayingCard in panel._blackjack_cards:
		assert_true(
			(
				String(card.name).begins_with("DealerCard")
				or String(card.name).begins_with("PlayerCard")
			)
		)
		assert_false(String(card.name).contains("@"), "%s kept its exact name" % card.name)


func test_reusable_deck_has_standard_pips_courts_and_a_symmetric_back() -> void:
	for rank: int in range(2, 11):
		var layout := PlayingCard.pip_layout(rank)
		assert_eq(layout.size(), rank, "%d carries exactly %d pips" % [rank, rank])
		for pip: Vector2 in layout:
			assert_between(pip.x, 0.3, 0.7, "Pips stay clear of the index columns")
			assert_between(pip.y, 0.19, 0.81)
	assert_true(PlayingCard.pip_layout(1).is_empty())
	var courts: Dictionary = {}
	for suit: int in range(4):
		for rank: int in range(11, 14):
			var texture := PlayingCard.court_texture(rank, suit)
			assert_not_null(texture, "Court %d of suit %d is illustrated" % [rank, suit])
			assert_true(texture.resource_path.begins_with("res://assets/production/cards/"))
			assert_gte(texture.get_height(), 800, "Court art is sharp at UHD card size")
			courts[texture.resource_path] = true
	assert_eq(courts.size(), 12, "Twelve unique court faces")
	for texture: Texture2D in PlayingCard.SUIT_TEXTURES:
		var image := texture.get_image()
		assert_eq(image.get_pixel(0, 0).a, 0.0, "%s pip art is transparent" % texture.resource_path)
	assert_true(PlayingCard.ACE_OF_SPADES.resource_path.ends_with("ace_spades.png"))
	var back := PlayingCard.BACK_TEXTURE.get_image()
	if back.is_compressed():
		back.decompress()
	var last := Vector2i(back.get_width() - 1, back.get_height() - 1)
	for sample: Vector2i in [Vector2i(120, 90), Vector2i(365, 200), Vector2i(600, 400)]:
		var mirrored := last - sample
		var a := back.get_pixelv(sample)
		var b := back.get_pixelv(mirrored)
		assert_almost_eq(a.r, b.r, 0.08, "Back is point-symmetric like a printed back")
		assert_almost_eq(a.g, b.g, 0.08)


func test_reduced_cue_never_crosses_the_dealer_or_the_card_lanes() -> void:
	var panel := _open(true)
	var dealer := panel._blackjack_dealer_presenter
	var cue: Line2D = dealer._cue
	var cue_rect := Rect2(cue.points[0], Vector2.ZERO).expand(cue.points[1]).grow(1.0)
	assert_false(cue_rect.intersects(dealer.visual_bounds()), "The cue never crosses her")
	var hand: Array[int] = [2, 3, 4, 5, 2, 3, 4, 5]
	panel._render_blackjack_hand(hand, hand, false)
	for card: PlayingCard in panel._blackjack_cards:
		assert_false(cue_rect.intersects(_card_bounds(card)), "The cue never crosses a card")
	assert_false(cue_rect.intersects(panel._blackjack_dealer_total_panel.get_rect()))
