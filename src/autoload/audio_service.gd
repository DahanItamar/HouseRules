extends Node

signal cue_played(cue: StringName)
signal ambient_changed(cue: StringName, playing: bool)

const MIX_RATE: int = 22050
const MUTE_SETTING: String = "house_rules/audio/muted"
const CUES: Dictionary = {
	&"confirm": [660.0, 0.07, &"bell", -14.0],
	&"move": [440.0, 0.035, &"tick", -18.0],
	&"spin": [128.0, 0.28, &"motor", -15.0],
	&"reel_stop": [108.0, 0.10, &"clack", -10.0],
	&"slot_win": [784.0, 0.48, &"jackpot", -10.0],
	&"card_deal": [190.0, 0.09, &"card", -17.0],
	&"card_flip": [310.0, 0.13, &"flip", -14.0],
	&"chip": [920.0, 0.08, &"chip", -15.0],
	&"blackjack_win": [660.0, 0.34, &"major", -11.0],
	&"blackjack_push": [390.0, 0.18, &"neutral", -15.0],
	&"blackjack_loss": [145.0, 0.22, &"thud", -14.0],
	&"vault_tension": [86.0, 0.24, &"tension", -18.0],
	&"vault_safe": [570.0, 0.16, &"safe", -13.0],
	&"vault_cashout": [740.0, 0.38, &"major", -11.0],
	&"vault_bust": [72.0, 0.36, &"bust", -9.0],
	&"reveal": [520.0, 0.08, &"bell", -14.0],
	&"win": [880.0, 0.24, &"major", -12.0],
	&"loss": [160.0, 0.18, &"thud", -14.0],
	&"floor_ambience": [55.0, 8.0, &"ambience", -31.0],
	&"lift_chime": [1046.5, 0.7, &"chime", -19.0],
	&"door_latch": [150.0, 0.2, &"latch", -15.0],
	&"stair_steps": [92.0, 0.62, &"steps", -18.0],
	&"oven_load": [210.0, 0.34, &"peel", -13.0],
	&"oven_pulse": [330.0, 0.11, &"crackle", -21.0],
	&"oven_tick": [880.0, 0.06, &"tick", -19.0],
	&"oven_roar": [58.0, 0.26, &"roar", -15.0],
	&"oven_serve": [720.0, 0.40, &"major", -11.0],
	&"oven_burn": [68.0, 0.42, &"scorch", -10.0],
}

var output_enabled: bool = true
var muted: bool = false
var _streams: Dictionary = {}
var _ambient_player: AudioStreamPlayer
var _ambient_cue: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	output_enabled = DisplayServer.get_name() != "headless"
	muted = bool(ProjectSettings.get_setting(MUTE_SETTING, false))


func set_muted(value: bool) -> void:
	if muted == value:
		return
	muted = value
	if muted:
		_stop_ambient_player()
	elif output_enabled and not _ambient_cue.is_empty():
		_start_ambient_player(_ambient_cue)


## `pitch` shifts one cue without a second stream: callers that rise with a
## value (the Tidewater depth pulse, its heartbeat) pass it every time.
func play(cue: StringName, pitch: float = 1.0) -> void:
	if not CUES.has(cue):
		return
	cue_played.emit(cue)
	if not output_enabled or muted:
		return
	var player := AudioStreamPlayer.new()
	player.stream = cue_stream(cue)
	player.pitch_scale = clampf(pitch, 0.25, 4.0)
	player.volume_db = float((CUES[cue] as Array)[3])
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func play_ambient(cue: StringName = &"floor_ambience") -> void:
	if not CUES.has(cue) or (CUES[cue] as Array)[2] != &"ambience":
		return
	if _ambient_cue == cue:
		return
	_ambient_cue = cue
	ambient_changed.emit(cue, true)
	_stop_ambient_player()
	if output_enabled and not muted:
		_start_ambient_player(cue)


func stop_ambient() -> void:
	if _ambient_cue.is_empty():
		return
	var stopped_cue := _ambient_cue
	_ambient_cue = &""
	_stop_ambient_player()
	ambient_changed.emit(stopped_cue, false)


