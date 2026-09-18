class_name InstanceGuard
extends RefCounted
## Filesystem lock directory, no sockets or outbound connections.
## A stale owner PID can be recovered after a crash.

var _lock_path: String = "user://instance.lock"
var _owned: bool = false


func acquire() -> bool:
	var error: Error = DirAccess.make_dir_absolute(_lock_path)
	if error != OK:
		var owner_file: String = _lock_path.path_join("pid")
		if not FileAccess.file_exists(owner_file):
			return false
		var owner: int = int(FileAccess.get_file_as_string(owner_file))
		if owner > 0 and OS.is_process_running(owner):
			return false
		if DirAccess.remove_absolute(owner_file) != OK:
			return false
		if DirAccess.remove_absolute(_lock_path) != OK:
			return false
		if DirAccess.make_dir_absolute(_lock_path) != OK:
			return false
	var file := FileAccess.open(_lock_path.path_join("pid"), FileAccess.WRITE)
	if file == null:
		DirAccess.remove_absolute(_lock_path)
		return false
	file.store_string(str(OS.get_process_id()))
	file.close()
	_owned = true
	return true


func release() -> void:
	if _owned:
		DirAccess.remove_absolute(_lock_path.path_join("pid"))
		DirAccess.remove_absolute(_lock_path)
		_owned = false
