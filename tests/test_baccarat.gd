extends GutTest
## Velvet Baccarat: exact eight-deck Punto Banco odds, the third-card tableau,
## whole-chip commission, the cabinet stream, settlement that waits for the
## reveal, the unique hostess and her lane, 44 px targets in TV-safe and the
## reduced-motion presentation.

const DEFINITION_PATH := "res://data/cabinets/baccarat.tres"
const TV_SAFE := Rect2(48, 27, 864, 486)
const MIN_TARGET: float = 44.0
## Exact ordered six-card sequence counts for eight decks (416 P 6), checked
## against an independent Python enumeration.
const EXACT_PLAYER: int = 2230518282592256
const EXACT_BANKER: int = 2292252566437888
const EXACT_TIE: int = 475627426473216
const EXACT_TOTAL: int = 4998398275503360
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
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	Wallet.reset(1000)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.set_test_mode(false)
	Wallet.reset(_starting_balance)
	Wallet.set_test_mode(_starting_test_mode)


func _open() -> CabinetSession:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(load(DEFINITION_PATH))
	return session


func _card(rank: int, suit: int = 0) -> int:
	return suit * 13 + rank - 1


## A draw Callable that hands out `ranks` in order (suits cycle so pairs are real).
func _scripted(ranks: Array) -> Callable:
	var queue := ranks.duplicate()
	var dealt: Array[int] = [0]
	return func() -> int:
		var rank: int = queue.pop_front()
		dealt[0] += 1
		return _card(rank, dealt[0] % 4)


func _coup(winner: int, player_pair: bool = false, banker_pair: bool = false) -> Dictionary:
	return {"winner": winner, "player_pair": player_pair, "banker_pair": banker_pair}


func test_exhaustive_enumeration_gives_the_exact_eight_deck_odds() -> void:
	var counts := BaccaratOdds.outcome_counts(8)
	assert_eq(counts.total, EXACT_TOTAL, "416 x 415 x ... x 411 ordered deals")
	assert_eq(counts.player + counts.banker + counts.tie, counts.total, "Every deal is counted")
	assert_eq(counts.player, EXACT_PLAYER)
	assert_eq(counts.banker, EXACT_BANKER)
	assert_eq(counts.tie, EXACT_TIE)
	assert_almost_eq(float(counts.banker) / counts.total, 0.458597, 0.000001)
	assert_almost_eq(float(counts.player) / counts.total, 0.446247, 0.000001)
	assert_almost_eq(float(counts.tie) / counts.total, 0.095156, 0.000001)
	var math := BaccaratMath.new()
	var banker := BaccaratOdds.expected_return(math, BaccaratMath.BANKER, 20)
	var player := BaccaratOdds.expected_return(math, BaccaratMath.PLAYER, 20)
	var tie := BaccaratOdds.expected_return(math, BaccaratMath.TIE, 20)
	var pair := BaccaratOdds.expected_return(math, BaccaratMath.PLAYER_PAIR, 20)
	assert_almost_eq(banker, 0.9894209422, 0.0000000005, "Banker 20: exact 5% commission")
	assert_almost_eq(player, 0.9876491867, 0.0000000005)
	assert_almost_eq(tie, 0.8564037122, 0.0000000005)
	assert_almost_eq(pair, 12.0 * 13.0 * 32.0 * 31.0 / (416.0 * 415.0), 0.0000000001)
	assert_eq(BaccaratOdds.expected_return(math, BaccaratMath.BANKER_PAIR, 40), pair, "Pairs match")
	for chip: int in [20, 40, 100, 200]:
		assert_almost_eq(
			BaccaratOdds.expected_return(math, BaccaratMath.BANKER, chip),
			banker,
			0.0000000005,
			"Every chip is a multiple of 20, so %d on Banker is exact" % chip
		)
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	assert_almost_eq(definition.target_rtp, banker, 0.0005, "Declared RTP is the Banker bet's")
	assert_eq(definition.tier, CabinetDefinition.Tier.HIGH_ROLLER)
	assert_true(definition.is_valid_definition())


func test_card_values_and_totals() -> void:
	for rank: int in range(1, 14):
		var expected := rank if rank < 10 else 0
		for suit: int in range(4):
			assert_eq(BaccaratRules.card_value(_card(rank, suit) + 52 * 7), expected)
			assert_eq(BaccaratRules.card_suit(_card(rank, suit) + 52 * 3), suit)
			assert_eq(BaccaratRules.card_rank(_card(rank, suit) + 52 * 5), rank)
	assert_eq(BaccaratRules.hand_total([_card(7), _card(8)]), 5, "15 counts 5")
	assert_eq(BaccaratRules.hand_total([_card(13), _card(9)]), 9)
	assert_eq(BaccaratRules.hand_total([_card(1), _card(10), _card(12)]), 1)
	assert_true(BaccaratRules.is_pair([_card(13, 0), _card(13, 2)]), "K-K is a pair")
	assert_false(BaccaratRules.is_pair([_card(10, 0), _card(13, 0)]), "10-K is not")


