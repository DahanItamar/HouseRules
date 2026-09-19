extends GutTest

const FOREGROUND_SCRIPT := preload("res://src/floor/floor_foreground.gd")


func test_foreground_builds_named_textured_object_fronts() -> void:
	var foreground := FOREGROUND_SCRIPT.new() as Node2D
	add_child_autofree(foreground)
	assert_eq(foreground.occluder_count(), 6)
	for expected_name: String in [
		"SlotMachineFront",
		"BlackjackMachineFront",
		"VaultMachineFront",
		"LoungeFront",
		"CashierFront",
		"PlanterFront",
	]:
		var patch := foreground.get_node_or_null(expected_name) as Polygon2D
		assert_not_null(patch)
		assert_same(patch.texture, FOREGROUND_SCRIPT.FLOOR_ART)
		assert_eq(patch.polygon.size(), patch.uv.size())


func test_foreground_uvs_sample_the_same_pixels_as_the_scaled_background() -> void:
	var foreground := FOREGROUND_SCRIPT.new() as Node2D
	add_child_autofree(foreground)
	var scale := Vector2(FOREGROUND_SCRIPT.FLOOR_ART.get_size()) / FOREGROUND_SCRIPT.VIEW_SIZE
	for patch: Polygon2D in foreground.get_children():
		for index: int in range(patch.polygon.size()):
			assert_eq(patch.uv[index], patch.polygon[index] * scale)
