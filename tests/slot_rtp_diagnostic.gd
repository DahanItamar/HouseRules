extends SceneTree
## Supplemental evidence only: never changes the strict million-round AC-027 gate.

const ROUNDS := 10_000_000
const SEED := 20260918


func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var math := SlotMachineMath.new()
	var returned: int = 0
	var jackpots: int = 0
	var started := Time.get_ticks_msec()
	for index in ROUNDS:
		var result := math.spin(10, rng)
		returned += result.payout
		if result.payout == 5000:
			jackpots += 1
	var report := {
		"purpose": "Supplemental ten-million-round stability evidence",
		"cabinet": "slot_classic",
		"rounds": ROUNDS,
		"seed": SEED,
		"wagered": ROUNDS * 10,
		"returned": returned,
		"observed_rtp": float(returned) / (ROUNDS * 10),
		"exact_rtp": 0.954952838105468,
		"standard_error": sqrt(14.819494032047853 / ROUNDS),
		"jackpots": jackpots,
		"elapsed_ms": Time.get_ticks_msec() - started,
	}
	DirAccess.make_dir_recursive_absolute("res://tests/results")
	var file := FileAccess.open("res://tests/results/slot_diagnostic.json", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0)
