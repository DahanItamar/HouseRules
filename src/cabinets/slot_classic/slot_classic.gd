extends MiniGame

var math := SlotMachineMath.new()
var _pending: RoundResult
var _spin_timer: Timer


func _ready() -> void:
	super._ready()
	_spin_timer = Timer.new()
	_spin_timer.one_shot = true
	_spin_timer.wait_time = 1.2
	_spin_timer.timeout.connect(resolve_pending)
	add_child(_spin_timer)


func start_round(amount: int) -> bool:
	if not can_stake(amount):
		return false
	current_stake = amount
	is_round_active = true
	_pending = math.spin(amount, context.rng)
	_spin_timer.start()
	panel.set_status("ROUND_SPINNING")
	return true


func resolve_pending() -> void:
	if not is_round_active or _pending == null:
		return
	var result: RoundResult = _pending
	_pending = null
	_finish(result)


func abandon() -> void:
	_pending = null
	if _spin_timer != null:
		_spin_timer.stop()
	super.abandon()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		start_round(selected_stake)
		get_viewport().set_input_as_handled()
	else:
		super._unhandled_input(event)
