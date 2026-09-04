## Renders terrain-derived vegetation using batched MultiMeshInstance3D nodes.
##
## This is presentation only. It reads the authoritative Terrain grid and the pure
## VegetationLayout rules, then can be deleted and rebuilt without changing simulation state.
## Each batch instances an authored low-poly .glb prop from assets/models/; the placement
## contract does not depend on which mesh a batch uses, so swapping a prop is a view-only change.
## Trees are split into broadleaf and pine batches by elevation — mesh choice, not a layout rule.
extends Node3D

const SETTINGS_PATH := "res://data/vegetation.json"
const DECIDUOUS_MATERIAL_PATH := "res://assets/materials/m_vegetation_deciduous.tres"
const EVERGREEN_MATERIAL_PATH := "res://assets/materials/m_vegetation_evergreen.tres"
const TREE_POSITION_SALT: int = 0x2B992DD1
const SCRUB_POSITION_SALT: int = 0x4C957F2D
const ROCK_POSITION_SALT: int = 0x7A3E91B7
const STUMP_POSITION_SALT: int = 0x18C7A4D3
const FALLEN_LOG_POSITION_SALT: int = 0x39D21B65
const FERN_POSITION_SALT: int = 0x52A86EF1
const REEDS_POSITION_SALT: int = 0x6F14C2A7
const TREE_SAMPLE_SALT: int = 0x0B41D2E7
const SCRUB_SAMPLE_SALT: int = 0x1C83A5F9
const ROCK_SAMPLE_SALT: int = 0x2DA617CB
const UNDERSTORY_SAMPLE_SALT: int = 0x3EC9289D
const REEDS_SAMPLE_SALT: int = 0x4FDA3B6F

var _settings: Dictionary = {}
var _models: Dictionary = {}
var _deciduous_material: ShaderMaterial = null
var _evergreen_material: ShaderMaterial = null
var _seasons := SeasonBlender.new()


func _ready() -> void:
	if not _load_settings():
		return
	_deciduous_material = load(DECIDUOUS_MATERIAL_PATH)
	_evergreen_material = load(EVERGREEN_MATERIAL_PATH)
	_populate()

	SimClock.day_passed.connect(_on_day_passed)
	_apply_season()


func _on_day_passed(_day_of_year: int) -> void:
	_apply_season()


## Pushes the day's foliage look into the two vegetation materials: the season's canopy tint
## (or a bare twig-brown once the broadleaves have dropped) and the snow dusting. The
## MultiMesh transforms never change with the season — only these uniforms do.
func _apply_season() -> void:
	var state := _seasons.sample(SimClock.day_of_year())
	if state.is_empty():
		return

	var snow: float = state["snow_coverage"]
	var bare: bool = state["broadleaf_bare"]

	if bare:
		_deciduous_material.set_shader_parameter("foliage_tint", Color("#5b4a38"))
		_deciduous_material.set_shader_parameter("foliage_recolor", 0.92)
	else:
		_deciduous_material.set_shader_parameter("foliage_tint", state["broadleaf_tint"])
		_deciduous_material.set_shader_parameter("foliage_recolor", 0.85)
	_deciduous_material.set_shader_parameter("snow_amount", snow)

	_evergreen_material.set_shader_parameter("foliage_tint", state["pine_tint"])
	_evergreen_material.set_shader_parameter("snow_amount", snow)


func _load_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("VegetationRenderer: cannot open %s" % SETTINGS_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary and parsed.has("founding_valley")):
		push_error("VegetationRenderer: no founding_valley settings in %s" % SETTINGS_PATH)
		return false
	_settings = parsed["founding_valley"] as Dictionary
	_models = parsed.get("models", {}) as Dictionary
	return true


