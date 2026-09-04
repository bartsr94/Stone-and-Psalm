## Every built road cell (Phase 4.10) as a flat tinted plate. Presentation only — it draws in
## response to `Terrain.road_changed` rather than polling the whole grid every frame, and reads
## `Terrain.road_cells()` once at start-up to pick up anything a save already restored before
## this node's `_ready` ran.
extends Node3D

var _tiles: Dictionary = {}   ## Vector2i cell -> MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Palette.of("mud")
	_material.roughness = 1.0

	Terrain.road_changed.connect(_on_road_changed)
	for cell in Terrain.road_cells():
		_add_tile(cell)


func _on_road_changed(x: int, y: int, is_road: bool) -> void:
	var cell := Vector2i(x, y)
	if is_road:
		_add_tile(cell)
	else:
		_remove_tile(cell)


func _add_tile(cell: Vector2i) -> void:
	if _tiles.has(cell):
		return
	var plate := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var cell_size := Terrain.cell_size_m()
	mesh.size = Vector3(cell_size, 0.06, cell_size)
	plate.mesh = mesh
	plate.material_override = _material
	plate.position = Terrain.cell_to_world(cell.x, cell.y) + Vector3(0.0, 0.03, 0.0)
	add_child(plate)
	_tiles[cell] = plate


func _remove_tile(cell: Vector2i) -> void:
	if not _tiles.has(cell):
		return
	(_tiles[cell] as MeshInstance3D).queue_free()
	_tiles.erase(cell)
