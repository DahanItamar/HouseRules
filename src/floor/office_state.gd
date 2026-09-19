class_name OfficeState
extends RefCounted
## Persistent Manager's Office state: the secretary's first-run tour and the
## Manager's one-time wing invitations, both stored in the active save.
##
## Invitations issued while the developer test bank is active are remembered for
## the session only, so test play never marks the player's real save.

const WINGS: Array[StringName] = [&"high_roller", &"vip"]

static var _session_invitations: Dictionary = {}


static func tutorial_state() -> String:
	if SaveService.state == null:
		return SaveGame.TUTORIAL_DONE
	return SaveService.state.tutorial_state


static func tutorial_pending() -> bool:
	return tutorial_state() == SaveGame.TUTORIAL_PENDING


static func set_tutorial_state(value: String) -> void:
	assert(value in SaveGame.TUTORIAL_STATES, "Unknown tutorial state: %s" % value)
	if SaveService.state == null:
		return
	SaveService.state.tutorial_state = value
	SaveService.save()


static func has_invitation(wing_id: StringName) -> bool:
	if _session_invitations.has(wing_id):
		return true
	return SaveService.state != null and SaveService.state.wing_invitations.has(String(wing_id))


static func record_invitation(wing_id: StringName) -> void:
	if Wallet.test_mode_enabled or SaveService.state == null:
		_session_invitations[wing_id] = true
		return
	if not SaveService.state.wing_invitations.has(String(wing_id)):
		SaveService.state.wing_invitations.append(String(wing_id))
		SaveService.save()


## Wings the floor's existing unlock rule has opened but the Manager has not
## yet formally offered, in threshold order.
static func pending_invitations(floor: FloorController) -> Array[StringName]:
	var pending: Array[StringName] = []
	for wing_id: StringName in WINGS:
		if floor.is_wing_unlocked(wing_id) and not has_invitation(wing_id):
			pending.append(wing_id)
	return pending


static func clear_session() -> void:
	_session_invitations.clear()
