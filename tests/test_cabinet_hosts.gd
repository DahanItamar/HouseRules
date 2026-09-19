extends GutTest

const DEFINITIONS: Array[String] = [
	"res://data/cabinets/slot_classic.tres",
	"res://data/cabinets/blackjack.tres",
	"res://data/cabinets/minefield_vault.tres",
]
const SLOT_REELS := Rect2(166, 151, 628, 234)
const SLOT_CREDITS := Rect2(48, 430, 128, 94)
const SLOT_LEVER := Rect2(820, 250, 80, 150)
const VAULT_GRID := Rect2(342, 122, 296, 296)
const VAULT_STATUS := Rect2(48, 150, 280, 122)
const VAULT_DECK := Rect2(48, 424, 864, 116)
const HOW_TO_PLAY := Rect2(770, 28, 142, 38)
## Hexbound Vault crypt: the back wall meets the flagstones at ~y370; her boots
## must land on the flagstones in front of it and above the control deck.
const VAULT_FLOOR_TOP := 380.0
const VAULT_FLOOR_FRONT := 393.0
var _starting_test_mode: bool
var _starting_balance: int


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	_starting_balance = Wallet.balance
	Wallet.test_mode_enabled = false
	Wallet.reset(500)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.test_mode_enabled = _starting_test_mode
	Wallet.reset(_starting_balance)


func _open(definition_path: String) -> CabinetPanel:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(load(definition_path))
	return session.cabinet.panel


func _host_pose_textures(panel: CabinetPanel) -> Array[Texture2D]:
	var host: CabinetHost
	match panel.cabinet.context.definition.id:
		&"slot_classic":
			host = panel._slot_hostess
		&"blackjack":
			host = panel._blackjack_dealer_presenter.host()
		&"minefield_vault":
			host = panel._vault_attendant
	var textures: Array[Texture2D] = []
	for id: StringName in host.pose_ids():
		textures.append(host.pose_texture(id))
	return textures


func test_each_game_has_a_unique_sharp_adult_host_pose_set() -> void:
	var owner_by_path: Dictionary = {}
	for definition_path: String in DEFINITIONS:
		var panel := _open(definition_path)
		var game_id: StringName = panel.cabinet.context.definition.id
		var textures := _host_pose_textures(panel)
		assert_gte(textures.size(), 4, "%s has directed pose masters" % game_id)
		for texture: Texture2D in textures:
			var path := texture.resource_path
			assert_true(
				path.contains("_v2")
				or path.contains("/slot_elf_princess")
				or path.contains("/vault_witcher_"),
				"%s runs on its authored master %s" % [game_id, path]
			)
			assert_false(
				owner_by_path.has(path) and owner_by_path[path] != game_id,
				"%s is not shared with another game" % path
			)
			owner_by_path[path] = game_id
			assert_gte(texture.get_width(), 1024, path)
			assert_gte(texture.get_height(), 1536, path)
			var image := texture.get_image()
			assert_ne(image.detect_alpha(), Image.ALPHA_NONE, "%s has real alpha" % path)
			var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
			for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
				assert_eq(
					image.get_pixel(corner.x, corner.y).a, 0.0, "%s corner %s" % [path, corner]
				)
	var games: Dictionary = {}
	for game_id: StringName in owner_by_path.values():
		games[game_id] = true
	assert_eq(games.size(), 3, "Every cabinet has its own authored person")


func test_authored_pose_bounds_match_the_real_alpha() -> void:
	# Lane assertions rely on the authored used_rect; keep it honest.
	for definition_path: String in [DEFINITIONS[0], DEFINITIONS[2]]:
		var panel := _open(definition_path)
		var host: CabinetHost = (
			panel._slot_hostess if definition_path == DEFINITIONS[0] else panel._vault_attendant
		)
		for id: StringName in host.pose_ids():
			var pose: CabinetHost.Pose = host._poses[id]
			var used := Rect2(pose.texture.get_image().get_used_rect())
			assert_true(
				pose.used_rect.grow(12).encloses(used),
				"%s used rect %s covers alpha %s" % [id, pose.used_rect, used]
			)


func test_slot_hostess_stays_in_the_left_lane_in_every_pose() -> void:
	var host: CabinetHost = _open(DEFINITIONS[0])._slot_hostess
	for id: StringName in host.pose_ids():
		var bounds := host.pose_bounds(id)
		assert_false(bounds.intersects(SLOT_REELS), "%s clears the reels %s" % [id, bounds])
		assert_false(bounds.intersects(SLOT_CREDITS), "%s clears the credits meter" % id)
		assert_false(bounds.intersects(SLOT_LEVER), "%s clears the lever" % id)
		assert_lte(bounds.end.y, 430.0, "%s stands above the deck" % id)
		assert_gte(bounds.position.x, 0.0)
	assert_false(host.visual_bounds().intersects(SLOT_REELS))
	assert_lte(host.lane_bounds().end.x, 166.0)


