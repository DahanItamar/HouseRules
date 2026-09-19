extends MiniGame

var math := SlotMachineMath.new()
var _pending: RoundResult


func _ready() -> void:
	super._ready()


func start_round(amount: int) -> bool:
	if not can_stake(amount):
		return false
	current_stake = amount
	is_round_active = true
	AudioService.play(&"chip")
	_pending = math.spin(amount, context.rng)
	panel.begin_slot_spin(_pending.detail.get("symbols", [0, 1, 2]), resolve_pending)
	return true


func resolve_pending() -> void:
	if not is_round_active or _pending == null:
		return
	var result: RoundResult = _pending
	_pending = null
	_finish(result)


func request_spin() -> bool:
	return start_round(selected_stake)


func abandon() -> void:
	_pending = null
	super.abandon()


func _unhandled_input(event: InputEvent) -> void:
	if handle_common_input(event):
		return
	if event.is_action_pressed("interact"):
		request_spin()
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)