func test_the_banker_tableau_cell_by_cell() -> void:
	# Rows: Banker total 0-7; columns: Player third card 0-9. D = draw, S = stand.
	var tableau := {
		0: "DDDDDDDDDD",
		1: "DDDDDDDDDD",
		2: "DDDDDDDDDD",
		3: "DDDDDDDDSD",
		4: "SSDDDDDDSS",
		5: "SSSSDDDDSS",
		6: "SSSSSSDDSS",
		7: "SSSSSSSSSS",
	}
	for banker: int in tableau:
		var row: String = tableau[banker]
		for third: int in range(10):
			assert_eq(
				BaccaratRules.banker_draws(banker, third),
				row[third] == "D",
				"Banker %d vs Player third %d" % [banker, third]
			)
	for banker: int in range(10):
		assert_eq(BaccaratRules.banker_draws(banker, -1), banker <= 5, "Player stood, B%d" % banker)
	for player: int in range(10):
		assert_eq(BaccaratRules.player_draws(player), player <= 5, "Player %d" % player)


func test_coups_follow_the_tableau_in_dealing_order() -> void:
	# Order dealt: P1, B1, P2, B2, P3, B3.
	var natural := BaccaratRules.play_coup(_scripted([4, 3, 5, 3]))
	assert_true(natural.natural, "Player 9 is a natural")
	assert_eq(natural.player_cards.size(), 2)
	assert_eq(natural.banker_cards.size(), 2, "Nobody draws against a natural")
	assert_eq(natural.winner, BaccaratRules.Winner.PLAYER)
	var player_stands := BaccaratRules.play_coup(_scripted([3, 2, 3, 3, 9]))
	assert_eq(player_stands.player_total, 6)
	assert_eq(player_stands.player_cards.size(), 2, "Player stands on 6")
	assert_eq(player_stands.banker_cards.size(), 3, "Banker 5 draws when the Player stood")
	assert_eq(player_stands.banker_total, 4)
	assert_eq(player_stands.winner, BaccaratRules.Winner.PLAYER)
	var banker_three_vs_eight := BaccaratRules.play_coup(_scripted([1, 1, 1, 2, 8]))
	assert_eq(banker_three_vs_eight.player_total, 0, "2 + 8 = 10 counts 0")
	assert_eq(banker_three_vs_eight.banker_cards.size(), 2, "Banker 3 stands on a Player 8")
	assert_eq(banker_three_vs_eight.winner, BaccaratRules.Winner.BANKER)
	var both_draw := BaccaratRules.play_coup(_scripted([2, 13, 2, 4, 5, 3]))
	assert_eq(both_draw.player_cards.size(), 3)
	assert_eq(both_draw.banker_cards.size(), 3, "Banker 4 draws on a Player 5")
	assert_eq(both_draw.player_total, 9)
	assert_eq(both_draw.banker_total, 7)
	var tie := BaccaratRules.play_coup(_scripted([13, 12, 7, 7]))
	assert_eq(tie.winner, BaccaratRules.Winner.TIE)
	assert_false(tie.player_pair)
	var pairs := BaccaratRules.play_coup(_scripted([9, 12, 9, 12]))
	assert_true(pairs.player_pair, "9-9")
	assert_true(pairs.banker_pair, "Q-Q")


