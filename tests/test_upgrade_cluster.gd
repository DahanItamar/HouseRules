extends GutTest
## Harlequin Masquerade (Upgrade Cluster): the 4-way connection rule, cluster
## detection, tumble determinism and replay, the upgrade ladder, chip
## conservation, settlement that waits for the replay, the measured RTP, and the
## presentation's TV-safe targets, protected rectangles and reduced-motion bounds.

const DEFINITION_PATH := "res://data/cabinets/upgrade_cluster.tres"
const TV_SAFE := Rect2(48, 27, 864, 486)
const MIN_TARGET: float = 44.0
const SEED := 20260918
## The sample that tunes the paytable. Big enough that the mean is meaningful and
## small enough to run inside the suite; the strict gate is AC-027's million.
const RTP_ROUNDS := 200_000
const RTP_STAKE := 10

var _starting_test_mode: bool
var _starting_balance: int


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	Wallet.reset(2000)
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


## A 7x7 board of `cells` set to `symbol`, on a background that cannot pay.
##
## The background is a checkerboard of two symbols. Under the 4-way rule every
## checkerboard cell touches only cells of the other symbol, so the whole
## background is 49 clusters of one and scores exactly nothing - which is itself
## the connection rule stated as a board. Anything these helpers score therefore
## came from `cells`.
func _grid(symbol: int, cells: Array) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(49)
	for index: int in range(49):
		grid[index] = (index / 7 + index % 7) % 2
	for cell: int in cells:
		grid[cell] = symbol
	return grid


# -- The connection rule ------------------------------------------------------


func test_diagonals_never_join_a_cluster() -> void:
	var math := UpgradeClusterMath.new()
	# A bare checkerboard pays nothing: no two same-symbol cells share an edge.
	assert_eq(math.score_grid(_grid(0, [])), 0, "Diagonal neighbours alone never pay")

	# Five cells of symbol 4 on the main diagonal. Each touches the next only at a
	# corner, so under a 4-way rule they are five separate single cells and none of
	# them pays. An 8-way rule would read this as one cluster of five.
	var diagonal := _grid(4, [0, 8, 16, 24, 32])
	for cluster: Dictionary in math.find_clusters(diagonal):
		assert_ne(int(cluster.symbol), 4, "A diagonal line is not a cluster")
	assert_eq(math.score_grid(diagonal), 0, "A diagonal line of five pays nothing")

	# The same five cells rearranged into an orthogonal L pay at once.
	var elbow := _grid(4, [0, 1, 2, 9, 16])
	var clusters := math.find_clusters(elbow).filter(
		func(entry: Dictionary) -> bool: return int(entry.symbol) == 4
	)
	assert_eq(clusters.size(), 1, "Four-way neighbours make one cluster")
	assert_eq((clusters[0].cells as PackedInt32Array).size(), 5)
	assert_eq(math.score_grid(elbow), math.paytable.pay_units(4, 5))

	# A knight's-move pair and a corner-only pair are both unconnected.
	for cells: Array in [[0, 9], [0, 8], [10, 18], [3, 11]]:
		assert_eq(math.score_grid(_grid(5, cells)), 0, "%s is not a cluster" % [cells])


func test_a_cluster_needs_the_minimum_and_grows_with_its_band() -> void:
	var math := UpgradeClusterMath.new()
	var paytable := math.paytable
	assert_eq(paytable.minimum_cluster, 5)
	# Four in a row is one short and pays nothing; the fifth turns it on.
	assert_eq(math.score_grid(_grid(6, [0, 1, 2, 3])), 0, "Four in a row does not pay")
	assert_eq(
		math.score_grid(_grid(6, [0, 1, 2, 3, 4])),
		paytable.pay_units(6, 5),
		"The fifth cell turns the row on"
	)
	# Bands are non-decreasing in size and strictly increasing across the table.
	for symbol: int in range(paytable.symbol_count()):
		var previous: int = 0
		for size: int in range(paytable.minimum_cluster, 26):
			var pay := paytable.pay_units(symbol, size)
			assert_gte(pay, previous, "symbol %d size %d never pays less" % [symbol, size])
			previous = pay
		assert_eq(paytable.pay_units(symbol, paytable.minimum_cluster - 1), 0)
	# Every high symbol out-pays every low symbol at the smallest cluster.
	var minimum := paytable.minimum_cluster
	for high: int in range(4, 8):
		for low: int in range(0, 4):
			assert_gt(
				paytable.pay_units(high, minimum),
				paytable.pay_units(low, minimum),
				"high %d beats low %d" % [high, low]
			)


