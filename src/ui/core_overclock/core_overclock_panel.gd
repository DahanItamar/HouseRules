class_name CoreOverclockPanel
extends CabinetPanel
## Corsair's Reach cabinet presentation, laid out on the centre line: the chart
## and the climb in the middle of the screen with the multiplier read off it, the
## crew in lanes down either edge, and the shared control deck across the foot.
## The auto-haul target sits top-left, mirroring How to play top-right.
##
## Game state is read from the cabinet every frame and never written. The run is
## already decided when it starts; this only replays it.

const STAGE_NAME := "CorsairStage"
## Shake starts only once the climb is genuinely long, and stays small.
const SHAKE_FROM: float = 0.30
const SHAKE_PIXELS: float = 3.2
const CRASH_IMPULSE: float = 8.0
const IMPULSE_DECAY: float = 22.0
## The swell's pulse: the interval shortens and the pitch rises with the climb.
const PULSE_SLOW: float = 0.50
const PULSE_FAST: float = 0.13
const ROAR_FROM: float = 0.40
const ROAR_SLOW: float = 0.62
const ROAR_FAST: float = 0.30
## How long a settled run is held on screen before the line is cleared.
const SETTLE_SECONDS: float = 2.4
## How long the ship's break-up plays for.
## How far inside the chart frame wreckage and spray are held, in canvas px.
const BURST_INSET: float = 62.0
const WRECK_SECONDS: float = 0.9
const NOTICE_SECONDS: float = 1.8

var backdrop: CoreOverclockBackdrop
var gauge: CoreOverclockGauge
var history: CoreOverclockHistory
var hosts: CoreOverclockHosts
var burst: CoreOverclockBurst
var flight: CoreOverclockFlight
## The ship breaking up, played once when a run is taken.
var _wreck: Sprite2D
var _wreck_left: float = 0.0
var _wreck_at: Vector2 = Vector2.ZERO
var deck: CabinetDeck
var primary_button: PromptButton
var auto_button: PromptButton
var _stage: Control
var _built: bool = false
var _shown_state: int = CoreOverclockMath.State.IDLE
var _shake_phase: float = 0.0
var _impulse: float = 0.0
var _pulse_left: float = 0.0
var _roar_left: float = 0.0
var _settle_left: float = 0.0
var _notice_key: String = ""
var _notice: Tween


func refresh() -> void:
	if _title == null or cabinet == null or cabinet.context == null:
		return
	if not _built:
		_build_cabinet()
	_title.text = tr("CORE_OVERCLOCK_THEME_TITLE")
	_refresh_status()
	_refresh_deck()
	_refresh_gauge()
	_refresh_help()


func _math() -> CoreOverclockMath:
	return cabinet.get("math") as CoreOverclockMath


func _state() -> int:
	var math := _math()
	return CoreOverclockMath.State.IDLE if math == null else math.state


func _is_open() -> bool:
	return not cabinet.is_round_active and not cabinet.is_result_pending and not help_open


## Every rectangle the cabinet promises to keep readable.
func protected_rects() -> Array[Rect2]:
	return [
		gauge.dial_rect(),
		CoreOverclockTheme.HISTORY_RECT,
		CoreOverclockTheme.AUTO_RECT,
		CabinetDeck.DECK_RECT,
	]


func _build_cabinet() -> void:
	_built = true
	_art_id = cabinet.context.definition.id
	_frame.position = Vector2.ZERO
	_frame.size = Vector2(960, 540)
	_frame.color = CoreOverclockTheme.NIGHT
	for hidden: CanvasItem in [
		_stake, _detail, _controls, _controls_backdrop, _stake_selector, _lighting
	]:
		hidden.hide()
	_stake_selector.process_mode = Node.PROCESS_MODE_DISABLED
	_stage = Control.new()
	_stage.name = STAGE_NAME
	_stage.size = Vector2(960, 540)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	backdrop = CoreOverclockBackdrop.new()
	backdrop.size = Vector2(960, 540)
	_stage.add_child(backdrop)
	_build_left_column()
	_build_hosts()
	_build_flight()
	gauge = CoreOverclockGauge.new()
	gauge.position = CoreOverclockTheme.GAUGE_CENTRE - gauge.size * 0.5
	gauge.bare = true
	gauge.z_index = 6
	gauge.whole_multiple_passed.connect(_on_whole_multiple)
	_stage.add_child(gauge)
	burst = CoreOverclockBurst.new()
	burst.z_index = 8
	burst.bounds = CoreOverclockTheme.FLIGHT_AREA
	_stage.add_child(burst)
	_build_title_plate()
	_build_deck()
	_build_timer_control()
	_style_help_button()
	_sync_state(true)
	call_deferred("_focus_default_action")


