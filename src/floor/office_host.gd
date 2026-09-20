class_name OfficeHost
extends Node
## The Manager's Office behaviour, kept out of FloorController.
##
## Reception: the secretary and the House Contracts board. The Manager's desk:
## markers (the floor's marker modal, same Economy rules) and one-time wing
## invitations. It also hosts the secretary's first-run tour. Every panel is
## drawn in a screen-space layer that the floor hides during a cabinet session.

const STATION_RADIUS: float = 58.0
const STATIONS: Array[StringName] = [&"reception", &"manager"]
const OVERLAY_LAYER: int = 12
## Cameo regions framing each speaker from head to mid-torso. Poses of one
## person share a head-aligned canvas, so they share a region.
const SECRETARY_REGION := Rect2(298, 10, 720, 800)
const MANAGER_REGION := Rect2(281, 10, 720, 800)
## The way each person's poses naturally turn: the secretary toward screen
## right, the Manager toward screen left. The cameo mirrors to face the text.
const FACES_RIGHT: Dictionary = {&"secretary": true, &"manager": false}
## Beside the painted speaker in the office, with a pointer toward them. The
## player is stepped onto the station anchor first, so these stay clear.
const OFFICE_PLACEMENTS: Dictionary = {
	&"secretary":
	{"panel": Rect2(196, 250, 520, 144), "cameo_side": &"right", "pointer": Vector2(856, 304)},
	&"manager":
	{"panel": Rect2(48, 70, 398, 160), "cameo_side": &"right", "pointer": Vector2(470, 110)},
}
## A cabinet's brass join inlay around its anchor (see FloorController).
const INLAY_HALF_SIZE := Vector2(64, 31)
const PORTRAITS: Dictionary = {
	&"secretary": preload("res://assets/production/characters/staff/secretary.png"),
	&"secretary_explain": preload("res://assets/production/characters/staff/secretary_explain.png"),
	&"secretary_point": preload("res://assets/production/characters/staff/secretary_point.png"),
	&"manager": preload("res://assets/production/characters/staff/manager.png"),
	&"manager_offer": preload("res://assets/production/characters/staff/manager_offer.png"),
	&"manager_toast": preload("res://assets/production/characters/staff/manager_toast.png"),
}
## The fixed HUD plates in main.gd - the bank plaque and the standing plate
## beside it - which no office panel may cover.
const HUD_BANK_RECT := Rect2(18, 10, 418, 52)

var floor_controller: FloorController
var dialogue: DialoguePanel
var board: ContractsBoard
## House standing: the Manager's compact bars, the ledger and the deed.
var standing: ManagerStandingPanel
var ledger: StatsPanel
var deed: DeedCard
var invitation: WingInvitationCard
var tutorial: TutorialDirector
## &"reception", &"manager" or &"" while no conversation is running.
var conversation: StringName = &""
var _layer: CanvasLayer
var _pending_invitations: Array[StringName] = []


func bind(controller: FloorController) -> void:
	floor_controller = controller
	name = "OfficeHost"
	_layer = CanvasLayer.new()
	_layer.name = "OfficeOverlay"
	_layer.layer = OVERLAY_LAYER
	add_child(_layer)
	board = ContractsBoard.new()
	_layer.add_child(board)
	board.closed.connect(_on_board_closed)
	standing = ManagerStandingPanel.new()
	_layer.add_child(standing)
	ledger = StatsPanel.new()
	_layer.add_child(ledger)
	ledger.closed.connect(_on_ledger_closed)
	deed = DeedCard.new()
	_layer.add_child(deed)
	deed.closed.connect(_on_deed_closed)
	invitation = WingInvitationCard.new()
	_layer.add_child(invitation)
	invitation.accepted.connect(_on_invitation_accepted)
	dialogue = DialoguePanel.new()
	_layer.add_child(dialogue)
	dialogue.choice_selected.connect(_on_choice)
	tutorial = TutorialDirector.new()
	tutorial.name = "TutorialDirector"
	tutorial.host = self
	add_child(tutorial)


func set_overlay_visible(is_visible: bool) -> void:
	if _layer != null:
		_layer.visible = is_visible


## A modal office panel owns input and holds the avatar still.
func is_modal_open() -> bool:
	return (
		board.is_open()
		or ledger.is_open()
		or deed.is_open()
		or invitation.is_open()
		or (dialogue.is_open() and dialogue.blocking)
	)


func blocks_movement() -> bool:
	return is_modal_open()


func handle_input(event: InputEvent) -> bool:
	if invitation.is_open():
		invitation.handle_input(event)
		return true
	if deed.is_open():
		deed.handle_input(event)
		return true
	if ledger.is_open():
		ledger.handle_input(event)
		return true
	if board.is_open():
		board.handle_input(event)
		return true
	if tutorial.is_active():
		return tutorial.handle_input(event)
	if dialogue.is_open():
		if event.is_action_pressed("back"):
			end_conversation()
		else:
			dialogue.handle_input(event)
		return true
	return false


