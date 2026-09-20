class_name DevBuildInfo
extends RefCounted
## Build identity for the developer menu's Info section.
##
## Runs from the editor or source tree read the live commit with
## `git rev-parse --short HEAD` (once, lazily). Exported builds read
## `res://build_stamp.txt` when a packaging step writes one, else say "dev".
## The version line names the game and engine only, never a tool or vendor.

const STAMP_PATH := "res://build_stamp.txt"
const FALLBACK := "dev"

static var _commit: String = ""


static func commit() -> String:
	if _commit.is_empty():
		_commit = _read_commit()
	return _commit


static func version() -> String:
	var game_version := String(ProjectSettings.get_setting("application/config/version", ""))
	if game_version.is_empty():
		game_version = FALLBACK
	var engine := Engine.get_version_info()
	var kind := "debug" if OS.is_debug_build() else "release"
	return (
		"%s %s · Godot %d.%d.%d · %s"
		% [
			ProjectSettings.get_setting("application/config/name", "House Rules"),
			game_version,
			int(engine.major),
			int(engine.minor),
			int(engine.patch),
			kind,
		]
	)


static func _read_commit() -> String:
	if FileAccess.file_exists(STAMP_PATH):
		var stamp := FileAccess.get_file_as_string(STAMP_PATH).strip_edges()
		if not stamp.is_empty():
			return stamp
	if not OS.has_feature("editor"):
		return FALLBACK
	var output: Array = []
	var project := ProjectSettings.globalize_path("res://")
	var code := OS.execute("git", ["-C", project, "rev-parse", "--short", "HEAD"], output, true)
	if code != 0 or output.is_empty():
		return FALLBACK
	var hash_text := String(output[0]).strip_edges()
	if hash_text.is_empty() or hash_text.contains(" "):
		return FALLBACK
	return "%s (live)" % hash_text
