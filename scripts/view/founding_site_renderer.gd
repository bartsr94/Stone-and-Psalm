## Places the first-foundation landmarks as a small, deterministic presentation layer.
##
## This is view state only. The anchors and labels live in data/founding_site.json, while the
## terrain search prevents a prop from floating on water or being planted on a steep bank. A
## later Buildings system can replace this layer without changing the valley or its save format.
extends Node3D

const SETTINGS_PATH := "res://data/founding_site.json"
const MATERIAL_PATH := "res://assets/materials/m_stone_and_psalm.tres"

var _settings: Dictionary = {}
var _models: Dictionary = {
	"founders_cross": "res://assets/models/prop_founders_cross.glb",
	"timber_shelter": "res://assets/models/prop_timber_shelter.glb",
	"campfire": "res://assets/models/prop_campfire.glb",
}
var _material: Material = null
var _lights: Array[Dictionary] = []
var _elapsed: float = 0.0
var _placements: Array[Dictionary] = []


func _ready() -> void:
	if not _load_settings():
		return
	_material = load(MATERIAL_PATH)
	_populate()


func _process(delta: float) -> void:
	_elapsed += delta
	for entry in _lights:
		var light: OmniLight3D = entry["light"] as OmniLight3D
		var base_energy: float = float(entry["energy"])
		# A restrained deterministic flicker keeps the fire alive without touching simulation RNG.
		light.light_energy = base_energy * (0.90 + 0.07 * sin(_elapsed * 8.3) + 0.03 * sin(_elapsed * 17.1))


func _load_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("FoundingSiteRenderer: cannot open %s" % SETTINGS_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary and parsed.has("site") and parsed.has("landmarks")):
		push_error("FoundingSiteRenderer: invalid settings in %s" % SETTINGS_PATH)
		return false
	_settings = parsed as Dictionary
	return true


func _populate() -> void:
	for landmark_variant in _settings["landmarks"]:
		var landmark: Dictionary = landmark_variant as Dictionary
		var cell := _find_valid_cell(landmark)
		if cell.x < 0:
			push_error("FoundingSiteRenderer: no valid cell for %s" % landmark["id"])
			continue
		var model: Mesh = _prop_mesh(str(landmark["model"]))
		var instance := MeshInstance3D.new()
		instance.name = str(landmark["id"])
		instance.mesh = model
		instance.material_override = _material
		instance.position = Terrain.cell_to_world(cell.x, cell.y) + Vector3.UP * 0.02
		instance.rotation_degrees.y = float(landmark.get("rotation_degrees", 0.0))
		instance.scale = Vector3.ONE * float(landmark.get("scale", 1.0))
		instance.set_meta("label", str(landmark["label"]))
		instance.set_meta("cell", cell)
		add_child(instance)

		var placement := {"id": str(landmark["id"]), "label": str(landmark["label"]), "cell": cell}
		_placements.append(placement)
		if landmark.has("light_energy"):
			_add_fire_light(instance, landmark)


func _find_valid_cell(landmark: Dictionary) -> Vector2i:
	var anchor_array: Array = landmark["anchor"] as Array
	var anchor := Vector2i(int(anchor_array[0]), int(anchor_array[1]))
	var radius: int = int(landmark.get("search_radius_cells", 0))
	var desired_terrain := _terrain_from_name(str(landmark.get("terrain", "meadow")))
	var max_slope := deg_to_rad(float(landmark.get("max_slope_degrees", 90.0)))
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for y in range(maxi(0, anchor.y - radius), mini(Terrain.cells_across(), anchor.y + radius + 1)):
		for x in range(maxi(0, anchor.x - radius), mini(Terrain.cells_across(), anchor.x + radius + 1)):
			if Terrain.terrain_at(x, y) != desired_terrain:
				continue
			if Terrain.water_at(x, y) != TerrainTypes.Water.NONE:
				continue
			if Terrain.slope_radians_at(x, y) > max_slope:
				continue
			var distance := Vector2(x, y).distance_squared_to(Vector2(anchor))
			if distance < best_distance:
				best_distance = distance
				best = Vector2i(x, y)
	return best


func _terrain_from_name(name: String) -> TerrainTypes.Terrain:
	match name:
		"woodland":
			return TerrainTypes.Terrain.WOODLAND
		"moor":
			return TerrainTypes.Terrain.MOOR
		"rock":
			return TerrainTypes.Terrain.ROCK
		"arable":
			return TerrainTypes.Terrain.ARABLE
		"built":
			return TerrainTypes.Terrain.BUILT
		_:
			return TerrainTypes.Terrain.MEADOW


func _add_fire_light(parent: Node3D, landmark: Dictionary) -> void:
	var light := OmniLight3D.new()
	light.name = "FireGlow"
	light.light_color = Color.from_string(str(landmark["light_color"]), Color("#E58C4D"))
	light.light_energy = float(landmark["light_energy"])
	light.omni_range = 9.0
	light.shadow_enabled = true
	light.position = Vector3(0.0, 0.8, 0.0)
	parent.add_child(light)
	_lights.append({"light": light, "energy": light.light_energy})


func _prop_mesh(model_key: String) -> Mesh:
	var path: String = _models.get(model_key, "")
	if path == "" or not ResourceLoader.exists(path):
		push_error("FoundingSiteRenderer: missing model '%s' (%s)" % [model_key, path])
		return _fallback_mesh()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("FoundingSiteRenderer: %s is not a PackedScene" % path)
		return _fallback_mesh()
	var root := packed.instantiate()
	var mesh: Mesh = null
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if not found.is_empty():
		mesh = (found[0] as MeshInstance3D).mesh
	root.free()
	if mesh == null:
		push_error("FoundingSiteRenderer: no MeshInstance3D in %s" % path)
		return _fallback_mesh()
	return mesh


func _fallback_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	return box


func site_info() -> Dictionary:
	return _settings.get("site", {}) as Dictionary


func placements() -> Array[Dictionary]:
	return _placements