## The office station whose anchor the foot point is near, or &"".
func station_near(point: Vector2) -> StringName:
	var room := floor_controller.room
	if room == null or room.id != FloorController.OFFICE:
		return &""
	var nearest := &""
	var nearest_distance := STATION_RADIUS
	for station: StringName in STATIONS:
		if not room.anchors.has(station):
			continue
		var distance := point.distance_to(room.anchor(station))
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = station
	return nearest


func interact_station(station: StringName) -> bool:
	if is_modal_open() or tutorial.is_active():
		return false
	if not station in STATIONS:
		return false
	# The player steps up to the desk, so the conversation frames them clearly.
	floor_controller.avatar_position = floor_controller.room.anchor(station)
	floor_controller.move_avatar(Vector2.ZERO, 0.0)
	if station == &"reception":
		talk_to_secretary()
	else:
		talk_to_manager()
	AudioService.play(&"confirm")
	return true


func talk_to_secretary() -> void:
	conversation = &"reception"
	var choices: Array[Dictionary] = [
		{"id": &"contracts", "label": tr("RECEPTION_CONTRACTS")},
		{"id": &"ledger", "label": tr("RECEPTION_LEDGER")},
		{"id": &"tour", "label": tr("RECEPTION_TOUR")},
		{"id": &"leave", "label": tr("DIALOGUE_GOODBYE"), "action": &"back"},
	]
	speak(&"secretary_explain", tr("RECEPTION_GREETING"), choices)


func talk_to_manager() -> void:
	conversation = &"manager"
	standing.show_standing()
	_pending_invitations = OfficeState.pending_invitations(floor_controller)
	if not _pending_invitations.is_empty():
		_offer_invitation(_pending_invitations[0])
		return
	_manager_business(tr("MANAGER_GREETING"))


## Opens the contracts board directly (reception choice, tests and captures).
func open_contracts_board() -> void:
	dialogue.close()
	conversation = &"reception"
	board.open()
	floor_controller.refresh_prompt()


## Opens the House Ledger. Reachable from either desk, and from tests and
## captures, because it only reads the save.
func open_ledger(start_view: int = StatsPanel.View.OVERVIEW) -> void:
	dialogue.close()
	standing.visible = false
	ledger.open(start_view)
	floor_controller.refresh_prompt()


## The Manager sells the House. The price leaves the bank through Progression,
## which uses the Wallet's own boundary; nothing is paid back.
func _buy_the_house() -> bool:
	var price := HouseLevel.DEED_PRICE
	var wagered := Progression.wagered()
	if not Progression.buy_house():
		_manager_business(tr("MANAGER_DEED_REFUSED"))
		return false
	dialogue.close()
	standing.visible = false
	AudioService.play(&"confirm")
	deed.present(price, wagered)
	floor_controller.refresh_prompt()
	return true


func end_conversation() -> void:
	conversation = &""
	_pending_invitations.clear()
	if not tutorial.is_active():
		dialogue.close()
	board.close()
	ledger.close()
	deed.close()
	standing.visible = false
	floor_controller.refresh_proximity()
	floor_controller.refresh_prompt()


## Closes conversations when the room changes. The tour keeps running.
func on_room_changed() -> void:
	if conversation != &"":
		conversation = &""
		_pending_invitations.clear()
		board.close()
		ledger.close()
		deed.close()
		standing.visible = false
		if invitation.is_open():
			invitation.accept_button().pressed.emit()
		if not tutorial.is_active():
			dialogue.close()


func begin_first_run_tutorial() -> bool:
	if not OfficeState.tutorial_pending() or tutorial.is_active():
		return false
	tutorial.start(false)
	return true


## Floor proximity changed: advance action steps and keep the line clear.
func on_floor_update() -> void:
	if tutorial == null:
		return
	tutorial.on_floor_update()
	if dialogue.is_open() and conversation == &"":
		var rects := avoid_rects()
		dialogue.relayout(rects.hard, rects.soft)


## Presents one line in the pose's person's voice. In the office the panel is
## anchored beside the painted speaker; elsewhere only the cameo represents them.
func speak(
	pose: StringName, text_value: String, choices: Array[Dictionary], is_blocking: bool = true
) -> void:
	var person := &"secretary" if String(pose).begins_with("secretary") else &"manager"
	var speaker := {
		"name": tr("SPEAKER_SECRETARY") if person == &"secretary" else tr("SPEAKER_MANAGER"),
		"texture": PORTRAITS[pose],
		"region": SECRETARY_REGION if person == &"secretary" else MANAGER_REGION,
		"faces_right": FACES_RIGHT[person],
	}
	var placement: Dictionary = {}
	if floor_controller.room != null and floor_controller.room.id == FloorController.OFFICE:
		placement = OFFICE_PLACEMENTS[person]
	var rects := avoid_rects()
	dialogue.present(speaker, text_value, choices, rects.hard, rects.soft, is_blocking, placement)
	floor_controller.refresh_prompt()


