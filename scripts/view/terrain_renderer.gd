## Builds the terrain mesh by reading `Terrain`, one chunk at a time.
##
## Owns nothing authoritative — every height and colour here is derived from the cell grid, and
## the whole mesh could be thrown away and rebuilt with no loss.
##
## **Heights sit at cell corners, cell data sits at cell centres.** A corner's height is the
## average of the up-to-four cells touching it, which turns blocky per-cell data into smooth
## ground. The same averaging gives a corner the same height whichever chunk asks for it, so
## chunk edges line up exactly.
##
## **Normals are computed from the height field, not from the triangles.** Averaging triangle
## normals inside a chunk would leave every shared edge shaded slightly differently from its
## neighbour, and those seams are glaring under a low sun. Central differences of the corner
## height function give a shared corner one normal by construction.
##
## Only dirty chunks are rebuilt (Roadmap 1.2 — retrofitting that later is miserable). Nothing
## edits terrain yet, so in practice this rebuilds everything once on load and then idles.
extends Node3D

const MATERIAL_PATH := "res://assets/materials/m_terrain_ground.tres"
const RIVER_MATERIAL_PATH := "res://assets/materials/m_river_water.tres"

## Ground colour per terrain type. Woodland uses a canopy green for the ground beneath it: seen
## from this camera angle the slope reads as wooded even before a single tree is placed.
const GROUND_COLOURS := {
	TerrainTypes.Terrain.MEADOW: "grass_summer",
	TerrainTypes.Terrain.WOODLAND: "foliage_dark",
	TerrainTypes.Terrain.MOOR: "moor_heather",
	TerrainTypes.Terrain.ROCK: "gritstone",
	TerrainTypes.Terrain.ARABLE: "soil",
	TerrainTypes.Terrain.BUILT: "mud",
}
const RIVER_BED_COLOUR := "mud"

var _material: Material = null
var _river_material: Material = null
var _chunks: Dictionary = {}
var _seasons := SeasonBlender.new()


func _ready() -> void:
	_material = load(MATERIAL_PATH)
	_river_material = load(RIVER_MATERIAL_PATH)
	_build_river_surface()
	_remesh_dirty()

	SimClock.day_passed.connect(_on_day_passed)
	_apply_season()


func _on_day_passed(_day_of_year: int) -> void:
	_apply_season()


## Pushes the day's seasonal look into the shader parameters: how much snow lies on the ground
## and how far down the moor it reaches, and the river's colour. The terrain mesh itself never
## changes with the season — only these uniforms do.
func _apply_season() -> void:
	var state := _seasons.sample(SimClock.day_of_year())
	if state.is_empty():
		return

	var snow: float = state["snow_coverage"]
	var line_base: float = Tuning.get_num("seasons.snow_line_base_m")
	var line_lapse: float = Tuning.get_num("seasons.snow_line_lapse_m")

	if _material is ShaderMaterial:
		_material.set_shader_parameter("snow_amount", snow)
		# Deep winter drops the snow line toward the valley floor.
		_material.set_shader_parameter("snow_line_m", line_base - line_lapse * snow)

	if _river_material is ShaderMaterial:
		_river_material.set_shader_parameter("water_color", state["water_color"])


func _process(_delta: float) -> void:
	if Terrain.has_dirty_chunks():
		_remesh_dirty()


func _remesh_dirty() -> void:
	for index in Terrain.take_dirty_chunks():
		_rebuild_chunk(index)


## Builds the visible water surface from the authoritative river cells. Water is deliberately a
## separate derived mesh: it has no say in terrain data and can be replaced by a more detailed
## stream representation later without changing saves or pathfinding.
func _build_river_surface() -> void:
	var cells_across: int = Terrain.cells_across()
	var cell_size: float = Terrain.cell_size_m()
	var half_extent: float = Terrain.world_size_m() * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	for y in cells_across:
		for x in cells_across:
			if Terrain.water_at(x, y) != TerrainTypes.Water.RIVER:
				continue

			var first: int = vertices.size()
			var water_y: float = Terrain.water_level_at(x, y)
			var left: float = float(x) * cell_size - half_extent
			var right: float = float(x + 1) * cell_size - half_extent
			var near: float = float(y) * cell_size - half_extent
			var far: float = float(y + 1) * cell_size - half_extent
			vertices.append_array([
				Vector3(left, water_y, near),
				Vector3(right, water_y, near),
				Vector3(left, water_y, far),
				Vector3(right, water_y, far),
			])
			normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
			var uv := Vector2(float(x) / float(cells_across), float(y) / float(cells_across))
			var uv_step := Vector2(1.0 / cells_across, 1.0 / cells_across)
			uvs.append_array([uv, uv + Vector2(uv_step.x, 0.0), uv + Vector2(0.0, uv_step.y), uv + uv_step])
			indices.append_array([
				first, first + 2, first + 1,
				first + 1, first + 2, first + 3,
			])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var surface := MeshInstance3D.new()
	surface.name = "RiverSurface"
	surface.material_override = _river_material
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	surface.mesh = mesh
	add_child(surface)


