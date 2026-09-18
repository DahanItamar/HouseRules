class_name LocalPlatform
extends PlatformServices

var base_path: String


func _init(directory: String = "user://") -> void:
	base_path = directory


func read_save(slot: StringName) -> PackedByteArray:
	var path: String = _path(slot)
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


func has_save(slot: StringName) -> bool:
	return FileAccess.file_exists(_path(slot))


func write_save(slot: StringName, bytes: PackedByteArray) -> Error:
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(base_path)
	if directory_error != OK:
		return directory_error
	var target: String = _path(slot)
	var temporary: String = target + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	return DirAccess.rename_absolute(temporary, target)


func preserve_corrupt(slot: StringName) -> Error:
	var path: String = _path(slot)
	var preserved: String = path + ".corrupt"
	if FileAccess.file_exists(preserved):
		preserved += "." + str(Time.get_ticks_usec())
	return DirAccess.rename_absolute(path, preserved)


func _path(slot: StringName) -> String:
	assert(str(slot).is_valid_filename())
	return base_path.path_join(str(slot) + ".json")
