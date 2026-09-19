extends GutTest

const PRACTICAL_LIGHT_RIG := preload("res://src/floor/practical_light_rig.gd")


func before_each() -> void:
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()


func test_practical_fixture_loop_is_deterministic_staggered_and_bounded() -> void:
	var rig: Node2D = PRACTICAL_LIGHT_RIG.new()
	add_child_autofree(rig)
	var first_pass: Array[float] = []
	var second_pass: Array[float] = []
	for index: int in range(PRACTICAL_LIGHT_RIG.FIXTURES.size()):
		first_pass.append(rig.fixture_intensity(index, 3.25))
		second_pass.append(rig.fixture_intensity(index, 3.25))
		assert_between(first_pass[index], 0.48, 0.96)
	assert_eq(first_pass, second_pass)
	assert_ne(first_pass[0], first_pass[1], "Fixtures use authored phase offsets")
	assert_almost_eq(
		rig.reflection_offset(2.4),
		rig.reflection_offset(2.4 + PRACTICAL_LIGHT_RIG.LOOP_SECONDS),
		0.0001
	)
	assert_lte(absf(rig.reflection_offset(3.0)), 18.0)


func test_reduced_motion_holds_the_exact_canonical_light_frame() -> void:
	var rig: Node2D = PRACTICAL_LIGHT_RIG.new()
	add_child_autofree(rig)
	rig._process(4.75)
	assert_gt(rig.elapsed, 0.0)
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_true(rig.reduced_motion)
	assert_false(rig.is_processing())
	assert_eq(rig.elapsed, PRACTICAL_LIGHT_RIG.REST_ELAPSED)
	var canonical: Array[float] = []
	for index: int in range(PRACTICAL_LIGHT_RIG.FIXTURES.size()):
		canonical.append(rig.fixture_intensity(index))
	rig._process(1.0)
	rig.apply_motion_preference(true)
	var held: Array[float] = []
	for index: int in range(PRACTICAL_LIGHT_RIG.FIXTURES.size()):
		held.append(rig.fixture_intensity(index))
	assert_eq(held, canonical)
	assert_eq(rig.reflection_offset(), 0.0)


func test_floor_owns_the_practical_rig_as_presentation_only_environment() -> void:
	var floor := FloorController.new()
	add_child_autofree(floor)
	floor.set_physics_process(false)
	assert_not_null(floor._practical_lights)
	assert_eq(floor._practical_lights.get_parent(), floor)
	assert_eq(floor._practical_lights.name, "PracticalLightRig")
