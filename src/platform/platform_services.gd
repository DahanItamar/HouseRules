class_name PlatformServices
extends RefCounted
## All save storage and achievement access crosses this interface.

var achievements: Dictionary = {}


func has_save(slot: StringName) -> bool:
	return not read_save(slot).is_empty()


func read_save(_slot: StringName) -> PackedByteArray:
	return PackedByteArray()


func write_save(_slot: StringName, _bytes: PackedByteArray) -> Error:
	return ERR_UNAVAILABLE


func preserve_corrupt(_slot: StringName) -> Error:
	return ERR_UNAVAILABLE


func unlock_achievement(id: StringName) -> void:
	achievements[str(id)] = true


func is_achievement_unlocked(id: StringName) -> bool:
	return achievements.get(str(id), false)
