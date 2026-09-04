## Ghost-preview building placement (roadmap 4.2), plus roads (4.10) as one more entry in the
## same cycle: press `B` to start, `Tab` cycles the type — buildings, then a single-cell road at
## the end of the list — `R` rotates a building 90°, left click confirms, `Escape` cancels.
##
## A view node — it only ever calls `Buildings.can_place`/`place_building` or
## `Terrain.is_walkable`/`set_road`, the same headless APIs `test_buildings.gd` and
## `test_terrain_roads.gd` exercise directly. Where the mouse points at the ground is
## `TerrainRay.intersect_ground` (pure, its own tests) fed by this camera's projection; nothing
## here assumes a specific camera transform, so it keeps working through pans, turns and zooms.
class_name BuildingPlacement
extends Node3D

## Not a real `data/buildings.json` entry — a road is one cell, not a footprint, and toggles
## rather than accumulating construction state, so it does not belong in `Buildings` at all.
## Appended to the end of the cycle so existing callers that assume index 0 is a real building
## type (the demo seed, most tests) are unaffected.
const ROAD_TYPE_ID := "__road__"

const _GHOST_HEIGHT_M := 1.0
const _VALID_COLOUR := Color(0.35, 0.9, 0.35, 0.45)
const _INVALID_COLOUR := Color(0.9, 0.3, 0.25, 0.45)

var _active: bool = false
var _type_index: int = 0
var _rotation_deg: int = 0
var _mouse_pos: Vector2 = Vector2.ZERO
var _has_hover: bool = false
var _hover_cell: Vector2i = Vector2i.ZERO

var _camera: Camera3D
var _ghost: MeshInstance3D
var _valid_material: StandardMaterial3D
var _invalid_material: StandardMaterial3D


func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	_valid_material = _translucent(_VALID_COLOUR)
	_invalid_material = _translucent(_INVALID_COLOUR)

	_ghost = MeshInstance3D.new()
	_ghost.name = "Ghost"
	_ghost.mesh = BoxMesh.new()
	_ghost.visible = false
	add_child(_ghost)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("build_toggle"):
		_toggle()
		return
	if not _active:
		return

	if event is InputEventMouseMotion:
		_mouse_pos = (event as InputEventMouseMotion).position
		_update_hover()
	elif event.is_action_pressed("build_cycle"):
		var count := type_ids().size()
		if count > 0:
			_type_index = (_type_index + 1) % count
		_update_hover()
	elif event.is_action_pressed("build_rotate"):
		_rotation_deg = posmod(_rotation_deg + 90, 360)
		_update_hover()
	elif event.is_action_pressed("ui_cancel"):
		_deactivate()
	elif event.is_action_pressed("build_place"):
		_confirm()


func is_active() -> bool:
	return _active


func current_type_id() -> String:
	var ids := type_ids()
	if ids.is_empty():
		return ""
	return ids[_type_index % ids.size()]


func hover_cell() -> Vector2i:
	return _hover_cell


func has_hover() -> bool:
	return _has_hover


## Every real building type, sorted (so cycling is stable and reproducible), plus the road
## pseudo-type at the end.
func type_ids() -> Array:
	var ids := Buildings.type_ids()
	ids.append(ROAD_TYPE_ID)
	return ids


func is_road_selected() -> bool:
	return current_type_id() == ROAD_TYPE_ID


func _toggle() -> void:
	if _active:
		_deactivate()
	else:
		_activate()


func _activate() -> void:
	if _camera == null:
		_camera = get_viewport().get_camera_3d()
	_active = true
	_update_hover()


func _deactivate() -> void:
	_active = false
	_has_hover = false
	_ghost.visible = false


func _update_hover() -> void:
	if not _active or _camera == null or type_ids().is_empty():
		_has_hover = false
		_ghost.visible = false
		return

	var origin := _camera.project_ray_origin(_mouse_pos)
	var direction := _camera.project_ray_normal(_mouse_pos)
	var hit: Variant = TerrainRay.intersect_ground(origin, direction, _elevation_at_world)
	if hit == null:
		_has_hover = false
		_ghost.visible = false
		return

	_has_hover = true
	_hover_cell = Terrain.world_to_cell(hit as Vector3)
	_refresh_ghost()


func _refresh_ghost() -> void:
	var type_id := current_type_id()
	if type_id == "":
		return

	var footprint := Vector2i.ONE if type_id == ROAD_TYPE_ID else Buildings.footprint_for(type_id, _rotation_deg)
	var size_m := Vector2(footprint) * Terrain.cell_size_m()
	var height := 0.1 if type_id == ROAD_TYPE_ID else _GHOST_HEIGHT_M
	(_ghost.mesh as BoxMesh).size = Vector3(size_m.x, height, size_m.y)

	var centre := Vector2(_hover_cell) + Vector2(footprint) * 0.5
	var ground := Terrain.cell_to_world(int(floor(centre.x)), int(floor(centre.y)))
	_ghost.position = ground + Vector3(0.0, height * 0.5, 0.0)

	var valid := (
		Terrain.is_walkable(_hover_cell.x, _hover_cell.y) if type_id == ROAD_TYPE_ID
		else Buildings.can_place(type_id, _hover_cell, _rotation_deg)
	)
	_ghost.material_override = _valid_material if valid else _invalid_material
	_ghost.visible = true


func _confirm() -> void:
	if not _has_hover:
		return
	var type_id := current_type_id()
	if type_id == "":
		return
	if type_id == ROAD_TYPE_ID:
		Terrain.set_road(_hover_cell.x, _hover_cell.y, not Terrain.is_road(_hover_cell.x, _hover_cell.y))
	else:
		Buildings.place_building(type_id, _hover_cell, _rotation_deg)
	_refresh_ghost()   # the site/cell changed; recolour immediately rather than waiting for the next hover


func _elevation_at_world(world_x: float, world_z: float) -> float:
	var cell := Terrain.world_to_cell(Vector3(world_x, 0.0, world_z))
	return Terrain.elevation_at(cell.x, cell.y)


func _translucent(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
