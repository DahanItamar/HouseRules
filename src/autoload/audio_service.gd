extends Node

signal cue_played(cue: StringName)

const MIX_RATE: int = 22050
const CUES: Dictionary = {
	&"confirm": [660.0, 0.06],
	&"move": [440.0, 0.04],
	&"spin": [220.0, 0.16],
	&"reveal": [520.0, 0.08],
	&"win": [880.0, 0.24],
	&"loss": [160.0, 0.18],
}

var output_enabled: bool = true
var _streams: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	output_enabled = DisplayServer.get_name() != "headless"


func play(cue: StringName) -> void:
	if not CUES.has(cue):
		return
	cue_played.emit(cue)
	if not output_enabled:
		return
	var player := AudioStreamPlayer.new()
	player.stream = cue_stream(cue)
	player.volume_db = -12.0
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


func cue_stream(cue: StringName) -> AudioStreamWAV:
	if _streams.has(cue):
		return _streams[cue]
	var definition: Array = CUES.get(cue, CUES.confirm)
	var frequency: float = definition[0]
	var duration: float = definition[1]
	var frame_count: int = ceili(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 2)
	for frame: int in range(frame_count):
		var time: float = float(frame) / MIX_RATE
		var envelope: float = 1.0 - time / duration
		var sweep: float = 1.0 + time if cue == &"spin" else 1.0
		var sample: int = roundi(sin(TAU * frequency * sweep * time) * envelope * 8192.0)
		bytes.encode_s16(frame * 2, sample)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	_streams[cue] = stream
	return stream
