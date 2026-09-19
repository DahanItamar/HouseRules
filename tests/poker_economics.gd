extends SceneTree
## Hold'em economics harness: the baseline player against the five NPC regulars.
##
## Poker has no fixed RTP: the return depends on how well the player plays. This
## run measures one declared baseline strategy (PokerMath.baseline_action) over a
## fixed seed and records it in tests/results/rtp.json next to the fixed-RTP
## cabinets, labelled skill-dependent. Other cabinets' entries are preserved.
##
##   godot --headless --path . -s tests/poker_economics.gd [-- --hands=20000]

const SEED := 20260918
const STAKE := 10
const DEFAULT_HANDS := 20_000
const BASELINE_SAMPLES := 24
const REPORT := "res://tests/results/rtp.json"


func _initialize() -> void:
	var hands := DEFAULT_HANDS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hands="):
			hands = maxi(1, int(argument.trim_prefix("--hands=")))
	var definition: CabinetDefinition = load("res://data/cabinets/poker.tres")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var math := PokerMath.new()
	var wagered := 0
	var returned := 0
	var rake := 0
	var net_squares := 0.0
	var wins := 0
	var folds := 0
	var showdowns := 0
	var npc_net: Array[int] = [0, 0, 0, 0, 0, 0]
	var started := Time.get_ticks_msec()
	for hand: int in range(hands):
		# A deep, constant bankroll: the measurement is per hand, not a ruin run.
		var result := math.play_baseline(STAKE, rng, 1_000_000, BASELINE_SAMPLES)
		wagered += result.stake
		returned += result.payout
		rake += int(result.detail.rake)
		var net := float(result.payout - result.stake) / float(STAKE)
		net_squares += net * net
		if result.payout > result.stake:
			wins += 1
		if bool(result.detail.folded):
			folds += 1
		if bool(result.detail.showdown) and not bool(result.detail.folded):
			showdowns += 1
		var start: Array = math.events[0].stacks
		var finish: Array = math.events[math.events.size() - 1].stacks
		for seat: int in range(1, 6):
			npc_net[seat] += int(finish[seat]) - int(start[seat])
	var elapsed := Time.get_ticks_msec() - started
	var observed := float(returned) / float(maxi(wagered, 1))
	var mean_net := float(returned - wagered) / float(STAKE * hands)
	var variance := net_squares / float(hands) - mean_net * mean_net
	# Standard error of the return ratio, in the same units as observed_rtp.
	var average_stake := float(wagered) / float(hands)
	var ratio_error := sqrt(maxf(variance, 0.0) / float(hands)) * float(STAKE) / average_stake
	var npc_bb_per_100: Dictionary = {}
	for seat: int in range(1, 6):
		var npc: PokerNpc = math.npcs[seat - 1]
		npc_bb_per_100[str(npc.id)] = snappedf(
			float(npc_net[seat]) / float(STAKE) / float(hands) * 100.0, 0.01
		)
	var measurement := {
		"cabinet": "poker",
		"rounds": hands,
		"seed": SEED,
		"wagered": wagered,
		"returned": returned,
		"observed_rtp": observed,
		"target_rtp": definition.target_rtp,
		"absolute_error": absf(observed - definition.target_rtp),
		"standard_error": ratio_error,
		"elapsed_ms": elapsed,
		"strategy": "baseline: top 25% preflop, equity vs pot odds postflop",
		"skill_dependent": true,
		"note": "Return depends on player skill; this is one declared baseline, not a fixed RTP.",
		"rake_paid": rake,
		"win_rate": float(wins) / float(hands),
		"fold_rate": float(folds) / float(hands),
		"player_showdown_rate": float(showdowns) / float(hands),
		"player_bb_per_100": snappedf(mean_net * 100.0, 0.01),
		"npc_bb_per_100": npc_bb_per_100,
	}
	print(JSON.stringify(measurement))
	_merge_into_report(measurement)
	quit(0)


func _merge_into_report(measurement: Dictionary) -> void:
	var report: Dictionary = {"engine": Engine.get_version_info(), "results": []}
	if FileAccess.file_exists(REPORT):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REPORT))
		if parsed is Dictionary:
			report = parsed
	var kept: Array = []
	for entry: Variant in report.get("results", []):
		if entry is Dictionary and str(entry.get("cabinet", "")) != "poker":
			kept.append(entry)
	kept.append(measurement)
	report["results"] = kept
	var file := FileAccess.open(REPORT, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
