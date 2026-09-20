extends GutTest
## Cabinet backdrop ambience: one presentation-only layer per game, sitting on the
## painted backdrop under every gameplay node, inside its alpha caps, frozen by
## reduced motion and clear of the protected gameplay rectangles.

const CABINETS: Array[StringName] = [
	&"slot_classic",
	&"blackjack",
	&"minefield_vault",
	&"roulette",
	&"poker",
	&"baccarat",
	&"match_point",
]
const HOW_TO_PLAY := Rect2(770, 27, 142, 44)
const CONTROL_DECK := Rect2(48, 425, 864, 110)
## Gameplay rectangles moving accents (sparks, sweeps, drifting shade) must avoid.
const PROTECTED: Dictionary = {
	&"slot_classic":
	[
		Rect2(158, 145, 644, 252),  # reel window and payline
		Rect2(262, 30, 438, 72),  # title and status plaque
		Rect2(840, 196, 44, 190),  # lever and its mount
		HOW_TO_PLAY,
		CONTROL_DECK,
	],
	&"minefield_vault":
	[
		Rect2(332, 112, 316, 316),  # tile grid bed
		Rect2(48, 150, 280, 210),  # status plaque and cash-out meter
		HOW_TO_PLAY,
		CONTROL_DECK,
	],
	&"roulette":
	[
		RouletteTablePanel.TITLE_RECT,
		RouletteTablePanel.RESULT_RECT,
		Rect2(296, 96, 616, 88),  # guest seat plates
		Rect2(296, 212, 616, 222),  # betting board
		HOW_TO_PLAY,
		CONTROL_DECK,
	],
	&"baccarat":
	[
		BaccaratTablePanel.TITLE_RECT,
		BaccaratTablePanel.RESULT_RECT,
		BaccaratTablePanel.PLAYER_ZONE,
		BaccaratTablePanel.BANKER_ZONE,
		BaccaratTablePanel.SHOE_RECT,
		Rect2(96, 346, 768, 82),  # betting spots
		Rect2(636, 80, 276, 133),  # bead road
		HOW_TO_PLAY,
		CONTROL_DECK,
	],
	&"match_point":
	[
		Rect2(283, 0, 394, 440),  # plinko court and drop slots
		MatchPointPanel.TITLE_RECT,
		MatchPointPanel.RISK_RECT,
		MatchPointPanel.HELP_RECT,
		CONTROL_DECK,
	],
	&"poker":
	[
		PokerTablePanel.POT_PLATE_RECT,
		PokerTablePanel.RESULT_RECT,
		PokerTablePanel.DECK_RECT,
		HOW_TO_PLAY,
	],
	&"blackjack": [Rect2(300, 150, 360, 280), HOW_TO_PLAY, CONTROL_DECK],
}
const SAMPLE_TIMES: Array[float] = [0.0, 0.7, 1.9, 3.3, 5.1, 7.6, 9.9, 12.4, 17.8, 29.3, 61.0]

var _starting_test_mode: bool
var _starting_balance: int


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	Wallet.set_test_mode(true)
	Wallet.reset(5000)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.set_test_mode(false)
	Wallet.reset(_starting_balance)
	Wallet.set_test_mode(_starting_test_mode)


func _open(cabinet_id: StringName) -> CabinetPanel:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(load("res://data/cabinets/%s.tres" % cabinet_id))
	return session.cabinet.panel


func test_every_cabinet_gets_its_own_layer_directly_on_the_backdrop() -> void:
	var scripts: Dictionary = {}
	for cabinet_id: StringName in CABINETS:
		var panel := _open(cabinet_id)
		var layer := CabinetAmbience.find(panel)
		assert_not_null(layer, "%s has backdrop ambience" % cabinet_id)
		if layer == null:
			continue
		var art := panel.get_node("CabinetArt")
		var anchor := art.get_node(String(CabinetAmbience.LAYERS[cabinet_id]["anchor"]))
		assert_same(layer.get_parent(), art)
		assert_eq(
			layer.get_index(), anchor.get_index() + 1, "%s sits right on the backdrop" % cabinet_id
		)
		assert_eq(layer.cabinet_id, cabinet_id)
		assert_same(CabinetAmbience.attach(panel), layer, "Attaching twice keeps one layer")
		scripts[cabinet_id] = layer.get_script()
	assert_ne(scripts[&"slot_classic"], scripts[&"minefield_vault"])
	assert_ne(scripts[&"roulette"], scripts[&"baccarat"])
	assert_ne(scripts[&"match_point"], scripts[&"blackjack"])


func test_ambient_layers_draw_under_every_gameplay_node() -> void:
	for cabinet_id: StringName in CABINETS:
		var panel := _open(cabinet_id)
		var layer := CabinetAmbience.find(panel)
		var art := panel.get_node("CabinetArt")
		# Relative z 0 inside the art root: nothing it draws can rise above a sibling
		# added after it, nor above the panel's own controls, cards and plates.
		assert_eq(layer.z_index, 0)
		assert_true(layer.z_as_relative)
		for canvas: CanvasItem in [layer.light_canvas, layer.shade_canvas]:
			assert_eq(canvas.z_index, 0, "%s canvases stay at the backdrop depth" % cabinet_id)
		for index: int in range(layer.get_index() + 1, art.get_child_count()):
			var sibling := art.get_child(index) as CanvasItem
			if sibling != null:
				assert_gte(sibling.z_index, 0, "%s gameplay art is above the layer" % cabinet_id)
		assert_lt(art.get_index(), panel.get_child_count() - 1, "Controls follow the art root")