## The recent-runs strip in the top-left corner, on the same brass-and-rope
## plate language as the title and the auto-haul target.
##
## A second drawn curve used to sit above it and plot the multiplier the readout
## was already showing. Two readouts of one number is one too many, so that curve
## is gone and the climb over the chart carries the tension instead.
func _build_left_column() -> void:
	var border := CoreOverclockTheme.frame_border()
	_stage.add_child(
		CoreOverclockTheme.frame_plate("CorsairRecentPlate", CoreOverclockTheme.HISTORY_RECT)
	)
	history = CoreOverclockHistory.new()
	history.position = CoreOverclockTheme.HISTORY_RECT.position + Vector2.ONE * border
	history.size = CoreOverclockTheme.HISTORY_RECT.size - Vector2.ONE * border * 2.0
	history.z_index = 2
	history.set_caption(tr("CORE_OVERCLOCK_RECENT"))
	_stage.add_child(history)


## Both of the crew, as one layer. Each state of the run is a single painted
## frame with both of them in it, so their reaction is shared by construction.
func _build_hosts() -> void:
	hosts = CoreOverclockHosts.new()
	hosts.z_index = 4
	_stage.add_child(hosts)


## The parrot and the line she draws. This is the multiplier made visible: she
## climbs the same curve the number does, and the trail is where she has been.
func _build_flight() -> void:
	# The chart frame is laid first so the swell draws inside it.
	var chart := NinePatchRect.new()
	chart.name = "CorsairChartFrame"
	chart.texture = CoreOverclockTheme.FRAME_CHART
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		chart.set_patch_margin(side, CoreOverclockTheme.FRAME_CHART_MARGIN)
	var chart_scale := 0.22
	chart.scale = Vector2.ONE * chart_scale
	var box := CoreOverclockTheme.FLIGHT_AREA.grow(CoreOverclockTheme.frame_chart_border())
	chart.position = box.position
	chart.size = box.size / chart_scale
	chart.z_index = 2
	_stage.add_child(chart)
	flight = CoreOverclockFlight.new()
	flight.area = CoreOverclockTheme.FLIGHT_AREA
	flight.z_index = 3
	_stage.add_child(flight)
	_wreck = Sprite2D.new()
	_wreck.name = "CorsairWreck"
	_wreck.texture = CoreOverclockTheme.WRECK
	_wreck.region_enabled = true
	_wreck.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_wreck.visible = false
	_wreck.z_index = 5
	_stage.add_child(_wreck)


func _build_title_plate() -> void:
	var plate := CoreOverclockTheme.frame_plate(
		"CorsairTitlePlate", CoreOverclockTheme.TITLE_RECT, 0.075
	)
	plate.z_index = 5
	add_child(plate)
	var inner := CoreOverclockTheme.TITLE_RECT.grow(-CoreOverclockTheme.frame_border(0.075))
	_title.position = inner.position
	_title.size = Vector2(inner.size.x, 26.0)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", CoreOverclockTheme.BRASS_BRIGHT)
	_title.z_index = 6
	_status.position = inner.position + Vector2(0, 28)
	_status.size = Vector2(inner.size.x, 18.0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 14)
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.add_theme_color_override("font_color", CoreOverclockTheme.MUTED)
	_status.z_index = 6


func _build_deck() -> void:
	deck = CabinetDeck.new()
	deck.name = "CorsairControlDeck"
	deck.z_index = 6
	add_child(deck)
	deck.build(CoreOverclockTheme.deck_style())
	deck.balance.caption = tr("DECK_BALANCE")
	deck.bet.step_requested.connect(_on_deck_bet_step)
	deck.quick_bets.operation_requested.connect(_on_quick_bet)
	primary_button = deck.add_action(
		&"primary", tr("CORE_OVERCLOCK_ACTION_LAUNCH"), &"interact", true
	)
	primary_button.name = "CorsairPrimaryAction"
	deck.action_pressed.connect(_on_deck_action)


