class_name DevActions
extends Node
## Everything the developer menu can do to the running game, through the
## game's own APIs: SceneRouter for tables, FloorController for rooms and
## warps, Wallet for the test bank, MotionPolicy, OfficeState and the tour.
##
## Navigation always leaves a live table through SceneRouter.return_to_floor
## first, so a jump from inside one cabinet to another settles or abandons
## the round exactly as the player's own exit would. Debug builds only.

signal status_changed(text: String)

const CABINET_REGISTRY := preload("res://src/cabinets/cabinet_scene_registry.gd")
const ROOM_LABELS: Dictionary = {
	&"main_floor": "Main Floor",
	&"high_roller": "High Roller Salon",
	&"vip": "VIP Penthouse",
	&"manager_office": "Manager's Office",
}
const ANCHOR_LABELS: Dictionary = {
	&"spawn": "Spawn",
	&"cashier": "Cashier",
	&"office": "Office door",
	&"high_roller": "High Roller entrance",
	&"vip": "VIP entrance",
	&"exit": "Exit to Main Floor",
	&"reception": "Reception desk",
	&"manager": "Manager's desk",
	&"bar": "Bar",
	&"roulette_view": "Roulette rail",
}
const DEV_GRANT: int = 1000
const LOW_BANK: int = 10
## Longest wait for a velvet-shutter transition before a jump gives up.
const TRANSITION_TIMEOUT_MSEC: int = 4000

## True while a room or table jump is waiting on a transition.
var busy: bool = false
var last_status: String = ""

static var _destinations: Array[Dictionary] = []
static var _cabinets: Array[StringName] = []


func floor_controller() -> FloorController:
	var controller: FloorController = SceneRouter.floor
	return controller if is_instance_valid(controller) and controller.is_inside_tree() else null


## The game is past the title menu: the floor is showing, or a table is open.
func is_playing() -> bool:
	var controller := floor_controller()
	return controller != null and (controller.is_visible_in_tree() or in_cabinet())


func in_cabinet() -> bool:
	return SceneRouter.session != null


func active_cabinet_id() -> StringName:
	var session := SceneRouter.session
	if session == null or session.context == null or session.context.definition == null:
		return &""
	return session.context.definition.id


static func definition(cabinet_id: StringName) -> CabinetDefinition:
	var path := "res://data/cabinets/%s.tres" % cabinet_id
	if not ResourceLoader.exists(path):
		return null
	return load(path) as CabinetDefinition


## Every playable table, read from the scene registry rather than a list here,
## so a cabinet added by anyone else shows up without touching this menu.
## Tables already seated in a room come first, in room order.
static func cabinets() -> Array[StringName]:
	if not _cabinets.is_empty():
		return _cabinets
	var seated: Array[StringName] = []
	var loose: Array[StringName] = []
	for cabinet_id: StringName in CABINET_REGISTRY.SCENE_PATHS:
		if not CABINET_REGISTRY.has_scene(cabinet_id) or definition(cabinet_id) == null:
			continue
		if cabinet_room(cabinet_id) == &"":
			loose.append(cabinet_id)
		else:
			seated.append(cabinet_id)
	seated.sort_custom(
		func(left: StringName, right: StringName) -> bool:
			return (
				FloorController.ROOM_IDS.find(cabinet_room(left))
				< FloorController.ROOM_IDS.find(cabinet_room(right))
			)
	)
	_cabinets = seated
	_cabinets.append_array(loose)
	return _cabinets


static func room_label(room_id: StringName) -> String:
	return String(ROOM_LABELS.get(room_id, String(room_id).capitalize()))


## The room whose floor plan seats this cabinet, or &"".
static func cabinet_room(cabinet_id: StringName) -> StringName:
	for room_id: StringName in FloorController.ROOM_IDS:
		if cabinet_id in FloorRoomLayout.load_room(room_id).cabinets:
			return room_id
	return &""


