extends Node

signal menu_requested
signal session_changed

var floor: FloorController
var session: CabinetSession
var _return_position: Vector2
var _transitioning: bool = false


func register_floor(controller: FloorController) -> void:
	floor = controller


func enter_cabinet(definition: CabinetDefinition) -> void:
	if _transitioning or session != null or definition == null or Wallet.balance < definition.min_bet:
		return
	if DisplayServer.get_name() == "headless":
		_enter_cabinet_now(definition)
		return
	_transitioning = true
	if floor != null:
		floor.set_physics_process(false)
		floor.set_process_unhandled_input(false)
	_enter_cabinet_animated(definition)


func _enter_cabinet_animated(definition: CabinetDefinition) -> void:
	await ScreenTransition.cover()
	_enter_cabinet_now(definition)
	await ScreenTransition.reveal()
	_transitioning = false


func _enter_cabinet_now(definition: CabinetDefinition) -> void:
	if floor != null:
		_return_position = floor.avatar_position
		floor.set_physics_process(false)
		floor.set_process_unhandled_input(false)
		floor.set_prompt_visible(false)
	session = CabinetSession.new()
	add_child(session)
	session.exit_requested.connect(return_to_floor)
	session.begin(definition)
	session_changed.emit()


func return_to_floor() -> void:
	if _transitioning or session == null:
		return
	if DisplayServer.get_name() == "headless":
		_return_to_floor_now()
		return
	_transitioning = true
	if session.cabinet != null:
		session.cabinet.set_process_unhandled_input(false)
	_return_to_floor_animated()


func _return_to_floor_animated() -> void:
	await ScreenTransition.cover()
	_return_to_floor_now()
	await ScreenTransition.reveal()
	_transitioning = false


func _return_to_floor_now() -> void:
	session.close()
	SaveService.save()
	remove_child(session)
	session.queue_free()
	session = null
	if is_instance_valid(floor):
		floor.avatar_position = _return_position
		floor.set_physics_process(true)
		floor.set_process_unhandled_input(true)
		floor.set_prompt_visible(true)
		floor.refresh_proximity()
		floor.dismiss_game_prompt()
	session_changed.emit()


func return_to_menu() -> void:
	if session != null:
		return_to_floor()
	else:
		SaveService.save()
	menu_requested.emit()