func _rebuild_chunk(index: int) -> void:
	var across: int = Terrain.chunks_across()
	@warning_ignore("integer_division")
	var chunk := Vector2i(index % across, index / across)

	var instance: MeshInstance3D = _chunks.get(index)
	if instance == null:
		instance = MeshInstance3D.new()
		instance.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
		instance.material_override = _material
		add_child(instance)
		_chunks[index] = instance

	instance.mesh = _build_chunk_mesh(chunk)


func _build_chunk_mesh(chunk: Vector2i) -> ArrayMesh:
	var chunk_cells: int = Terrain.chunk_cells()
	var cells_across: int = Terrain.cells_across()
	var cell_size: float = Terrain.cell_size_m()
	var half_extent: float = Terrain.world_size_m() * 0.5

	var first := chunk * chunk_cells
	# The last chunk on each axis may be short if the map does not divide evenly.
	var span := Vector2i(
		mini(chunk_cells, cells_across - first.x),
		mini(chunk_cells, cells_across - first.y)
	)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()

	var stride: int = span.x + 1
	vertices.resize(stride * (span.y + 1))
	normals.resize(vertices.size())
	colours.resize(vertices.size())

	for corner_y in span.y + 1:
		for corner_x in span.x + 1:
			var corner := first + Vector2i(corner_x, corner_y)
			var vertex_index: int = corner_y * stride + corner_x

			vertices[vertex_index] = Vector3(
				float(corner.x) * cell_size - half_extent,
				_corner_height(corner.x, corner.y),
				float(corner.y) * cell_size - half_extent
			)
			normals[vertex_index] = _corner_normal(corner.x, corner.y, cell_size)
			colours[vertex_index] = _corner_colour(corner.x, corner.y)

	for cell_y in span.y:
		for cell_x in span.x:
			var top_left: int = cell_y * stride + cell_x
			var top_right: int = top_left + 1
			var bottom_left: int = top_left + stride
			var bottom_right: int = bottom_left + 1
			# Clockwise seen from above: Godot culls the other winding, which renders the whole
			# terrain invisible from the only angle the game is ever viewed from.
			indices.append_array([
				top_left, top_right, bottom_left,
				top_right, bottom_right, bottom_left,
			])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The height at a cell corner: the average of the cells around it. Cells outside the map are
## skipped rather than clamped, so the map's outer edge keeps the height of the ground just
## inside it.
func _corner_height(corner_x: int, corner_y: int) -> float:
	var total: float = 0.0
	var samples: int = 0
	for offset_y in [-1, 0]:
		for offset_x in [-1, 0]:
			var cell_x: int = corner_x + offset_x
			var cell_y: int = corner_y + offset_y
			if Terrain.is_inside(cell_x, cell_y):
				total += Terrain.elevation_at(cell_x, cell_y)
				samples += 1
	if samples == 0:
		return 0.0
	return total / float(samples)


func _corner_normal(corner_x: int, corner_y: int, cell_size: float) -> Vector3:
	var west: float = _corner_height(corner_x - 1, corner_y)
	var east: float = _corner_height(corner_x + 1, corner_y)
	var north: float = _corner_height(corner_x, corner_y - 1)
	var south: float = _corner_height(corner_x, corner_y + 1)
	return Vector3((west - east) * 0.5, cell_size, (north - south) * 0.5).normalized()


## The colour at a cell corner, averaged from the cells around it so that the boundaries between
## meadow, woodland and moor blend rather than staircase along cell edges.
func _corner_colour(corner_x: int, corner_y: int) -> Color:
	var total := Color(0.0, 0.0, 0.0, 0.0)
	var samples: int = 0
	for offset_y in [-1, 0]:
		for offset_x in [-1, 0]:
			var cell_x: int = corner_x + offset_x
			var cell_y: int = corner_y + offset_y
			if Terrain.is_inside(cell_x, cell_y):
				total += _cell_colour(cell_x, cell_y)
				samples += 1
	if samples == 0:
		return Palette.vertex(GROUND_COLOURS[TerrainTypes.Terrain.MOOR])
	return total / float(samples)


func _cell_colour(cell_x: int, cell_y: int) -> Color:
	if Terrain.water_at(cell_x, cell_y) == TerrainTypes.Water.RIVER:
		return Palette.vertex(RIVER_BED_COLOUR)
	return Palette.vertex(GROUND_COLOURS[Terrain.terrain_at(cell_x, cell_y)])