## The auto-haul target mirrors How to play at the other end of the header, so
## the two settings sit at the same height and the header stays balanced. The
## deck itself is full: balance, bet, the shared quick-bet row and the primary
## key.
func _build_timer_control() -> void:
	var style := CoreOverclockTheme.deck_style()
	auto_button = PromptButton.new()
	auto_button.name = "CorsairAutoHaulAction"
	auto_button.text = tr("CORE_OVERCLOCK_AUTO_OFF")
	auto_button.action = &"secondary"
	auto_button.focus_mode = Control.FOCUS_ALL
	auto_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	auto_button.add_theme_font_override("font", Typography.DISPLAY_FONT)
	auto_button.add_theme_font_size_override("font_size", 16)
	auto_button.position = CoreOverclockTheme.AUTO_RECT.position
	auto_button.size = CoreOverclockTheme.AUTO_RECT.size
	auto_button.z_index = 6
	style.style_button(auto_button, style.secondary_face, style.secondary_edge, false)
	auto_button.pressed.connect(func() -> void: cabinet.call("cycle_auto_target"))
	add_child(auto_button)
	ButtonFeedback.attach(auto_button)
	_link_focus()


## The deck's bet steppers are pointer and shoulder-button controls and never
## take focus, so the focus row is the auto-haul target, the primary key and Help.
func _link_focus() -> void:
	# The header reads left to right - the target, then How to play - and both
	# drop to the primary key at the foot of the screen.
	auto_button.focus_neighbor_right = auto_button.get_path_to(_help_button)
	auto_button.focus_neighbor_bottom = auto_button.get_path_to(primary_button)
	_help_button.focus_neighbor_left = _help_button.get_path_to(auto_button)
	_help_button.focus_neighbor_bottom = _help_button.get_path_to(primary_button)
	primary_button.focus_neighbor_left = primary_button.get_path_to(auto_button)
	primary_button.focus_neighbor_top = primary_button.get_path_to(_help_button)


func _style_help_button() -> void:
	if _help_button == null:
		return
	_help_button.add_theme_font_override("font", Typography.UI_FONT)
	_help_button.add_theme_font_size_override("font_size", 15)


func _on_deck_action(id: StringName) -> void:
	if id == &"primary":
		cabinet.call("request_primary")


## The shared MIN / 10 / 25 / X2 / X5 / ALL keys, applied under the cabinet's
## own bet rules.
func _on_quick_bet(operation: int) -> void:
	if cabinet.apply_bet(operation):
		refresh()


## Each whole multiple the climb passes gets one tick, in step with the pop the
## readout gives the number.
func _on_whole_multiple() -> void:
	AudioService.play(&"corsair_tick", 1.0 + CoreOverclockTheme.climb_of(gauge.centi) * 0.7)


func _focus_default_action() -> void:
	if help_open or not is_inside_tree() or primary_button == null:
		return
	primary_button.grab_focus()


## WASD/D-pad focus walk between the auto-haul target, the primary key and Help.
func navigate(direction: Vector2i) -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not _owns_control(focused):
		_focus_default_action()
		return true
	var side := SIDE_LEFT
	match direction:
		Vector2i.RIGHT:
			side = SIDE_RIGHT
		Vector2i.UP:
			side = SIDE_TOP
		Vector2i.DOWN:
			side = SIDE_BOTTOM
	var next := focused.find_valid_focus_neighbor(side)
	if next != null and next != focused:
		next.grab_focus()
		AudioService.play(&"move")
	return true


func _owns_control(control: Control) -> bool:
	return control == _help_button or control == primary_button or control == auto_button


## Transient message (for example: no stake the bankroll can cover).
func show_notice(key: String) -> void:
	_notice_key = key
	if _notice != null and _notice.is_valid():
		_notice.kill()
	_notice = create_tween()
	_notice.tween_interval(NOTICE_SECONDS)
	_notice.tween_callback(
		func() -> void:
			_notice_key = ""
			refresh()
	)
	refresh()