func test_slot_hostess_faces_the_reels_and_keeps_a_planted_stature() -> void:
	var host: CabinetHost = _open(DEFINITIONS[0])._slot_hostess
	var idle := host.pose_bounds(&"idle")
	var win := host.pose_bounds(&"win")
	# Presenting arm extends toward the reels (screen-right of the body).
	assert_gt(idle.end.x - host.anchor_point.x - host.position.x, 40.0)
	# The smaller-painted win master is rescaled to the same planted feet.
	assert_almost_eq(idle.end.y, win.end.y, 2.0)
	assert_almost_eq(host.pose_bounds(&"reels").end.y, idle.end.y, 2.5)


func test_vault_attendant_stands_on_the_floor_clear_of_every_control() -> void:
	var panel := _open(DEFINITIONS[2])
	var host: CabinetHost = panel._vault_attendant
	var meter := Rect2(panel._vault_cashout_meter.position, panel._vault_cashout_meter.size)
	var protected: Array[Rect2] = [
		VAULT_GRID,
		meter,
		VAULT_STATUS,
		VAULT_DECK,
		HOW_TO_PLAY,
		Rect2(panel._vault_open.position, panel._vault_open.size),
		Rect2(panel._vault_cash_out.position, panel._vault_cash_out.size),
	]
	for id: StringName in host.pose_ids():
		var bounds := host.pose_bounds(id)
		for rect: Rect2 in protected:
			assert_false(bounds.intersects(rect), "%s %s clears %s" % [id, bounds, rect])
		assert_gte(bounds.position.y, 0.0, "%s is fully visible" % id)
		assert_lte(bounds.end.x, 912.0, "%s stays inside TV-safe bounds" % id)
		# Grounded: her shoes land on the visible floor stage, not on the wall.
		assert_gte(bounds.end.y, VAULT_FLOOR_TOP, "%s feet reach the floor" % id)
		assert_lte(bounds.end.y, VAULT_FLOOR_FRONT, "%s feet stay on the stage" % id)
	var feet_y := host.position.y + host.anchor_point.y
	assert_between(feet_y, VAULT_FLOOR_TOP, VAULT_FLOOR_FRONT)
	assert_not_null(host.find_child("HostContactShadow", true, false), "Shoes meet the floor")
	# Turned toward the grid: the indicating hand reaches left of the body.
	var indicate := host.pose_bounds(&"indicate")
	assert_lt(indicate.position.x, host.position.x + host.anchor_point.x - 40.0)


func test_vault_cashout_meter_moved_to_the_left_column() -> void:
	var panel := _open(DEFINITIONS[2])
	var meter := Rect2(panel._vault_cashout_meter.position, panel._vault_cashout_meter.size)
	assert_eq(meter.size, Vector2(262, 76), "Meter keeps its size")
	assert_gte(meter.position.y, VAULT_STATUS.end.y, "Directly under the status panel")
	assert_almost_eq(meter.position.x, VAULT_STATUS.position.x, 0.5)
	assert_false(meter.intersects(VAULT_GRID))
	assert_false(meter.intersects(VAULT_DECK))
	var safe := Rect2(48, 27, 864, 486)
	assert_true(safe.encloses(meter), "Meter stays inside TV-safe bounds")


func test_slot_hostess_beats_follow_the_spin_and_result() -> void:
	var panel := _open(DEFINITIONS[0])
	var host: CabinetHost = panel._slot_hostess
	assert_eq(host.current_pose, &"idle", "Calm idle presents the reels")
	host.watch_spin()
	assert_eq(host.current_pose, &"reels", "Spin: she watches the reel window")
	assert_true(host.has_active_gesture(), "Pose change is a cross-fade")
	await wait_seconds(0.25)
	host.anticipate()
	assert_eq(host.current_pose, &"anticipation")
	await wait_seconds(0.25)
	host.react_to_result(true)
	assert_eq(host.current_pose, &"win", "Clear win reaction")
	await wait_seconds(1.25)
	assert_eq(host.current_pose, &"player", "Then she acknowledges the player")
	await wait_seconds(1.45)
	assert_eq(host.current_pose, &"idle", "Neutral reset")
	assert_false(host.has_active_gesture())


func test_slot_spin_and_real_anticipation_drive_the_hostess() -> void:
	var panel := _open(DEFINITIONS[0])
	panel.begin_slot_spin([2, 2, 4], func() -> void: pass)
	assert_eq(panel._slot_hostess.current_pose, &"reels")
	assert_true(panel._slot_anticipating_third)
	await wait_seconds(1.5)
	assert_eq(
		panel._slot_hostess.current_pose,
		&"anticipation",
		"Hands clasp only during the outcome-driven third-reel beat"
	)