## Every named spot in every room, read from the rooms' own floor plans:
## {"room", "anchor", "position", "label"}. Cabinet anchors are join inlays.
static func destinations() -> Array[Dictionary]:
	if not _destinations.is_empty():
		return _destinations
	for room_id: StringName in FloorController.ROOM_IDS:
		var layout := FloorRoomLayout.load_room(room_id)
		var spots: Dictionary = {&"spawn": layout.spawn}
		spots.merge(layout.anchors)
		for anchor_id: StringName in spots:
			var label := String(ANCHOR_LABELS.get(anchor_id, ""))
			if anchor_id in layout.cabinets:
				label = "%s join" % cabinet_name(anchor_id)
			elif label.is_empty():
				label = String(anchor_id).capitalize()
			(
				_destinations
				. append(
					{
						"room": room_id,
						"anchor": anchor_id,
						"position": spots[anchor_id],
						"label": label,
					}
				)
			)
	return _destinations


static func cabinet_name(cabinet_id: StringName) -> String:
	var cabinet := definition(cabinet_id)
	return String(TranslationServer.translate(cabinet.name_key)) if cabinet else String(cabinet_id)


# --- Navigation ---------------------------------------------------------------


## Switches the environment through FloorController.enter_room. Asking for
## the room the player is already in stands them on its spawn instead.
func go_to_room(room_id: StringName) -> bool:
	if not await _begin_navigation():
		return false
	var controller := floor_controller()
	if controller.room.id == room_id:
		controller.dev_warp(room_id, controller.room.spawn)
	else:
		controller.enter_room(room_id)
	return _finish_navigation("Entered %s" % room_label(room_id))


func go_to_destination(room_id: StringName, anchor_id: StringName) -> bool:
	if not await _begin_navigation():
		return false
	var layout := FloorRoomLayout.load_room(room_id)
	var at: Vector2 = layout.spawn if anchor_id == &"spawn" else layout.anchor(anchor_id)
	floor_controller().dev_warp(room_id, at)
	var label := String(ANCHOR_LABELS.get(anchor_id, String(anchor_id).capitalize()))
	return _finish_navigation("%s · %s" % [room_label(room_id), label])


## Opens a table from anywhere: leaves any live table first, walks the avatar
## to the cabinet's join inlay in its own room, then enters through SceneRouter.
func open_cabinet(cabinet_id: StringName) -> bool:
	var cabinet := definition(cabinet_id)
	if cabinet == null:
		return _report("Unknown table: %s" % cabinet_id, false)
	if active_cabinet_id() == cabinet_id:
		return _report("Already at %s" % cabinet_name(cabinet_id), true)
	if not await _begin_navigation():
		return false
	var room_id := cabinet_room(cabinet_id)
	var controller := floor_controller()
	# A table with no join inlay yet (one being built into a room) opens from
	# wherever the player is standing instead of warping to nowhere.
	if room_id != &"":
		controller.dev_warp(room_id, FloorRoomLayout.load_room(room_id).anchor(cabinet_id))
	if Wallet.balance < cabinet.min_bet:
		busy = false
		return _report(
			(
				"%s needs %d chips. Turn the test bank on or add chips."
				% [cabinet_name(cabinet_id), cabinet.min_bet]
			),
			false
		)
	var deadline := Time.get_ticks_msec() + TRANSITION_TIMEOUT_MSEC
	# SceneRouter refuses while a shutter is still moving; ask again each frame.
	while SceneRouter.session == null and Time.get_ticks_msec() < deadline:
		SceneRouter.enter_cabinet(cabinet)
		if SceneRouter.session == null:
			await get_tree().process_frame
	busy = false
	var opened := active_cabinet_id() == cabinet_id
	var verb := "Opened" if opened else "Could not open"
	return _report("%s %s" % [verb, cabinet_name(cabinet_id)], opened)


## Leaves a live table through SceneRouter, exactly like the player's exit.
func leave_cabinet() -> bool:
	var deadline := Time.get_ticks_msec() + TRANSITION_TIMEOUT_MSEC
	while SceneRouter.session != null and Time.get_ticks_msec() < deadline:
		SceneRouter.return_to_floor()
		if SceneRouter.session != null:
			await get_tree().process_frame
	return SceneRouter.session == null


func _begin_navigation() -> bool:
	if busy:
		return _report("Still travelling, one moment.", false)
	if floor_controller() == null or not is_playing():
		return _report("Start the game first: the floor is not open yet.", false)
	busy = true
	if not await leave_cabinet():
		busy = false
		return _report("The table did not close in time.", false)
	return true


