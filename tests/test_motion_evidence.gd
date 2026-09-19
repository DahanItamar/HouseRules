extends GutTest

const ROOT := "res://tests/results/screenshots/"
const MANIFEST_PATH := ROOT + "motion_manifest.json"
const CAPTURE_SIZE := Vector2i(1920, 1080)


func test_motion_manifest_references_decodable_exact_fhd_frames() -> void:
	var manifest := _manifest()
	assert_eq(int(manifest.seed), 20260918)
	assert_eq(String(manifest.capture_size), "1920x1080")
	for mode_key: String in ["full_motion", "reduced_motion"]:
		var sequences: Dictionary = manifest[mode_key]
		for sequence_key: String in sequences:
			if not sequences[sequence_key] is Array:
				continue
			for relative_path: String in sequences[sequence_key]:
				var path := ROOT + relative_path
				assert_true(FileAccess.file_exists(path), "%s exists" % relative_path)
				var image := Image.load_from_file(ProjectSettings.globalize_path(path))
				assert_false(image.is_empty(), "%s decodes" % relative_path)
				assert_eq(image.get_size(), CAPTURE_SIZE, "%s is exact FHD" % relative_path)


func test_each_full_motion_sequence_contains_a_visible_temporal_change() -> void:
	var sequences: Dictionary = _manifest().full_motion
	for sequence_key: String in sequences:
		var frames: Array = sequences[sequence_key]
		assert_eq(frames.size(), 2, "%s has a before/mid pair" % sequence_key)
		var first_path := ROOT + String(frames[0])
		var second_path := ROOT + String(frames[1])
		assert_ne(
			FileAccess.get_sha256(first_path),
			FileAccess.get_sha256(second_path),
			"%s changes pixels over time" % sequence_key
		)


func test_reduced_motion_menu_holds_a_byte_stable_final_composition() -> void:
	var reduced: Dictionary = _manifest().reduced_motion
	var frames: Array = reduced.menu
	assert_eq(frames.size(), 2)
	var first_hash := FileAccess.get_sha256(ROOT + String(frames[0]))
	var second_hash := FileAccess.get_sha256(ROOT + String(frames[1]))
	assert_eq(first_hash, second_hash)
	assert_eq(first_hash.to_upper(), String(reduced.sha256).to_upper())


func _manifest() -> Dictionary:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "Motion manifest exists")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed is Dictionary, "Motion manifest parses as an object")
	return parsed as Dictionary
