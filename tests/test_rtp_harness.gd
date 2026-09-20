extends GutTest
## AC-027: execute shipped domain math, one million rounds per cabinet.

const ROUNDS := 1_000_000
const SEED := 20260918


func test_million_rounds_per_cabinet() -> void:
	var measurements: Array[Dictionary] = []
	for id in [
		"slot_classic",
		"blackjack",
		"minefield_vault",
		"roulette",
		"match_point",
		"baccarat",
		"core_overclock",
		"upgrade_cluster",
	]:
		var definition = load("res://data/cabinets/%s.tres" % id)
		assert_not_null(definition, "Shipped definition exists: " + id)
		if definition == null:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		var math
		match id:
			"slot_classic":
				math = SlotMachineMath.new()
			"blackjack":
				math = BlackjackMath.new()
			"minefield_vault":
				math = MinefieldMath.new()
			"roulette":
				math = RouletteMath.new()
			"match_point":
				math = MatchPointMath.new()
			"baccarat":
				math = BaccaratMath.new()
			"core_overclock":
				math = CoreOverclockMath.new()
			"upgrade_cluster":
				math = UpgradeClusterMath.new()
		var roulette_spots: Array = math.spots().keys() if id == "roulette" else []
		var wagered: int = 0
		var returned: int = 0
		var started := Time.get_ticks_msec()
		for index in ROUNDS:
			var result: RoundResult
			match id:
				"slot_classic":
					result = math.spin(10, rng)
				"blackjack":
					result = math.play_basic_strategy(10, rng)
				"minefield_vault":
					math.begin(25, 3, rng)
					for tile in 3:
						result = math.reveal(tile)
						if result != null:
							break
					if result == null:
						result = math.cash_out()
				"roulette":
					# Four independently chosen layout spots, 10 chips each, per spin.
					for pick in 4:
						math.place(
							roulette_spots[rng.randi_range(0, roulette_spots.size() - 1)], 10, 100
						)
					result = math.spin(rng)
				"match_point":
					# One drop of 10 per round, risk cycling Low, Medium, High.
					result = math.drop(10, index % 3, rng)
				"baccarat":
					# 20 on Banker every coup: the declared (best) bet, commission exact.
					math.place(BaccaratMath.BANKER, 20, 400)
					result = math.deal(rng)
				"core_overclock":
					# 100 a dive, surfacing depth cycling 1.20x, 2.00x, 5.00x and
					# 10.00x. One advance past the whole climb settles the decided
					# dive exactly, which is the same arithmetic the cabinet runs
					# frame by frame.
					math.reset()
					math.set_auto_target([120, 200, 500, 1000][index % 4])
					math.begin(100, rng)
					result = math.advance(1000.0)
				"upgrade_cluster":
					# One 10-chip board a round. `play` draws the grid, every tumble
					# and the upgrade bar in one call, so the whole round settles here.
					result = math.play(10, rng)
			wagered += result.stake
			returned += result.payout
		var observed := float(returned) / wagered
		var measurement := {
			"cabinet": id,
			"rounds": ROUNDS,
			"seed": SEED,
			"wagered": wagered,
			"returned": returned,
			"observed_rtp": observed,
			"target_rtp": definition.target_rtp,
			"absolute_error": absf(observed - definition.target_rtp),
			"elapsed_ms": Time.get_ticks_msec() - started,
			"strategy":
			(
				"basic strategy"
				if id == "blackjack"
				else (
					"fixed 3 reveals / 3 mines"
					if id == "minefield_vault"
					else (
						"4 random spots x 10"
						if id == "roulette"
						else (
							"10 per drop, risk cycles low/medium/high"
							if id == "match_point"
							else "spin"
						)
					)
				)
			),
		}
		if id == "baccarat":
			measurement.strategy = "20 on Banker, 8-deck shoe shuffled every coup"
		if id == "core_overclock":
			measurement.strategy = "100 a dive, auto surface cycles 1.20x/2x/5x/10x"
		if id == "upgrade_cluster":
			measurement.strategy = "10 a board, tumbles and upgrade bar to the end"
		measurements.append(measurement)
		print(JSON.stringify(measurement))
		assert_almost_eq(observed, definition.target_rtp, 0.01, "AC-027 " + id)
	DirAccess.make_dir_recursive_absolute("res://tests/results")
	# Keep entries this harness does not measure (the skill-dependent poker
	# baseline written by tests/poker_economics.gd) instead of dropping them.
	var measured: Array[String] = []
	for entry: Dictionary in measurements:
		measured.append(str(entry.cabinet))
	var results: Array = measurements.duplicate()
	var previous: Variant = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/results/rtp.json")
	)
	if previous is Dictionary:
		for entry: Variant in (previous as Dictionary).get("results", []):
			if entry is Dictionary and not measured.has(str(entry.get("cabinet", ""))):
				results.append(entry)
	var report := FileAccess.open("res://tests/results/rtp.json", FileAccess.WRITE)
	assert_not_null(report)
	if report != null:
		report.store_string(
			JSON.stringify({"engine": Engine.get_version_info(), "results": results}, "\t")
		)
