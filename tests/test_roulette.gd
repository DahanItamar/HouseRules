extends GutTest
## European Roulette: exact single-zero math, layout geometry, controller and
## pointer targets, the table-life guests' isolation, and presentation that
## only ever shows the pocket the math already decided.

const DEFINITION_PATH := "res://data/cabinets/roulette.tres"
const TV_SAFE := Rect2(48, 27, 864, 486)
const MIN_TARGET: float = 44.0
const EXPECTED_KIND_COUNTS := {
	RouletteMath.BetKind.STRAIGHT: 37,
	RouletteMath.BetKind.SPLIT: 60,
	RouletteMath.BetKind.STREET: 14,
	RouletteMath.BetKind.CORNER: 23,
	RouletteMath.BetKind.SIX_LINE: 11,
	RouletteMath.BetKind.DOZEN: 3,
	RouletteMath.BetKind.COLUMN: 3,
	RouletteMath.BetKind.RED: 1,
	RouletteMath.BetKind.BLACK: 1,
	RouletteMath.BetKind.ODD: 1,
	RouletteMath.BetKind.EVEN: 1,
	RouletteMath.BetKind.LOW: 1,
	RouletteMath.BetKind.HIGH: 1,
}
var _starting_test_mode: bool
var _starting_balance: int


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	Wallet.reset(500)
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


func test_every_bet_returns_exactly_36_of_37_over_all_pockets() -> void:
	var math := RouletteMath.new()
	var counts: Dictionary = {}
	for id: String in math.spots():
		var spot := math.spot(id)
		counts[spot.kind] = int(counts.get(spot.kind, 0)) + 1
		var covered: int = (spot.numbers as Array).size()
		assert_eq(36 % covered, 0, "%s covers a divisor of 36" % id)
		assert_eq(math.pays_to_one(spot.kind), 36 / covered - 1, "%s pays (36/k)-1 to one" % id)
		var hits: int = 0
		for pocket: int in range(37):
			if math.returned_for(id, 1, pocket) > 0:
				hits += 1
		assert_eq(hits, covered, "%s wins on exactly its covered pockets" % id)
		assert_eq(math.expected_return_numerator(id), 36, "%s returns 36 chips per 37 staked" % id)
	assert_eq(math.spots().size(), 157, "Every single-zero layout spot exists once")
	for kind: int in EXPECTED_KIND_COUNTS:
		assert_eq(int(counts.get(kind, 0)), EXPECTED_KIND_COUNTS[kind], "kind %d count" % kind)
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	assert_almost_eq(36.0 / 37.0, definition.target_rtp, 0.0005, "Declared RTP is the wheel's")


func test_zero_and_colours_follow_the_european_wheel() -> void:
	var math := RouletteMath.new()
	assert_eq(math.paytable.red_numbers.size(), 18)
	assert_eq(math.paytable.wheel_order.size(), 37)
	var sorted := Array(math.paytable.wheel_order)
	sorted.sort()
	assert_eq(sorted, range(37), "The wheel carries each pocket exactly once")
	for index: int in range(1, 37):
		var here := math.paytable.wheel_order[index]
		var next := math.paytable.wheel_order[(index % 36) + 1]
		if index < 36:
			assert_ne(math.is_red(here), math.is_red(next), "Colours alternate around the wheel")
	for id: String in ["red", "black", "odd", "even", "low", "high", "dozen:1", "column:3"]:
		assert_eq(math.returned_for(id, 10, 0), 0, "Zero loses %s" % id)
	assert_eq(math.returned_for("straight:0", 10, 0), 360)
	assert_eq(math.returned_for("split:0,3", 10, 3), 180)
	assert_eq(math.returned_for("corner:0,1,2,3", 10, 2), 90)


