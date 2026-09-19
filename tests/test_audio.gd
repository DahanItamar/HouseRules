extends GutTest

var _original_output: bool
var _original_muted: bool


func before_each() -> void:
	_original_output = AudioService.output_enabled
	_original_muted = AudioService.muted
	AudioService.output_enabled = false
	AudioService.set_muted(false)
	AudioService.stop_ambient()


func after_each() -> void:
	AudioService.stop_ambient()
	AudioService.output_enabled = _original_output
	AudioService.set_muted(_original_muted)


func test_m5_audio_cues_are_deterministic_pcm() -> void:
	var first := AudioService.cue_stream(&"win")
	var second := AudioService.cue_stream(&"win")
	assert_same(first, second, "Generated cues are cached")
	assert_eq(first.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(first.mix_rate, AudioService.MIX_RATE)
	assert_false(first.stereo)
	assert_gt(first.data.size(), 0)


func test_m5_audio_events_emit_even_when_output_is_disabled() -> void:
	watch_signals(AudioService)
	AudioService.play(&"move")
	AudioService.play(&"spin")
	assert_signal_emit_count(AudioService, "cue_played", 2)


func test_casino_cue_palette_is_distinct_cached_pcm() -> void:
	var required: Array[StringName] = [
		&"spin",
		&"reel_stop",
		&"slot_win",
		&"card_deal",
		&"card_flip",
		&"chip",
		&"blackjack_win",
		&"blackjack_push",
		&"blackjack_loss",
		&"vault_tension",
		&"vault_safe",
		&"vault_cashout",
		&"vault_bust",
	]
	var fingerprints: Dictionary = {}
	for cue: StringName in required:
		assert_true(AudioService.CUES.has(cue), "%s is registered" % cue)
		var stream := AudioService.cue_stream(cue)
		assert_same(stream, AudioService.cue_stream(cue), "%s is cached" % cue)
		var fingerprint := hash(stream.data)
		assert_false(fingerprints.has(fingerprint), "%s has a distinct waveform" % cue)
		fingerprints[fingerprint] = cue


func test_floor_ambience_is_looped_and_has_idempotent_lifecycle() -> void:
	var stream := AudioService.cue_stream(&"floor_ambience")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(stream.loop_begin, 0)
	assert_gt(stream.loop_end, AudioService.MIX_RATE)
	watch_signals(AudioService)
	AudioService.play_ambient()
	AudioService.play_ambient()
	assert_signal_emit_count(AudioService, "ambient_changed", 1, "Repeated start is ignored")
	AudioService.stop_ambient()
	assert_signal_emit_count(AudioService, "ambient_changed", 2)


func test_mute_keeps_semantic_events_without_creating_players() -> void:
	AudioService.output_enabled = true
	AudioService.set_muted(true)
	watch_signals(AudioService)
	var before := AudioService.get_child_count()
	AudioService.play(&"card_deal")
	AudioService.play_ambient()
	assert_signal_emit_count(AudioService, "cue_played", 1)
	assert_eq(AudioService.get_child_count(), before)


func test_each_cabinet_maps_results_to_its_own_audio_language() -> void:
	var panel := CabinetPanel.new()
	var game := MiniGame.new()
	var context := MiniGameContext.new()
	game.context = context
	panel.cabinet = game
	var win := RoundResult.create(10, 20, RoundResult.Outcome.WIN)
	var loss := RoundResult.create(10, 0, RoundResult.Outcome.LOSS)
	var push := RoundResult.create(10, 10, RoundResult.Outcome.PUSH)
	context.definition = load("res://data/cabinets/slot_classic.tres")
	assert_eq(panel._result_audio_cue(win), &"slot_win")
	context.definition = load("res://data/cabinets/blackjack.tres")
	assert_eq(panel._result_audio_cue(win), &"blackjack_win")
	assert_eq(panel._result_audio_cue(loss), &"blackjack_loss")
	assert_eq(panel._result_audio_cue(push), &"blackjack_push")
	context.definition = load("res://data/cabinets/minefield_vault.tres")
	assert_eq(panel._result_audio_cue(win), &"vault_cashout")
	assert_eq(panel._result_audio_cue(loss), &"vault_bust")
	panel.free()
	game.free()