## The cabinet has locked the stake and decided the run; start the replay.
func begin_run() -> void:
	_result = null
	gauge.reset()
	gauge.set_number_color(CoreOverclockTheme.CREAM)
	burst.clear()
	# She leaves the perch; the line builds from nothing.
	flight.set_reach(0.0, true)
	_settle_left = 0.0
	_impulse = 0.0
	_pulse_left = 0.0
	_roar_left = 0.0
	AudioService.play(&"corsair_cast_off")
	_sync_state(true)
	refresh()


## Called by the cabinet every frame while the panel is on screen.
func tick(delta: float) -> void:
	if not _built:
		return
	var math := _math()
	var climbing := math.state == CoreOverclockMath.State.OVERCLOCKING
	var climb := CoreOverclockTheme.climb_of(math.multiplier_centi)
	if math.state != _shown_state:
		_sync_state(false)
	gauge.set_centi(math.multiplier_centi)
	gauge.set_climb_state(climbing)
	gauge.set_charge(
		(
			0.0
			if math.state != CoreOverclockMath.State.COUNTDOWN
			else 1.0 - math.countdown_left / maxf(math.paytable.countdown_seconds, 0.001)
		)
	)
	backdrop.set_climb(climb, climbing or math.state == CoreOverclockMath.State.COUNTDOWN)
	if climbing:
		gauge.set_value(tr("CORE_OVERCLOCK_VALUE") % math.current_payout())
		# She climbs with the multiplier: same curve, drawn instead of counted.
		flight.set_reach(climb, true)
	_advance_wreck(delta)
	_update_shake(delta, climb, climbing)
	_update_audio(delta, climb, climbing)
	if _settle_left > 0.0:
		_settle_left = maxf(_settle_left - delta, 0.0)
		if _settle_left <= 0.0:
			flight.set_reach(0.0, false)


## Reacts once to each state the run moves through.
func _sync_state(initial: bool) -> void:
	var math := _math()
	var state := math.state
	var previous := _shown_state
	_shown_state = state
	hosts.show_state(_host_state_for(state))
	if initial:
		return
	if (
		state == CoreOverclockMath.State.OVERCLOCKING
		and previous == CoreOverclockMath.State.COUNTDOWN
	):
		# She is away: a burst of spray off the water as the line goes out.
		burst.puff(_burst_point(1.0), CoreOverclockTheme.EMBER_SPRAY[0], 170.0)
		burst.sparks(_burst_point(1.0), 8)
	refresh()


## What the pair are feeling at this point in the run. Both of them feel it,
## because a state is one painted frame of the two of them.
static func _host_state_for(state: int) -> StringName:
	match state:
		CoreOverclockMath.State.OVERCLOCKING:
			return &"tense"
		CoreOverclockMath.State.CASHED_OUT:
			return &"cheer"
		CoreOverclockMath.State.CRASHED:
			return &"wince"
	return &"ready"


func _update_shake(delta: float, climb: float, climbing: bool) -> void:
	if _impulse > 0.0:
		_impulse = maxf(_impulse - delta * IMPULSE_DECAY, 0.0)
	if not MotionPolicy.allows_camera_emphasis():
		_stage.position = Vector2.ZERO
		return
	_shake_phase += delta
	var amplitude := _impulse
	if climbing and climb > SHAKE_FROM:
		amplitude = maxf(amplitude, (climb - SHAKE_FROM) / (1.0 - SHAKE_FROM) * SHAKE_PIXELS)
	if amplitude <= 0.0:
		_stage.position = Vector2.ZERO
		return
	_stage.position = (
		Vector2(sin(_shake_phase * 53.0), sin(_shake_phase * 41.0) * 0.6) * amplitude
	)


## The sea: a pulse that speeds up and rises in pitch with the climb, and a roar
## under it once the run is far enough along to be worth losing.
func _update_audio(delta: float, climb: float, climbing: bool) -> void:
	if not climbing:
		return
	_pulse_left -= delta
	if _pulse_left <= 0.0:
		AudioService.play(&"corsair_wave", 1.0 + climb * 1.4)
		_pulse_left = lerpf(PULSE_SLOW, PULSE_FAST, climb)
	if climb < ROAR_FROM:
		return
	_roar_left -= delta
	if _roar_left <= 0.0:
		AudioService.play(&"corsair_roar", 0.86 + climb * 0.4)
		_roar_left = lerpf(ROAR_SLOW, ROAR_FAST, climb)