func test_layout_limits_rebet_and_one_spin_settle_every_bet() -> void:
	var math := RouletteMath.new()
	assert_true(math.place("straight:17", 10, 100))
	assert_true(math.place("red", 50, 100))
	assert_false(math.place("black", 41, 100), "Total may never exceed the cap")
	assert_false(math.place("not-a-spot", 1, 100))
	assert_false(math.place("odd", 0, 100))
	assert_eq(math.remove("red", 25), 25)
	assert_eq(math.total_bet(), 35)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260918
	var expected := RandomNumberGenerator.new()
	expected.seed = 20260918
	var result := math.spin(rng)
	var pocket := expected.randi_range(0, 36)
	assert_eq(result.detail.pocket, pocket, "One uniform draw from the cabinet stream")
	assert_eq(result.stake, 35)
	var returned := math.returned_for("straight:17", 10, pocket)
	returned += math.returned_for("red", 25, pocket)
	assert_eq(result.payout, returned)
	assert_true(math.bets.is_empty(), "Chips leave the layout with the spin")
	assert_true(math.rebet(35))
	assert_eq(math.total_bet(), 35)
	math.clear()
	assert_false(math.can_rebet(34), "Rebet respects a lower limit")


func test_board_nodes_are_domain_spots_and_all_reachable_by_cursor() -> void:
	var math := RouletteMath.new()
	var geometry := RouletteBoardGeometry.new(math)
	var ids: Dictionary = {}
	for node: Dictionary in geometry.nodes:
		assert_false(ids.has(node.id), "%s appears once" % node.id)
		ids[node.id] = true
	for id: String in math.spots():
		assert_true(ids.has(id), "%s has a place on the layout" % id)
	var seen: Dictionary = {0: true}
	var frontier: Array[int] = [0]
	while not frontier.is_empty():
		var current: int = frontier.pop_back()
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := geometry.neighbor(current, direction)
			if next >= 0 and not seen.has(next):
				seen[next] = true
				frontier.append(next)
	assert_eq(seen.size(), geometry.nodes.size(), "D-pad reaches every spot")
	var moves := [
		["low", Vector2i.RIGHT, "even"],
		["even", Vector2i.UP, "dozen:1"],
		["street:1,2,3", Vector2i.DOWN, "dozen:1"],
		["column:3", Vector2i.DOWN, "column:2"],
		["split:0,3", Vector2i.LEFT, "straight:0"],
		["straight:1", Vector2i.RIGHT, "split:1,4"],
		["straight:1", Vector2i.DOWN, "street:1,2,3"],
		["straight:36", Vector2i.RIGHT, "column:3"],
	]
	for move: Array in moves:
		var next := geometry.neighbor(geometry.index_of(move[0]), move[1])
		assert_eq(
			geometry.nodes[next].id if next >= 0 else "", move[2], "%s %s" % [move[0], move[1]]
		)
	var bottom := geometry.index_of("high")
	assert_eq(geometry.neighbor(bottom, Vector2i.DOWN), -1, "Below the layout the deck takes over")


func test_pointer_hits_numbers_edges_corners_and_outside_boxes() -> void:
	var geometry := RouletteBoardGeometry.new(RouletteMath.new())
	var cell_17 := RouletteBoardGeometry.number_rect(17)
	var cases := {
		cell_17.get_center(): "straight:17",
		Vector2(cell_17.end.x, cell_17.get_center().y): "split:17,20",
		Vector2(cell_17.get_center().x, cell_17.position.y): "split:17,18",
		cell_17.end: "corner:16,17,19,20",
		Vector2(cell_17.get_center().x, RouletteBoardGeometry.GRID_BOTTOM): "street:16,17,18",
		Vector2(cell_17.end.x, RouletteBoardGeometry.GRID_BOTTOM): "six:16,17,18,19,20,21",
		Vector2(10, 60): "straight:0",
		Vector2(RouletteBoardGeometry.GRID_LEFT, 22): "split:0,3",
		Vector2(RouletteBoardGeometry.GRID_LEFT, RouletteBoardGeometry.GRID_BOTTOM):
		"corner:0,1,2,3",
		Vector2(600, 20): "column:3",
		Vector2(400, 150): "dozen:3",
		Vector2(300, 200): "red",
	}
	for point: Vector2 in cases:
		var index := geometry.hit_test(point)
		assert_gte(index, 0, "%s hits a spot" % point)
		if index >= 0:
			assert_eq(geometry.nodes[index].id, cases[point], "pointer at %s" % point)
	assert_eq(geometry.hit_test(Vector2(-4, 10)), -1)


