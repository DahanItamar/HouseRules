extends GutTest
## The shared CabinetDeck, piloted on Blackjack: only valid actions are shown,
## the bet stepper stays within limits and wallet, targets stay 44 px inside
## TV-safe, prompts follow the device, and the deck never covers the table.

const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
const TV_SAFE := Rect2(48, 27, 864, 486)

var _starting_balance: int
var _starting_test_mode: bool
var _device: InputRouter.Device


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	_device = InputRouter.active_device
	Wallet.reset(200)
	InputRouter.force_prompt_family(InputRouter.Device.KEYBOARD, InputRouter.GamepadFamily.XBOX)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.set_test_mode(false)
	Wallet.reset(_starting_balance)
	Wallet.set_test_mode(_starting_test_mode)
	InputRouter.force_prompt_family(_device, InputRouter.GamepadFamily.XBOX)
	InputRouter.force_prompt_family(-1, -1)


func _open(reduced: bool = true) -> CabinetPanel:
	MotionPolicy.set_reduced_motion_for_tests(reduced)
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(BLACKJACK_DEFINITION)
	return session.cabinet.panel


func _deal_fixture(panel: CabinetPanel, player: Array[int], dealer: Array[int]) -> void:
	var game: MiniGame = panel.cabinet
	var math: BlackjackMath = game.get("math")
	math.player.assign(player)
	math.dealer.assign(dealer)
	math.stake = 10
	math.active = true
	game.current_stake = 10
	game.is_round_active = true
	panel.refresh()


