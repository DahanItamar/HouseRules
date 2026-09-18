class_name SaveGame
extends RefCounted

const CURRENT_SCHEMA_VERSION: int = 2

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
		"created_at": created_at
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
	return result
