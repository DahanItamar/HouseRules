class_name TutorialDirector
extends Node
## The secretary's first-run tour of the casino.
##
## Talking steps wait for confirm. Action steps stay on screen without blocking
## the floor and advance when the player actually moves, reaches a game's join
## inlay or joins a table. Back skips the tour at any time. Finishing or skipping
## is saved; a replay from reception runs the same steps.

signal finished(skipped: bool)
signal step_changed(step_id: StringName)

enum Advance { CONFIRM, MOVED, INLAY, JOIN }

const MOVE_DISTANCE: float = 32.0
const STEPS: Array[Dictionary] = [
	{"id": &"welcome", "pose": &"secretary", "advance": Advance.CONFIRM},
	{"id": &"move", "pose": &"secretary_explain", "advance": Advance.MOVED},
	{"id": &"inlay", "pose": &"secretary_point", "advance": Advance.INLAY},
	{"id": &"join", "pose": &"secretary_explain", "advance": Advance.JOIN},
	{"id": &"cashier", "pose": &"secretary_point", "advance": Advance.CONFIRM},
	{"id": &"contracts", "pose": &"secretary_explain", "advance": Advance.CONFIRM},
	{"id": &"manager", "pose": &"secretary", "advance": Advance.CONFIRM},
	{"id": &"help", "pose": &"secretary", "advance": Advance.CONFIRM},
]

var host: OfficeHost
var step_index: int = -1
var replaying: bool = false
var _origin := Vector2.ZERO
var _advance_on_return: bool = false


func _ready() -> void:
	SceneRouter.session_changed.connect(_on_session_changed)


func is_active() -> bool:
	return step_index >= 0


func current_step_id() -> StringName:
	return STEPS[step_index].id if is_active() else &""


func is_blocking() -> bool:
	return is_active() and int(STEPS[step_index].advance) == Advance.CONFIRM


func start(replay: bool = false) -> void:
	replaying = replay
	_advance_on_return = false
	var floor_controller := host.floor_controller
	if not floor_controller.is_main_floor():
		floor_controller.enter_room(FloorController.MAIN_FLOOR)
	_show(0)


func advance() -> void:
	if not is_active():
		return
	if step_index + 1 >= STEPS.size():
		_finish(false)
		return
	_show(step_index + 1)


func skip() -> void:
	if is_active():
		_finish(true)


func on_choice(choice_id: StringName) -> void:
	match choice_id:
		&"tutorial_next":
			advance()
		&"tutorial_skip":
			skip()


## Called whenever the floor refreshes proximity (every move and room change).
func on_floor_update() -> void:
	if not is_active() or SceneRouter.session != null:
		return
	var floor_controller := host.floor_controller
	match int(STEPS[step_index].advance):
		Advance.MOVED:
			if floor_controller.avatar_position.distance_to(_origin) >= MOVE_DISTANCE:
				advance()
		Advance.INLAY:
			if floor_controller.nearby_definition != null:
				advance()


func handle_input(event: InputEvent) -> bool:
	if not is_active():
		return false
	if event.is_action_pressed("back"):
		skip()
		return true
	if is_blocking():
		host.dialogue.handle_input(event)
		return true
	# Action steps leave movement and table joining to the floor; the secondary
	# button moves the tour on for a player who would rather not do the action.
	if event.is_action_pressed("secondary"):
		advance()
		return true
	return false


static func index_of(step_id: StringName) -> int:
	for index: int in range(STEPS.size()):
		if STEPS[index].id == step_id:
			return index
	return -1


func line_text(step_id: StringName) -> String:
	match step_id:
		&"move":
			return tr("TUTORIAL_MOVE") % InputPromptLabel.token(&"move")
		&"join":
			return tr("TUTORIAL_JOIN") % InputPromptLabel.tokens([&"interact", &"back"])
		&"help":
			return tr("TUTORIAL_HELP") % InputPromptLabel.token(&"help")
	return tr("TUTORIAL_" + String(step_id).to_upper())


func _show(index: int) -> void:
	step_index = index
	var step: Dictionary = STEPS[index]
	_origin = host.floor_controller.avatar_position
	var choices: Array[Dictionary] = []
	var last := index == STEPS.size() - 1
	if int(step.advance) == Advance.CONFIRM:
		(
			choices
			. append(
				{
					"id": &"tutorial_next",
					"label": tr("TUTORIAL_DONE") if last else tr("TUTORIAL_NEXT"),
					"action": &"interact",
				}
			)
		)
	elif int(step.advance) == Advance.JOIN:
		(
			choices
			. append(
				{
					"id": &"tutorial_next",
					"label": tr("TUTORIAL_NEXT"),
					"action": &"secondary",
				}
			)
		)
	if not last:
		choices.append(
			{"id": &"tutorial_skip", "label": tr("TUTORIAL_SKIP_LABEL"), "action": &"back"}
		)
	host.speak(step.pose, line_text(step.id), choices, is_blocking())
	step_changed.emit(step.id)


func _finish(skipped: bool) -> void:
	step_index = -1
	_advance_on_return = false
	host.dialogue.close()
	OfficeState.set_tutorial_state(SaveGame.TUTORIAL_SKIPPED if skipped else SaveGame.TUTORIAL_DONE)
	host.floor_controller.refresh_proximity()
	finished.emit(skipped)


func _on_session_changed() -> void:
	if not is_active():
		return
	if SceneRouter.session != null:
		# Joining a table completes the join lesson; the tour resumes afterwards.
		if current_step_id() in [&"inlay", &"join"]:
			_advance_on_return = true
			step_index = index_of(&"join")
	elif _advance_on_return:
		_advance_on_return = false
		advance()