func test_flood_fill_finds_every_cluster_once_and_keeps_them_separate() -> void:
	var math := UpgradeClusterMath.new()
	# Two blocks of symbol 2 in opposite corners, with a gap between them.
	var grid := _grid(2, [0, 1, 2, 7, 8, 44, 45, 46, 37, 38])
	var clusters := math.find_clusters(grid).filter(
		func(entry: Dictionary) -> bool: return int(entry.symbol) == 2
	)
	assert_eq(clusters.size(), 2, "Two separated blocks are two clusters")
	assert_eq(math.score_grid(grid), math.paytable.pay_units(2, 5) * 2, "and both of them pay")
	var seen: Dictionary = {}
	for cluster: Dictionary in math.find_clusters(grid):
		for cell: int in cluster.cells as PackedInt32Array:
			assert_false(seen.has(cell), "cell %d belongs to one cluster only" % cell)
			seen[cell] = true
	# Rows do not wrap. Cells 6 and 7 are consecutive indices, but they are the end
	# of row 0 and the start of row 1, so they are not neighbours: these two blocks
	# of five stay two clusters instead of merging into one of ten.
	var wrap := _grid(3, [2, 3, 4, 5, 6, 7, 14, 15, 16, 17])
	var wrapped := math.find_clusters(wrap).filter(
		func(entry: Dictionary) -> bool: return int(entry.symbol) == 3
	)
	assert_eq(wrapped.size(), 2, "The grid edge is a wall, not a wrap")
	for cluster: Dictionary in wrapped:
		assert_eq((cluster.cells as PackedInt32Array).size(), 5)


# -- Tumbles ------------------------------------------------------------------


func test_a_tumble_drops_survivors_and_refills_only_the_holes() -> void:
	var math := UpgradeClusterMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var grid := PackedByteArray()
	grid.resize(49)
	for index: int in range(49):
		grid[index] = index % 8
	# Clear the top two cells of column 0 and the bottom cell of column 1.
	var cleared := PackedInt32Array([0, 7, 43])
	var before := grid.duplicate()
	var after := math.tumble(grid, cleared, rng)
	assert_eq(before, grid, "tumble() never mutates the grid it was given")
	# Column 0 lost two cells from the top: the survivors keep their order and
	# stay where they were, and two new symbols arrive above them.
	for row: int in range(2, 7):
		assert_eq(after[row * 7], before[row * 7], "column 0 row %d did not move" % row)
	# Column 1 lost its bottom cell, so everything above it falls one row.
	for row: int in range(1, 7):
		assert_eq(after[row * 7 + 1], before[(row - 1) * 7 + 1], "column 1 row %d fell" % row)
	# Untouched columns are identical.
	for column: int in range(2, 7):
		for row: int in range(7):
			assert_eq(after[row * 7 + column], before[row * 7 + column])


func test_a_round_tumbles_until_no_cluster_is_left() -> void:
	var math := UpgradeClusterMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var winning: RoundResult = null
	for _attempt: int in 500:
		var result := math.play(10, rng)
		if (result.detail.cascades as Array).size() >= 2:
			winning = result
			break
	assert_not_null(winning, "A multi-tumble round exists in the first 500")
	if winning == null:
		return
	var cascades: Array = winning.detail.cascades
	for cascade: Dictionary in cascades:
		assert_gt((cascade.destroyed as PackedInt32Array).size(), 0)
		for cluster: Dictionary in cascade.clusters as Array:
			assert_gte((cluster.cells as PackedInt32Array).size(), math.paytable.minimum_cluster)
	# The board the last tumble left has no cluster on it: that is why it stopped.
	var final_grid: PackedByteArray = (cascades[-1] as Dictionary).grid_after
	assert_eq(math.find_clusters(final_grid).size(), 0, "The round ends on a dead board")
	assert_lte(cascades.size(), math.paytable.max_cascades)


