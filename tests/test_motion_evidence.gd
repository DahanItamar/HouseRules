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


func test_blackjack_dealer_lane_itself_changes_during_each_articulated_gesture() -> void:
	var dealer_evidence: Dictionary = _manifest().regions_of_interest.blackjack_dealer_lane
	var values: Array = dealer_evidence.rect
	assert_eq(values.size(), 4)
	var region := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
	for sequence_key: String in dealer_evidence.sequences:
		var frames: Array = dealer_evidence.sequences[sequence_key]
		assert_eq(frames.size(), 2)
		var first := _load_evidence_image(String(frames[0])).get_region(region)
		var second := _load_evidence_image(String(frames[1])).get_region(region)
		assert_ne(
			first.get_data(),
			second.get_data(),
			"%s gesture changes pixels inside the dealer lane" % sequence_key
		)


func test_blackjack_player_lane_changes_during_live_hand_reflow() -> void:
	var evidence: Dictionary = _manifest().regions_of_interest.blackjack_player_lane
	var values: Array = evidence.rect
	var region := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
	var frames: Array = evidence.sequences.hit_reflow
	var first := _load_evidence_image(String(frames[0])).get_region(region)
	var second := _load_evidence_image(String(frames[1])).get_region(region)
	assert_ne(
		first.get_data(),
		second.get_data(),
		"Hit choreography visibly refans cards inside the player table lane"
	)


func test_cashier_ledger_and_chip_strip_remains_alive_after_entry_settles() -> void:
	var evidence: Dictionary = _manifest().regions_of_interest.cashier_ambient_strip
	var values: Array = evidence.rect
	var region := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
	var frames: Array = evidence.sequences.idle
	var first := _load_evidence_image(String(frames[0])).get_region(region)
	var second := _load_evidence_image(String(frames[1])).get_region(region)
	assert_ne(
		first.get_data(),
		second.get_data(),
		"The settled cashier keeps a restrained ledger and chip-tray motion"
	)


func test_high_value_alive_flows_have_named_temporal_evidence() -> void:
	var full: Dictionary = _manifest().full_motion
	for sequence_key: String in [
		"floor_practical_lights", "cashier_idle", "help_reveal", "help_dismiss", "exit_reveal",
		"exit_cancel", "exit_confirm",
		"blackjack_deal", "blackjack_hit", "blackjack_reveal", "vault_hazard",
	]:
		assert_true(full.has(sequence_key), "%s is represented in the manifest" % sequence_key)
		assert_eq((full[sequence_key] as Array).size(), 2)


func _load_evidence_image(relative_path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(ROOT + relative_path))
	assert_false(image.is_empty(), "%s decodes" % relative_path)
	return image


func _manifest() -> Dictionary:
	assert_true(FileAccess.file_exists(MANIFEST_PATH), "Motion manifest exists")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	assert_true(parsed is Dictionary, "Motion manifest parses as an object")
	return parsed as Dictionary