## Called by MiniGame after CabinetSession has settled the run.
func show_result(result: RoundResult) -> void:
	_result = result
	_status_key = "ROUND_READY"
	var hauled_in: bool = result.detail.get("cashed_out", false)
	var math := _math()
	gauge.settle_pop()
	# Gold when she came home, pale when the sea took her. Both have to hold
	# against a dark canvas, so neither goes near the reds on the ramp.
	gauge.set_number_color(
		CoreOverclockTheme.BRASS_BRIGHT if hauled_in else CoreOverclockTheme.MUTED
	)
	history.set_entries(math.history)
	hosts.show_state(&"cheer" if hauled_in else &"wince")
	if hauled_in:
		_present_haul(result)
	else:
		_present_crash()
	refresh()
	call_deferred("_focus_default_action")


## She comes home with it: the line holds at the settled multiplier and the head
## of it throws spray.
func _present_haul(result: RoundResult) -> void:
	AudioService.play(&"corsair_haul")
	var multiple := float(result.payout) / maxf(result.stake, 1.0)
	flight.set_reach(CoreOverclockTheme.climb_of(_math().settled_centi), true)
	_settle_left = MotionPolicy.finite_duration(SETTLE_SECONDS)
	burst.sparks(_burst_point(1.0), 18 if multiple >= 5.0 else 10)
	burst.puff(_burst_point(0.92), CoreOverclockTheme.EMBER_SPRAY[1], 150.0)
	_win_flash.play(CoreOverclockTheme.BRASS_BRIGHT, multiple >= BIG_WIN_MULTIPLE)


## Steps the break-up through its four painted stages and then clears it.
func _advance_wreck(delta: float) -> void:
	if _wreck_left <= 0.0:
		_wreck.visible = false
		return
	_wreck_left = maxf(_wreck_left - delta, 0.0)
	var played := 1.0 - _wreck_left / maxf(WRECK_SECONDS, 0.001)
	var cells := int(CoreOverclockTheme.WRECK_GRID.x * CoreOverclockTheme.WRECK_GRID.y)
	var frame := clampi(int(played * float(cells)), 0, cells - 1)
	_wreck.region_rect = CoreOverclockTheme.sheet_region(
		frame, CoreOverclockTheme.WRECK_GRID, CoreOverclockTheme.WRECK_CELL
	)
	_wreck.position = _wreck_at
	_wreck.scale = (
		Vector2.ONE * (CoreOverclockFlight.BIRD_SPAN * 1.8 / CoreOverclockTheme.WRECK_CELL)
	)
	_wreck.visible = true


## She is taken: the needle slams, the screen goes white, and the sea closes
## over where she was.
## Where wreckage and spray may sit.
##
## Both belong at the bird, but on an early break-up the bird is in the very
## corner of the chart, and a puff 300 across centred there spills out of the
## frame and lands on the crew standing beside it and on the bet row. Held far
## enough inside that the wreck still reads as happening on the line.
func _burst_point(t: float) -> Vector2:
	var area := CoreOverclockTheme.FLIGHT_AREA
	var point := flight.crest_point(t)
	return Vector2(
		clampf(point.x, area.position.x + BURST_INSET, area.end.x - BURST_INSET),
		clampf(point.y, area.position.y + BURST_INSET, area.end.y - BURST_INSET)
	)


func _present_crash() -> void:
	AudioService.play(&"corsair_breakup")
	_wreck_at = _burst_point(1.0)
	_wreck_left = MotionPolicy.finite_duration(WRECK_SECONDS)
	flight.set_reach(CoreOverclockTheme.climb_of(maxi(_math().crash_centi, 100)), false)
	_settle_left = MotionPolicy.finite_duration(SETTLE_SECONDS)
	gauge.slam()
	burst.puff(_burst_point(1.0), CoreOverclockTheme.EMBER_SMOKE[0], 220.0, 0.9)
	burst.puff(_burst_point(0.92), CoreOverclockTheme.EMBER_SMOKE[1], 150.0, 0.8)
	burst.sparks(_burst_point(1.0), 14)
	if MotionPolicy.allows_camera_emphasis():
		_impulse = CRASH_IMPULSE
	_win_flash.play(CoreOverclockTheme.CREAM, true)