func test_table_targets_are_large_enough_and_inside_tv_safe() -> void:
	var panel: RouletteTablePanel = _open().cabinet.panel
	var board_rect := Rect2(panel.board.position, panel.board.size)
	assert_true(TV_SAFE.encloses(board_rect), "Layout %s is inside TV-safe" % board_rect)
	assert_gte(RouletteBoardGeometry.CELL, MIN_TARGET)
	var controls: Array[Control] = [panel._help_button]
	for child: Node in panel.deck.get_children():
		if child is BaseButton:
			controls.append(child)
	assert_eq(controls.size(), 9, "Help, five chips, Clear, Rebet and Spin")
	for control: Control in controls:
		var rect := control.get_global_rect()
		assert_gte(rect.size.x, MIN_TARGET, "%s width" % control.name)
		assert_gte(rect.size.y, MIN_TARGET, "%s height" % control.name)
		assert_true(TV_SAFE.encloses(rect), "%s %s is inside TV-safe" % [control.name, rect])
		assert_false(rect.intersects(board_rect), "%s stays off the layout" % control.name)


func test_croupier_is_unique_clean_and_clear_of_the_play_surfaces() -> void:
	var panel: RouletteTablePanel = _open().cabinet.panel
	var croupier := panel.croupier
	assert_eq(croupier.pose_ids().size(), 4, "idle, spin, no more bets, announce")
	for id: StringName in croupier.pose_ids():
		var path := croupier.pose_texture(id).resource_path
		assert_true(path.begins_with("res://assets/production/characters/hosts/roulette_croupier"))
		var image := croupier.pose_texture(id).get_image()
		assert_gte(image.get_width(), 1024, path)
		assert_gte(image.get_height(), 1536, path)
		var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner %s is clear" % [path, corner])
	var lane := croupier.get_parent() as Control
	assert_true(lane.clip_contents, "The far rail hides her below the upper thigh")
	var lane_rect := Rect2(lane.position, lane.size)
	var protected: Array[Rect2] = [
		Rect2(panel.board.position, panel.board.size),
		Rect2(panel.deck.position, panel.deck.size),
		RouletteTablePanel.TITLE_RECT,
		Rect2(panel.result_plaque.position, panel.result_plaque.size),
	]
	for plate: RouletteSeatPlate in panel.seat_plates:
		protected.append(Rect2(plate.position, plate.size))
	for rect: Rect2 in protected:
		assert_false(lane_rect.intersects(rect), "Croupier lane stays clear of %s" % rect)
	for path: String in [
		"res://assets/production/characters/hosts/slot_elf_princess.png",
		"res://assets/production/characters/hosts/blackjack_dealer_v2.png",
		"res://assets/production/characters/hosts/vault_witcher_sorceress.png",
	]:
		assert_ne(croupier.portrait_texture().resource_path, path)


func test_spin_settles_only_after_the_ball_lands_in_the_decided_pocket() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var panel: RouletteTablePanel = game.panel
	game.select_stake(10)
	assert_true(game.call("request_place", "straight:17"))
	assert_true(game.call("request_place", "black"))
	var guest_chips_before := panel.guests.guests[1].bets.duplicate()
	assert_true(game.call("request_spin"))
	var pocket: int = panel._spin_result.detail.pocket
	assert_true(game.is_result_pending, "Settlement waits for the wheel")
	assert_eq(Wallet.balance, 500, "Wallet untouched while the ball travels")
	assert_true(panel.wheel.spinning)
	panel.wheel.settle()
	assert_eq(panel.wheel.ball_pocket, pocket, "The ball lands in the decided pocket")
	assert_eq(panel.board.result_pocket, pocket, "The layout marks the same pocket")
	await wait_seconds(RouletteTablePanel.REVEAL_BEAT_SECONDS + 0.2)
	assert_false(game.is_result_pending)
	var result: RoundResult = panel._result
	assert_eq(Wallet.balance, 500 - 20 + result.payout, "One settlement of the whole layout")
	assert_eq(panel.guests.guests[1].bets, guest_chips_before, "Guests' chips are their own")


