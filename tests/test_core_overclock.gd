extends GutTest
## Corsair's Reach (cabinet id core_overclock): the crash distribution and its
## exact 97% return at every auto-haul target, the 3% instant crash, exact auto
## cash-out, one settlement after the replay, replay determinism, chip
## conservation, wallet guards, the state machine, the unique host, 44 px targets
## inside TV-safe, the protected rectangles and reduced motion bounding every
## effect.

const DEFINITION_PATH := "res://data/cabinets/core_overclock.tres"
const TV_SAFE := Rect2(48, 27, 864, 486)
const MIN_TARGET: float = 44.0
const OTHER_HOSTS: Array[String] = [
	"res://assets/production/characters/hosts/slot_elf_princess.png",
	"res://assets/production/characters/hosts/blackjack_dealer_v2.png",
	"res://assets/production/characters/hosts/vault_witcher_sorceress.png",
	"res://assets/production/characters/hosts/roulette_croupier.png",
	"res://assets/production/characters/hosts/poker_dealer.png",
	"res://assets/production/characters/hosts/match_point_hostess.png",
	"res://assets/production/characters/hosts/tidewater_hostess.png",
]
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


func _action(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## Steps the cabinet's own clock, the way _process does in the tree.
func _step(game: MiniGame, seconds: float, slices: int = 1) -> void:
	for _index: int in range(slices):
		game._process(seconds / float(slices))


# ---------------------------------------------------------------- distribution


func test_the_crash_curve_is_the_documented_survival_function() -> void:
	var math := CoreOverclockMath.new()
	var rules := math.paytable
	var total := rules.curve_denominator
	# P(crash >= m) = 0.97 / m, exactly on the lattice where it can be exact.
	assert_eq(math.winning_count(100), 970_000_000, "1.00x is reached 97% of the time")
	assert_almost_eq(math.reach_probability(100), 0.97, 1e-12)
	assert_eq(math.winning_count(200), 485_000_000, "2.00x is reached 48.5% of the time")
	assert_eq(math.winning_count(1000), 97_000_000, "10.00x is reached 9.7% of the time")
	# The crash point falls as the uniform rises, so "this run reaches m" is
	# exactly "this uniform is one of the winning_count(m) smallest".
	for centi: int in [100, 101, 137, 200, 333, 1000, 12345]:
		var cut := math.winning_count(centi)
		for probe: int in [1, 2, 7, 999, cut - 1, cut, cut + 1, total]:
			assert_eq(
				math.crash_for(probe) >= centi,
				probe <= cut,
				"Uniform %d against a %d target" % [probe, centi]
			)
	assert_eq(math.crash_for(1), rules.cap_centi, "The smallest uniform is capped")
	assert_eq(math.crash_for(total), 97, "The largest uniform crashes before 1.00x")


func test_every_timer_setting_returns_the_same_97_percent() -> void:
	var math := CoreOverclockMath.new()
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	assert_eq(definition.target_rtp, 0.97)
	var worst: float = 1.0
	for centi: int in range(100, 2001):
		var expected := math.expected_return(centi)
		# Never above the declared return, and short of it by less than one
		# lattice step: centi / (100 * curve_denominator).
		assert_lte(expected, 0.97, "%d returns at most 97%%" % centi)
		var floor_value := 0.97 - float(centi) / (100.0 * float(math.paytable.curve_denominator))
		assert_gt(expected, floor_value, "%d returns within one lattice step" % centi)
		worst = minf(worst, expected)
	assert_almost_eq(worst, 0.97, 0.000001, "The whole 1.00x-20.00x band is 97%")
	for centi: int in [100, 200, 500, 1000, 100_000, 1_000_000]:
		assert_almost_eq(math.expected_return(centi), 0.97, 0.00002, "%d" % centi)


func test_the_instant_crash_is_exactly_three_percent() -> void:
	var math := CoreOverclockMath.new()
	assert_almost_eq(math.bust_probability(), 0.03, 1e-12, "Exactly 3% of runs never open a window")
	assert_eq(
		math.paytable.curve_denominator - math.winning_count(100),
		30_000_000,
		"30 million of the 1000 million uniforms crash, with no rounding"
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260920
	var busts: int = 0
	var rounds: int = 40000
	for _index: int in range(rounds):
		math.reset()
		math.begin(100, rng)
		math.advance(1000.0)
		if math.is_bust(math.crash_centi):
			busts += 1
	assert_almost_eq(float(busts) / float(rounds), 0.03, 0.004, "Sampled crash rate")


func test_legal_stakes_always_settle_to_whole_chips() -> void:
	var math := CoreOverclockMath.new()
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	assert_eq(definition.min_bet % math.paytable.stake_unit, 0)
	assert_eq(definition.max_bet % math.paytable.stake_unit, 0)
	assert_eq(
		math.paytable.stake_unit,
		math.paytable.multiplier_scale,
		"A stake unit of one whole multiplier step is what makes payouts exact"
	)
	for stake: int in [100, 200, 500, 1000]:
		assert_true(math.is_legal_stake(stake))
		for centi: int in [100, 101, 137, 250, 999, 1_000_000]:
			assert_eq(stake * centi % 100, 0, "%d at %d is a whole payout" % [stake, centi])
			assert_eq(math.payout_for(stake, centi), stake / 100 * centi)
	assert_false(math.is_legal_stake(150))
	assert_false(math.is_legal_stake(0))


# --------------------------------------------------------------- state machine


func test_the_state_machine_walks_idle_countdown_climbing_and_settles() -> void:
	var math := CoreOverclockMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	assert_eq(math.state, CoreOverclockMath.State.IDLE)
	assert_false(math.can_cash_out())
	math.begin(100, rng)
	assert_eq(math.state, CoreOverclockMath.State.COUNTDOWN)
	assert_true(math.is_running())
	assert_false(math.can_cash_out(), "No window while she is making sail")
	assert_null(math.cash_out(), "Cashing out before the window is refused")
	assert_null(math.advance(math.paytable.countdown_seconds * 0.5))
	assert_eq(math.state, CoreOverclockMath.State.COUNTDOWN)
	assert_null(math.advance(math.paytable.countdown_seconds * 0.5 + 0.001))
	assert_eq(math.state, CoreOverclockMath.State.OVERCLOCKING, "The window opens")
	assert_true(math.can_cash_out())
	assert_eq(math.multiplier_centi, 100, "The climb starts at 1.00x")
	var result := math.cash_out()
	assert_not_null(result)
	assert_eq(math.state, CoreOverclockMath.State.CASHED_OUT)
	assert_false(math.is_running())
	assert_null(math.cash_out(), "One haul per run")
	assert_null(math.advance(1.0), "A settled run does not keep climbing")


func test_an_instant_crash_ends_on_the_frame_the_window_would_open() -> void:
	var math := CoreOverclockMath.new()
	# The largest uniforms crash below 1.00x; seed the draw by hand.
	math.begin_from(100, math.paytable.curve_denominator)
	assert_true(math.is_bust(math.crash_centi))
	var result := math.advance(math.paytable.countdown_seconds + 0.001)
	assert_not_null(result, "The crash settles on that same step")
	assert_eq(math.state, CoreOverclockMath.State.CRASHED)
	assert_eq(result.payout, 0)
	assert_eq(result.outcome, RoundResult.Outcome.LOSS)
	assert_true(result.detail.bust)
	assert_null(math.cash_out(), "There was never a window to cash out in")


func test_the_curve_is_the_replay_and_never_rolls_again() -> void:
	var math := CoreOverclockMath.new()
	assert_eq(math.curve_centi(0.0), 100)
	# Read from the paytable rather than pinned to a number: the climb rate is a
	# pacing decision that has been changed before and will be again, and this
	# test is about the curve being the inverse of itself, not about its speed.
	assert_almost_eq(math.seconds_for(200), log(2.0) / math.paytable.growth_per_second, 0.0001)
	for centi: int in [150, 200, 500, 1000, 10000]:
		var seconds := math.seconds_for(centi)
		# A slower climb spends longer inside each hundredth, so the reading at
		# the exact second can land on the step below; a hair later never does.
		assert_almost_eq(
			math.curve_centi(seconds + 0.0005), centi, 1, "%d is reached at its own second" % centi
		)
		assert_lt(math.curve_centi(seconds - 0.01), centi, "and not before")
	assert_eq(math.curve_centi(120.0), math.paytable.cap_centi, "The climb is capped")


func test_one_run_uses_exactly_one_uniform_from_the_cabinet_stream() -> void:
	var math := CoreOverclockMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260920
	var expected := RandomNumberGenerator.new()
	expected.seed = 20260920
	for _index: int in range(300):
		math.reset()
		math.begin(100, rng)
		math.advance(1000.0)
		var value := expected.randi_range(1, math.paytable.curve_denominator)
		assert_eq(math.value, value, "One uniform per run")
		assert_eq(math.crash_centi, math.crash_for(value))
	assert_eq(rng.state, expected.state, "No hidden extra draws")


func test_the_same_seed_replays_the_same_runs() -> void:
	var first := _replay(4242)
	var second := _replay(4242)
	var other := _replay(4243)
	assert_eq(first, second, "A seed reproduces the whole session")
	assert_ne(first, other, "A different seed does not")


func _replay(seed_value: int) -> Array:
	var math := CoreOverclockMath.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rounds: Array = []
	for index: int in range(40):
		math.reset()
		math.set_auto_target([0, 150, 200, 500][index % 4])
		math.begin(100, rng)
		var result: RoundResult = null
		while result == null:
			result = math.advance(0.25)
		rounds.append([math.crash_centi, result.payout, math.settled_centi])
	return rounds


# --------------------------------------------------------------- auto cash-out


func test_the_auto_haul_settles_at_exactly_its_setting_whatever_the_frame_rate() -> void:
	var math := CoreOverclockMath.new()
	for target: int in [120, 150, 200, 300, 500, 1000]:
		for slice: float in [1.0 / 120.0, 1.0 / 30.0, 0.5, 4.0, 1000.0]:
			math.reset()
			assert_true(math.set_auto_target(target) or math.auto_centi == target)
			math.begin_from(100, 1)
			assert_gte(math.crash_centi, target, "This run reaches the target")
			var result: RoundResult = null
			var guard: int = 0
			while result == null and guard < 100000:
				result = math.advance(slice)
				guard += 1
			assert_not_null(result)
			assert_eq(
				math.settled_centi,
				target,
				"Target %d at a %.4f s step settles exactly there" % [target, slice]
			)
			assert_eq(result.payout, target, "100 staked at %d" % target)
			assert_eq(result.outcome, RoundResult.Outcome.CASHED_OUT)


func test_a_target_past_the_crash_point_still_loses() -> void:
	var math := CoreOverclockMath.new()
	math.set_auto_target(1000)
	# This uniform crashes at 2.42x, well under the 10.00x target.
	math.begin_from(100, 200_000_000)
	assert_eq(math.crash_centi, 485, "This uniform crashes at 4.85x")
	var result := math.advance(1000.0)
	assert_not_null(result)
	assert_eq(result.payout, 0)
	assert_eq(math.state, CoreOverclockMath.State.CRASHED)
	assert_eq(math.multiplier_centi, math.crash_centi, "It stops at the crash point")


func test_a_target_on_the_crash_point_hauls_in_and_never_races_it() -> void:
	var math := CoreOverclockMath.new()
	var exact := math.crash_for(12345)
	assert_true(math.set_auto_target(exact))
	math.begin_from(100, 12345)
	assert_eq(math.crash_centi, exact)
	var result := math.advance(1000.0)
	assert_eq(result.outcome, RoundResult.Outcome.CASHED_OUT, "Reaching the setting hauls it in")
	assert_eq(math.settled_centi, exact)


func test_the_auto_haul_target_is_locked_while_a_run_is_out() -> void:
	var math := CoreOverclockMath.new()
	math.begin_from(100, 1)
	assert_false(math.set_auto_target(500), "Not while a run is climbing")
	math.advance(1000.0)
	assert_true(math.set_auto_target(500), "Between runs it changes")
	assert_false(math.is_legal_target(99))
	assert_true(math.is_legal_target(0))


# ------------------------------------------------------------------- cabinet


func test_the_wallet_settles_once_after_the_replay() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var math: CoreOverclockMath = game.get("math")
	game.select_stake(100)
	assert_true(game.call("cycle_auto_target"), "Step the auto-haul target on")
	while math.auto_centi != 200:
		game.call("cycle_auto_target")
	assert_true(game.call("request_launch"))
	assert_true(game.is_round_active)
	assert_eq(Wallet.balance, 2000, "The wallet is untouched while she climbs")
	assert_eq(math.state, CoreOverclockMath.State.COUNTDOWN)
	_step(game, math.paytable.countdown_seconds + 0.001)
	assert_eq(math.state, CoreOverclockMath.State.OVERCLOCKING)
	assert_eq(Wallet.balance, 2000, "Still untouched mid-run")
	assert_false(game.call("request_launch"), "One run at a time")
	var guard: int = 0
	while game.is_round_active and guard < 4000:
		_step(game, 1.0 / 60.0)
		guard += 1
	assert_false(game.is_round_active, "The run ends")
	var banked := math.state == CoreOverclockMath.State.CASHED_OUT
	var expected := 2000 - 100 + (200 if banked else 0)
	assert_eq(Wallet.balance, expected, "One settlement, once")
	assert_eq(math.history.size(), 1, "The crash point is on the strip")


func test_hauling_in_by_hand_pays_the_multiplier_on_the_readout() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var math: CoreOverclockMath = game.get("math")
	game.select_stake(100)
	assert_true(game.call("request_launch"))
	_step(game, math.paytable.countdown_seconds + 0.5, 40)
	if not game.is_round_active:
		pass_test("This seeded run crashed before the first half second")
		return
	var shown := math.multiplier_centi
	assert_true(game.call("request_pull"))
	assert_false(game.is_round_active)
	assert_eq(math.settled_centi, shown, "It pays what the readout showed")
	assert_eq(Wallet.balance, 2000 - 100 + shown, "100 staked pays the multiplier")


func test_leaving_mid_run_forfeits_and_cannot_dodge_a_loss() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var math: CoreOverclockMath = game.get("math")
	game.select_stake(100)
	assert_true(game.call("request_launch"))
	game._unhandled_input(_action("back"))
	assert_true(game.exit_confirmation.is_open, "A live stake needs the confirmation")
	session.close()
	assert_false(game.is_round_active)
	assert_eq(Wallet.balance, 1900, "The stake is forfeit")
	assert_eq(math.history.size(), 1, "The run is still recorded")


func test_wallet_guards_refuse_a_run_the_bankroll_cannot_cover() -> void:
	Wallet.reset(50)
	var game: MiniGame = _open().cabinet
	assert_eq(game.selected_stake, 0, "No stake below the 100-credit minimum")
	assert_false(game.call("can_launch"))
	assert_false(game.call("request_launch"))
	assert_false(game.is_round_active)
	assert_true((game.panel as CoreOverclockPanel).primary_button.disabled)
	Wallet.reset(300)
	var richer: MiniGame = _open().cabinet
	assert_eq(richer.available_stakes(), [100, 200] as Array[int], "Keys above the bank lock")
	assert_false(richer.select_stake(1000))


func test_the_guide_waits_until_the_run_is_over() -> void:
	var game: MiniGame = _open().cabinet
	var panel: CoreOverclockPanel = game.panel
	game._unhandled_input(_action("help"))
	assert_true(panel.help_open, "Between runs the guide opens")
	panel.set_help_open(false)
	game.select_stake(100)
	assert_true(game.call("request_launch"))
	game._unhandled_input(_action("help"))
	assert_false(panel.help_open, "A run is not paused to read the guide")


func test_the_controller_launches_hauls_and_walks_the_deck() -> void:
	var game: MiniGame = _open().cabinet
	var panel: CoreOverclockPanel = game.panel
	await wait_process_frames(2)
	assert_eq(get_viewport().gui_get_focus_owner(), panel.primary_button, "Cast off has focus")
	var math: CoreOverclockMath = game.get("math")
	game._unhandled_input(_action("secondary"))
	assert_ne(math.auto_centi, 0, "X steps the auto-haul target")
	game._unhandled_input(_action("move_left"))
	assert_eq(get_viewport().gui_get_focus_owner(), panel.auto_button, "Left reaches the target")
	game._unhandled_input(_action("move_right"))
	assert_eq(get_viewport().gui_get_focus_owner(), panel._help_button, "The header reads on")
	game._unhandled_input(_action("move_down"))
	assert_eq(get_viewport().gui_get_focus_owner(), panel.primary_button, "Down returns")
	game._unhandled_input(_action("interact"))
	assert_true(game.is_round_active, "A casts off")
	game._unhandled_input(_action("secondary"))
	assert_false(game.call("cycle_auto_target"), "The target is locked while she climbs")


# -------------------------------------------------------------- presentation


func test_the_hosts_are_one_pair_who_share_every_reaction() -> void:
	# The two of the crew are generated as ONE frame per state, so there is no way
	# for one of them to celebrate while the other winces.
	var panel: CoreOverclockPanel = _open().cabinet.panel
	var hosts := panel.hosts
	assert_eq(
		hosts.state_ids(),
		[&"ready", &"tense", &"cheer", &"wince"] as Array[StringName],
		"One frame per feeling the run can be in"
	)
	for id: StringName in hosts.state_ids():
		var texture := hosts.state_texture(id)
		var path := texture.resource_path
		assert_true(path.begins_with("res://assets/production/corsair/corsair_crew_"), path)
		assert_false(OTHER_HOSTS.has(path), "%s is not another game's person" % path)
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		assert_eq(image.get_size(), Vector2i(1920, 1080), path)
		var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner %s is clear" % [path, corner])
		assert_lt(_grey_rim_fraction(image), 0.08, "%s has no grey matte rim" % path)


## Share of soft-edge texels that are still the grey render backdrop.
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
			if spread < 0.03 and pixel.r > 0.42 and pixel.r < 0.62:
				grey += 1
	return float(grey) / float(maxi(rim, 1))


func test_the_painted_art_is_sharp_enough_and_really_transparent() -> void:
	var painted: Array[Texture2D] = [
		CoreOverclockTheme.GAUGE,
		CoreOverclockTheme.ICONS,
		CoreOverclockTheme.EMBERS,
		CoreOverclockTheme.PARROT_FLIGHT,
		CoreOverclockTheme.TRAIL,
		CoreOverclockTheme.WRECK,
		CoreOverclockTheme.CREST,
		CoreOverclockTheme.PARROT,
	]
	for texture: Texture2D in painted:
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		assert_gte(image.get_width(), 512, texture.resource_path)
		var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner" % texture.resource_path)
	var backdrop := CoreOverclockTheme.BACKDROP.get_image()
	assert_eq(backdrop.get_size(), Vector2i(3840, 2160), "The backdrop is a 4K master")


func test_nothing_covers_the_dial_the_strip_or_the_deck() -> void:
	var panel: CoreOverclockPanel = _open().cabinet.panel
	var dial := panel.gauge.dial_rect()
	for rect: Rect2 in [
		CoreOverclockTheme.HISTORY_RECT,
		CoreOverclockTheme.AUTO_RECT,
		CabinetDeck.DECK_RECT,
		CoreOverclockTheme.TITLE_RECT,
		panel._help_button.get_global_rect(),
	]:
		assert_false(dial.intersects(rect), "The dial keeps clear of %s" % rect)
	assert_true(TV_SAFE.encloses(dial), "The dial is inside TV-safe")
	# The pair stand either side of the chart; the centre of every frame is clear,
	# so the number and the climb are never behind one of them.
	for id: StringName in panel.hosts.state_ids():
		var image := panel.hosts.state_texture(id).get_image()
		if image.is_compressed():
			image.decompress()
		var middle := image.get_width() / 2
		for row: int in range(0, image.get_height(), 64):
			assert_eq(image.get_pixel(middle, row).a, 0.0, "%s leaves the centre line clear" % id)


func test_controls_are_large_enough_and_inside_tv_safe() -> void:
	var panel: CoreOverclockPanel = _open().cabinet.panel
	# The deck slides a newly shown key up into place; measure where it lands.
	await wait_seconds(CabinetDeck.SLIDE_SECONDS + 0.1)
	var controls: Array[Control] = [
		panel._help_button,
		panel.primary_button,
		panel.auto_button,
		panel.deck.bet.step_down_button(),
		panel.deck.bet.step_up_button(),
	]
	for control: Control in controls:
		var rect := control.get_global_rect()
		assert_gte(rect.size.x, MIN_TARGET, "%s width" % control.name)
		assert_gte(rect.size.y, MIN_TARGET, "%s height" % control.name)
		assert_true(TV_SAFE.encloses(rect), "%s %s is inside TV-safe" % [control.name, rect])
		assert_false(rect.intersects(panel.gauge.dial_rect()), "%s is off the dial" % control.name)
	# Keyboard and controller focus is the action keys; the steppers are pointer
	# and shoulder-button controls, as on every other cabinet.
	for control: Control in [panel._help_button, panel.auto_button, panel.primary_button]:
		assert_eq(control.focus_mode, Control.FOCUS_ALL, "%s takes focus" % control.name)


func test_the_history_strip_keeps_the_recent_runs() -> void:
	var session := _open()
	var game: MiniGame = session.cabinet
	var math: CoreOverclockMath = game.get("math")
	var panel: CoreOverclockPanel = game.panel
	game.select_stake(100)
	for _round_index: int in range(4):
		assert_true(game.call("request_launch"))
		var guard: int = 0
		while game.is_round_active and guard < 4000:
			_step(game, 1.0 / 60.0)
			guard += 1
	assert_eq(math.history.size(), 4)
	assert_eq(panel.history.entries, math.history, "The strip mirrors the cabinet")
	for _round_index: int in range(math.paytable.history_length + 3):
		math._record(250)
	assert_eq(math.history.size(), math.paytable.history_length, "The strip is bounded")


func test_reduced_motion_bounds_every_effect() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var game: MiniGame = _open().cabinet
	var panel: CoreOverclockPanel = game.panel
	game.select_stake(100)
	assert_true(game.call("request_launch"))
	_step(game, 0.5, 20)
	assert_eq(panel._stage.position, Vector2.ZERO, "No screen shake")
	assert_eq(panel.gauge._pop_left, 0.0, "The ticker is instant, with no pop")
	assert_false(panel.burst.is_busy(), "No spray and no smoke")
	# Reduced motion cuts straight to the frame instead of cross-fading, but the
	# pair still show whatever the run is doing.
	assert_eq(
		panel.hosts.current_state,
		CoreOverclockPanel._host_state_for(panel._math().state),
		"The pair show the state the run is actually in"
	)
	var guard: int = 0
	while game.is_round_active and guard < 4000:
		_step(game, 1.0 / 60.0)
		guard += 1
	assert_false(panel.burst.is_busy(), "No burst on the result either")
	assert_eq(panel._stage.position, Vector2.ZERO, "No impact on the result")
	assert_eq(
		panel.hosts.current_state,
		CoreOverclockPanel._host_state_for(panel._math().state),
		"and they react together to how it ended"
	)
	assert_ne(panel.hosts.current_state, &"ready", "which is never 'waiting'")
	panel.backdrop._process(1.0)
	assert_eq(panel.backdrop._phase, 0.0, "The backdrop is static")


func test_full_motion_shakes_only_once_the_climb_is_long() -> void:
	var game: MiniGame = _open().cabinet
	var panel: CoreOverclockPanel = game.panel
	panel.tick(0.016)
	assert_eq(panel._stage.position, Vector2.ZERO, "Nothing shakes between runs")
	var math: CoreOverclockMath = game.get("math")
	game.select_stake(100)
	game.call("request_launch")
	_step(game, math.paytable.countdown_seconds + 0.01)
	if game.is_round_active:
		assert_lte(
			panel._stage.position.length(),
			CoreOverclockPanel.SHAKE_PIXELS + 0.001,
			"Shake stays inside its bound"
		)


func test_every_corsair_label_is_translated() -> void:
	var keys: Array[String] = [
		"CABINET_CORE_OVERCLOCK_NAME",
		"CORE_OVERCLOCK_THEME_TITLE",
		"CORE_OVERCLOCK_STATE_READY",
		"CORE_OVERCLOCK_STATE_COUNTDOWN",
		"CORE_OVERCLOCK_STATE_RUNNING",
		"CORE_OVERCLOCK_STATE_HAULED",
		"CORE_OVERCLOCK_STATE_CRASHED",
		"CORE_OVERCLOCK_ACTION_LAUNCH",
		"CORE_OVERCLOCK_ACTION_PULL",
		"CORE_OVERCLOCK_AUTO_OFF",
		"CORE_OVERCLOCK_AUTO_AT",
		"CORE_OVERCLOCK_VALUE",
		"CORE_OVERCLOCK_NEED_STAKE",
		"CORE_OVERCLOCK_HELP_LOCKED",
		"DECK_CORSAIR_BETTING",
		"DECK_CORSAIR_COUNTDOWN",
		"DECK_CORSAIR_RUNNING",
		"DECK_CORSAIR_HAULED",
		"DECK_CORSAIR_CRASHED",
		"HELP_CORE_OVERCLOCK_RULES",
		"HELP_CORE_OVERCLOCK_CONTROLS",
		"HELP_CORE_OVERCLOCK_GOAL",
		"HELP_CORE_OVERCLOCK_STEPS",
		"HELP_CORE_OVERCLOCK_NOTE",
	]
	for key: String in keys:
		assert_ne(tr(key), key, "%s is translated" % key)


func test_the_cabinet_is_registered_and_declares_its_return() -> void:
	var definition: CabinetDefinition = load(DEFINITION_PATH)
	assert_true(definition.is_valid_definition())
	assert_eq(definition.id, &"core_overclock")
	assert_eq(definition.name_key, "CABINET_CORE_OVERCLOCK_NAME")
	assert_true(CabinetSceneRegistry.has_scene(&"core_overclock"))
	assert_eq(definition.min_bet, 100)
	assert_eq(definition.max_bet, 1000)