func test_commission_rounds_up_to_a_whole_chip_and_ties_push() -> void:
	var math := BaccaratMath.new()
	var expected := {1: 1, 10: 1, 19: 1, 20: 1, 30: 2, 40: 2, 100: 5, 200: 10, 400: 20}
	for stake: int in expected:
		assert_eq(math.commission_for(stake), expected[stake], "Commission on %d" % stake)
	var banker := _coup(BaccaratRules.Winner.BANKER)
	var player := _coup(BaccaratRules.Winner.PLAYER)
	var tie := _coup(BaccaratRules.Winner.TIE, true, false)
	assert_eq(math.returned_for(BaccaratMath.BANKER, 20, banker), 39, "20 on Banker wins 19")
	assert_eq(math.returned_for(BaccaratMath.BANKER, 60, banker), 117)
	assert_eq(math.returned_for(BaccaratMath.BANKER, 20, player), 0)
	assert_eq(math.returned_for(BaccaratMath.PLAYER, 20, player), 40)
	assert_eq(math.returned_for(BaccaratMath.PLAYER, 20, tie), 20, "Player pushes on a tie")
	assert_eq(math.returned_for(BaccaratMath.BANKER, 20, tie), 20, "Banker pushes on a tie")
	assert_eq(math.returned_for(BaccaratMath.TIE, 20, tie), 180, "Tie pays 8 to 1")
	assert_eq(math.returned_for(BaccaratMath.PLAYER_PAIR, 20, tie), 240, "Pair pays 11 to 1")
	assert_eq(math.returned_for(BaccaratMath.BANKER_PAIR, 20, tie), 0)
	assert_true(math.place(BaccaratMath.BANKER, 40, 400))
	assert_true(math.place(BaccaratMath.TIE, 20, 400))
	var result := math.settle(banker)
	assert_eq(result.stake, 60)
	assert_eq(result.payout, 78, "40 back + 38 won; the tie chip is swept")
	assert_eq(result.detail.commission, 2)
	assert_eq(result.outcome, RoundResult.Outcome.WIN)


func test_layout_limits_and_rebet() -> void:
	var math := BaccaratMath.new()
	assert_true(math.place(BaccaratMath.PLAYER, 200, 400))
	assert_true(math.place(BaccaratMath.TIE, 100, 400))
	assert_false(math.place(BaccaratMath.BANKER, 200, 400), "The total may never pass the cap")
	assert_false(math.place("nowhere", 20, 400))
	assert_eq(math.remove(BaccaratMath.PLAYER, 40), 40)
	assert_eq(math.total_bet(), 260)
	math.settle(_coup(BaccaratRules.Winner.TIE))
	assert_true(math.bets.is_empty(), "Chips leave the layout with the coup")
	assert_true(math.rebet(400))
	assert_eq(math.total_bet(), 260)
	math.clear()
	assert_false(math.can_rebet(259), "Rebet respects a lower limit")


func test_the_deal_draws_the_whole_coup_from_the_cabinet_stream() -> void:
	var math := BaccaratMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260918
	var mirror := RandomNumberGenerator.new()
	mirror.seed = 20260918
	var counts := [0, 0, 0]
	for coup_index: int in range(4000):
		var coup := math.deal_coup(rng)
		var cards: Array = coup.player_cards + coup.banker_cards
		var seen: Dictionary = {}
		for card: int in cards:
			assert_between(card, 0, 415)
			assert_false(seen.has(card), "A physical card is dealt once per coup")
			seen[card] = true
		counts[coup.winner] += 1
		if coup_index == 0:
			var first := mirror.randi_range(0, 415)
			assert_eq(coup.player_cards[0], first, "The first card is the stream's next draw")
	var total := 4000.0
	assert_almost_eq(counts[BaccaratRules.Winner.BANKER] / total, 0.4586, 0.025)
	assert_almost_eq(counts[BaccaratRules.Winner.PLAYER] / total, 0.4462, 0.025)
	assert_almost_eq(counts[BaccaratRules.Winner.TIE] / total, 0.0952, 0.015)


func test_deal_settles_only_after_every_card_is_face_up() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var panel: BaccaratTablePanel = game.panel
	game.select_stake(40)
	assert_true(game.call("request_place", BaccaratMath.BANKER))
	game.select_stake(20)
	assert_true(game.call("request_place", BaccaratMath.PLAYER_PAIR))
	assert_true(game.call("request_deal"))
	var coup: Dictionary = panel._coup
	assert_true(game.is_result_pending, "Settlement waits for the reveal")
	assert_eq(Wallet.balance, 1000, "Wallet untouched while the cards are out")
	assert_false(panel.is_revealed())
	assert_eq(panel.cards.size(), coup.player_cards.size() + coup.banker_cards.size())
	await wait_seconds(0.9)
	assert_eq(Wallet.balance, 1000, "Still untouched mid-squeeze")
	for card: BaccaratCard in panel.cards:
		var expected_hand: Array = coup.player_cards if card.hand == 0 else coup.banker_cards
		assert_eq(card.card_id, expected_hand[card.slot], "Every card shown is the decided card")
	await wait_until(func() -> bool: return panel.is_revealed(), 12.0)
	assert_eq(panel.zones[0].total, coup.player_total, "Player total matches the coup")
	assert_eq(panel.zones[1].total, coup.banker_total, "Banker total matches the coup")
	for card: BaccaratCard in panel.cards:
		assert_true(card.is_revealed())
		var landed := card.position + BaccaratCard.SIZE * 0.5
		assert_true(
			BaccaratTablePanel.slot_rect(card.hand, card.slot).has_point(landed),
			"Card %d/%d landed at %s" % [card.hand, card.slot, card.position]
		)
	await wait_seconds(BaccaratTablePanel.REVEAL_BEAT_SECONDS + 0.2)
	assert_false(game.is_result_pending)
	var result: RoundResult = panel._result
	assert_not_null(result)
	assert_eq(Wallet.balance, 1000 - 60 + result.payout, "One settlement of the whole layout")
	assert_eq(panel.bead_road.beads.size(), 1)


