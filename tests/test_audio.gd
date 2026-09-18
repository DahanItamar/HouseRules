extends GutTest

var _original_output: bool


func before_each() -> void:
	_original_output = AudioService.output_enabled
	AudioService.output_enabled = false


func after_each() -> void:
	AudioService.output_enabled = _original_output


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