func _ids(names: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(names)
	return ids


func test_betting_shows_only_deal_and_says_what_to_do() -> void:
	var panel := _open()
	var deck := panel.control_deck()
	assert_not_null(deck)
	assert_eq(deck.visible_action_ids(), _ids([&"primary"]))
	assert_true(panel._blackjack_primary.is_visible_in_tree())
	assert_false(panel._blackjack_stand.visible, "Stand is hidden, not greyed, before a deal")
	assert_false(panel._blackjack_double.visible)
	assert_eq(panel._blackjack_primary.text, tr("ACTION_DEAL"))
	assert_eq(panel._blackjack_primary.action, &"interact")
	assert_eq(deck.instruction.template, tr("DECK_BJ_BETTING"))
	assert_true(deck.instruction.has_glyphs(), "The instruction names the inputs inline")
	assert_true(deck.bet.step_up_button().visible)
	assert_false(panel._stake_selector.visible, "The chip-button row is replaced by the stepper")


func test_decision_shows_hit_stand_and_double_only_while_double_is_legal() -> void:
	var panel := _open()
	var deck := panel.control_deck()
	_deal_fixture(panel, [5, 6], [9, 8])
	assert_eq(deck.visible_action_ids(), _ids([&"double", &"stand", &"primary"]))
	assert_eq(panel._blackjack_primary.text, tr("ACTION_HIT"))
	assert_eq(panel._blackjack_stand.action, &"secondary", "Stand keeps X")
	assert_eq(panel._blackjack_double.action, &"tertiary", "Double keeps Y")
	assert_eq(deck.instruction.template, tr("DECK_BJ_DECIDE_DOUBLE") % 11)
	assert_false(deck.bet.step_up_button().visible, "The stake is locked while the hand plays")
	_deal_fixture(panel, [5, 6, 2], [9, 8])
	assert_eq(
		deck.visible_action_ids(), _ids([&"stand", &"primary"]), "Double disappears after a hit"
	)
	assert_eq(deck.instruction.template, tr("DECK_BJ_DECIDE") % 13)


func test_dealer_drawing_hides_every_action() -> void:
	var panel := _open()
	var deck := panel.control_deck()
	_deal_fixture(panel, [10, 7], [9, 8])
	panel.cabinet.is_result_pending = true
	panel.refresh()
	assert_true(deck.visible_action_ids().is_empty())
	assert_true(panel._blackjack_primary.disabled, "Hidden actions are also disabled")
	assert_eq(deck.instruction.template, tr("DECK_BJ_DEALER_DRAWING"))
	panel.cabinet.is_result_pending = false


func test_result_offers_deal_again_with_one_accent_per_meaning() -> void:
	var panel := _open()
	var deck := panel.control_deck()
	var cases: Array = [
		[
			RoundResult.create(
				10, 20, RoundResult.Outcome.WIN, {"player": [10, 9], "dealer": [10, 8]}
			),
			tr("DECK_BJ_RESULT_WIN") % 10,
			InfoPlate.Tone.WIN
		],
		[
			RoundResult.create(
				10, 10, RoundResult.Outcome.PUSH, {"player": [10, 8], "dealer": [10, 8]}
			),
			tr("DECK_BJ_RESULT_PUSH"),
			InfoPlate.Tone.PUSH
		],
		[
			RoundResult.create(
				10, 0, RoundResult.Outcome.LOSS, {"player": [10, 7], "dealer": [10, 9]}
			),
			tr("DECK_BJ_RESULT_LOSS") % 10,
			InfoPlate.Tone.LOSS
		],
	]
	for entry: Array in cases:
		panel.show_result(entry[0])
		assert_eq(deck.visible_action_ids(), _ids([&"primary"]))
		assert_eq(deck.instruction.template, entry[1])
		assert_eq(deck.instruction_tone(), entry[2])
	assert_eq(panel.BLACKJACK_WIN_INK, Color("f2c84b"), "Win reads brass")
	assert_eq(panel.BLACKJACK_LOSS_INK, Color("d27a6c"), "Loss reads muted red")
	assert_eq(panel.BLACKJACK_TEXT, Color("f1e8d8"), "Push reads ivory")


func test_empty_wallet_explains_instead_of_greying_deal() -> void:
	Wallet.reset(0)
	var panel := _open()
	var deck := panel.control_deck()
	assert_true(deck.visible_action_ids().is_empty(), "No unusable Deal key is shown")
	assert_eq(deck.instruction.template, tr("DECK_NEED_FUNDS") % BLACKJACK_DEFINITION.min_bet)


func test_bet_stepper_reaches_every_denomination_within_limits_and_wallet() -> void:
	Wallet.reset(30)
	var panel := _open()
	var game: MiniGame = panel.cabinet
	var bet := panel.control_deck().bet
	var stakes := game.available_stakes()
	assert_eq(stakes, [5, 10, 25, 30] as Array[int], "The wallet caps the table maximum")
	game.select_stake(stakes[0])
	var seen: Array[int] = [game.selected_stake]
	for step: int in range(stakes.size() + 2):
		bet.step_requested.emit(1)
		if not seen.has(game.selected_stake):
			seen.append(game.selected_stake)
	assert_eq(seen, stakes, "+ walks every legal denomination in order")
	assert_eq(game.selected_stake, 30, "Never past the wallet")
	assert_true(bet.step_up_button().disabled, "+ reads unavailable at the cap")
	for step: int in range(stakes.size() + 2):
		bet.step_requested.emit(-1)
	assert_eq(game.selected_stake, 5, "Never below the table minimum")
	assert_true(bet.step_down_button().disabled)
	assert_eq(bet.amount, 5)
	assert_eq(bet.limit_text, tr("DECK_TABLE_LIMIT") % [5, 100])


func test_shoulder_and_trigger_inputs_step_the_bet() -> void:
	var panel := _open()
	var game: MiniGame = panel.cabinet
	game.select_stake(5)
	game._unhandled_input(_action(&"bet_up"))
	assert_eq(game.selected_stake, 10)
	game._unhandled_input(_action(&"bet_down"))
	assert_eq(game.selected_stake, 5)
	game._unhandled_input(_action(&"bet_max"))
	assert_eq(game.selected_stake, game.available_stakes()[-1])
	_deal_fixture(panel, [10, 7], [9, 8])
	var locked := game.selected_stake
	game._unhandled_input(_action(&"bet_down"))
	assert_eq(game.selected_stake, locked, "Bet inputs never change a live hand")


func test_scroll_wheel_over_the_bet_steps_it() -> void:
	var panel := _open()
	var game: MiniGame = panel.cabinet
	game.select_stake(10)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	panel.control_deck().bet._gui_input(wheel)
	assert_eq(game.selected_stake, 25)


func test_every_deck_target_is_44px_and_inside_tv_safe() -> void:
	var panel := _open()
	var deck := panel.control_deck()
	assert_true(TV_SAFE.encloses(deck.get_global_rect()), "The deck sits inside TV-safe")
	for state: int in range(2):
		if state == 1:
			_deal_fixture(panel, [5, 6], [9, 8])
		var targets: Array[Control] = [panel._help_button]
		for id: StringName in deck.visible_action_ids():
			targets.append(deck.action_button(id))
		if deck.bet.step_up_button().visible:
			targets.append_array([deck.bet.step_down_button(), deck.bet.step_up_button()])
		if deck.quick_bets.visible:
			for quick: PromptButton in deck.quick_bets.keys():
				targets.append(quick)
		for target: Control in targets:
			var rect := target.get_global_rect()
			assert_gte(rect.size.x, 44.0, "%s is 44 px wide" % target.name)
			assert_gte(rect.size.y, 44.0, "%s is 44 px tall" % target.name)
			assert_true(TV_SAFE.encloses(rect), "%s %s stays inside TV-safe" % [target.name, rect])
		var shown := deck.visible_action_ids()
		for index: int in range(shown.size()):
			for other: int in range(index + 1, shown.size()):
				assert_false(
					deck.action_button(shown[index]).get_global_rect().intersects(
						deck.action_button(shown[other]).get_global_rect()
					),
					"Action keys never overlap"
				)
		assert_false(
			deck.bet.get_global_rect().intersects(deck.action_button(&"primary").get_global_rect())
		)


func test_deck_never_covers_cards_badges_wager_or_dealer() -> void:
	var panel := _open()
	var deck_rect := panel.control_deck().get_global_rect()
	panel._clear_blackjack_cards()
	panel._render_blackjack_hand([2, 3, 2, 4, 2], [9, 8, 2, 3], false)
	for card: PlayingCard in panel._blackjack_cards:
		var sweep := absf(sin(card.rotation)) * card.size.y * 0.5 + 1.0
		var bounds := Rect2(card.position, card.size).grow(sweep)
		assert_false(bounds.intersects(deck_rect), "%s clears the deck" % card.name)
	for badge_name: String in ["DealerTotalBadge", "PlayerTotalBadge"]:
		var badge := panel.find_child(badge_name, true, false) as Control
		assert_false(badge.get_rect().intersects(deck_rect), "%s clears the deck" % badge_name)
	_deal_fixture(panel, [10, 7], [9, 8])
	var stack: BlackjackBetStack = panel._blackjack_bet_stack
	assert_false(
		Rect2(stack.position, stack.size).intersects(deck_rect), "The wager stays on the felt"
	)
	var dealer: BlackjackDealerPresenter = panel._blackjack_dealer_presenter
	for id: StringName in dealer.host().pose_ids():
		assert_false(
			dealer.host().pose_bounds(id).intersects(deck_rect), "Dealer %s clears the deck" % id
		)
	assert_false(
		panel._help_button.get_global_rect().intersects(deck_rect), "Help and deck never touch"
	)


func test_instruction_and_keys_follow_the_active_device() -> void:
	var panel := _open()
	var deck := panel.control_deck()
	assert_string_contains(deck.instruction.text, tr("INPUT_ENTER"))
	assert_eq(panel._blackjack_primary.glyph_spec().label, tr("INPUT_ENTER"))
	InputRouter.force_prompt_family(InputRouter.Device.GAMEPAD, InputRouter.GamepadFamily.XBOX)
	assert_string_contains(deck.instruction.text, "[A]")
	assert_string_contains(deck.instruction.text, "[LB]")
	assert_eq(panel._blackjack_primary.glyph_spec().label, "A")
	InputRouter.force_prompt_family(
		InputRouter.Device.GAMEPAD, InputRouter.GamepadFamily.PLAYSTATION
	)
	assert_eq(panel._blackjack_primary.glyph_spec().symbol, &"cross")
	assert_eq(deck.bet.step_down_button().get("action"), &"bet_down")


func test_bet_preview_sits_on_the_betting_spot_before_the_deal() -> void:
	var panel := _open()
	var stack: BlackjackBetStack = panel._blackjack_bet_stack
	assert_true(stack.preview, "The chosen stake waits on the felt")
	assert_true(stack.visible)
	assert_eq(stack.position, BlackjackBetStack.TABLE_POSITION)
	assert_almost_eq(stack.modulate.a, BlackjackBetStack.PREVIEW_ALPHA, 0.01)
	assert_eq(stack.wager, panel.cabinet.selected_stake)
	_deal_fixture(panel, [10, 7], [9, 8])
	assert_false(stack.preview)
	assert_true(stack.is_live)
	assert_eq(stack.modulate.a, 1.0, "Reduced motion commits the chips at once")


func test_reduced_motion_swaps_actions_without_travel() -> void:
	var panel := _open(true)
	var deck := panel.control_deck()
	_deal_fixture(panel, [5, 6], [9, 8])
	assert_false(deck.has_active_motion(), "No slide, fade or sweep under reduced motion")
	var primary := deck.action_button(&"primary")
	assert_eq(primary.position.x + primary.size.x, deck.size.x - CabinetDeck.INSET)


func test_full_motion_swap_slides_new_keys_up_into_place() -> void:
	var panel := _open(false)
	var deck := panel.control_deck()
	await get_tree().process_frame
	_deal_fixture(panel, [5, 6], [9, 8])
	var stand := deck.action_button(&"stand")
	assert_true(deck.has_active_motion())
	await wait_seconds(0.45)
	assert_false(deck.has_active_motion())
	assert_almost_eq(
		stand.position.y, CabinetDeck.ROW_TOP + (CabinetDeck.ROW_HEIGHT - stand.size.y) * 0.5, 0.01
	)


func test_help_button_is_a_compact_44px_header_control() -> void:
	var panel := _open()
	var help := panel._help_button as HelpButton
	assert_not_null(help)
	assert_eq(help.get_global_rect(), CabinetPanel.HELP_BUTTON_RECT)
	assert_true(TV_SAFE.encloses(help.get_global_rect()))
	assert_gte(help.size.y, 44.0)
	assert_not_null(help.medallion_texture(), "Blackjack uses its painted kit medallion")


func test_help_card_is_structured_and_pages() -> void:
	var panel := _open()
	panel.set_help_open(true)
	var card := panel.help_card()
	assert_gt(card.page_count(), 1, "Long guides page instead of cramming")
	var templates := card.visible_templates()
	assert_true(templates.has(tr("HELP_BLACKJACK_GOAL")), "Goal in one line on page one")
	assert_eq(card.page, 0)
	assert_true(panel.help_page_step(1))
	assert_eq(card.page, 1)
	assert_false(panel.help_page_step(1), "The last page stops")
	var game: MiniGame = panel.cabinet
	game.handle_common_input(_action(&"bet_down"))
	assert_eq(card.page, 0, "LB / Q turns back a page")
	panel.set_help_open(false)


func test_help_control_instructions_wrap_instead_of_being_cut_off() -> void:
	var card := HelpCard.new()
	add_child_autofree(card)
	card.set_content(
		{
			"controls":
			[
				"{back} Leave (asks first while chips are still committed to the table)",
			]
		}
	)
	var rows := card.find_children("*", "InputPromptLabel", true, false)
	var instruction: InputPromptLabel
	for row: InputPromptLabel in rows:
		if "committed" in row.template:
			instruction = row
			break
	assert_not_null(instruction, "The long keyboard instruction is rendered")
	assert_eq(instruction.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART)
	assert_eq(instruction.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING)
	assert_gt(instruction.size.y, HelpCard.CONTROL_HEIGHT, "The complete label gets a second line")
	assert_lte(
		instruction.get_global_rect().end.y,
		card.get_global_rect().position.y + HelpCard.BODY_HEIGHT,
		"Wrapped instructions stay inside the help body"
	)


func test_legacy_help_text_becomes_glyph_rows_and_notes() -> void:
	InputRouter.force_prompt_family(InputRouter.Device.KEYBOARD, InputRouter.GamepadFamily.XBOX)
	var controls := (
		"%s  Move on the layout\n\n[%s] Place chip\n\nChips sit below the layout\n\n[%s] Leave"
		% [InputRouter.glyph("move"), InputRouter.glyph("interact"), InputRouter.glyph("back")]
	)
	var content := CabinetPanel.legacy_help_content(
		"Goal line.\n\nStep one.\n\nStep two.", controls
	)
	assert_eq(content.goal, "Goal line.")
	assert_eq(content.steps, ["Step one.", "Step two."])
	assert_eq(
		content.controls, ["{move} Move on the layout", "{interact} Place chip", "{back} Leave"]
	)
	assert_eq(content.notes, ["Chips sit below the layout"])


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_quick_bets_offer_the_same_six_keys_and_clamp_through_the_cabinet() -> void:
	var panel := _open()
	var deck := panel.control_deck()
	var cabinet: MiniGame = panel.cabinet
	assert_true(deck.quick_bets.visible, "The row is live while the bet can change")
	var labels: Array[String] = []
	for key: PromptButton in deck.quick_bets.keys():
		labels.append(key.text)
	assert_eq(labels, ["MIN", "10", "25", "X2", "X5", "ALL"], "One learnable order everywhere")
	cabinet.selected_stake = cabinet.context.definition.min_bet
	panel.refresh()
	deck.quick_bets.key(MiniGame.BetOperation.ADD_10).pressed.emit()
	assert_eq(
		cabinet.selected_stake,
		cabinet.context.definition.min_bet + 10,
		"A quick key applies through the cabinet's own rules"
	)
	# The table maximum is the cabinet's clamp, so the key is simply unavailable.
	cabinet.selected_stake = cabinet.context.definition.max_bet
	panel.refresh()
	var over := deck.quick_bets.key(MiniGame.BetOperation.MULTIPLY_5)
	assert_true(over.disabled, "X5 past the table maximum is unavailable")
	assert_eq(over.focus_mode, Control.FOCUS_NONE, "An unavailable key is not in the focus chain")
	over.pressed.emit()
	assert_eq(cabinet.selected_stake, cabinet.context.definition.max_bet, "The clamp holds")
	assert_true(deck.quick_bets.key(MiniGame.BetOperation.MIN).disabled == false, "MIN stays open")


func test_a_refused_quick_bet_says_why_only_while_it_is_reached_for() -> void:
	var panel := _open()
	var deck := panel.control_deck()
	var cabinet: MiniGame = panel.cabinet
	cabinet.selected_stake = cabinet.context.definition.max_bet
	panel.refresh()
	var plain := deck.instruction.text
	assert_eq(deck.quick_bets.unavailable_reason(cabinet), "", "Nothing reached for, nothing said")
	deck.quick_bets.key(MiniGame.BetOperation.MULTIPLY_5).mouse_entered.emit()
	var reason := deck.quick_bets.unavailable_reason(cabinet)
	assert_string_contains(reason, "X5", "The refusal names the key")
	# Wallet first: 5x the table maximum is more than this wallet holds, so the
	# player is told the number they would need, not the table's limit.
	assert_string_contains(reason, str(cabinet.selected_stake * 5), "and what it would cost them")
	assert_string_contains(deck.instruction.text, "X5", "The rail explains it where they look")
	deck.quick_bets.key(MiniGame.BetOperation.MULTIPLY_5).mouse_exited.emit()
	assert_eq(deck.instruction.text, plain, "Then the ordinary instruction comes back")
	# With money to spare it is the table that refuses, and the rail says so.
	Wallet.reset(100000)
	cabinet.context.balance = 100000
	cabinet.selected_stake = cabinet.context.definition.max_bet
	panel.refresh()
	deck.quick_bets.key(MiniGame.BetOperation.MULTIPLY_2).mouse_entered.emit()
	assert_string_contains(
		deck.quick_bets.unavailable_reason(cabinet),
		str(cabinet.context.definition.max_bet),
		"A rich player is refused by the table, not the wallet"
	)


func test_quick_bets_hide_once_the_stake_is_locked() -> void:
	var panel := _open()
	_deal_fixture(panel, [10, 7], [9, 8])
	assert_false(
		panel.control_deck().quick_bets.visible, "A dealt hand's stake cannot be quick-bet"
	)
