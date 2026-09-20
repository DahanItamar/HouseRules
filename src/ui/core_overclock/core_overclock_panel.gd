class_name CoreOverclockPanel
extends CabinetPanel
## Forno d'Oro cabinet presentation, laid out on the centre line: the oven gauge
## at the middle of the screen, the bake curve and the recent-bakes board in the
## left column, the pizzaiola in the right column at the same width, the pizza
## baking on the counter under the gauge, and the shared control deck across the
## foot. The oven timer sits top-left, mirroring How to play top-right.
##
## Game state is read from the cabinet every frame and never written. The bake
## is already decided when it starts; this only replays it.

const STAGE_NAME := "FornoStage"
## Shake starts only once the oven is genuinely hot, and stays small.
const SHAKE_FROM: float = 0.30
const SHAKE_PIXELS: float = 3.2
const BURN_IMPULSE: float = 8.0
const IMPULSE_DECAY: float = 22.0
## The fire's pulse: the interval shortens and the pitch rises with the heat.
const PULSE_SLOW: float = 0.50
const PULSE_FAST: float = 0.13
const ROAR_FROM: float = 0.40
const ROAR_SLOW: float = 0.62
const ROAR_FAST: float = 0.30
const SERVED_SECONDS: float = 2.4
const NOTICE_SECONDS: float = 1.8

var backdrop: CoreOverclockBackdrop
var gauge: CoreOverclockGauge
var history: CoreOverclockHistory
var hosts: CoreOverclockHosts
var burst: CoreOverclockBurst
var baking_pizza: TextureRect
## Which painted bake stage `baking_pizza` is showing; -1 before the first one.
var _bake_stage: int = -1
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
var _served_left: float = 0.0
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
	_build_baking_pizza()
	gauge = CoreOverclockGauge.new()
	gauge.position = CoreOverclockTheme.GAUGE_CENTRE - gauge.size * 0.5
	gauge.z_index = 4
	gauge.whole_multiple_passed.connect(_on_whole_multiple)
	_stage.add_child(gauge)
	burst = CoreOverclockBurst.new()
	burst.z_index = 8
	_stage.add_child(burst)
	_build_title_plate()
	_build_deck()
	_build_timer_control()
	_style_help_button()
	_sync_state(true)
	call_deferred("_focus_default_action")


## The left column: the recent-bakes board, on the same terracotta plate language
## and the same width as the host lane opposite.
##
## A drawn bake curve used to sit above it and plot the multiplier the dial was
## already showing. Two readouts of one number is one too many, so the curve is
## gone and the pizza in the oven carries the tension instead.
func _build_left_column() -> void:
	var border := CoreOverclockTheme.frame_border()
	_stage.add_child(
		CoreOverclockTheme.frame_plate("FornoRecentPlate", CoreOverclockTheme.HISTORY_RECT)
	)
	history = CoreOverclockHistory.new()
	history.position = CoreOverclockTheme.HISTORY_RECT.position + Vector2.ONE * border
	history.size = CoreOverclockTheme.HISTORY_RECT.size - Vector2.ONE * border * 2.0
	history.z_index = 2
	history.set_caption(tr("CORE_OVERCLOCK_RECENT"))
	_stage.add_child(history)


## Both pizzaiole, as one layer. Each state of the bake is a single painted
## frame with both of them in it, so their reaction is shared by construction.
func _build_hosts() -> void:
	hosts = CoreOverclockHosts.new()
	hosts.z_index = 2
	_stage.add_child(hosts)


## The pizza itself, in the oven mouth, browning as it bakes.
func _build_baking_pizza() -> void:
	baking_pizza = TextureRect.new()
	baking_pizza.name = "FornoBakingPizza"
	baking_pizza.texture = CoreOverclockTheme.BAKE_STAGES[CoreOverclockTheme.BAKE_STAGE_RAW]
	baking_pizza.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	baking_pizza.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	baking_pizza.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	baking_pizza.mouse_filter = Control.MOUSE_FILTER_IGNORE
	baking_pizza.size = Vector2.ONE * CoreOverclockTheme.BAKE_HEIGHT
	baking_pizza.position = CoreOverclockTheme.BAKE_CENTRE - baking_pizza.size * 0.5
	baking_pizza.pivot_offset = baking_pizza.size * 0.5
	baking_pizza.z_index = 3
	baking_pizza.visible = false
	_stage.add_child(baking_pizza)


