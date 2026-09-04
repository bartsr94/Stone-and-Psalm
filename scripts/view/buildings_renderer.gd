## The greybox construction site: every player-placed `Building`, drawn from its footprint,
## construction state and `build_progress`. Presentation only — reads `Buildings` every frame
## and writes nothing back, same contract as `monk_view.gd`.
##
## A site rises from a staked-out plot to its full height as `build_progress` climbs, and gets a
## roof once `COMPLETE` — the honest greybox picture of "under construction" (roadmap 4.11) until
## a real per-building model exists (Phase 5+, once recipes give buildings their working
## silhouette).
extends Node3D

## Full wall height by category, since `data/buildings.json` does not carry a height yet (its
## footprint is a 2D floor plan). Placeholder, same spirit as the precinct's greybox boxes.
const _FULL_HEIGHT_M := {"production": 3.2, "storage": 3.8}
const _DEFAULT_HEIGHT_M := 3.0
const _SITE_HEIGHT_M := 0.15   ## a cleared, staked-out plot before any wall has risen

var _materials: Dictionary = {}
var _sites: Dictionary = {}   ## building id -> _Site


func _process(_delta: float) -> void:
	var ids := Buildings.building_ids()
	for id in ids:
		var site: _Site = _sites.get(id)
		if site == null:
			site = _Site.new()
			site.build()
			add_child(site.root)
			_sites[id] = site
		_refresh(site, id)

	for id in _sites.keys():
		if not ids.has(id):
			(_sites[id] as _Site).root.queue_free()
			_sites.erase(id)


func _refresh(site: _Site, id: int) -> void:
	var b := Buildings.get_building(id)
	var type := Buildings.get_type(b.type_id)
	var full_height: float = _FULL_HEIGHT_M.get(str(type.get("category", "")), _DEFAULT_HEIGHT_M)

	var height := full_height
	match b.construction_state:
		Building.State.PLANNED, Building.State.MATERIALS_PENDING:
			height = _SITE_HEIGHT_M
		Building.State.UNDER_CONSTRUCTION:
			height = lerpf(_SITE_HEIGHT_M, full_height, clampf(b.build_progress, 0.0, 1.0))
		_:
			height = full_height

	var footprint_m := Vector2(b.footprint) * Terrain.cell_size_m()
	var centre := Vector2(b.anchor) + Vector2(b.footprint) * 0.5
	var ground := Terrain.cell_to_world(int(floor(centre.x)), int(floor(centre.y)))

	site.root.position = ground
	site.set_size(Vector3(footprint_m.x, height, footprint_m.y))
	site.set_wall_material(_material(str(type.get("colour", "soil"))))
	site.show_roof(
		b.construction_state == Building.State.COMPLETE,
		_material(str(type.get("roof_colour", "thatch"))),
		full_height
	)


func _material(palette_key: String) -> StandardMaterial3D:
	if not _materials.has(palette_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.of(palette_key)
		material.roughness = 0.9
		material.metallic = 0.0
		_materials[palette_key] = material
	return _materials[palette_key]


## One rendered building: rising walls, and a roof once complete.
class _Site:
	var root: Node3D
	var _walls: MeshInstance3D
	var _wall_mesh: BoxMesh
	var _roof: MeshInstance3D

	func build() -> void:
		root = Node3D.new()
		root.name = "ConstructionSite"
		_wall_mesh = BoxMesh.new()
		_walls = MeshInstance3D.new()
		_walls.mesh = _wall_mesh
		root.add_child(_walls)

	func set_size(size: Vector3) -> void:
		_wall_mesh.size = size
		_walls.position = Vector3(0.0, size.y * 0.5, 0.0)

	func set_wall_material(material: Material) -> void:
		_walls.material_override = material

	func show_roof(complete: bool, material: Material, full_height: float) -> void:
		if not complete:
			if _roof != null:
				_roof.visible = false
			return
		if _roof == null:
			_roof = MeshInstance3D.new()
			_roof.mesh = BoxMesh.new()
			root.add_child(_roof)
		var wall_size: Vector3 = _wall_mesh.size
		var roof_size := Vector3(wall_size.x * 1.1, maxf(full_height * 0.3, 1.0), wall_size.z * 1.06)
		(_roof.mesh as BoxMesh).size = roof_size
		_roof.position = Vector3(0.0, full_height + roof_size.y * 0.5 - 0.1, 0.0)
		_roof.material_override = material
		_roof.visible = true