func test_ambient_alpha_stays_under_the_caps() -> void:
	for cabinet_id: StringName in CABINETS:
		var layer := CabinetAmbience.find(_open(cabinet_id))
		for at_time: float in SAMPLE_TIMES:
			var peaks: Dictionary = layer.sample_alpha_peaks(at_time)
			assert_lte(
				peaks["pool"], AmbientLayer.POOL_ALPHA_CAP, "%s pool %.1f" % [cabinet_id, at_time]
			)
			assert_lte(peaks["shadow"], AmbientLayer.SHADOW_ALPHA_CAP)
			assert_lte(peaks["sweep"], AmbientLayer.SWEEP_ALPHA_CAP)
			assert_lte(peaks["spark"], AmbientLayer.SPARK_ALPHA_CAP)
		# Authored strengths respect the cap before any clamping.
		for index: int in range(layer.pool_count()):
			assert_lte(
				layer._pool_strength[index] * (1.0 + layer._pool_depth[index]),
				AmbientLayer.POOL_ALPHA_CAP + 0.0001,
				"%s pool %d is authored under the cap" % [cabinet_id, index]
			)


func test_ambient_actually_moves_with_full_motion() -> void:
	for cabinet_id: StringName in CABINETS:
		var layer := CabinetAmbience.find(_open(cabinet_id))
		var first: Dictionary = layer.sample_alpha_peaks(1.0)
		var changed := false
		for at_time: float in SAMPLE_TIMES:
			if layer.sample_alpha_peaks(at_time) != first:
				changed = true
		if cabinet_id != &"match_point":
			assert_true(changed, "%s ambience breathes over time" % cabinet_id)
	var clouds = CabinetAmbience.find(_open(&"match_point"))
	assert_ne(clouds.cloud_center(0, 0.0), clouds.cloud_center(0, 5.0), "Cloud shadows drift")


func test_reduced_motion_holds_every_layer_still() -> void:
	var layers: Array[AmbientLayer] = []
	for cabinet_id: StringName in CABINETS:
		layers.append(CabinetAmbience.find(_open(cabinet_id)))
	for layer: AmbientLayer in layers:
		layer._process(2.5)
	MotionPolicy.set_reduced_motion_for_tests(true)
	for layer: AmbientLayer in layers:
		assert_true(layer.reduced_motion)
		assert_false(layer.is_processing(), "%s stops processing" % layer.cabinet_id)
		assert_eq(layer.elapsed, AmbientLayer.REST_ELAPSED)
		var rest: Dictionary = layer.sample_alpha_peaks(0.0)
		for at_time: float in SAMPLE_TIMES:
			assert_eq(layer.sample_alpha_peaks(at_time), rest, "%s is static" % layer.cabinet_id)
		assert_eq(rest["sweep"], 0.0, "No sweeps under reduced motion")
		assert_eq(rest["spark"], 0.0, "No sparks under reduced motion")
		for index: int in range(layer.pool_count()):
			assert_eq(
				layer.pool_alpha_at(index), layer._pool_strength[index], "Pools rest at average"
			)
		for child: Node in layer.get_children():
			if child is AmbientSweep:
				assert_false((child as AmbientSweep).visible)
	var roulette_layer = layers[CABINETS.find(&"roulette")]
	assert_false(roulette_layer.wheel_sweep.visible, "The wheel sweep is hidden")
	var clouds = layers[CABINETS.find(&"match_point")]
	assert_eq(clouds.cloud_center(0, 0.0), clouds.cloud_center(0, 30.0), "Clouds hold still")


func test_moving_accents_stay_clear_of_protected_gameplay() -> void:
	for cabinet_id: StringName in CABINETS:
		var layer := CabinetAmbience.find(_open(cabinet_id))
		var protected: Array = PROTECTED[cabinet_id]
		for bounds: Rect2 in layer.moving_effect_bounds():
			assert_true(
				Rect2(0, 0, 960, 540).encloses(bounds), "%s effect stays on screen" % cabinet_id
			)
			for rect: Rect2 in protected:
				assert_false(
					bounds.intersects(rect),
					"%s effect %s clears protected %s" % [cabinet_id, bounds, rect]
				)


func test_roulette_sweep_rides_directly_above_the_wheel() -> void:
	var panel := _open(&"roulette")
	var layer = CabinetAmbience.find(panel)
	var art := panel.get_node("CabinetArt")
	var wheel := art.get_node("RouletteWheel")
	assert_not_null(layer.wheel_sweep)
	assert_eq(layer.wheel_sweep.get_index(), wheel.get_index() + 1)
	assert_lt(
		layer.get_index(), wheel.get_index(), "Sconce pools stay behind the croupier and wheel"
	)
	assert_eq(layer.WHEEL_CENTER, RouletteTablePanel.WHEEL_CENTER)
	assert_eq(layer.WHEEL_RADIUS, RouletteTablePanel.WHEEL_RADIUS)
	assert_eq(layer.WHEEL_SQUASH, RouletteTablePanel.WHEEL_SQUASH)