func test_the_same_seed_replays_the_identical_round() -> void:
	var first := UpgradeClusterMath.new()
	var second := UpgradeClusterMath.new()
	var left := RandomNumberGenerator.new()
	var right := RandomNumberGenerator.new()
	left.seed = SEED
	right.seed = SEED
	for _round: int in 40:
		var a := first.play(25, left)
		var b := second.play(25, right)
		assert_eq(a.payout, b.payout)
		assert_eq(a.detail.grid, b.detail.grid)
		assert_eq(a.detail.charge, b.detail.charge)
		assert_eq(a.detail.total_units, b.detail.total_units)
		var left_cascades: Array = a.detail.cascades
		var right_cascades: Array = b.detail.cascades
		assert_eq(left_cascades.size(), right_cascades.size())
		for index: int in range(left_cascades.size()):
			var one: Dictionary = left_cascades[index]
			var two: Dictionary = right_cascades[index]
			assert_eq(one.destroyed, two.destroyed)
			assert_eq(one.grid_after, two.grid_after)
			assert_eq(one.multiplier, two.multiplier)
			assert_eq(one.win_units, two.win_units)
	# A different seed gives a different round, so the replay is not a constant.
	var other := RandomNumberGenerator.new()
	other.seed = SEED + 1
	assert_ne(
		UpgradeClusterMath.new().play(25, other).detail.grid, first.play(25, left).detail.grid
	)


# -- The upgrade bar ----------------------------------------------------------


func test_the_ladder_steps_only_at_its_thresholds() -> void:
	var paytable: UpgradeClusterPaytable = load("res://data/paytables/upgrade_cluster.tres")
	assert_eq(paytable.charge_thresholds.size(), paytable.multipliers.size())
	assert_eq(paytable.multiplier_for(0), paytable.base_multiplier)
	var previous := paytable.base_multiplier
	for index: int in range(paytable.charge_thresholds.size()):
		var threshold := paytable.charge_thresholds[index]
		assert_gt(threshold, 0)
		if index > 0:
			assert_gt(threshold, paytable.charge_thresholds[index - 1], "thresholds ascend")
		assert_eq(paytable.multiplier_for(threshold - 1), previous, "rung %d is not early" % index)
		assert_eq(paytable.multiplier_for(threshold), paytable.multipliers[index])
		previous = paytable.multipliers[index]
		assert_gt(previous, paytable.base_multiplier)
	var top := paytable.multipliers[-1]
	assert_eq(paytable.multiplier_for(paytable.charge_thresholds[-1] + 10_000), top, "capped")
	assert_eq(top, 256, "The ladder reaches 256x")


func test_the_bar_charges_on_destroyed_symbols_and_prices_each_cascade() -> void:
	var math := UpgradeClusterMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var checked: int = 0
	for _round: int in 400:
		var result := math.play(10, rng)
		var charge: int = 0
		var total: int = 0
		for cascade: Dictionary in result.detail.cascades as Array:
			charge += (cascade.destroyed as PackedInt32Array).size()
			assert_eq(int(cascade.charge), charge, "charge counts every destroyed symbol")
			assert_eq(
				int(cascade.multiplier),
				math.paytable.multiplier_for(charge),
				"the cascade uses the rung its own charge has reached"
			)
			var base: int = 0
			for cluster: Dictionary in cascade.clusters as Array:
				base += math.paytable.pay_units(
					int(cluster.symbol), (cluster.cells as PackedInt32Array).size()
				)
			assert_eq(int(cascade.base_units), base)
			assert_eq(int(cascade.win_units), base * int(cascade.multiplier))
			total += int(cascade.win_units)
		assert_eq(int(result.detail.raw_units), total, "the round is the sum of its cascades")
		assert_eq(int(result.detail.charge), charge)
		if charge > 0:
			checked += 1
	assert_gt(checked, 0, "Some rounds charged the bar")


# -- Money --------------------------------------------------------------------


func test_settlement_is_one_rounding_of_the_whole_round() -> void:
	assert_eq(UpgradeClusterMath.settle(0, 10), 0)
	assert_eq(UpgradeClusterMath.settle(1000, 10), 10, "1.000 x 10 is 10 chips")
	assert_eq(UpgradeClusterMath.settle(320, 10), 3, "0.320 x 10 rounds to 3")
	assert_eq(UpgradeClusterMath.settle(350, 10), 4, "a half rounds up, not down")
	assert_eq(UpgradeClusterMath.settle(2514, 100), 251)
	assert_eq(UpgradeClusterMath.settle(500, 0), 0, "no stake, no payout")
	# Whatever the cascades did, the payout is settle(total, stake) exactly once.
	var math := UpgradeClusterMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for stake: int in [1, 5, 10, 25, 100]:
		for _round: int in 120:
			var result := math.play(stake, rng)
			assert_eq(
				result.payout,
				UpgradeClusterMath.settle(int(result.detail.total_units), stake),
				"payout is one conversion of the round total"
			)
			assert_eq(result.stake, stake)
			assert_gte(result.payout, 0)
			assert_lte(
				result.payout, math.paytable.max_win_multiple * stake + 1, "the ceiling holds"
			)


