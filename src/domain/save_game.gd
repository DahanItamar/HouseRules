class_name SaveGame
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 2
## First-run tour states. Saves written before the tour existed load as DONE.
const TUTORIAL_PENDING := "pending"
const TUTORIAL_DONE := "done"
const TUTORIAL_SKIPPED := "skipped"
const TUTORIAL_STATES: Array[String] = [TUTORIAL_PENDING, TUTORIAL_DONE, TUTORIAL_SKIPPED]
const CONTRACT_LOG_SIZE: int = 6

var schema_version: int = CURRENT_SCHEMA_VERSION
var chips: int = 0
var debt: int = 0
var lifetime_wagered: int = 0
var active_contracts: Array[Dictionary] = []
var contract_completions: int = 0
var tier_unlocked: CabinetDefinition.Tier = CabinetDefinition.Tier.MAIN_FLOOR
var cabinet_stats: Dictionary = {}
var achievements: Dictionary = {}
var rng_seed: int = 0
var played_seconds: float = 0.0
var created_at: String = ""
# Strings preserve all 64 bits through JSON's floating-point number parser.
var rng_states: Dictionary = {}
var tutorial_state: String = TUTORIAL_PENDING
## Wing ids the Manager has formally invited the player into.
var wing_invitations: Array[String] = []
## Newest first: {"title_key": String, "reward": int}.
var contract_log: Array[Dictionary] = []


func to_dict() -> Dictionary:
	var stats: Dictionary = {}
	for key: Variant in cabinet_stats:
		stats[String(key)] = (cabinet_stats[key] as CabinetStats).to_dict()
	return {
		"schema_version": schema_version,
		"chips": str(chips),
		"debt": str(debt),
		"lifetime_wagered": str(lifetime_wagered),
		"active_contracts": active_contracts.duplicate(true),
		"contract_completions": str(contract_completions),
		"tier_unlocked": tier_unlocked,
		"cabinet_stats": stats,
		"achievements": achievements.duplicate(true),
		"rng_seed": str(rng_seed),
		"rng_states": rng_states.duplicate(true),
		"played_seconds": played_seconds,
		"created_at": created_at,
		"tutorial_state": tutorial_state,
		"wing_invitations": wing_invitations.duplicate(),
		"contract_log": contract_log.duplicate(true)
	}


static func from_dict(data: Dictionary) -> SaveGame:
	var result: SaveGame = SaveGame.new()
	result.schema_version = int(data.get("schema_version", CURRENT_SCHEMA_VERSION))
	result.chips = int(data.get("chips", 0))
	result.debt = int(data.get("debt", 0))
	result.lifetime_wagered = int(data.get("lifetime_wagered", 0))
	result.active_contracts.assign(data.get("active_contracts", []))
	result.contract_completions = int(data.get("contract_completions", 0))
	result.tier_unlocked = int(data.get("tier_unlocked", 0)) as CabinetDefinition.Tier
	var stats: Dictionary = data.get("cabinet_stats", {})
	for key: Variant in stats:
		result.cabinet_stats[StringName(key)] = CabinetStats.from_dict(stats[key])
	result.achievements = data.get("achievements", {}).duplicate(true)
	result.rng_seed = int(data.get("rng_seed", 0))
	result.rng_states = data.get("rng_states", {}).duplicate(true)
	result.played_seconds = float(data.get("played_seconds", 0.0))
	result.created_at = String(data.get("created_at", ""))
	var tour := str(data.get("tutorial_state", TUTORIAL_DONE))
	result.tutorial_state = tour if tour in TUTORIAL_STATES else TUTORIAL_DONE
	var invitations: Variant = data.get("wing_invitations", [])
	if invitations is Array:
		for wing: Variant in invitations:
			if wing is String and not result.wing_invitations.has(wing):
				result.wing_invitations.append(wing)
	result.contract_log = sanitize_contract_log(data.get("contract_log", []))
	return result


static func sanitize_contract_log(value: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not value is Array:
		return entries
	for entry: Variant in value:
		if entries.size() >= CONTRACT_LOG_SIZE:
			break
		if entry is Dictionary and entry.get("title_key", null) is String:
			var reward := (
				int(str(entry.get("reward", 0)))
				if str(entry.get("reward", 0)).is_valid_int()
				else 0
			)
			entries.append({"title_key": String(entry.title_key), "reward": maxi(reward, 0)})
	return entries
