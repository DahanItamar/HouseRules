extends GutTest
## AC-027: execute shipped domain math, one million rounds per cabinet.

const ROUNDS := 1_000_000
const SEED := 20260918


func test_million_rounds_per_cabinet() -> void:
	var measurements: Array[Dictionary] = []
	for id in ["slot_classic", "blackjack", "minefield_vault"]:
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
				else "fixed 3 reveals / 3 mines" if id == "minefield_vault" else "spin"
			),
		}
		measurements.append(measurement)
		print(JSON.stringify(measurement))
		assert_almost_eq(observed, definition.target_rtp, 0.01, "AC-027 " + id)
	DirAccess.make_dir_recursive_absolute("res://tests/results")
	var report := FileAccess.open("res://tests/results/rtp.json", FileAccess.WRITE)
	assert_not_null(report)
	if report != null:
		report.store_string(
			JSON.stringify({"engine": Engine.get_version_info(), "results": measurements}, "\t")
		)