func test_chips_are_conserved_through_the_wallet() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var math: UpgradeClusterMath = game.get("math")
	var opening := Wallet.balance
	var wagered: int = 0
	var returned: int = 0
	for _round: int in 30:
		game.select_stake(5)
		var before := Wallet.balance
		var result := math.play(5, game.context.rng)
		assert_true(session.apply_result(result), "the round settles once")
		wagered += result.stake
		returned += result.payout
		assert_eq(Wallet.balance, before - result.stake + result.payout, "one net movement")
		assert_eq(Wallet.balance, int(Wallet.balance), "chips stay whole")
		# Replaying the same result must never pay twice.
		assert_false(session.apply_result(result), "a result settles exactly once")
	assert_eq(Wallet.balance, opening - wagered + returned, "no chips appear or vanish")


func test_the_wallet_waits_for_the_replay() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var panel: UpgradeClusterPanel = game.panel
	game.select_stake(5)
	var before := Wallet.balance
	var settled: Array[RoundResult] = []
	game.round_resolved.connect(func(result: RoundResult) -> void: settled.append(result))
	assert_true(game.call("request_play"))
	# The round is decided immediately, and the screen has the whole script...
	assert_true(game.is_round_active)
	assert_true(game.is_result_pending, "settlement is gated on the replay")
	assert_not_null(panel._round)
	assert_eq((panel._round.detail.grid as PackedByteArray).size(), 49)
	# ...but nothing has reached the wallet yet.
	assert_eq(Wallet.balance, before, "the wallet is untouched while the board tumbles")
	assert_true(settled.is_empty())
	# A second press during the replay cannot start another round.
	assert_false(game.call("request_play"), "one round at a time")
	game.complete_pending_result()
	assert_eq(settled.size(), 1, "exactly one result")
	assert_false(game.is_round_active)


func test_the_cabinet_is_registered_and_declared() -> void:
	assert_true(CabinetSceneRegistry.has_scene(&"upgrade_cluster"))
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	assert_true(definition.is_valid_definition())
	assert_eq(definition.id, &"upgrade_cluster")
	assert_eq(definition.name_key, "CABINET_UPGRADE_CLUSTER_NAME")
	assert_almost_eq(definition.target_rtp, 0.966, 0.0001)
	assert_ne(tr("CABINET_UPGRADE_CLUSTER_NAME"), "CABINET_UPGRADE_CLUSTER_NAME")
	# Every scene path in the registry is unique, so no cabinet can shadow another.
	var paths: Dictionary = {}
	for id: StringName in CabinetSceneRegistry.SCENE_PATHS:
		var path: String = CabinetSceneRegistry.SCENE_PATHS[id]
		assert_false(paths.has(path), "%s is registered once" % path)
		paths[path] = true


# -- Return -------------------------------------------------------------------


func test_measured_return_matches_the_declared_rtp() -> void:
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	var math := UpgradeClusterMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var returned: int = 0
	var wins: int = 0
	var reached: Dictionary = {}
	for _round: int in RTP_ROUNDS:
		var result := math.play(RTP_STAKE, rng)
		returned += result.payout
		if result.payout > 0:
			wins += 1
		reached[int(result.detail.multiplier)] = true
	var observed := float(returned) / float(RTP_ROUNDS * RTP_STAKE)
	gut.p(
		(
			"upgrade_cluster %d rounds: RTP %.5f, hit rate %.4f"
			% [RTP_ROUNDS, observed, float(wins) / float(RTP_ROUNDS)]
		)
	)
	# The tail is heavy, so this in-suite sample gets the sampling tolerance its
	# size earns. tests/test_rtp_harness.gd runs the strict million-round gate.
	assert_almost_eq(observed, definition.target_rtp, 0.02, "measured return")
	assert_between(float(wins) / float(RTP_ROUNDS), 0.25, 0.45, "roughly one board in three pays")
	assert_true(reached.has(16), "the 16x rung is reachable in normal play")


# -- Presentation -------------------------------------------------------------