func _populate() -> void:
	var broadleaf_transforms: Array[Transform3D] = []
	var pine_transforms: Array[Transform3D] = []
	var scrub_transforms: Array[Transform3D] = []
	var rock_transforms: Array[Transform3D] = []
	var stump_transforms: Array[Transform3D] = []
	var fallen_log_transforms: Array[Transform3D] = []
	var fern_transforms: Array[Transform3D] = []
	var reeds_transforms: Array[Transform3D] = []
	var cells_across: int = Terrain.cells_across()
	var seed: int = int(_settings["seed"])
	var tree_slope: float = deg_to_rad(float(_settings["tree_max_slope_degrees"]))
	var scrub_slope: float = deg_to_rad(float(_settings["scrub_max_slope_degrees"]))
	var tree_stride: int = int(_settings["tree_sample_stride_cells"])
	var scrub_stride: int = int(_settings["scrub_sample_stride_cells"])
	var rock_stride: int = int(_settings["rock_sample_stride_cells"])
	var understory_stride: int = int(_settings["understory_sample_stride_cells"])
	var reeds_stride: int = int(_settings["reeds_sample_stride_cells"])
	var pine_min_elevation: float = float(_settings["pine_min_elevation_m"])
	var tree_settings: Dictionary = _settings["tree"]
	var scrub_settings: Dictionary = _settings["scrub"]
	var rock_settings: Dictionary = _settings["rock"]
	var stump_settings: Dictionary = _settings["stump"]
	var fallen_log_settings: Dictionary = _settings["fallen_log"]
	var fern_settings: Dictionary = _settings["fern"]
	var reeds_settings: Dictionary = _settings["reeds"]

	for base_y in range(0, cells_across, tree_stride):
		for base_x in range(0, cells_across, tree_stride):
			var sample := _sample_cell(base_x, base_y, tree_stride, seed, TREE_SAMPLE_SALT)
			var x: int = sample.x
			var y: int = sample.y
			var placement := _placement(x, y, seed, tree_slope, scrub_slope)
			if placement == VegetationLayout.Placement.TREE:
				var xform := _transform_for_cell(x, y, seed, tree_settings, TREE_POSITION_SALT)
				if Terrain.elevation_at(x, y) >= pine_min_elevation:
					pine_transforms.append(xform)
				else:
					broadleaf_transforms.append(xform)

	for base_y in range(0, cells_across, scrub_stride):
		for base_x in range(0, cells_across, scrub_stride):
			var sample := _sample_cell(base_x, base_y, scrub_stride, seed, SCRUB_SAMPLE_SALT)
			var x: int = sample.x
			var y: int = sample.y
			var placement := _placement(x, y, seed, tree_slope, scrub_slope)
			if placement == VegetationLayout.Placement.SCRUB:
				scrub_transforms.append(_transform_for_cell(x, y, seed, scrub_settings, SCRUB_POSITION_SALT))

	for base_y in range(0, cells_across, rock_stride):
		for base_x in range(0, cells_across, rock_stride):
			var sample := _sample_cell(base_x, base_y, rock_stride, seed, ROCK_SAMPLE_SALT)
			var x: int = sample.x
			var y: int = sample.y
			var placement := _placement(x, y, seed, tree_slope, scrub_slope)
			if placement == VegetationLayout.Placement.ROCK:
				rock_transforms.append(_transform_for_cell(x, y, seed, rock_settings, ROCK_POSITION_SALT))

	# These are view-only understory accents. They use the same stable coordinate hash as the
	# primary layout, but do not change its single-candidate TREE/SCRUB/ROCK contract.
	for base_y in range(0, cells_across, understory_stride):
		for base_x in range(0, cells_across, understory_stride):
			var sample := _sample_cell(base_x, base_y, understory_stride, seed, UNDERSTORY_SAMPLE_SALT)
			var x: int = sample.x
			var y: int = sample.y
			if not _woodland_eligible(x, y, tree_slope):
				continue
			var understory_value := VegetationLayout.cell_value(seed, x, y, STUMP_POSITION_SALT)
			if understory_value < float(_settings["stump_density"]):
				stump_transforms.append(_transform_for_cell(x, y, seed, stump_settings, STUMP_POSITION_SALT))
			elif understory_value < float(_settings["stump_density"]) + float(_settings["fallen_log_density"]):
				fallen_log_transforms.append(_transform_for_cell(
					x, y, seed, fallen_log_settings, FALLEN_LOG_POSITION_SALT
				))
			if VegetationLayout.should_place(
				float(_settings["fern_density"]), seed, x, y, FERN_POSITION_SALT
			):
				fern_transforms.append(_transform_for_cell(x, y, seed, fern_settings, FERN_POSITION_SALT))

	# Reeds sit on dry cells immediately beside the river, keeping their feet on the bank rather
	# than in the water surface. The neighbour check makes this robust to a meandering channel.
	for base_y in range(0, cells_across, reeds_stride):
		for base_x in range(0, cells_across, reeds_stride):
			var sample := _sample_cell(base_x, base_y, reeds_stride, seed, REEDS_SAMPLE_SALT)
			var x: int = sample.x
			var y: int = sample.y
			if not _near_river(x, y) or Terrain.slope_radians_at(x, y) > scrub_slope:
				continue
			if VegetationLayout.should_place(float(_settings["reed_density"]), seed, x, y, REEDS_POSITION_SALT):
				reeds_transforms.append(_transform_for_cell(x, y, seed, reeds_settings, REEDS_POSITION_SALT))

	# Broadleaves and scrub take the season's canopy colour; pines and the woody understorey
	# props barely shift and share the evergreen material.
	add_child(_make_multimesh_instance("Trees", _prop_mesh("tree_broadleaf"), broadleaf_transforms, _deciduous_material))
	add_child(_make_multimesh_instance("Scrub", _prop_mesh("scrub"), scrub_transforms, _deciduous_material))
	add_child(_make_multimesh_instance("Ferns", _prop_mesh("fern"), fern_transforms, _deciduous_material))
	add_child(_make_multimesh_instance("Pines", _prop_mesh("tree_pine"), pine_transforms, _evergreen_material))
	add_child(_make_multimesh_instance("Rocks", _prop_mesh("rock"), rock_transforms, _evergreen_material))
	add_child(_make_multimesh_instance("Stumps", _prop_mesh("stump"), stump_transforms, _evergreen_material))
	add_child(_make_multimesh_instance("FallenLogs", _prop_mesh("fallen_log"), fallen_log_transforms, _evergreen_material))
	add_child(_make_multimesh_instance("Reeds", _prop_mesh("reeds"), reeds_transforms, _evergreen_material))