func cue_stream(cue: StringName) -> AudioStreamWAV:
	if _streams.has(cue):
		return _streams[cue]
	var definition: Array = CUES.get(cue, CUES[&"confirm"])
	var frequency: float = definition[0]
	var duration: float = definition[1]
	var character: StringName = definition[2]
	var frame_count: int = ceili(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame: int in range(frame_count):
		var time: float = float(frame) / MIX_RATE
		var phase: float = time / duration
		var sample: float = _sample(character, frequency, time, phase)
		bytes.encode_s16(frame * 2, clampi(roundi(sample * 8192.0), -32767, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if character == &"ambience":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = frame_count
	_streams[cue] = stream
	return stream


func _sample(character: StringName, frequency: float, time: float, phase: float) -> float:
	var attack := minf(phase * 24.0, 1.0)
	var decay := pow(maxf(1.0 - phase, 0.0), 2.2)
	match character:
		&"tick":
			return sin(TAU * frequency * time) * attack * pow(1.0 - phase, 5.0) * 0.45
		&"motor":
			return (
				(
					sin(TAU * (frequency + phase * 74.0) * time) * 0.46
					+ sin(TAU * 31.0 * time) * 0.12
				)
				* decay
			)
		&"clack":
			return (
				(sin(TAU * frequency * time) + sin(TAU * 1700.0 * time) * 0.28)
				* pow(1.0 - phase, 7.0)
			)
		&"jackpot":
			var step: float = 1.0 + floor(phase * 4.0) * 0.25
			return sin(TAU * frequency * step * time) * attack * (1.0 - phase) * 0.8
		&"card":
			return (
				(
					sin(TAU * (frequency + phase * 80.0) * time) * 0.36
					+ sin(TAU * 1260.0 * time) * 0.12
				)
				* pow(1.0 - phase, 3.0)
			)
		&"flip":
			return sin(TAU * (frequency + phase * 520.0) * time) * sin(phase * PI) * 0.62
		&"chip":
			return (
				(sin(TAU * frequency * time) * 0.52 + sin(TAU * frequency * 1.51 * time) * 0.25)
				* decay
			)
		&"major":
			var major_step: float = [1.0, 1.25, 1.5][mini(int(phase * 3.0), 2)]
			return sin(TAU * frequency * major_step * time) * attack * (1.0 - phase) * 0.78
		&"neutral":
			return sin(TAU * frequency * time) * attack * decay * 0.5
		&"thud":
			return sin(TAU * frequency * (1.0 - phase * 0.35) * time) * pow(1.0 - phase, 3.2) * 0.75
		&"tension":
			return (
				(sin(TAU * frequency * time) * 0.44 + sin(TAU * frequency * 1.5 * time) * 0.16)
				* sin(phase * PI)
			)
		&"safe":
			return (
				(sin(TAU * frequency * time) + sin(TAU * frequency * 1.5 * time) * 0.32)
				* attack
				* decay
				* 0.65
			)
		&"bust":
			return (
				(sin(TAU * frequency * (1.0 - phase * 0.5) * time) + sin(TAU * 43.0 * time) * 0.4)
				* decay
				* 0.8
			)
		&"ambience":
			var hum := sin(TAU * frequency * time) * 0.10 + sin(TAU * frequency * 1.5 * time) * 0.05
			var room := sin(TAU * 0.25 * time) * 0.025
			var chime_phase := fmod(time, 4.0)
			var chime := sin(TAU * 880.0 * chime_phase) * exp(-chime_phase * 8.0) * 0.035
			return hum + room + chime
		&"chime":
			# Two soft bell strikes a major third apart, like a lift arriving.
			var second_time := maxf(time - 0.22, 0.0)
			var second_gate := 1.0 if time >= 0.22 else 0.0
			var first_bell := (
				(sin(TAU * frequency * time) + sin(TAU * frequency * 2.76 * time) * 0.16)
				* exp(-time * 7.0)
			)
			var second_bell := (
				(
					sin(TAU * frequency * 0.8 * second_time)
					+ sin(TAU * frequency * 0.8 * 2.76 * second_time) * 0.16
				)
				* exp(-second_time * 6.0)
				* second_gate
			)
			return (first_bell + second_bell) * attack * 0.4
		&"latch":
			# A brass bolt click, its catch, then the walnut door settling.
			var catch_time := maxf(time - 0.04, 0.0)
			var click := sin(TAU * 2600.0 * time) * exp(-time * 260.0) * 0.4
			var bolt := sin(TAU * 1500.0 * catch_time) * exp(-catch_time * 220.0) * 0.3
			var thunk := sin(TAU * frequency * time) * exp(-time * 24.0) * 0.7
			return click + (bolt if time >= 0.04 else 0.0) + thunk
		&"peel":
			# The peel on the stone: a wooden scrape, then the dough landing.
			var scrape := sin(TAU * 1500.0 * time) * exp(-time * 40.0) * 0.26
			var slide := sin(TAU * frequency * (1.0 - phase * 0.3) * time) * decay * 0.5
			var settle := sin(TAU * 86.0 * time) * exp(-time * 12.0) * 0.22
			return scrape + slide + settle
		&"crackle":
			# One crackle from the fire; the caller pitches it up with the heat.
			return (
				(sin(TAU * frequency * time) + sin(TAU * frequency * 2.0 * time) * 0.22)
				* attack
				* pow(1.0 - phase, 4.0)
				* 0.5
			)
		&"roar":
			# The draw of a wood fire: a low swell with a second breath under it.
			var second := maxf(time - 0.11, 0.0)
			var first_breath := sin(TAU * frequency * time) * exp(-time * 20.0)
			var second_breath := (
				sin(TAU * frequency * 0.86 * second)
				* exp(-second * 24.0)
				* 0.6
				* (1.0 if time >= 0.11 else 0.0)
			)
			return (first_breath + second_breath) * 0.85
		&"scorch":
			# A pizza going black: a falling note with a hiss of smoke over it.
			return (
				(sin(TAU * frequency * (1.0 - phase * 0.45) * time) + sin(TAU * 39.0 * time) * 0.45)
				* pow(1.0 - phase, 1.6)
				* 0.82
			)
		&"steps":
			# Three soft footfalls on a carpeted stair, each a little quieter.
			var step_index := floorf(time / 0.2)
			var local := fmod(time, 0.2)
			var fall := sin(TAU * frequency * (1.0 - local * 1.4) * local) * exp(-local * 36.0)
			var scuff := sin(TAU * 1700.0 * local) * exp(-local * 180.0) * 0.12
			return (fall + scuff) * (1.0 - step_index * 0.2) * 0.7
	return sin(TAU * frequency * time) * attack * decay * 0.65


func _start_ambient_player(cue: StringName) -> void:
	_stop_ambient_player()
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientBed"
	_ambient_player.stream = cue_stream(cue)
	_ambient_player.volume_db = float((CUES[cue] as Array)[3])
	add_child(_ambient_player)
	_ambient_player.play()


func _stop_ambient_player() -> void:
	if _ambient_player != null:
		_ambient_player.stop()
		_ambient_player.queue_free()
		_ambient_player = null