func test_controls_are_large_enough_and_inside_tv_safe() -> void:
	var panel: UpgradeClusterPanel = _open().cabinet.panel
	# Deck keys slide up into place when they appear. Reduced motion puts them at
	# their resting target immediately, which is the geometry under test.
	MotionPolicy.set_reduced_motion_for_tests(true)
	panel.refresh()
	var controls: Array[Control] = [panel._help_button, panel.deck.primary_button()]
	controls.append(panel.deck.bet.step_down_button())
	controls.append(panel.deck.bet.step_up_button())
	for key: Button in panel.deck.quick_bets.keys():
		controls.append(key)
	for control: Control in controls:
		assert_not_null(control, "control exists")
		if control == null:
			continue
		var rect := Rect2(control.global_position, control.size)
		assert_gte(rect.size.x, MIN_TARGET, "%s width" % control.name)
		assert_gte(rect.size.y, MIN_TARGET, "%s height" % control.name)
		assert_true(TV_SAFE.encloses(rect), "%s %s is inside TV-safe" % [control.name, rect])
	for rect: Rect2 in ClusterTheme.PROTECTED_RECTS:
		assert_true(TV_SAFE.encloses(rect), "%s is inside TV-safe" % rect)
	assert_true(TV_SAFE.encloses(CabinetDeck.DECK_RECT))
	assert_true(TV_SAFE.encloses(ClusterTheme.HOSTESS_RECT))


func test_nothing_stands_on_the_readouts_the_board_or_the_deck() -> void:
	var panel: UpgradeClusterPanel = _open().cabinet.panel
	var protected: Array[Rect2] = ClusterTheme.PROTECTED_RECTS.duplicate()
	protected.append(CabinetDeck.DECK_RECT)
	# The board and the readouts never overlap each other or the deck.
	for index: int in range(protected.size()):
		for other: int in range(index + 1, protected.size()):
			assert_false(
				protected[index].intersects(protected[other]),
				"%s and %s are separate" % [protected[index], protected[other]]
			)
	# The host and both sidekicks stand clear of every one of them.
	for occupied: Rect2 in panel.company.occupied_rects():
		for rect: Rect2 in protected:
			assert_false(occupied.intersects(rect), "%s covers %s" % [occupied, rect])
	# The painted frame surrounds the board without covering a cell.
	assert_true(ClusterTheme.FRAME_RECT.encloses(ClusterTheme.GRID_RECT))
	# The floating arithmetic stays on the board wherever its cluster sits.
	for cell: int in range(49):
		var centre := ClusterTheme.cell_center(cell % 7, cell / 7)
		var anchor := panel.popup.anchor_for(centre)
		var popup := Rect2(anchor, panel.popup.size)
		assert_true(
			ClusterTheme.GRID_RECT.encloses(popup), "popup at cell %d leaves the board" % cell
		)
		for rect: Rect2 in [
			ClusterTheme.BAR_RECT, ClusterTheme.READOUT_RECT, CabinetDeck.DECK_RECT
		]:
			assert_false(popup.intersects(rect), "popup at cell %d covers %s" % [cell, rect])


func test_the_board_matches_the_domain_and_every_symbol_has_its_own_art() -> void:
	var panel: UpgradeClusterPanel = _open().cabinet.panel
	var math: UpgradeClusterMath = panel.cabinet.get("math")
	assert_eq(panel.grid.tiles.size(), math.cell_count(), "one tile per cell")
	assert_eq(ClusterTheme.symbol_count(), math.paytable.symbol_count())
	assert_eq(ClusterTheme.TILES.size(), math.paytable.symbol_count())
	var seen: Dictionary = {}
	for index: int in range(ClusterTheme.symbol_count()):
		var texture := ClusterTheme.symbol_texture(index)
		assert_not_null(texture, "symbol %d has art" % index)
		assert_false(seen.has(texture.resource_path), "symbol %d has its own art" % index)
		seen[texture.resource_path] = true
		assert_ne(
			ClusterTheme.symbol_name(index),
			String(ClusterTheme.symbol(index).key),
			"symbol %d is named in the catalog" % index
		)
	# The cells tile the board exactly, with no gap and no overlap in the pitch.
	for cell: int in range(math.cell_count()):
		var top_left := ClusterTheme.cell_position(cell % 7, cell / 7)
		var tile := Rect2(top_left, Vector2.ONE * ClusterTheme.TILE_SIZE)
		assert_true(ClusterTheme.GRID_RECT.encloses(tile), "cell %d sits on the board" % cell)


