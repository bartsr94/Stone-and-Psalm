## Save and load: the orchestrator. `SIMULATION_SPEC.md` §19, Architecture Guide §8.
##
## Every authoritative autoload implements `serialize() -> Dictionary` /
## `deserialize(Dictionary)`. This calls them in a fixed order and writes one JSON document
## with a schema version stamped on top; load reverses it. It holds no game state itself, and
## it references the other autoloads by their singleton names — never `get_tree()`, so the
## Fundamental Rule (only `world_renderer` touches the tree) still holds.
##
## The systems are listed explicitly, not discovered, so the save format is stable and
## reviewable: adding a system is a deliberate line here.
extends Node

const SCHEMA_VERSION := 1
const SAVE_DIR := "user://saves"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIR))


## The whole game state as one Dictionary, systems always visited in the same order so the same
## state always produces the same document. `Tuning` and `Goods` are pure config and are not
## saved; `Terrain` rebuilds every other array from its preset and saves only its roads, the one
## piece of terrain state a player actually edits (Phase 4.10).
func capture() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"systems": {
			"SimClock": SimClock.serialize(),
			"Terrain": Terrain.serialize(),
			"Weather": Weather.serialize(),
			"Liturgy": Liturgy.serialize(),
			"Population": Population.serialize(),
			"Buildings": Buildings.serialize(),
			"Hauling": Hauling.serialize(),
		},
	}


## Restores a captured state. A system missing from the document keeps its current state; a
## save from a newer build is refused rather than half-loaded.
func restore(state: Dictionary) -> bool:
	if int(state.get("schema_version", 0)) > SCHEMA_VERSION:
		push_error("SaveManager: save is schema v%d, this build understands v%d" % [
			state.get("schema_version", 0), SCHEMA_VERSION
		])
		return false

	var systems: Dictionary = state.get("systems", {})
	if systems.has("SimClock"):
		SimClock.deserialize(systems["SimClock"])
	if systems.has("Terrain"):
		Terrain.deserialize(systems["Terrain"])
	if systems.has("Weather"):
		Weather.deserialize(systems["Weather"])
	if systems.has("Liturgy"):
		Liturgy.deserialize(systems["Liturgy"])
	if systems.has("Population"):
		Population.deserialize(systems["Population"])
	if systems.has("Buildings"):
		Buildings.deserialize(systems["Buildings"])
	if systems.has("Hauling"):
		Hauling.deserialize(systems["Hauling"])
	return true


## A stable hash of the current game state — for the determinism acceptance test (save, load,
## run N ticks must equal running N ticks straight through). JSON with sorted keys, so the
## hash does not depend on dictionary iteration order.
func state_hash() -> String:
	return JSON.stringify(capture(), "", true).sha256_text()


func save_to_slot(slot: String) -> Error:
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: cannot write %s" % path)
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(capture(), "  "))
	return OK


func load_from_slot(slot: String) -> bool:
	var path := "%s/%s.json" % [SAVE_DIR, slot]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveManager: cannot read %s" % path)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("SaveManager: %s is not a JSON object" % path)
		return false
	return restore(parsed)
