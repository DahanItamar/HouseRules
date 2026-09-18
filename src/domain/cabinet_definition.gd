class_name CabinetDefinition
extends Resource

enum Tier { MAIN_FLOOR, HIGH_ROLLER, VIP }
enum Volatility { LOW, MEDIUM, HIGH }

@export var id: StringName = &""
@export var name_key: String = ""
@export var tier: Tier = Tier.MAIN_FLOOR
@export var scene: PackedScene
@export var min_bet: int = 1
@export var max_bet: int = 50
@export var target_rtp: float = 0.96
@export var volatility: Volatility = Volatility.MEDIUM
@export var unlock_chips: int = 0


func is_valid_definition() -> bool:
	return (
		id != &""
		and not name_key.is_empty()
		and scene != null
		and min_bet > 0
		and max_bet >= min_bet
		and is_finite(target_rtp)
		and target_rtp >= 0.80
		and target_rtp <= 1.20
		and tier >= Tier.MAIN_FLOOR
		and tier <= Tier.VIP
		and volatility >= Volatility.LOW
		and volatility <= Volatility.HIGH
		and unlock_chips >= 0
	)