func _refresh_gauge() -> void:
	var math := _math()
	gauge.set_auto_target(math.auto_centi)
	history.set_entries(math.history)
	var ink := CoreOverclockTheme.CREAM
	match math.state:
		CoreOverclockMath.State.CASHED_OUT:
			ink = CoreOverclockTheme.BRASS_BRIGHT
		CoreOverclockMath.State.CRASHED:
			ink = CoreOverclockTheme.ENSIGN
	gauge.set_caption(tr(_state_key()), ink)
	if math.state == CoreOverclockMath.State.CASHED_OUT and _result != null:
		gauge.set_value(tr("CORE_OVERCLOCK_VALUE") % _result.payout)
	elif math.state == CoreOverclockMath.State.CRASHED:
		gauge.set_value(tr("CORE_OVERCLOCK_VALUE") % 0)
	elif math.state != CoreOverclockMath.State.OVERCLOCKING:
		gauge.set_value("")


func _state_key() -> String:
	match _state():
		CoreOverclockMath.State.COUNTDOWN:
			return "CORE_OVERCLOCK_STATE_COUNTDOWN"
		CoreOverclockMath.State.OVERCLOCKING:
			return "CORE_OVERCLOCK_STATE_RUNNING"
		CoreOverclockMath.State.CASHED_OUT:
			return "CORE_OVERCLOCK_STATE_HAULED"
		CoreOverclockMath.State.CRASHED:
			return "CORE_OVERCLOCK_STATE_CRASHED"
	return "CORE_OVERCLOCK_STATE_READY"


func _refresh_status() -> void:
	var math := _math()
	var text := ""
	if not _notice_key.is_empty():
		text = tr(_notice_key)
	elif math.state == CoreOverclockMath.State.CASHED_OUT and _result != null:
		text = (
			tr("CORE_OVERCLOCK_STATUS_HAULED")
			% [CoreOverclockMath.multiplier_text(math.settled_centi), _result.payout]
		)
	elif math.state == CoreOverclockMath.State.CRASHED and _result != null:
		text = (
			tr("CORE_OVERCLOCK_STATUS_CRASHED")
			% CoreOverclockMath.multiplier_text(maxi(math.crash_centi, 100))
		)
	elif math.state == CoreOverclockMath.State.COUNTDOWN:
		text = tr("CORE_OVERCLOCK_STATUS_COUNTDOWN")
	elif math.state == CoreOverclockMath.State.OVERCLOCKING:
		text = tr("CORE_OVERCLOCK_STATUS_RUNNING")
	elif cabinet.selected_stake == 0:
		text = tr("BET_NEED_CASHIER") % cabinet.context.definition.min_bet
	else:
		text = tr("CORE_OVERCLOCK_STATUS_READY")
	_set_live_text(_status, text)


## The deck's state. Presentation only: it reads the cabinet, never changes it.
func _refresh_deck() -> void:
	if deck == null:
		return
	var math := _math()
	var running: bool = cabinet.is_round_active
	var climbing := math.state == CoreOverclockMath.State.OVERCLOCKING
	var balance: int = cabinet.context.balance - (cabinet.current_stake if running else 0)
	if Wallet.test_mode_enabled:
		deck.balance.tag = tr("DECK_TEST_TAG")
		deck.balance.set_infinite()
	else:
		deck.balance.tag = ""
		deck.balance.set_value(maxi(0, balance))
	var stakes := cabinet.available_stakes()
	var index := stakes.find(cabinet.selected_stake)
	var betting := not running
	deck.bet.set_state(
		cabinet.current_stake if running else cabinet.selected_stake,
		betting and not stakes.is_empty(),
		betting and index > 0,
		betting and index >= 0 and index < stakes.size() - 1,
		tr("DECK_IN_PLAY") if running else tr("DECK_YOUR_BET"),
		(
			tr("DECK_TABLE_LIMIT")
			% [cabinet.context.definition.min_bet, cabinet.context.definition.max_bet]
		),
		cabinet.stake_options()
	)
	deck.quick_bets.set_states(cabinet)
	primary_button.text = (
		tr("CORE_OVERCLOCK_ACTION_PULL") if running else tr("CORE_OVERCLOCK_ACTION_LAUNCH")
	)
	if auto_button != null:
		auto_button.text = (
			tr("CORE_OVERCLOCK_AUTO_OFF")
			if math.auto_centi == 0
			else tr("CORE_OVERCLOCK_AUTO_AT") % CoreOverclockMath.multiplier_text(math.auto_centi)
		)
		_set_action_disabled(auto_button, running)
	_set_action_disabled(
		primary_button,
		(running and not climbing) or (not running and not cabinet.call("can_launch"))
	)
	deck.show_actions([&"primary"] as Array[StringName])
	var line := _instruction()
	deck.set_instruction(line[0], line[1])