func test_hostess_is_unique_clean_and_clear_of_the_play_surfaces() -> void:
	var panel: BaccaratTablePanel = _open().cabinet.panel
	var hostess := panel.hostess
	assert_eq(hostess.pose_ids(), [&"idle", &"deal", &"squeeze", &"announce"])
	for id: StringName in hostess.pose_ids():
		var path := hostess.pose_texture(id).resource_path
		assert_true(path.begins_with("res://assets/production/characters/hosts/baccarat_hostess"))
		assert_false(OTHER_HOSTS.has(path), "%s is her own art" % path)
		var image := hostess.pose_texture(id).get_image()
		assert_eq(image.get_size(), Vector2i(1392, 2080), path)
		var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner %s is clear" % [path, corner])
		# Real alpha: the figure is opaque and the canvas around it is empty.
		assert_gt(image.get_pixel(int(BaccaratHostess.STANCE_X), 400).a, 0.98, "%s face" % path)
		assert_eq(image.get_pixel(40, 1000).a, 0.0, "%s background" % path)
	for other: String in OTHER_HOSTS:
		assert_ne(hostess.portrait_texture().resource_path, other)
	var lane := hostess.get_parent() as Control
	assert_true(lane.clip_contents, "The far rail hides her below the hip")
	var lane_rect := Rect2(lane.position, lane.size)
	assert_eq(lane_rect.end.y, BaccaratTablePanel.RAIL_Y, "Lane ends on the painted rail")
	var bounds := hostess.lane_bounds()
	assert_almost_eq(bounds.position.y, 40.0, 2.0, "Her head sits below the top edge")
	assert_true(
		Rect2(Vector2.ZERO, lane.size).grow(1.0).encloses(
			Rect2(
				bounds.position,
				Vector2(bounds.size.x, BaccaratTablePanel.RAIL_Y - bounds.position.y)
			)
		),
		"Every pose fits the lane above the rail"
	)
	var protected: Array[Rect2] = [
		BaccaratTablePanel.TITLE_RECT,
		BaccaratTablePanel.RESULT_RECT,
		BaccaratTablePanel.HELP_RECT,
		Rect2(panel.bead_road.position, panel.bead_road.size),
		Rect2(panel.deck.position, panel.deck.size),
		BaccaratTablePanel.PLAYER_ZONE,
		BaccaratTablePanel.BANKER_ZONE,
	]
	for id: String in BaccaratTablePanel.SPOT_RECTS:
		protected.append(BaccaratTablePanel.SPOT_RECTS[id])
	for hand: int in range(2):
		for slot: int in range(3):
			protected.append(BaccaratTablePanel.slot_rect(hand, slot))
	for rect: Rect2 in protected:
		assert_false(lane_rect.intersects(rect), "Hostess lane stays clear of %s" % rect)


func test_table_targets_are_large_enough_and_inside_tv_safe() -> void:
	var panel: BaccaratTablePanel = _open().cabinet.panel
	var controls: Array[Control] = [panel._help_button]
	for child: Node in panel.deck.get_children():
		if child is BaseButton:
			controls.append(child)
	for id: String in panel.spots:
		controls.append(panel.spots[id])
	assert_eq(controls.size(), 13, "Help, four chips, Clear, Rebet, Deal and five spots")
	for control: Control in controls:
		var rect := control.get_global_rect()
		assert_gte(rect.size.x, MIN_TARGET, "%s width" % control.name)
		assert_gte(rect.size.y, MIN_TARGET, "%s height" % control.name)
		assert_true(TV_SAFE.encloses(rect), "%s %s is inside TV-safe" % [control.name, rect])
		for other: Control in controls:
			if other != control:
				assert_false(rect.intersects(other.get_global_rect()), "%s overlaps" % control.name)
	for hand: int in range(2):
		for slot: int in range(3):
			var card := BaccaratTablePanel.slot_rect(hand, slot)
			var zone := (
				BaccaratTablePanel.PLAYER_ZONE if hand == 0 else BaccaratTablePanel.BANKER_ZONE
			)
			assert_true(zone.encloses(card), "Card %d/%d sits in its hand box" % [hand, slot])
			var disc := panel.zones[hand].disc_center() + zone.position
			var disc_rect := Rect2(disc - Vector2(23, 23), Vector2(46, 46))
			assert_false(
				card.intersects(disc_rect), "Card %d/%d clears the total disc" % [hand, slot]
			)
			for id: String in BaccaratTablePanel.SPOT_RECTS:
				assert_false(card.intersects(BaccaratTablePanel.SPOT_RECTS[id]))


