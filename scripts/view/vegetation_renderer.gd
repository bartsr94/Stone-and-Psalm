## Renders terrain-derived vegetation using three batched MultiMeshInstance3D nodes.
##
## This is presentation only. It reads the authoritative Terrain grid and the pure
## VegetationLayout rules, then can be deleted and rebuilt without changing simulation state.
## The founding valley uses deliberately simple generated meshes until authored Blender assets
## exist; the placement contract does not depend on which mesh replaces them later.
extends Node3D

const SETTINGS_PATH := "res://data/vegetation.json"
const MATERIAL_PATH := "res://assets/materials/m_stone_and_psalm.tres"
const TREE_POSITION_SALT: int = 0x2B992DD1
const SCRUB_POSITION_SALT: int = 0x4C957F2D
const ROCK_POSITION_SALT: int = 0x7A3E91B7

var _settings: Dictionary = {}
var _material: Material = null


func _ready() -> void:
	_settings = _load_settings()
	if _settings.is_empty():
		return
	_material = load(MATERIAL_PATH)
	_populate()


func _load_settings() -> Dictionary:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("VegetationRenderer: cannot open %s" % SETTINGS_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary and parsed.has("founding_valley")):
		push_error("VegetationRenderer: no founding_valley settings in %s" % SETTINGS_PATH)
		return {}
	return parsed["founding_valley"] as Dictionary


func _populate() -> void:
	var tree_transforms: Array[Transform3D] = []
	var scrub_transforms: Array[Transform3D] = []
	var rock_transforms: Array[Transform3D] = []
	var cells_across: int = Terrain.cells_across()
	var seed: int = int(_settings["seed"])
	var tree_slope: float = deg_to_rad(float(_settings["tree_max_slope_degrees"]))
	var scrub_slope: float = deg_to_rad(float(_settings["scrub_max_slope_degrees"]))
	var tree_stride: int = int(_settings["tree_sample_stride_cells"])
	var scrub_stride: int = int(_settings["scrub_sample_stride_cells"])
	var rock_stride: int = int(_settings["rock_sample_stride_cells"])
	var tree_settings: Dictionary = _settings["tree"]
	var scrub_settings: Dictionary = _settings["scrub"]
	var rock_settings: Dictionary = _settings["rock"]

	for y in range(0, cells_across, tree_stride):
		for x in range(0, cells_across, tree_stride):
			var placement := _placement(x, y, seed, tree_slope, scrub_slope)
			if placement == VegetationLayout.Placement.TREE:
				tree_transforms.append(_transform_for_cell(x, y, seed, tree_settings, TREE_POSITION_SALT))

	for y in range(0, cells_across, scrub_stride):
		for x in range(0, cells_across, scrub_stride):
			var placement := _placement(x, y, seed, tree_slope, scrub_slope)
			if placement == VegetationLayout.Placement.SCRUB:
				scrub_transforms.append(_transform_for_cell(x, y, seed, scrub_settings, SCRUB_POSITION_SALT))

	for y in range(0, cells_across, rock_stride):
		for x in range(0, cells_across, rock_stride):
			var placement := _placement(x, y, seed, tree_slope, scrub_slope)
			if placement == VegetationLayout.Placement.ROCK:
				rock_transforms.append(_transform_for_cell(x, y, seed, rock_settings, ROCK_POSITION_SALT))

	add_child(_make_multimesh_instance("Trees", _make_tree_mesh(), tree_transforms))
	add_child(_make_multimesh_instance("Scrub", _make_scrub_mesh(), scrub_transforms))
	add_child(_make_multimesh_instance("Rocks", _make_rock_mesh(), rock_transforms))


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
	transforms: Array[Transform3D]
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
	instance.material_override = _material
	return instance


func _make_tree_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_box(tool, Vector3(0.3, 1.2, 0.3), Vector3(0.0, 0.6, 0.0), Palette.vertex("oak_dark"))
	_add_frustum(tool, 1.15, 0.32, 2.1, 1.0, 7, Palette.vertex("foliage_dark"))
	_add_frustum(tool, 0.9, 0.08, 1.7, 2.35, 7, Palette.vertex("foliage_light"))
	tool.generate_normals()
	return tool.commit()


func _make_scrub_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_frustum(tool, 0.6, 0.06, 0.9, 0.0, 6, Palette.vertex("bracken"))
	tool.generate_normals()
	return tool.commit()


func _make_rock_mesh() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_frustum(tool, 0.82, 0.48, 0.7, 0.0, 7, Palette.vertex("gritstone"))
	tool.generate_normals()
	return tool.commit()


func _add_box(tool: SurfaceTool, size: Vector3, centre: Vector3, colour: Color) -> void:
	var half := size * 0.5
	var min_corner := centre - half
	var max_corner := centre + half
	var a := Vector3(min_corner.x, min_corner.y, min_corner.z)
	var b := Vector3(max_corner.x, min_corner.y, min_corner.z)
	var c := Vector3(max_corner.x, max_corner.y, min_corner.z)
	var d := Vector3(min_corner.x, max_corner.y, min_corner.z)
	var e := Vector3(min_corner.x, min_corner.y, max_corner.z)
	var f := Vector3(max_corner.x, min_corner.y, max_corner.z)
	var g := Vector3(max_corner.x, max_corner.y, max_corner.z)
	var h := Vector3(min_corner.x, max_corner.y, max_corner.z)
	_add_quad(tool, a, b, c, d, colour)
	_add_quad(tool, f, e, h, g, colour)
	_add_quad(tool, e, a, d, h, colour)
	_add_quad(tool, b, f, g, c, colour)
	_add_quad(tool, d, c, g, h, colour)
	_add_quad(tool, e, f, b, a, colour)


func _add_frustum(
	tool: SurfaceTool,
	bottom_radius: float,
	top_radius: float,
	height: float,
	base_y: float,
	sides: int,
	colour: Color
) -> void:
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for index in sides:
		var angle: float = TAU * float(index) / float(sides)
		var direction := Vector2(cos(angle), sin(angle))
		bottom.append(Vector3(direction.x * bottom_radius, base_y, direction.y * bottom_radius))
		top.append(Vector3(direction.x * top_radius, base_y + height, direction.y * top_radius))

	for index in sides:
		var next: int = (index + 1) % sides
		_add_quad(tool, bottom[index], bottom[next], top[next], top[index], colour)
		_add_triangle(tool, Vector3(0.0, base_y, 0.0), bottom[next], bottom[index], colour)
		_add_triangle(tool, Vector3(0.0, base_y + height, 0.0), top[index], top[next], colour)


func _add_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	_add_triangle(tool, a, b, c, colour)
	_add_triangle(tool, a, c, d, colour)


func _add_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, colour: Color) -> void:
	tool.set_color(colour)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)
	tool.set_color(colour)
	tool.add_vertex(c)
	tool.add_vertex(b)
	tool.add_vertex(a)
