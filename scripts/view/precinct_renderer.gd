## The precinct: a timber church and a dormitory range for the one monk to walk between.
## Presentation only — it reads the resolved building cells from `Population` and
## `data/precinct.json` and owns nothing. Phase 8 replaces the church with the real staged build.
##
## These two are the largest things in the valley until the stone church rises, so they are drawn
## from authored `bld_precinct_*.glb` models on the same terms as every player-placed building
## (`BuildingModels`), sharing the same vertex-colour material. The original boxes remain as the
## fallback for a precinct entry with no model, which is what keeps `data/precinct.json` editable
## without waiting on art.
extends Node3D

const MODEL_PREFIX := "precinct_"
const MATERIAL_PATH := "res://assets/materials/m_building.tres"

var _materials: Dictionary = {}
var _model_material: ShaderMaterial = null
var _seasons := SeasonBlender.new()


func _ready() -> void:
	_model_material = load(MATERIAL_PATH)
	if _model_material != null:
		_model_material = _model_material.duplicate()
	SimClock.day_passed.connect(_on_day_passed)
	_apply_season()

	var config := Population.precinct_config()
	for building in config.get("buildings", []):
		_build_building(building as Dictionary)
	_mark_work_site()


func _on_day_passed(_day_of_year: int) -> void:
	_apply_season()


## The precinct shares the buildings' snow blend, so a roof here whitens with every other roof.
func _apply_season() -> void:
	var state := _seasons.sample(SimClock.day_of_year())
	if state.is_empty() or _model_material == null:
		return
	_model_material.set_shader_parameter("snow_amount", state["snow_coverage"])


func _build_building(building: Dictionary) -> void:
	var cell := _resolved_cell(building)
	var ground := Terrain.cell_to_world(cell.x, cell.y)
	var size := _vec3(building["size_m"])

	var root := Node3D.new()
	root.name = str(building["id"]).capitalize()
	root.position = ground
	add_child(root)

	var mesh := BuildingModels.mesh_for(MODEL_PREFIX + str(building["id"]))
	if mesh != null:
		var instance := MeshInstance3D.new()
		instance.name = "Model"
		instance.mesh = mesh
		instance.material_override = _model_material
		root.add_child(instance)
		return

	var walls := _box(size, _material(str(building.get("colour", "oak_weathered"))))
	walls.name = "Walls"
	walls.position = Vector3(0.0, size.y * 0.5, 0.0)
	root.add_child(walls)

	# A shallow hipped roof: a flatter, wider box sitting on the wall plate.
	var roof_size := Vector3(size.x * 1.12, maxf(size.y * 0.35, 1.4), size.z * 1.08)
	var roof := _box(roof_size, _material(str(building.get("roof_colour", "thatch"))))
	roof.name = "Roof"
	roof.position = Vector3(0.0, size.y + roof_size.y * 0.5 - 0.15, 0.0)
	root.add_child(roof)

	if building.has("tower_m"):
		var tower_size := _vec3(building["tower_m"])
		var tower := _box(tower_size, _material(str(building.get("colour", "oak_weathered"))))
		tower.name = "Tower"
		tower.position = Vector3(0.0, tower_size.y * 0.5, -size.z * 0.5 + tower_size.z * 0.5)
		root.add_child(tower)
		var spire := _box(
			Vector3(tower_size.x * 0.5, tower_size.y * 0.6, tower_size.z * 0.5),
			_material(str(building.get("roof_colour", "shingle")))
		)
		spire.name = "Spire"
		spire.position = tower.position + Vector3(0.0, tower_size.y * 0.5 + tower_size.y * 0.3, 0.0)
		root.add_child(spire)


## A low cairn of stones marking where work happens, so the assart reads as a place in a clip.
func _mark_work_site() -> void:
	var cell := Population.work_site_cell()
	var marker := _box(Vector3(1.4, 0.8, 1.4), _material("gritstone"))
	marker.name = "AssartMarker"
	marker.position = Terrain.cell_to_world(cell.x, cell.y) + Vector3(0.0, 0.4, 0.0)
	add_child(marker)


func _resolved_cell(building: Dictionary) -> Vector2i:
	# Population already snapped the anchor to walkable ground for the door; re-derive the
	# footprint from the door and the offset so the box sits where the monk enters it.
	var door_offset := Vector2i(int(building["door_offset_cells"][0]), int(building["door_offset_cells"][1]))
	if str(building["id"]) == "church":
		return Population.church_door() - door_offset
	if str(building["id"]) == "dormitory":
		return Population.dormitory_door() - door_offset
	return Vector2i(int(building["anchor"][0]), int(building["anchor"][1]))


func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _material(palette_key: String) -> StandardMaterial3D:
	if not _materials.has(palette_key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Palette.of(palette_key)
		material.roughness = 0.9
		material.metallic = 0.0
		_materials[palette_key] = material
	return _materials[palette_key]


func _vec3(array: Variant) -> Vector3:
	return Vector3(float(array[0]), float(array[1]), float(array[2]))