func test_a_replayed_board_shows_the_grid_the_maths_drew() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var panel: UpgradeClusterPanel = game.panel
	game.select_stake(5)
	assert_true(game.call("request_play"))
	var opening: PackedByteArray = panel._round.detail.grid
	for index: int in range(opening.size()):
		assert_eq(
			panel.grid.tiles[index].symbol,
			int(opening[index]),
			"tile %d shows the symbol the round drew" % index
		)
	game.complete_pending_result()


func test_reduced_motion_bounds_every_phase() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	# Every phase is capped, and the cap is shorter than the full-motion beat.
	for full: float in [
		ClusterTheme.PULSE_SECONDS,
		ClusterTheme.MATH_POP_SECONDS,
		ClusterTheme.MATH_HOLD_SECONDS,
		ClusterTheme.MATH_RISE_SECONDS,
		ClusterTheme.SHATTER_SECONDS,
		ClusterTheme.TUMBLE_SECONDS,
		ClusterTheme.SETTLE_SECONDS,
		ClusterTheme.CELEBRATION_HOLD_SECONDS,
	]:
		var bounded := ClusterTheme.phase(full)
		assert_lte(bounded, ClusterTheme.REDUCED_PHASE, "phase %.2f is bounded" % full)
		assert_gt(bounded, 0.0, "a bounded phase still happens")
	MotionPolicy.clear_test_override()
	for full: float in [ClusterTheme.PULSE_SECONDS, ClusterTheme.TUMBLE_SECONDS]:
		assert_eq(ClusterTheme.phase(full), full, "full motion is unchanged")


func test_reduced_motion_leaves_no_tile_or_shard_moving() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var session := _open()
	var game: MiniGame = session.cabinet
	var panel: UpgradeClusterPanel = game.panel
	game.select_stake(5)
	assert_true(game.call("request_play"))
	var cascades: Array = panel._round.detail.cascades
	if not cascades.is_empty():
		var cells: PackedInt32Array = (cascades[0] as Dictionary).destroyed
		panel.grid.pulse(cells)
		panel.grid.shatter(cells)
		# No shard particles are spawned at all under reduced motion.
		assert_false(panel.grid.has_active_motion(), "shatter scatters nothing")
		panel.grid.tumble_to((cascades[0] as Dictionary).grid_after, cells)
		for tile: ClusterTile in panel.grid.tiles:
			assert_eq(tile.position, tile.rest_position, "%s lands, never travels" % tile.name)
	# The celebration shows its final state instead of rising and counting.
	panel.celebration.play(1000, 10)
	assert_eq(panel.celebration.shown_payout, 1000, "the payout is shown, not ticked")
	assert_eq(panel.celebration.tier, "mega")
	panel.celebration.settle()
	assert_false(panel.celebration.is_running())
	game.complete_pending_result()
	MotionPolicy.clear_test_override()


func test_the_celebration_tiers_follow_the_round_win() -> void:
	assert_eq(ClusterTheme.celebration_tier(14.9), "", "below 15x there is no celebration")
	assert_eq(ClusterTheme.celebration_tier(15.0), "big")
	assert_eq(ClusterTheme.celebration_tier(49.9), "big")
	assert_eq(ClusterTheme.celebration_tier(50.0), "super")
	assert_eq(ClusterTheme.celebration_tier(99.9), "super")
	assert_eq(ClusterTheme.celebration_tier(100.0), "mega")
	assert_eq(ClusterTheme.celebration_tier(5000.0), "mega")
	assert_false(ClusterCelebration.earns_celebration(149, 10))
	assert_true(ClusterCelebration.earns_celebration(150, 10))
	for tier: String in ["big", "super", "mega"]:
		var key := ClusterTheme.tier_key(tier)
		assert_false(key.is_empty(), "%s has a banner key" % tier)
		assert_ne(tr(key), key, "%s banner is translated" % tier)


func test_the_arithmetic_popup_prints_what_the_round_worked_out() -> void:
	var popup := ClusterMathPopup.new()
	autofree(popup)
	popup.base_units = 320
	popup.multiplier = 256
	assert_eq(popup.win_text(), "0.32  x256", "the machine shows its own working")
	popup.multiplier = 1
	assert_eq(popup.win_text(), "0.32", "no upgrade, no multiplier on the label")
	assert_eq(ClusterTheme.bet_text(0), "0.00")
	assert_eq(ClusterTheme.bet_text(1257), "1.26")
	assert_eq(ClusterTheme.bet_text(12568), "12.57")