func _finish_navigation(message: String) -> bool:
	busy = false
	AudioService.play(&"move")
	return _report(message, true)


# --- Test toggles ---------------------------------------------------------------


func can_toggle_collision() -> bool:
	return floor_controller() != null and not in_cabinet() and is_playing()


func collision_overlay_on() -> bool:
	var controller := floor_controller()
	return controller != null and controller.collision_overlay_visible()


func toggle_collision_overlay() -> bool:
	if not can_toggle_collision():
		return _report("The collision overlay is for the floor rooms only.", false)
	floor_controller().toggle_collision_overlay(not collision_overlay_on())
	return _report("Collision overlay %s" % _on_off(collision_overlay_on()), true)


func toggle_reduced_motion() -> bool:
	MotionPolicy.set_reduced_motion(not MotionPolicy.is_reduced())
	return _report("Reduced motion %s" % _on_off(MotionPolicy.is_reduced()), true)


## Money never changes under a live table: the session's context and the
## cabinet's own credit meter are built for the bank it opened with.
func can_change_bank() -> bool:
	return not in_cabinet()


func toggle_test_bank() -> bool:
	if not can_change_bank():
		return _report("Leave the table before switching banks.", false)
	Wallet.set_test_mode(not Wallet.test_mode_enabled)
	_refresh_floor()
	return _report("Unlimited test bank %s" % _on_off(Wallet.test_mode_enabled), true)


## Adds real chips to the loaded profile through the Wallet's own boundary.
## Dev-flagged: the grant is saved with the profile like any other payout.
func grant_chips() -> bool:
	if not can_change_bank():
		return _report("Leave the table before changing chips.", false)
	if Wallet.test_mode_enabled:
		return _report("The test bank is already unlimited. Turn it off to add chips.", false)
	if not Wallet.try_apply(0, DEV_GRANT):
		return _report("The wallet refused the dev grant.", false)
	_refresh_floor()
	return _report("DEV: +%d chips, bank now %d" % [DEV_GRANT, Wallet.balance], true)


## Drops the real bank to 10 chips, under the Manager's 20-chip solvency floor,
## so markers and the office waypoint can be tested. Leaves the test bank.
func set_low_bank() -> bool:
	if not can_change_bank():
		return _report("Leave the table before changing chips.", false)
	Wallet.set_test_mode(false)
	Wallet.reset(LOW_BANK)
	_refresh_floor()
	return _report("DEV: test bank off, chips set to %d" % LOW_BANK, true)


func wings_unlocked() -> bool:
	var controller := floor_controller()
	return controller != null and controller.dev_wings_unlocked


## Opens both wings for this session only; nothing is written to the save.
func toggle_wings() -> bool:
	var controller := floor_controller()
	if controller == null:
		return _report("Start the game first.", false)
	controller.dev_wings_unlocked = not controller.dev_wings_unlocked
	controller.refresh_proximity()
	return _report("Both wings %s for this session" % _on_off(controller.dev_wings_unlocked), true)


## Dev-only: walks House standing to the next rung by setting the lifetime
## wagered total the ladder already reads. It mints no chips, touches no
## paytable, and lands on exactly the number a real session would have reached.
func cycle_standing() -> bool:
	if in_cabinet():
		return _report("Leave the table before moving standing.", false)
	var next := (Progression.tier_index() + 1) % HouseLevel.TIERS.size()
	Economy.lifetime_wagered = int(HouseLevel.TIERS[next].target)
	Progression.refresh_standing(true)
	_refresh_floor()
	return _report(
		(
			"DEV: standing set to %s (%s wagered)"
			% [
				TranslationServer.translate(String(HouseLevel.TIERS[next].name_key)),
				HouseLevel.short_chips(Economy.lifetime_wagered),
			]
		),
		true
	)


func standing_label() -> String:
	return TranslationServer.translate(String(Progression.tier().name_key))


func replay_tutorial() -> bool:
	if not await _begin_navigation():
		return false
	busy = false
	var office := floor_controller().office_host()
	if office == null:
		return _report("The office host is not ready.", false)
	if office.conversation != &"":
		office.end_conversation()
	office.tutorial.start(true)
	return _report("Replaying the secretary's tour", true)