## One plain sentence for the current state, with inline glyphs.
func _instruction() -> Array:
	var math := _math()
	match math.state:
		CoreOverclockMath.State.COUNTDOWN:
			return [tr("DECK_CORSAIR_COUNTDOWN"), InfoPlate.Tone.NEUTRAL]
		CoreOverclockMath.State.OVERCLOCKING:
			return [tr("DECK_CORSAIR_RUNNING"), InfoPlate.Tone.NEUTRAL]
		CoreOverclockMath.State.CASHED_OUT:
			if _result != null:
				return [
					tr("DECK_CORSAIR_HAULED") % (_result.payout - _result.stake),
					InfoPlate.Tone.WIN,
				]
		CoreOverclockMath.State.CRASHED:
			if _result != null:
				return [tr("DECK_CORSAIR_CRASHED") % _result.stake, InfoPlate.Tone.LOSS]
	if not cabinet.call("can_launch"):
		return [tr("DECK_NEED_FUNDS") % cabinet.context.definition.min_bet, InfoPlate.Tone.LOSS]
	return [tr("DECK_CORSAIR_BETTING"), InfoPlate.Tone.NEUTRAL]


func _refresh_help() -> void:
	if _help_title == null:
		return
	_help_button.text = tr("HELP_BUTTON")
	_help_title.text = tr("HELP_TITLE") % tr(cabinet.context.definition.name_key)
	_help_rules.text = tr("HELP_CORE_OVERCLOCK_RULES")
	_help_controls.text = (
		tr("HELP_CORE_OVERCLOCK_CONTROLS")
		% [
			InputRouter.glyph("interact"),
			InputRouter.glyph("secondary"),
			InputRouter.glyph("move_horizontal"),
			InputRouter.glyph("back"),
		]
	)


func _help_content() -> Dictionary:
	var math := _math()
	var payouts: Array = []
	for centi: int in [120, 200, 500, 1000]:
		(
			payouts
			. append(
				[
					tr("HELP_PAY_CORSAIR_REACH") % CoreOverclockMath.multiplier_text(centi),
					tr("HELP_PAY_TIMES_DECIMAL") % (float(centi) / 100.0),
				]
			)
		)
	return {
		"goal": tr("HELP_CORE_OVERCLOCK_GOAL"),
		"steps": Array(tr("HELP_CORE_OVERCLOCK_STEPS").split("\n")),
		"controls":
		[
			"{interact} " + tr("HELP_CONTROL_CORSAIR_PRIMARY"),
			"{secondary} " + tr("HELP_CONTROL_CORSAIR_AUTO"),
			"{bet_down}{bet_up} " + tr("HELP_CONTROL_BET"),
			"{bet_max} " + tr("HELP_CONTROL_BET_MAX"),
			"{help} " + tr("HELP_CONTROL_GUIDE"),
			"{back} " + tr("HELP_CONTROL_LEAVE"),
		],
		"payouts": payouts,
		"payout_caption": tr("HELP_PAYOUTS_TIMES_BET"),
		"notes": [tr("HELP_CORE_OVERCLOCK_NOTE") % (math.bust_probability() * 100.0)],
	}


func set_help_open(open: bool) -> void:
	super.set_help_open(open)
	if deck != null:
		refresh()
