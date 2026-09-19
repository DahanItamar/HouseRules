class_name CabinetSession
extends Node
## The only path from a cabinet result to the wallet.

const CABINET_SCENE_REGISTRY := preload("res://src/cabinets/cabinet_scene_registry.gd")

signal exit_requested
signal round_applied(result: RoundResult)

var cabinet: MiniGame
var context: MiniGameContext
var _seen_results: Dictionary = {}
var _is_closed: bool = false


func begin(definition: CabinetDefinition) -> void:
	assert(definition != null)
	assert(CABINET_SCENE_REGISTRY.has_scene(definition.id))
	context = MiniGameContext.new()
	context.definition = definition
	context.balance = Wallet.balance
	context.rng = RNGService.stream(definition.id)
	cabinet = CABINET_SCENE_REGISTRY.instantiate(definition.id)
	assert(cabinet != null)
	cabinet.round_resolved.connect(apply_result)
	cabinet.exit_requested.connect(func() -> void: exit_requested.emit())
	add_child(cabinet)
	cabinet.begin(context)


func apply_result(result: RoundResult) -> bool:
	if _is_closed or result == null or _seen_results.has(result):
		return false
	_seen_results[result] = true
	if not Wallet.try_apply(result.stake, result.payout):
		context.balance = Wallet.balance
		return false
	Economy.lifetime_wagered += result.stake
	if SaveService.state != null:
		var id: String = str(context.definition.id)
		var stats: CabinetStats = SaveService.state.cabinet_stats.get(id, CabinetStats.new())
		stats.rounds += 1
		stats.wagered += result.stake
		stats.returned += result.payout
		stats.best_win = maxi(stats.best_win, result.payout)
		SaveService.state.cabinet_stats[id] = stats
	Economy.record_round(context.definition.id, result)
	context.balance = Wallet.balance
	cabinet.normalize_selected_stake()
	round_applied.emit(result)
	return true


func close() -> void:
	if _is_closed:
		return
	if cabinet != null:
		if cabinet.is_result_pending:
			cabinet.complete_pending_result()
		else:
			cabinet.abandon()
	_is_closed = true