func _woodland_eligible(x: int, y: int, tree_slope: float) -> bool:
	return (
		Terrain.terrain_at(x, y) == TerrainTypes.Terrain.WOODLAND
		and Terrain.water_at(x, y) == TerrainTypes.Water.NONE
		and Terrain.elevation_at(x, y) <= float(_settings["tree_max_elevation_m"])
		and Terrain.slope_radians_at(x, y) <= tree_slope
	)


func _near_river(x: int, y: int) -> bool:
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if Terrain.water_at(x + offset.x, y + offset.y) == TerrainTypes.Water.RIVER:
			return true
	return false


## Returns one deterministic sample inside a stride-sized tile. Fixed lattice samples make the
## population read as rows when viewed from far away; jittering each tile in both axes keeps the
## same bounded candidate count while removing that grid signature.
func _sample_cell(base_x: int, base_y: int, stride: int, seed: int, sample_salt: int) -> Vector2i:
	var safe_stride: int = maxi(stride, 1)
	var offset_x: int = mini(
		int(VegetationLayout.cell_value(seed, base_x, base_y, sample_salt) * float(safe_stride)),
		safe_stride - 1
	)
	var offset_y: int = mini(
		int(VegetationLayout.cell_value(seed, base_x, base_y, sample_salt + 1) * float(safe_stride)),
		safe_stride - 1
	)
	return Vector2i(
		mini(base_x + offset_x, Terrain.cells_across() - 1),
		mini(base_y + offset_y, Terrain.cells_across() - 1)
	)


func _placement(x: int, y: int, seed: int, tree_slope: float, scrub_slope: float) -> VegetationLayout.Placement:
	return VegetationLayout.placement_for_cell(
		Terrain.terrain_at(x, y),
		Terrain.water_at(x, y),
		Terrain.forest_density_at(x, y),
		Terrain.slope_radians_at(x, y),
		Terrain.elevation_at(x, y),
		seed,
		x,
		y,
		tree_slope,
		float(_settings["tree_max_elevation_m"]),
		scrub_slope,
		float(_settings["rock_density"])
	)


func _transform_for_cell(
	x: int,
	y: int,
	seed: int,
	settings: Dictionary,
	position_salt: int
) -> Transform3D:
	var ground_position := Terrain.cell_to_world(x, y)
	var cell_size: float = Terrain.cell_size_m()
	var jitter_fraction: float = float(settings["jitter_fraction"])
	var jitter := Vector2(
		(VegetationLayout.cell_value(seed, x, y, position_salt) * 2.0 - 1.0) * cell_size * 0.5 * jitter_fraction,
		(VegetationLayout.cell_value(seed, x, y, position_salt + 1) * 2.0 - 1.0) * cell_size * 0.5 * jitter_fraction
	)
	var rotation: float = VegetationLayout.cell_value(seed, x, y, position_salt + 2) * TAU
	var scale: float = lerpf(
		float(settings["scale_min"]),
		float(settings["scale_max"]),
		VegetationLayout.cell_value(seed, x, y, position_salt + 3)
	)
	var basis := Basis.from_euler(Vector3(0.0, rotation, 0.0)).scaled(Vector3.ONE * scale)
	return Transform3D(basis, ground_position + Vector3(jitter.x, 0.0, jitter.y))


func _make_multimesh_instance(
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D],
	material: Material
) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in transforms.size():
		multimesh.set_instance_transform(index, transforms[index])

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	return instance


## Loads the authored .glb prop for a batch and returns its mesh. The .glb imports as a
## PackedScene, so it is instanced once here, its MeshInstance3D's mesh is kept, and the
## instance is discarded. Falls back to a unit box if the model is missing so the scene still
## renders and the integration test still has a mesh to assert on.
func _prop_mesh(model_key: String) -> Mesh:
	var path: String = _models.get(model_key, "")
	if path == "" or not ResourceLoader.exists(path):
		push_error("VegetationRenderer: missing model '%s' (%s)" % [model_key, path])
		return _fallback_mesh()
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("VegetationRenderer: %s is not a PackedScene" % path)
		return _fallback_mesh()
	var root := packed.instantiate()
	var mesh: Mesh = null
	var found := root.find_children("*", "MeshInstance3D", true, false)
	if not found.is_empty():
		mesh = (found[0] as MeshInstance3D).mesh
	# Never entered the tree; free it now rather than deferring so no orphan lingers a frame.
	root.free()
	if mesh == null:
		push_error("VegetationRenderer: no MeshInstance3D in %s" % path)
		return _fallback_mesh()
	return mesh


func _fallback_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	return box
