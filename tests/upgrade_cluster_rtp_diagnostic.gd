extends SceneTree
## Supplemental Upgrade Cluster evidence: return, hit rate, tumble depth, the
## upgrade bar's rung distribution and the big-win tier frequencies.
##
## It never changes the strict million-round AC-027 gate in test_rtp_harness.gd.
##
##   godot --headless --path . -s tests/upgrade_cluster_rtp_diagnostic.gd
##
## `-- --rounds=200000` shortens the sample while tuning the paytable.

const DEFAULT_ROUNDS := 1_000_000
const SEED := 20260918
const STAKE := 10


func _initialize() -> void:
	var rounds := DEFAULT_ROUNDS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--rounds="):
			rounds = int(argument.trim_prefix("--rounds="))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var math := UpgradeClusterMath.new()
	var returned: int = 0
	var wins: int = 0
	var cascade_total: int = 0
	var deepest: int = 0
	var best: int = 0
	var multiplier_hits: Dictionary = {}
	var tiers := {"big": 0, "super": 0, "mega": 0}
	var square_sum: float = 0.0
	var started := Time.get_ticks_msec()
	for index: int in rounds:
		var result := math.play(STAKE, rng)
		returned += result.payout
		var multiple := float(result.payout) / float(STAKE)
		square_sum += multiple * multiple
		if result.payout > 0:
			wins += 1
		best = maxi(best, result.payout)
		var cascades: int = (result.detail.cascades as Array).size()
		cascade_total += cascades
		deepest = maxi(deepest, cascades)
		var rung: int = int(result.detail.multiplier)
		multiplier_hits[rung] = int(multiplier_hits.get(rung, 0)) + 1
		if multiple >= 100.0:
			tiers.mega += 1
		elif multiple >= 50.0:
			tiers.super += 1
		elif multiple >= 15.0:
			tiers.big += 1
	var wagered := rounds * STAKE
	var observed := float(returned) / float(wagered)
	var variance := square_sum / float(rounds) - observed * observed
	var report := {
		"purpose": "Supplemental Upgrade Cluster stability evidence",
		"cabinet": "upgrade_cluster",
		"rounds": rounds,
		"seed": SEED,
		"stake": STAKE,
		"wagered": wagered,
		"returned": returned,
		"observed_rtp": observed,
		"hit_rate": float(wins) / float(rounds),
		"mean_cascades": float(cascade_total) / float(rounds),
		"deepest_cascade": deepest,
		"best_payout_multiple": float(best) / float(STAKE),
		"multiplier_rungs": multiplier_hits,
		"big_win_rate": float(tiers.big) / float(rounds),
		"super_win_rate": float(tiers.super) / float(rounds),
		"mega_win_rate": float(tiers.mega) / float(rounds),
		"payout_multiple_variance": variance,
		"standard_error": sqrt(variance / float(rounds)),
		"elapsed_ms": Time.get_ticks_msec() - started,
	}
	DirAccess.make_dir_recursive_absolute("res://tests/results")
	var file := FileAccess.open(
		"res://tests/results/upgrade_cluster_diagnostic.json", FileAccess.WRITE
	)
	if file == null:
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit(0)
