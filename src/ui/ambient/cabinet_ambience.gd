class_name CabinetAmbience
extends RefCounted
## Places each cabinet's own ambient layer inside its painted backdrop.
##
## The layer is inserted into the panel's `CabinetArt` root directly above the
## backdrop node, so every reel, card, tile, board, presenter and control that the
## panel adds afterwards draws over it. Attaching twice is harmless.
##
## A cabinet without a row in `LAYERS` simply has no ambience. To give a new
## cabinet one, write its `AmbientLayer` subclass and add a single row here;
## `docs/design/AMBIENT-LIFE.md` has the four-step hook and the alpha caps the
## shared test suite enforces.

const NODE_NAME := "CabinetAmbience"
const ELVEN_COURT := preload("res://src/ui/ambient/elven_court_ambient.gd")
const CARD_TABLE := preload("res://src/ui/ambient/card_table_ambient.gd")
const HEXBOUND_VAULT := preload("res://src/ui/ambient/hexbound_vault_ambient.gd")
const ROULETTE := preload("res://src/ui/ambient/roulette_ambient.gd")
const BACCARAT := preload("res://src/ui/ambient/baccarat_ambient.gd")
const MATCH_POINT := preload("res://src/ui/ambient/match_point_ambient.gd")
## Cabinet id -> the backdrop node the ambient layer sits on, and its script.
const LAYERS: Dictionary = {
	&"slot_classic": {"anchor": "SlotCabinetArt", "script": ELVEN_COURT},
	&"blackjack": {"anchor": "BlackjackTableArt", "script": CARD_TABLE},
	&"minefield_vault": {"anchor": "VaultBackdropArt", "script": HEXBOUND_VAULT},
	&"roulette": {"anchor": "RouletteSalonArt", "script": ROULETTE},
	&"poker": {"anchor": "PokerTableArt", "script": CARD_TABLE},
	&"baccarat": {"anchor": "BaccaratSalonArt", "script": BACCARAT},
	&"match_point": {"anchor": "MatchPointClubhouse", "script": MATCH_POINT},
}


## Adds the ambient layer for the panel's cabinet once its art exists. Returns
## the layer, or null for a cabinet without one (or before its art is built).
static func attach(panel: Node) -> AmbientLayer:
	if panel == null:
		return null
	var art := panel.get_node_or_null("CabinetArt")
	var cabinet: Variant = panel.get("cabinet")
	if art == null or cabinet == null or cabinet.get("context") == null:
		return null
	var existing := art.get_node_or_null(NODE_NAME) as AmbientLayer
	if existing != null:
		return existing
	var cabinet_id: StringName = cabinet.context.definition.id
	var spec: Dictionary = LAYERS.get(cabinet_id, {})
	if spec.is_empty():
		return null
	var anchor := art.get_node_or_null(String(spec["anchor"]))
	if anchor == null:
		return null
	var layer := (spec["script"] as GDScript).new() as AmbientLayer
	layer.name = NODE_NAME
	layer.cabinet_id = cabinet_id
	layer.backdrop_texture = anchor.get("texture") as Texture2D
	art.add_child(layer)
	art.move_child(layer, anchor.get_index() + 1)
	if layer.has_method("place_overlays"):
		layer.call("place_overlays", art)
	return layer


## The ambient layer inside a panel, if one is attached.
static func find(panel: Node) -> AmbientLayer:
	var art := panel.get_node_or_null("CabinetArt") if panel != null else null
	return art.get_node_or_null(NODE_NAME) as AmbientLayer if art != null else null