func _build_title_plate() -> void:
	var plate := CoreOverclockTheme.frame_plate(
		"FornoTitlePlate", CoreOverclockTheme.TITLE_RECT, 0.075
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
	deck.name = "FornoControlDeck"
	deck.z_index = 6
	add_child(deck)
	deck.build(CoreOverclockTheme.deck_style())
	deck.balance.caption = tr("DECK_BALANCE")
	deck.bet.step_requested.connect(_on_deck_bet_step)
	deck.quick_bets.operation_requested.connect(_on_quick_bet)
	primary_button = deck.add_action(
		&"primary", tr("CORE_OVERCLOCK_ACTION_BAKE"), &"interact", true
	)
	primary_button.name = "FornoPrimaryAction"
	deck.action_pressed.connect(_on_deck_action)


## The oven timer mirrors How to play at the other end of the header, so the
## two settings sit at the same height and the header stays balanced. The deck
## itself is full: balance, bet, the shared quick-bet row and the primary key.
func _build_timer_control() -> void:
	var style := CoreOverclockTheme.deck_style()
	auto_button = PromptButton.new()
	auto_button.name = "FornoTimerAction"
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
## take focus, so the focus row is the timer, the primary key and Help.
func _link_focus() -> void:
	# The header reads left to right - timer, then How to play - and both drop to
	# the primary key at the foot of the screen.
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


## Each whole multiple the bake passes gets one tick, in step with the pop the
## gauge gives the number.
func _on_whole_multiple() -> void:
	AudioService.play(&"oven_tick", 1.0 + CoreOverclockTheme.heat_of(gauge.centi) * 0.7)


func _focus_default_action() -> void:
	if help_open or not is_inside_tree() or primary_button == null:
		return
	primary_button.grab_focus()


## WASD/D-pad focus walk between the timer, the primary key and Help.
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


## The cabinet has locked the stake and decided the bake; start the replay.
func begin_bake() -> void:
	_result = null
	gauge.reset()
	gauge.set_number_color(CoreOverclockTheme.INK)
	burst.clear()
	# The peel has just set it on the stone: topped, raw, nothing browned yet.
	_bake_stage = -1
	_show_bake_stage(CoreOverclockTheme.BAKE_STAGE_RAW)
	baking_pizza.modulate = Color.WHITE
	baking_pizza.visible = true
	baking_pizza.rotation = 0.0
	_served_left = 0.0
	_impulse = 0.0
	_pulse_left = 0.0
	_roar_left = 0.0
	AudioService.play(&"oven_load")
	_sync_state(true)
	refresh()


## Called by the cabinet every frame while the panel is on screen.
func tick(delta: float) -> void:
	if not _built:
		return
	var math := _math()
	var baking := math.state == CoreOverclockMath.State.OVERCLOCKING
	var heat := CoreOverclockTheme.heat_of(math.multiplier_centi)
	if math.state != _shown_state:
		_sync_state(false)
	gauge.set_centi(math.multiplier_centi)
	gauge.set_bake_state(baking)
	gauge.set_charge(
		(
			0.0
			if math.state != CoreOverclockMath.State.COUNTDOWN
			else 1.0 - math.countdown_left / maxf(math.paytable.countdown_seconds, 0.001)
		)
	)
	backdrop.set_bake(heat, baking or math.state == CoreOverclockMath.State.COUNTDOWN)
	if math.state == CoreOverclockMath.State.COUNTDOWN:
		# The pizza is being made while the oven comes up to heat: a dough ball,
		# stretched, sauced, then topped and ready for the peel.
		var left := math.countdown_left / maxf(math.paytable.countdown_seconds, 0.001)
		_show_bake_stage(CoreOverclockTheme.prep_stage(1.0 - left))
	if baking:
		gauge.set_value(tr("CORE_OVERCLOCK_VALUE") % math.current_payout())
		_show_bake_stage(CoreOverclockTheme.bake_stage(heat))
		if MotionPolicy.allows_continuous_motion():
			baking_pizza.rotation = sin(_shake_phase * 1.2) * 0.02
	_update_shake(delta, heat, baking)
	_update_audio(delta, heat, baking)
	if _served_left > 0.0:
		_served_left = maxf(_served_left - delta, 0.0)
		if _served_left <= 0.0:
			baking_pizza.visible = false


## Shows one painted bake stage. The pizza is the multiplier made visible, so
## this is the only thing that decides which stage is on screen.
func _show_bake_stage(stage: int) -> void:
	var index := clampi(stage, 0, CoreOverclockTheme.BAKE_STAGES.size() - 1)
	if _bake_stage == index:
		return
	_bake_stage = index
	baking_pizza.texture = CoreOverclockTheme.BAKE_STAGES[index]


## Reacts once to each state the bake moves through.
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
		# The dough is on the stone: a puff of flour off the peel.
		burst.puff(
			CoreOverclockTheme.OVEN_MOUTH.get_center(), CoreOverclockTheme.EMBER_FLOUR[0], 170.0
		)
		burst.sparks(CoreOverclockTheme.OVEN_MOUTH.get_center(), 8)
	refresh()


## What the pair are feeling at this point in the bake. Both of them feel it,
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


func _update_shake(delta: float, heat: float, baking: bool) -> void:
	if _impulse > 0.0:
		_impulse = maxf(_impulse - delta * IMPULSE_DECAY, 0.0)
	if not MotionPolicy.allows_camera_emphasis():
		_stage.position = Vector2.ZERO
		return
	_shake_phase += delta
	var amplitude := _impulse
	if baking and heat > SHAKE_FROM:
		amplitude = maxf(amplitude, (heat - SHAKE_FROM) / (1.0 - SHAKE_FROM) * SHAKE_PIXELS)
	if amplitude <= 0.0:
		_stage.position = Vector2.ZERO
		return
	_stage.position = (
		Vector2(sin(_shake_phase * 53.0), sin(_shake_phase * 41.0) * 0.6) * amplitude
	)


## The fire: a pulse that speeds up and rises in pitch with the heat, and a roar
## under it once the bake is far enough along to be worth losing.
func _update_audio(delta: float, heat: float, baking: bool) -> void:
	if not baking:
		return
	_pulse_left -= delta
	if _pulse_left <= 0.0:
		AudioService.play(&"oven_pulse", 1.0 + heat * 1.4)
		_pulse_left = lerpf(PULSE_SLOW, PULSE_FAST, heat)
	if heat < ROAR_FROM:
		return
	_roar_left -= delta
	if _roar_left <= 0.0:
		AudioService.play(&"oven_roar", 0.86 + heat * 0.4)
		_roar_left = lerpf(ROAR_SLOW, ROAR_FAST, heat)


## Called by MiniGame after CabinetSession has settled the bake.
func show_result(result: RoundResult) -> void:
	_result = result
	_status_key = "ROUND_READY"
	var served: bool = result.detail.get("cashed_out", false)
	var math := _math()
	gauge.settle_pop()
	gauge.set_number_color(
		CoreOverclockTheme.TERRACOTTA_DEEP if served else CoreOverclockTheme.CHAR
	)
	history.set_entries(math.history)
	hosts.show_state(&"cheer" if served else &"wince")
	if served:
		_present_served(result)
	else:
		_present_burnt()
	refresh()
	call_deferred("_focus_default_action")


func _present_served(result: RoundResult) -> void:
	AudioService.play(&"oven_serve")
	var multiple := float(result.payout) / maxf(result.stake, 1.0)
	_show_bake_stage(
		CoreOverclockTheme.bake_stage(CoreOverclockTheme.heat_of(_math().settled_centi))
	)
	baking_pizza.visible = true
	_served_left = MotionPolicy.finite_duration(SERVED_SECONDS)
	burst.sparks(CoreOverclockTheme.OVEN_MOUTH.get_center(), 18 if multiple >= 5.0 else 10)
	burst.puff(CoreOverclockTheme.BAKE_CENTRE, CoreOverclockTheme.EMBER_FLOUR[1], 150.0)
	_win_flash.play(CoreOverclockTheme.BRASS_BRIGHT, multiple >= BIG_WIN_MULTIPLE)


## The meltdown: the needle slams, the screen flashes white-hot, smoke rolls out
## of the mouth and over the pizza, and the stage settles.
func _present_burnt() -> void:
	AudioService.play(&"oven_burn")
	_show_bake_stage(CoreOverclockTheme.BAKE_STAGE_BURNT)
	baking_pizza.modulate = Color.WHITE
	baking_pizza.visible = true
	_served_left = MotionPolicy.finite_duration(SERVED_SECONDS)
	gauge.slam()
	burst.puff(
		CoreOverclockTheme.OVEN_MOUTH.get_center(), CoreOverclockTheme.EMBER_SMOKE[0], 300.0, 0.9
	)
	burst.puff(CoreOverclockTheme.BAKE_CENTRE, CoreOverclockTheme.EMBER_SMOKE[1], 190.0, 0.8)
	burst.sparks(CoreOverclockTheme.OVEN_MOUTH.get_center(), 14)
	if MotionPolicy.allows_camera_emphasis():
		_impulse = BURN_IMPULSE
	_win_flash.play(CoreOverclockTheme.CREAM, true)


func _refresh_gauge() -> void:
	var math := _math()
	gauge.set_auto_target(math.auto_centi)
	history.set_entries(math.history)
	var ink := CoreOverclockTheme.TERRACOTTA_DEEP
	match math.state:
		CoreOverclockMath.State.CASHED_OUT:
			ink = CoreOverclockTheme.BASIL
		CoreOverclockMath.State.CRASHED:
			ink = CoreOverclockTheme.TOMATO
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
			return "CORE_OVERCLOCK_STATE_BAKING"
		CoreOverclockMath.State.CASHED_OUT:
			return "CORE_OVERCLOCK_STATE_SERVED"
		CoreOverclockMath.State.CRASHED:
			return "CORE_OVERCLOCK_STATE_BURNT"
	return "CORE_OVERCLOCK_STATE_READY"


func _refresh_status() -> void:
	var math := _math()
	var text := ""
	if not _notice_key.is_empty():
		text = tr(_notice_key)
	elif math.state == CoreOverclockMath.State.CASHED_OUT and _result != null:
		text = (
			tr("CORE_OVERCLOCK_STATUS_SERVED")
			% [CoreOverclockMath.multiplier_text(math.settled_centi), _result.payout]
		)
	elif math.state == CoreOverclockMath.State.CRASHED and _result != null:
		text = (
			tr("CORE_OVERCLOCK_STATUS_BURNT")
			% CoreOverclockMath.multiplier_text(maxi(math.crash_centi, 100))
		)
	elif math.state == CoreOverclockMath.State.COUNTDOWN:
		text = tr("CORE_OVERCLOCK_STATUS_COUNTDOWN")
	elif math.state == CoreOverclockMath.State.OVERCLOCKING:
		text = tr("CORE_OVERCLOCK_STATUS_BAKING")
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
	var baking := math.state == CoreOverclockMath.State.OVERCLOCKING
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
		tr("CORE_OVERCLOCK_ACTION_PULL") if running else tr("CORE_OVERCLOCK_ACTION_BAKE")
	)
	if auto_button != null:
		auto_button.text = (
			tr("CORE_OVERCLOCK_AUTO_OFF")
			if math.auto_centi == 0
			else tr("CORE_OVERCLOCK_AUTO_AT") % CoreOverclockMath.multiplier_text(math.auto_centi)
		)
		_set_action_disabled(auto_button, running)
	_set_action_disabled(
		primary_button, (running and not baking) or (not running and not cabinet.call("can_bake"))
	)
	deck.show_actions([&"primary"] as Array[StringName])
	var line := _instruction()
	deck.set_instruction(line[0], line[1])