## Marks the first-run tour as not yet seen in the loaded profile, so it runs
## again on the next start (Replay runs it now).
func reset_tutorial() -> bool:
	if SaveService.state == null:
		return _report("No profile is loaded.", false)
	OfficeState.set_tutorial_state(SaveGame.TUTORIAL_PENDING)
	return _report("Tour reset: it runs on the next start", true)


## Forced prompt glyphs: Auto, Keyboard, Xbox, PlayStation. Wired to
## InputRouter.force_prompt_family when the router exposes it.
const GLYPH_CHOICES: Array[String] = ["Auto", "Keyboard", "Xbox", "PlayStation"]
const GLYPH_SETTER := &"force_prompt_family"

var glyph_choice: int = 0


func glyph_family_supported() -> bool:
	return InputRouter.has_method(GLYPH_SETTER) and _router_enum(&"GamepadFamily").size() >= 2


func glyph_family_label() -> String:
	return GLYPH_CHOICES[glyph_choice] if glyph_family_supported() else "N/A"


## Steps Auto → Keyboard → Xbox → PlayStation. The router pins the pad family;
## the device itself follows the next real key, mouse or pad input again.
func cycle_glyph_family() -> bool:
	if not glyph_family_supported():
		return _report("The input router does not expose a glyph family setter.", false)
	glyph_choice = (glyph_choice + 1) % GLYPH_CHOICES.size()
	var devices := _router_enum(&"Device")
	var families := _router_enum(&"GamepadFamily")
	match glyph_choice:
		0:
			InputRouter.call(GLYPH_SETTER, -1, -1)
		1:
			InputRouter.call(GLYPH_SETTER, int(devices.get("KEYBOARD", 0)), -1)
		2:
			InputRouter.call(
				GLYPH_SETTER, int(devices.get("GAMEPAD", 1)), int(families.get("XBOX", 0))
			)
		3:
			InputRouter.call(
				GLYPH_SETTER, int(devices.get("GAMEPAD", 1)), int(families.get("PLAYSTATION", 1))
			)
	return _report("Input glyphs: %s" % GLYPH_CHOICES[glyph_choice], true)


static func _router_enum(enum_name: StringName) -> Dictionary:
	var script := InputRouter.get_script() as Script
	if script == null:
		return {}
	var value: Variant = script.get_script_constant_map().get(enum_name, {})
	return value if value is Dictionary else {}


# --- Info -----------------------------------------------------------------------


func info_lines() -> Array[String]:
	var lines: Array[String] = []
	var controller := floor_controller()
	var room_text := "Title menu"
	if controller != null and is_playing():
		room_text = "%s (%s)" % [room_label(controller.room.id), controller.room.id]
	lines.append("Room: %s" % room_text)
	if controller != null:
		var at := controller.avatar_position
		lines.append("Avatar: %d, %d" % [roundi(at.x), roundi(at.y)])
	else:
		lines.append("Avatar: none")
	var cabinet := active_cabinet_id()
	var table := "none"
	if cabinet != &"":
		table = "%s (%s)" % [cabinet_name(cabinet), cabinet]
	lines.append("Table: %s" % table)
	var bank := "unlimited test bank" if Wallet.test_mode_enabled else "%d chips" % Wallet.balance
	lines.append("Bank: %s · debt %d" % [bank, Economy.debt])
	(
		lines
		. append(
			(
				"Standing: %s (tier %d) · %s wagered"
				% [
					TranslationServer.translate(String(Progression.tier().name_key)),
					Progression.level(),
					HouseLevel.short_chips(Progression.wagered()),
				]
			)
		)
	)
	lines.append("Tour: %s" % OfficeState.tutorial_state())
	lines.append("Build: %s" % DevBuildInfo.commit())
	lines.append("Version: %s" % DevBuildInfo.version())
	return lines


func _refresh_floor() -> void:
	var controller := floor_controller()
	if controller != null:
		controller.refresh_proximity()


func _report(message: String, ok: bool) -> bool:
	last_status = message
	status_changed.emit(message)
	return ok


static func _on_off(value: bool) -> String:
	return "on" if value else "off"