func test_reduced_motion_reveals_at_once_with_one_bounded_cue() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := _open()
	var game: MiniGame = session.cabinet
	var panel: BaccaratTablePanel = game.panel
	assert_true(game.call("request_place", BaccaratMath.PLAYER))
	assert_true(game.call("request_deal"))
	assert_true(panel.is_revealed(), "Every card is already face up")
	for card: BaccaratCard in panel.cards:
		assert_true(card.is_revealed())
		assert_eq(card.position, panel.card_target(card.hand, card.slot), "No travel")
	assert_eq(panel.hostess.current_pose, &"idle", "She keeps the static master pose")
	var cues := panel.zones.filter(func(zone: BaccaratHandZone) -> bool: return zone.cue_active())
	assert_gt(cues.size(), 0, "One bounded cue marks the winner")
	assert_lte(
		MotionPolicy.finite_duration(BaccaratHandZone.CUE_SECONDS), BaccaratHandZone.CUE_SECONDS
	)
	await wait_seconds(0.7)
	assert_false(game.is_round_active)
	for zone: BaccaratHandZone in panel.zones:
		assert_false(zone.cue_active(), "The cue is finite")


func test_back_mid_deal_asks_before_leaving() -> void:
	var game: MiniGame = _open().cabinet
	assert_true(game.call("request_place", BaccaratMath.TIE))
	assert_true(game.call("request_deal"))
	var event := InputEventAction.new()
	event.action = "back"
	event.pressed = true
	game._unhandled_input(event)
	assert_true(game.exit_confirmation.is_open, "Cards on the table need the exit confirmation")


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_controller_places_on_spots_and_walks_to_the_rack_and_back() -> void:
	var game: MiniGame = _open().cabinet
	var panel: BaccaratTablePanel = game.panel
	await wait_process_frames(2)
	var player_spot: Control = panel.spots[BaccaratMath.PLAYER]
	assert_eq(get_viewport().gui_get_focus_owner(), player_spot, "The Player spot has focus")
	game._unhandled_input(_action("move_right"))
	var tie_spot: Control = panel.spots[BaccaratMath.TIE]
	assert_eq(get_viewport().gui_get_focus_owner(), tie_spot, "Right walks the spot row")
	(tie_spot as BaseButton).pressed.emit()
	assert_eq(game.get("math").chips_on(BaccaratMath.TIE), game.selected_stake, "A places")
	game._unhandled_input(_action("secondary"))
	assert_eq(game.get("math").chips_on(BaccaratMath.TIE), 0, "X takes it back")
	game._unhandled_input(_action("move_down"))
	var focused := get_viewport().gui_get_focus_owner()
	assert_true(panel.deck.owns_focus(focused), "Down reaches the rack")
	assert_eq((focused as BaccaratChipButton).amount, game.selected_stake, "On the selected chip")
	game._unhandled_input(_action("move_right"))
	assert_true(panel.deck.owns_focus(get_viewport().gui_get_focus_owner()))
	game._unhandled_input(_action("move_up"))
	assert_eq(get_viewport().gui_get_focus_owner(), tie_spot, "Up returns to the last spot")
	assert_true(game.call("request_place", BaccaratMath.BANKER))
	game._unhandled_input(_action("tertiary"))
	assert_true(game.is_round_active, "Y deals")


func test_every_baccarat_label_is_translated() -> void:
	for id: String in BaccaratMath.SPOTS:
		var key := BaccaratTablePanel.spot_name_key(id)
		assert_ne(tr(key), key, "%s is translated" % key)
	for key: String in [
		"CABINET_BACCARAT_NAME",
		"BACCARAT_PRICE",
		"BACCARAT_PRICE_BANKER",
		"HELP_BACCARAT_RULES",
		"HELP_BACCARAT_CONTROLS",
		"BACCARAT_ROAD_COUNTS",
	]:
		assert_ne(tr(key), key, "%s is translated" % key)
	assert_eq(tr("BACCARAT_PRICE_BANKER") % 5, "1 TO 1 LESS 5%")
