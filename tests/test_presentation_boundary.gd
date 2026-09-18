extends GutTest

const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")


func test_domain_layer_has_no_presentation_dependencies() -> void:
	var forbidden: Array[String] = [
		"extends Node",
		"extends Control",
		"Tween",
		"Particles2D",
		"AnimationPlayer",
		"Shader",
		"draw_",
		"AudioService",
		"Input.",
	]
	for filename: String in DirAccess.get_files_at("res://src/domain"):
		if not filename.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string("res://src/domain/" + filename)
		for token: String in forbidden:
			assert_false(
				source.contains(token),
				"%s keeps presentation token %s out of deterministic math" % [filename, token]
			)


func test_each_slot_reel_emits_a_stop_impact_without_changing_its_symbol() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(SLOT_DEFINITION)
	var panel: CabinetPanel = session.cabinet.panel
	var before: Array[int] = []
	for reel_index: int in range(3):
		before.append(panel._slot_reel_cells[reel_index][2].symbol_index)
	panel.set_status("ROUND_SPINNING")
	panel._process(2.2)
	var bursts := panel.find_children("*", "CPUParticles2D", true, false)
	assert_eq(bursts.size(), 3, "Every stopped reel emits one bounded presentation burst")
	var after: Array[int] = []
	for reel_index: int in range(3):
		after.append(panel._slot_reel_cells[reel_index][2].symbol_index)
	assert_eq(after, before, "Stop particles never alter evaluated reel symbols")