## Screen rectangles the dialogue must not cover (`hard`: the player and HUD
## controls) or should avoid (`soft`: interaction anchors and the floor prompt).
func avoid_rects() -> Dictionary:
	var hard: Array[Rect2] = [HUD_BANK_RECT]
	var soft: Array[Rect2] = []
	var canvas := floor_controller.get_viewport().get_canvas_transform()
	var avatar_scale := floor_controller.room.avatar_scale if floor_controller.room != null else 1.0
	var foot := floor_controller.avatar_position
	hard.append(
		(
			canvas
			* Rect2(
				foot.x - 14.0 * avatar_scale,
				foot.y - 70.0 * avatar_scale,
				28.0 * avatar_scale,
				72.0 * avatar_scale
			)
		)
	)
	var back := floor_controller.room_back_button_rect()
	if back.has_area():
		hard.append(back)
	var prompt := floor_controller.prompt_rect()
	if prompt.has_area():
		hard.append(canvas * prompt)
	if floor_controller.room != null:
		for anchor_id: StringName in floor_controller.room.anchors:
			var at: Vector2 = canvas * floor_controller.room.anchor(anchor_id)
			soft.append(Rect2(at - Vector2(8, 8), Vector2(16, 16)))
		for cabinet_id: StringName in floor_controller.cabinet_positions:
			var inlay: Vector2 = floor_controller.cabinet_positions[cabinet_id]
			hard.append(canvas * Rect2(inlay - INLAY_HALF_SIZE, INLAY_HALF_SIZE * 2.0))
	return {"hard": hard, "soft": soft}


func _offer_invitation(wing_id: StringName) -> void:
	var choices: Array[Dictionary] = [
		{"id": &"invitation", "label": tr("MANAGER_SEE_INVITATION")},
	]
	speak(
		&"manager_toast",
		tr("MANAGER_INVITE_LINE") % tr("INVITE_WING_" + String(wing_id).to_upper()),
		choices
	)


func _manager_business(line: String) -> void:
	var choices: Array[Dictionary] = [
		{"id": &"markers", "label": tr("MANAGER_MARKERS")},
	]
	if Progression.can_buy_house():
		choices.append(
			{
				"id": &"deed",
				"label": tr("MANAGER_BUY_HOUSE") % HouseLevel.short_chips(HouseLevel.DEED_PRICE)
			}
		)
	choices.append({"id": &"ledger", "label": tr("MANAGER_LEDGER")})
	choices.append({"id": &"leave", "label": tr("DIALOGUE_GOODBYE"), "action": &"back"})
	var pose := &"manager_offer" if Economy.can_take_marker() or Economy.debt > 0 else &"manager"
	# The Manager keeps the standing board on his desk while he is talking.
	standing.show_standing()
	speak(pose, line, choices)


func _on_choice(choice_id: StringName) -> void:
	if String(choice_id).begins_with("tutorial_"):
		tutorial.on_choice(choice_id)
		return
	match choice_id:
		&"contracts":
			open_contracts_board()
		&"ledger":
			open_ledger()
		&"deed":
			_buy_the_house()
		&"tour":
			conversation = &""
			dialogue.close()
			tutorial.start(true)
		&"leave":
			end_conversation()
		&"invitation":
			dialogue.close()
			var wing: StringName = _pending_invitations[0]
			invitation.present(wing, int(FloorController.WING_THRESHOLDS[wing]))
			floor_controller.refresh_prompt()
		&"markers":
			conversation = &""
			dialogue.close()
			floor_controller.open_marker_desk()


func _on_invitation_accepted(wing_id: StringName) -> void:
	_pending_invitations.erase(wing_id)
	if conversation != &"manager":
		return
	if not _pending_invitations.is_empty():
		_offer_invitation(_pending_invitations[0])
	else:
		_manager_business(tr("MANAGER_AFTER_INVITATION"))


func _on_board_closed() -> void:
	conversation = &""
	floor_controller.refresh_proximity()


func _on_ledger_closed() -> void:
	conversation = &""
	standing.visible = false
	floor_controller.refresh_proximity()
	floor_controller.refresh_prompt()


func _on_deed_closed() -> void:
	standing.show_standing()
	_manager_business(tr("MANAGER_AFTER_DEED"))
