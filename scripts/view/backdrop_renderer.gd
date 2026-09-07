## The fells beyond the map edge: a ring of low-poly hills outside the playable terrain, so the
## dale has a horizon instead of ending in nothing when the camera tilts low or pans to an edge.
##
## Presentation only. It reads `Terrain` for the edge heights it has to meet and owns nothing;
## everything about its shape is `data/backdrop.json`. It uses the terrain ground material, so
## the slope-to-rock wear, the snow line and the seasonal tint all apply to it for free — and
## the depth fog in the environment does the rest, turning the far tops pale and blue.
##
## The playable map is square, so the ring is built on a "squircle": for each bearing the inner
## vertex sits on the square's edge and takes the terrain's own height there, and the rings
## step outward from that edge. Heights blend from the terrain edge into the noise fells over
## `blend_m`, which is what stops the join reading as a cliff.
##
## No shadows: the fells are hundreds of metres out, past the directional shadow range, and
## they only ever need to be a silhouette.
extends Node3D

const SETTINGS_PATH := "res://data/backdrop.json"
const MATERIAL_PATH := "res://assets/materials/m_terrain_ground.tres"

var _settings: Dictionary = {}


func _ready() -> void:
	if not _load_settings():
		return
	_build()


func _load_settings() -> bool:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("BackdropRenderer: cannot open %s" % SETTINGS_PATH)
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary and parsed.has("rings")):
		push_error("BackdropRenderer: %s has no ring settings" % SETTINGS_PATH)
		return false
	_settings = parsed
	return true


## Terrain height at the map edge for a bearing, matching the mesh's own edge corner height:
## the average of the edge cells either side of the boundary point.
func _edge_height(edge_point: Vector2) -> float:
	var across := Terrain.cells_across()
	var cell := Terrain.world_to_cell(Vector3(edge_point.x, 0.0, edge_point.y))
	var x := clampi(cell.x, 0, across - 1)
	var y := clampi(cell.y, 0, across - 1)
	var sum := Terrain.elevation_at(x, y)
	var count := 1
	for offset: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if Terrain.is_inside(nx, ny) and (nx == x or ny == y):
			var world := Terrain.cell_to_world(nx, ny)
			# Only neighbours that also touch the boundary point, so the average stays local.
			if absf(world.x - edge_point.x) <= Terrain.cell_size_m() and absf(world.z - edge_point.y) <= Terrain.cell_size_m():
				sum += Terrain.elevation_at(nx, ny)
				count += 1
	return sum / float(count)


func _build() -> void:
	var half_extent := Terrain.world_size_m() * 0.5
	var outer_radius := float(_settings["outer_radius_m"])
	var rings := int(_settings["rings"])
	var segments := int(_settings["segments"])
	var blend_m := float(_settings["blend_m"])
	var rise_min := float(_settings["rise_min_m"])
	var rise_max := float(_settings["rise_max_m"])
	var colours: Dictionary = _settings["colours"]
	var low := Palette.vertex(str(colours["low"]))
	var high := Palette.vertex(str(colours["high"]))
	var rock := Palette.vertex(str(colours["rock"]))
	var high_from := float(colours["high_from_m"])
	var rock_from := float(colours["rock_from_m"])

	var broad := FastNoiseLite.new()
	broad.seed = int(_settings["seed"])
	broad.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	broad.frequency = float(_settings["noise_frequency"])
	broad.fractal_octaves = 3
	var detail := FastNoiseLite.new()
	detail.seed = int(_settings["seed"]) + 1
	detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail.frequency = float(_settings["detail_frequency"])
	var broad_amp := float(_settings["noise_amplitude_m"])
	var detail_amp := float(_settings["detail_amplitude_m"])

	# Positions on a (ring, segment) grid, then normals from the grid, then one indexed mesh.
	var grid: Array[PackedVector3Array] = []
	for ring in rings + 1:
		var row := PackedVector3Array()
		# Rings are denser near the map, where the join with the terrain has to be smooth.
		var t := pow(float(ring) / float(rings), 1.5)
		for segment in segments:
			var angle := TAU * float(segment) / float(segments)
			var dir := Vector2(cos(angle), sin(angle))
			# Distance along `dir` to the square map edge.
			var edge_distance := half_extent / maxf(absf(dir.x), absf(dir.y))
			var edge_point := dir * edge_distance
			var outward := (outer_radius - edge_distance) * t
			var p := dir * (edge_distance + outward)
			var edge_h := _edge_height(edge_point)
			var rise := lerpf(rise_min, rise_max, smoothstep(0.0, 1.0, t))
			var fell_h := edge_h + rise + broad.get_noise_2d(p.x, p.y) * broad_amp * (0.35 + 0.65 * t) \
				+ detail.get_noise_2d(p.x, p.y) * detail_amp
			var blend := smoothstep(0.0, 1.0, clampf(outward / blend_m, 0.0, 1.0))
			var h := lerpf(edge_h, fell_h, blend)
			row.append(Vector3(p.x, h, p.y))
		grid.append(row)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var vertex_colours := PackedColorArray()
	var indices := PackedInt32Array()

	# Colour bands are measured from the dale floor, the lowest ground on the map.
	var floor_height := INF
	var across_cells := Terrain.cells_across()
	for y in across_cells:
		for x in across_cells:
			floor_height = minf(floor_height, Terrain.elevation_at(x, y))

	for ring in rings + 1:
		for segment in segments:
			var here := grid[ring][segment]
			var next_seg := grid[ring][(segment + 1) % segments]
			var prev_seg := grid[ring][(segment - 1 + segments) % segments]
			var ring_out: Vector3 = grid[mini(ring + 1, rings)][segment]
			var ring_in: Vector3 = grid[maxi(ring - 1, 0)][segment]
			var along := next_seg - prev_seg
			var across := ring_out - ring_in
			var normal := across.cross(along).normalized()
			if normal.y < 0.0:
				normal = -normal
			vertices.append(here)
			normals.append(normal)
			var height_above := here.y - floor_height
			var colour := low.lerp(high, smoothstep(high_from * 0.6, high_from * 1.6, height_above))
			colour = colour.lerp(rock, smoothstep(rock_from * 0.8, rock_from * 1.3, height_above))
			vertex_colours.append(colour)

	for ring in rings:
		for segment in segments:
			var a := ring * segments + segment
			var b := ring * segments + (segment + 1) % segments
			var c := (ring + 1) * segments + segment
			var d := (ring + 1) * segments + (segment + 1) % segments
			# Wound so the faces look up (+Y), matching the normals.
			indices.append_array([a, c, b, b, c, d])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = vertex_colours
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var instance := MeshInstance3D.new()
	instance.name = "Fells"
	instance.mesh = mesh
	instance.material_override = load(MATERIAL_PATH)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
