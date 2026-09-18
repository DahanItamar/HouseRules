extends Node
## Streams derive only from the master seed and their stable UTF-8 name.

var master_seed: int = 1
var _streams: Dictionary = {}


func reset(seed_value: int) -> void:
	master_seed = seed_value
	_streams.clear()


func stream(stream_name: StringName) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var generator := RandomNumberGenerator.new()
		var digest: PackedByteArray = (str(master_seed) + ":" + str(stream_name)).sha256_buffer()
		generator.seed = digest.decode_s64(0)
		_streams[stream_name] = generator
	return _streams[stream_name]


func snapshot() -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in _streams:
		result[str(key)] = str((_streams[key] as RandomNumberGenerator).state)
	return result


func restore(states: Dictionary) -> void:
	for key: String in states:
		stream(StringName(key)).state = int(states[key])