## One plain sentence for the current state, with inline glyphs.
func _instruction() -> Array:
	var math := _math()
	match math.state:
		CoreOverclockMath.State.COUNTDOWN:
			return [tr("DECK_FORNO_COUNTDOWN"), InfoPlate.Tone.NEUTRAL]
		CoreOverclockMath.State.OVERCLOCKING:
			return [tr("DECK_FORNO_BAKING"), InfoPlate.Tone.NEUTRAL]
		CoreOverclockMath.State.CASHED_OUT:
			if _result != null:
				return [
					tr("DECK_FORNO_SERVED") % (_result.payout - _result.stake),
					InfoPlate.Tone.WIN,
				]
		CoreOverclockMath.State.CRASHED:
			if _result != null:
				return [tr("DECK_FORNO_BURNT") % _result.stake, InfoPlate.Tone.LOSS]
	if not cabinet.call("can_bake"):
		return [tr("DECK_NEED_FUNDS") % cabinet.context.definition.min_bet, InfoPlate.Tone.LOSS]
	return [tr("DECK_FORNO_BETTING"), InfoPlate.Tone.NEUTRAL]


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
					tr("HELP_PAY_FORNO_REACH") % CoreOverclockMath.multiplier_text(centi),
					tr("HELP_PAY_TIMES_DECIMAL") % (float(centi) / 100.0),
				]
			)
		)
	return {
		"goal": tr("HELP_CORE_OVERCLOCK_GOAL"),
		"steps": Array(tr("HELP_CORE_OVERCLOCK_STEPS").split("\n")),
		"controls":
		[
			"{interact} " + tr("HELP_CONTROL_FORNO_PRIMARY"),
			"{secondary} " + tr("HELP_CONTROL_FORNO_AUTO"),
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
