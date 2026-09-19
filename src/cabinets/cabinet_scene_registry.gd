class_name CabinetSceneRegistry
extends RefCounted
## Presentation-side mapping from semantic cabinet ids to playable scenes.

const SCENE_PATHS: Dictionary = {
	&"slot_classic": "res://src/cabinets/slot_classic/slot_classic.tscn",
	&"blackjack": "res://src/cabinets/blackjack/blackjack.tscn",
	&"minefield_vault": "res://src/cabinets/minefield_vault/minefield_vault.tscn",
}


static func has_scene(cabinet_id: StringName) -> bool:
	return SCENE_PATHS.has(cabinet_id)


static func instantiate(cabinet_id: StringName) -> MiniGame:
	var scene_path: String = SCENE_PATHS.get(cabinet_id, "")
	assert(not scene_path.is_empty(), "No scene registered for cabinet %s" % cabinet_id)
	var packed_scene := load(scene_path) as PackedScene
	assert(packed_scene != null, "Cabinet scene failed to load: %s" % scene_path)
	return packed_scene.instantiate() as MiniGame
