## One placed building: its site, its construction state, and its local inventory.
##
## Authoritative and headless, owned by `autoloads/buildings.gd` exactly as `Person` is owned by
## `Population` (Architecture Guide §2.2). Static facts about the *type* (footprint, build cost,
## worker slots) live in `data/buildings.json` and are looked up by `type_id` rather than copied
## in here, so retuning a building type never requires migrating saved instances.
##
## `inventory` is this building's own stock and nothing else's — `SIMULATION_SPEC.md` §10's
## rule that there is no global resource pool starts here.
class_name Building
extends RefCounted

## `SIMULATION_SPEC.md` §7.1. RUINED is reserved for Phase 6+ (collapse from neglect); nothing
## drives a building into it yet. Append-only — the save format depends on the order.
enum State { PLANNED, MATERIALS_PENDING, UNDER_CONSTRUCTION, COMPLETE, RUINED }

var id: int = 0
var type_id: String = ""
var anchor: Vector2i = Vector2i.ZERO      ## the footprint's low corner, in terrain cells
var footprint: Vector2i = Vector2i.ONE    ## width × length in cells, already rotated
var rotation_deg: int = 0

var construction_state: State = State.PLANNED
var build_progress: float = 0.0
var delivered_materials: Dictionary = {}  ## good_id -> qty delivered so far
var assigned_workers: Array[int] = []     ## person ids; slot enforcement is Phase 4.9
var inventory: Dictionary = {}            ## good_id -> qty held locally
var active_recipe: String = ""            ## empty until Phase 5 production exists
var recipe_progress: float = 0.0
var condition: float = 100.0              ## decay is a Phase 5+ concern; carried for the save format

var _door_cell: Vector2i = Vector2i.ZERO
var _door_known: bool = false


func footprint_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in footprint.y:
		for dx in footprint.x:
			cells.append(anchor + Vector2i(dx, dy))
	return cells


func contains_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= anchor.x and cell.x < anchor.x + footprint.x
		and cell.y >= anchor.y and cell.y < anchor.y + footprint.y
	)


## The door cell, once found by `autoloads/buildings.gd`, cached on the instance so repeated
## haul/build tasks do not re-search the surrounding cells every time.
func cached_door() -> Vector2i:
	return _door_cell


func has_cached_door() -> bool:
	return _door_known


func set_cached_door(cell: Vector2i) -> void:
	_door_cell = cell
	_door_known = true


func to_dict() -> Dictionary:
	var assigned: Array = []
	for person_id in assigned_workers:
		assigned.append(person_id)
	return {
		"id": id,
		"type_id": type_id,
		"anchor": [anchor.x, anchor.y],
		"footprint": [footprint.x, footprint.y],
		"rotation_deg": rotation_deg,
		"construction_state": construction_state,
		"build_progress": build_progress,
		"delivered_materials": delivered_materials.duplicate(),
		"assigned_workers": assigned,
		"inventory": inventory.duplicate(),
		"active_recipe": active_recipe,
		"recipe_progress": recipe_progress,
		"condition": condition,
		"door_cell": [_door_cell.x, _door_cell.y] if _door_known else null,
	}


static func from_dict(data: Dictionary) -> Building:
	var b := Building.new()
	b.id = int(data.get("id", 0))
	b.type_id = str(data.get("type_id", ""))
	b.anchor = _to_cell(data.get("anchor", [0, 0]))
	b.footprint = _to_cell(data.get("footprint", [1, 1]))
	b.rotation_deg = int(data.get("rotation_deg", 0))
	b.construction_state = int(data.get("construction_state", State.PLANNED)) as State
	b.build_progress = float(data.get("build_progress", 0.0))
	b.delivered_materials = (data.get("delivered_materials", {}) as Dictionary).duplicate()
	var assigned: Array[int] = []
	for person_id in data.get("assigned_workers", []):
		assigned.append(int(person_id))
	b.assigned_workers = assigned
	b.inventory = (data.get("inventory", {}) as Dictionary).duplicate()
	b.active_recipe = str(data.get("active_recipe", ""))
	b.recipe_progress = float(data.get("recipe_progress", 0.0))
	b.condition = float(data.get("condition", 100.0))
	var door: Variant = data.get("door_cell", null)
	if door != null:
		b.set_cached_door(_to_cell(door))
	return b


static func _to_cell(pair: Variant) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))
