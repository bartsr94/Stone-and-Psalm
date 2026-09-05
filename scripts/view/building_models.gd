## Looks up the authored `.glb` for a building type, and caches it.
##
## A view helper, not a node and not authoritative: it turns a `type_id` from
## `data/buildings.json` into a `Mesh`, and nothing else knows or cares where that mesh came
## from. Both `buildings_renderer.gd` and `building_placement.gd` go through here, so a building
## and its own placement ghost can never be different shapes.
##
## **A missing model is not an error.** The path is derived from the type id by convention, and a
## type with no `.glb` yet returns `null` so the caller can fall back to the greybox box. That is
## what keeps the promise in CLAUDE.md — a new building type needs a JSON entry, a `.glb`, and no
## code — honest in both directions: the entry works before the art exists, and the art is picked
## up the moment it does, with no registry to edit in between.
class_name BuildingModels
extends RefCounted

const MODEL_DIR := "res://assets/models/"
const MODEL_PREFIX := "bld_"

## type_id -> Mesh, or `null` recorded for a type whose model is absent, so a missing file is
## looked for once rather than on every frame of every site.
static var _meshes: Dictionary = {}


static func path_for(type_id: String) -> String:
	return "%s%s%s.glb" % [MODEL_DIR, MODEL_PREFIX, type_id]


## The mesh for this building type, or `null` if it has no authored model.
static func mesh_for(type_id: String) -> Mesh:
	if _meshes.has(type_id):
		return _meshes[type_id]

	var mesh: Mesh = null
	var path := path_for(type_id)
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		if scene != null:
			var root: Node = scene.instantiate()
			mesh = _first_mesh(root)
			# The instance was only ever a carrier for the mesh resource, which outlives it.
			root.free()
		if mesh == null:
			push_error("BuildingModels: %s has no mesh" % path)

	_meshes[type_id] = mesh
	return mesh


## Discards the cache. Only tests need this — nothing swaps a model at runtime.
static func clear_cache() -> void:
	_meshes.clear()


static func _first_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null