func test_vault_attendant_beats_track_the_round() -> void:
	var host: CabinetHost = _open(DEFINITIONS[2])._vault_attendant
	assert_eq(host.current_pose, &"idle", "Calm security idle between rounds")
	host.set_round_active(true)
	assert_eq(host.current_pose, &"indicate", "Live round: she indicates the grid")
	await wait_seconds(0.3)
	host.acknowledge_safe()
	assert_eq(host.current_pose, &"indicate", "Safe tile keeps the indication")
	assert_true(host.has_active_gesture())
	await wait_seconds(0.12)
	assert_between(host._figure.skew, -0.0041, 0.0, "Safe nod is small and bounded")
	await wait_seconds(0.3)
	assert_eq(host._figure.skew, 0.0)
	host.warn_mine()
	assert_eq(host.current_pose, &"warning")
	host.set_round_active(false)
	await wait_seconds(2.1)
	assert_eq(host.current_pose, &"idle", "Resets to idle once the round is over")
	host.present_cash_out()
	assert_eq(host.current_pose, &"cashout")


func test_host_idle_breath_is_bounded_and_cross_fades_never_ghost() -> void:
	var host: CabinetHost = _open(DEFINITIONS[0])._slot_hostess
	for step: int in range(12):
		host._process(0.37)
		assert_lte(host.breath_offset_pixels(), CabinetHost.BREATH_PIXELS + 0.001)
	host.watch_spin()
	await wait_seconds(0.12)
	var incoming: Sprite2D = host._sprites[&"reels"]
	var outgoing: Sprite2D = host._sprites[&"idle"]
	assert_true(incoming.visible and outgoing.visible, "Both poses overlap mid-fade")
	assert_gte(
		incoming.modulate.a + outgoing.modulate.a * (1.0 - incoming.modulate.a),
		0.85,
		"Stacked cross-fade keeps the figure opaque"
	)
	await wait_seconds(0.4)
	assert_false(outgoing.visible, "Outgoing pose is released after the fade")
	assert_eq(host._figure.skew, 0.0, "Weight shift settles back")


func test_reduced_motion_holds_the_master_pose_with_one_bounded_cue() -> void:
	for definition_path: String in [DEFINITIONS[0], DEFINITIONS[2]]:
		MotionPolicy.set_reduced_motion_for_tests(true)
		var panel := _open(definition_path)
		var host: CabinetHost = (
			panel._slot_hostess if definition_path == DEFINITIONS[0] else panel._vault_attendant
		)
		assert_false(host.is_processing())
		assert_eq(host.current_pose, host.master_pose)
		assert_eq(host._figure.scale, Vector2.ONE)
		if definition_path == DEFINITIONS[0]:
			host.watch_spin()
		else:
			host.set_round_active(true)
			host.warn_mine()
		assert_eq(host.current_pose, host.master_pose, "Static pose in reduced motion")
		assert_eq(host._cue.modulate.a, 1.0, "One cue acknowledges the beat")
		await wait_seconds(0.3)
		assert_eq(host._cue.modulate.a, CabinetHost.CUE_REST_ALPHA, "Cue settles, never loops")
		assert_eq(host.current_pose, host.master_pose)


func test_enabling_reduced_motion_mid_beat_settles_to_rest_immediately() -> void:
	var host: CabinetHost = _open(DEFINITIONS[0])._slot_hostess
	host.react_to_result(true)
	await wait_seconds(0.08)
	assert_true(host.has_active_gesture())
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(host.has_active_gesture())
	assert_eq(host.current_pose, host.master_pose)
	assert_eq(host._figure.skew, 0.0)
	assert_eq(host._figure.scale, Vector2.ONE)
	for id: StringName in host.pose_ids():
		assert_eq((host._sprites[id] as Sprite2D).visible, id == host.master_pose)


func test_slot_elf_princess_clears_every_protected_slot_rect() -> void:
	var panel := _open(DEFINITIONS[0])
	var host: CabinetHost = panel._slot_hostess
	for id: StringName in host.pose_ids():
		var path := host.pose_texture(id).resource_path
		assert_string_starts_with(
			path, "res://assets/production/characters/hosts/slot_elf_princess", "%s is the elf" % id
		)
	var lever: SlotLever = panel._slot_lever
	var lever_target: Button = lever.get_node("LeverHitTarget")
	var protected: Array[Rect2] = [
		SLOT_REELS,
		SLOT_CREDITS,
		Rect2(panel._title.position, panel._title.size),
		Rect2(panel._status.position, panel._status.size),
		Rect2(panel._slot_payline.position, panel._slot_payline.size).intersection(SLOT_REELS),
		Rect2(lever.position + lever_target.position, lever_target.size),
		Rect2(panel._slot_spin_label.position, panel._slot_spin_label.size),
		Rect2(panel._stake_selector.position, panel._stake_selector.size),
		(panel.find_child("SlotBetTray", true, false) as Control).get_rect(),
		(panel.find_child("SlotResultMeter", true, false) as Control).get_rect(),
	]
	for id: StringName in host.pose_ids():
		var bounds := host.pose_bounds(id)
		for rect: Rect2 in protected:
			assert_false(bounds.intersects(rect), "%s %s clears %s" % [id, bounds, rect])
		assert_gte(bounds.position.x, 0.0, "%s stays on screen" % id)
		assert_gte(bounds.position.y, 27.0, "%s stays inside the TV-safe top" % id)