func test_reduced_motion_lands_at_once_with_one_bounded_cue() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := _open()
	var game: MiniGame = session.cabinet
	var panel: RouletteTablePanel = game.panel
	assert_true(game.call("request_place", "red"))
	var angle_before := panel.wheel.rotor_angle
	assert_true(game.call("request_spin"))
	assert_true(panel._ball_landed, "The ball is already in its pocket")
	assert_false(panel.wheel.spinning)
	assert_eq(panel.wheel.rotor_angle, angle_before, "No wheel travel under reduced motion")
	assert_gt(panel.wheel._cue_left, 0.0)
	assert_lte(panel.wheel._cue_left, RouletteWheel.REDUCED_CUE_SECONDS)
	await wait_seconds(0.6)
	assert_false(game.is_round_active)
	assert_eq(panel.wheel._cue_left, 0.0, "The cue is finite")


func test_guests_bet_for_atmosphere_without_touching_the_player() -> void:
	var math := RouletteMath.new()
	var guests := RouletteTableGuests.new(math)
	for spin: int in range(40):
		guests.place_bets()
		for guest: RouletteTableGuests.Guest in guests.guests:
			assert_gt(guest.bets.size(), 0)
			for id: String in guest.bets:
				assert_true(math.has_spot(id), "%s is a real spot" % id)
			assert_false(guest.line_key.is_empty())
		guests.settle(spin % 37)
	assert_true(math.bets.is_empty(), "Guests never bet through the player's math")
	var system := guests.guests[0]
	system.unit = RouletteTableGuests.SYSTEM_BASE_UNIT
	system.backs_red = true
	guests.place_bets()
	guests.settle(2)
	assert_eq(system.unit, 10, "The system bettor doubles after a loss")
	guests.place_bets()
	guests.settle(1)
	assert_eq(system.unit, RouletteTableGuests.SYSTEM_BASE_UNIT, "and resets after a win")
	assert_true(guests.guests[1].bets.has("straight:17"), "The dreamer always backs 17")
	for number: int in RouletteTableGuests.BIRTHDAY_NUMBERS:
		assert_true(guests.guests[2].bets.has("straight:%d" % number), "Birthday %d" % number)


func test_every_dynamic_roulette_label_is_translated() -> void:
	var math := RouletteMath.new()
	for id: String in math.spots():
		var spot := math.spot(id)
		if (spot.numbers as Array).size() >= 12:
			var name_key := RouletteSpotNames.name_key(id)
			assert_ne(tr(name_key), name_key, "%s is translated" % name_key)
			if spot.kind != RouletteMath.BetKind.RED and spot.kind != RouletteMath.BetKind.BLACK:
				var face_key := RouletteSpotNames.face_key(id)
				assert_ne(tr(face_key), face_key, "%s is translated" % face_key)
	var guests := RouletteTableGuests.new(math)
	for guest: RouletteTableGuests.Guest in guests.guests:
		for key: String in [guest.name_key, guest.tag_key]:
			assert_ne(tr(key), key)


func test_back_mid_spin_asks_before_leaving() -> void:
	var game: MiniGame = _open().cabinet
	assert_true(game.call("request_place", "odd"))
	assert_true(game.call("request_spin"))
	var event := InputEventAction.new()
	event.action = "back"
	event.pressed = true
	game._unhandled_input(event)
	assert_true(game.exit_confirmation.is_open, "Live wager needs the exit confirmation")


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_controller_places_on_the_layout_and_walks_to_the_deck_and_back() -> void:
	var game: MiniGame = _open().cabinet
	var panel: RouletteTablePanel = game.panel
	await wait_process_frames(2)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.board, "The layout owns focus first")
	var start := panel.board.cursor_spot_id()
	panel.board._gui_input(_action("move_right"))
	assert_ne(panel.board.cursor_spot_id(), start, "D-pad moves the layout cursor")
	panel.board._gui_input(_action("interact"))
	var placed_on := panel.board.cursor_spot_id()
	assert_eq(game.get("math").chips_on(placed_on), game.selected_stake, "A places the chip")
	panel.board._gui_input(_action("secondary"))
	assert_eq(game.get("math").chips_on(placed_on), 0, "X takes it back")
	panel.board.set_cursor(panel.board.geometry.index_of("high"))
	panel.board._gui_input(_action("move_down"))
	var focused := get_viewport().gui_get_focus_owner()
	assert_true(panel.deck.owns_focus(focused), "Down from the outside row reaches the deck")
	assert_true(panel.navigate_from_deck(Vector2i.UP))
	assert_eq(get_viewport().gui_get_focus_owner(), panel.board, "Up returns to the layout")
