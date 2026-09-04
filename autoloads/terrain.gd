## The cell grid: the authoritative shape of the world.
##
## Headless, and it never touches the scene tree. The mesh that renders this lives in
## `scripts/view/terrain_renderer.gd` and is built by reading these cells — nothing here knows
## that a mesh exists.
##
## Cells are stored as parallel packed arrays indexed `y * cells_across + x`, rather than as an
## array of dictionaries: at 192² cells that is the difference between a few hundred kilobytes
## and several megabytes, and the whole grid has to be cheap to walk every time a chunk remeshes.
##
## **Elevation is sampled at cell centres.** The renderer averages neighbouring cells to get its
## vertex heights, which is why editing one cell dirties its neighbours' chunks too — see
## `mark_cell_dirty`.
##
## Rebuilt from `data/terrain_presets.json` rather than saved cell by cell; only later deltas
## (`SIMULATION_SPEC.md` §19) need storing.
extends Node

signal road_changed(x: int, y: int, is_road: bool)

const PRESETS_PATH := "res://data/terrain_presets.json"
const FOUNDING_PRESET := "founding_valley"

var _cells_across: int = 0
var _chunk_cells: int = 0
var _cell_size_m: float = 0.0
var _half_extent_m: float = 0.0

var _elevation := PackedFloat32Array()
var _terrain := PackedByteArray()
var _water := PackedByteArray()
var _water_level := PackedFloat32Array()
var _forest_density := PackedFloat32Array()

## Player-built roads (Phase 4.10) — the one piece of terrain state that is not derived from the
## preset, and so the one piece this autoload actually has to save (§19; every other array is
## rebuilt fresh by `build_preset`).
var _road := PackedByteArray()
var _road_move_cost_factor: float = 0.5

# The cross-section of each column down the dale, one entry per cell along the valley.
var _river_centre := PackedFloat32Array()
var _north_slope_half := PackedFloat32Array()
var _north_slope_rise := PackedFloat32Array()
var _south_slope_half := PackedFloat32Array()
var _south_slope_rise := PackedFloat32Array()

var _river_half_width: float = 0.0
var _bank_blend_cells: float = 0.0
var _bed_depth_m: float = 0.0
var _water_depth_m: float = 0.0

var _dirty_chunks: Dictionary = {}


func _ready() -> void:
	_road_move_cost_factor = Tuning.get_num("roads.move_cost_factor")
	build_preset(FOUNDING_PRESET)


## Rebuilds the whole grid from a named preset. Deterministic: the same preset always produces
## the same valley, which is what lets a save store later edits rather than every cell.
func build_preset(preset_name: String) -> void:
	var file := FileAccess.open(PRESETS_PATH, FileAccess.READ)
	if file == null:
		push_error("Terrain: cannot open %s" % PRESETS_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary and parsed.has(preset_name)):
		push_error("Terrain: no preset %s in %s" % [preset_name, PRESETS_PATH])
		return

	_cell_size_m = Tuning.get_num("world.terrain_cell_m")
	_chunk_cells = Tuning.get_int("world.terrain_chunk_cells")
	_build(parsed[preset_name])


# --- reading the grid -------------------------------------------------------------------------

func cells_across() -> int:
	return _cells_across


func chunk_cells() -> int:
	return _chunk_cells


func chunks_across() -> int:
	if _chunk_cells <= 0:
		return 0
	return int(ceil(float(_cells_across) / float(_chunk_cells)))


func cell_size_m() -> float:
	return _cell_size_m


## The width of the whole map in metres.
func world_size_m() -> float:
	return float(_cells_across) * _cell_size_m


func is_inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < _cells_across and y < _cells_across


func elevation_at(x: int, y: int) -> float:
	if not is_inside(x, y):
		return 0.0
	return _elevation[y * _cells_across + x]


func terrain_at(x: int, y: int) -> TerrainTypes.Terrain:
	if not is_inside(x, y):
		return TerrainTypes.Terrain.MOOR
	return _terrain[y * _cells_across + x] as TerrainTypes.Terrain


func water_at(x: int, y: int) -> TerrainTypes.Water:
	if not is_inside(x, y):
		return TerrainTypes.Water.NONE
	return _water[y * _cells_across + x] as TerrainTypes.Water


## The height of the water surface on this cell. Level across the channel and falling
## downstream, rather than following the noisy bed — standing water is level.
func water_level_at(x: int, y: int) -> float:
	if not is_inside(x, y):
		return 0.0
	return _water_level[y * _cells_across + x]


func forest_density_at(x: int, y: int) -> float:
	if not is_inside(x, y):
		return 0.0
	return _forest_density[y * _cells_across + x]


# --- roads (Phase 4.10) -----------------------------------------------------------------------

func is_road(x: int, y: int) -> bool:
	if not is_inside(x, y):
		return false
	return _road[y * _cells_across + x] != 0


## Builds or removes a road on a walkable cell. A no-op off the map or on unwalkable ground (the
## river, or too steep) — a road cannot make a cell buildable that the terrain itself refuses.
## Emits `road_changed` only on an actual change, so a renderer never has to re-check state that
## did not move.
func set_road(x: int, y: int, value: bool) -> void:
	if not is_inside(x, y) or (value and not is_walkable(x, y)):
		return
	var index := y * _cells_across + x
	var was := _road[index] != 0
	if was == value:
		return
	_road[index] = 1 if value else 0
	road_changed.emit(x, y, value)


## Every built road cell, sorted so an iteration order never depends on how they were added.
func road_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in _cells_across:
		for x in _cells_across:
			if is_road(x, y):
				cells.append(Vector2i(x, y))
	return cells


## The world position of a cell's centre, at its own elevation. The map is centred on the world
## origin, so the camera starts mid-dale.
func cell_to_world(x: int, y: int) -> Vector3:
	return Vector3(
		(float(x) + 0.5) * _cell_size_m - _half_extent_m,
		elevation_at(x, y),
		(float(y) + 0.5) * _cell_size_m - _half_extent_m
	)


func world_to_cell(position: Vector3) -> Vector2i:
	return Vector2i(
		int(floor((position.x + _half_extent_m) / _cell_size_m)),
		int(floor((position.z + _half_extent_m) / _cell_size_m))
	)


## The steepness of the ground at a cell, in radians, from the height difference across it.
func slope_radians_at(x: int, y: int) -> float:
	var west: float = elevation_at(maxi(x - 1, 0), y)
	var east: float = elevation_at(mini(x + 1, _cells_across - 1), y)
	var upstream: float = elevation_at(x, maxi(y - 1, 0))
	var downstream: float = elevation_at(x, mini(y + 1, _cells_across - 1))
	var gradient := Vector2(
		(east - west) / (2.0 * _cell_size_m),
		(downstream - upstream) / (2.0 * _cell_size_m)
	)
	return atan(gradient.length())


# --- walkability (for the pathfinder) --------------------------------------------------------

## Per-terrain traversal factor: how much slower than open meadow a cell is to cross. Built
## cells are cheapest (a yard or a road). Rock is nearly a wall. Read once and cached.
const _TERRAIN_MOVE_FACTOR := {
	TerrainTypes.Terrain.MEADOW: 1.0,
	TerrainTypes.Terrain.WOODLAND: 1.15,
	TerrainTypes.Terrain.MOOR: 1.35,
	TerrainTypes.Terrain.ROCK: 1.9,
	TerrainTypes.Terrain.ARABLE: 1.1,
	TerrainTypes.Terrain.BUILT: 0.7,
}

var _max_walk_slope_radians: float = 0.0
var _slope_cost_weight: float = 0.0


## True if a person can stand on and walk through this cell: on the map, not in the river, and
## not too steep. Ponds and future walls will extend this.
func is_walkable(x: int, y: int) -> bool:
	if not is_inside(x, y):
		return false
	if water_at(x, y) == TerrainTypes.Water.RIVER:
		return false
	return slope_radians_at(x, y) <= _walk_slope_limit()


## Vararg-friendly overload taking a cell.
func is_walkable_cell(cell: Vector2i) -> bool:
	return is_walkable(cell.x, cell.y)


## Cost of a single step between two adjacent cells, in "meadow-metres": the geometric distance
## scaled by the destination's terrain factor and its steepness. Diagonals cost √2 before
## scaling. Used as the `step_cost` callable for `Pathfinder`.
func move_cost(from_cell: Vector2i, to_cell: Vector2i) -> float:
	var diff := to_cell - from_cell
	var base: float = _cell_size_m * (Pathfinder._SQRT2 if diff.x != 0 and diff.y != 0 else 1.0)
	# A road overrides the terrain-type factor entirely — it is cheaper than every natural
	# terrain (including "built", 0.7), so the pathfinder actively routes onto one rather than
	# merely accepting it, which is what makes roads "a genuine investment" (SIMULATION_SPEC.md
	# §10) instead of a cosmetic.
	var terrain_factor: float = (
		_road_move_cost_factor if is_road(to_cell.x, to_cell.y)
		else _TERRAIN_MOVE_FACTOR.get(terrain_at(to_cell.x, to_cell.y), 1.5)
	)
	var slope_penalty: float = 1.0 + _slope_weight() * slope_radians_at(to_cell.x, to_cell.y)
	return base * terrain_factor * slope_penalty


## The cheapest possible single step, for the pathfinder's heuristic scale. Must never exceed the
## true cheapest cost anywhere on the map or A*'s heuristic stops being admissible — since a road
## can be cheaper than "built" terrain, that is the one this compares against, not `_TERRAIN_MOVE_FACTOR` alone.
func min_step_cost() -> float:
	return _cell_size_m * minf(_TERRAIN_MOVE_FACTOR[TerrainTypes.Terrain.BUILT], _road_move_cost_factor)


func _walk_slope_limit() -> float:
	if _max_walk_slope_radians <= 0.0:
		_max_walk_slope_radians = deg_to_rad(Tuning.get_num("pathfinding.max_walk_slope_deg"))
	return _max_walk_slope_radians


func _slope_weight() -> float:
	if _slope_cost_weight <= 0.0:
		_slope_cost_weight = Tuning.get_num("pathfinding.slope_cost_weight")
	return _slope_cost_weight


# --- dirty chunks -----------------------------------------------------------------------------

## Marks the chunks that must be remeshed after this cell changed. Neighbours are included
## because chunk meshes take their edge vertex heights from cells on the far side of the seam;
## remeshing only the owning chunk would leave a visible crack.
func mark_cell_dirty(x: int, y: int) -> void:
	var across: int = chunks_across()
	for offset_y in [-1, 0, 1]:
		for offset_x in [-1, 0, 1]:
			var cell_x: int = x + offset_x
			var cell_y: int = y + offset_y
			if not is_inside(cell_x, cell_y):
				continue
			@warning_ignore("integer_division")
			var chunk_x: int = cell_x / _chunk_cells
			@warning_ignore("integer_division")
			var chunk_y: int = cell_y / _chunk_cells
			_dirty_chunks[chunk_y * across + chunk_x] = true


## The chunks needing a remesh, lowest index first, clearing the set. Sorted so a rebuild is
## reproducible rather than dependent on dictionary order.
func take_dirty_chunks() -> PackedInt32Array:
	var indices := PackedInt32Array(_dirty_chunks.keys())
	indices.sort()
	_dirty_chunks.clear()
	return indices


func has_dirty_chunks() -> bool:
	return not _dirty_chunks.is_empty()


# --- building ---------------------------------------------------------------------------------

func _build(preset: Dictionary) -> void:
	var river: Dictionary = preset["river"]
	var profile: Dictionary = preset["profile"]
	var noise_settings: Dictionary = preset["noise"]
	var cover: Dictionary = preset["cover"]

	_cells_across = int(preset["cells_across"])
	_half_extent_m = world_size_m() * 0.5

	_river_half_width = float(river["half_width_cells"])
	_bank_blend_cells = float(river["bank_blend_cells"])
	_bed_depth_m = float(river["bed_depth_m"])
	_water_depth_m = float(river["water_depth_m"])

	var count: int = _cells_across * _cells_across
	_elevation.resize(count)
	_terrain.resize(count)
	_water.resize(count)
	_water_level.resize(count)
	_forest_density.resize(count)
	# Resize alone would keep old values if the new preset is the same size as the last one — a
	# rebuild must start with no roads, not whatever the previous world had.
	_road.resize(count)
	_road.fill(0)

	var broad := FastNoiseLite.new()
	broad.seed = int(noise_settings["seed"])
	broad.frequency = float(noise_settings["broad_frequency"])

	var detail := FastNoiseLite.new()
	detail.seed = int(noise_settings["seed"]) + 1
	detail.frequency = float(noise_settings["detail_frequency"])

	_build_columns(river, profile, noise_settings)
	_build_elevation(profile, noise_settings, broad, detail)
	_build_cover(river, profile, cover, detail)

	for chunk in chunks_across() * chunks_across():
		_dirty_chunks[chunk] = true


## Precomputes the cross-section of every column down the dale.
##
## Held in arrays rather than recomputed per pass because the elevation and cover passes have to
## agree exactly: if cover used even a slightly different valley width, the woodland band would
## sit beside the slope it is meant to be growing on.
##
## The variation is the whole point. With a constant cross-section the two valley sides are
## parallel ribbons and the dale reads as painted stripes; letting each side narrow, widen, rise
## and fall independently along its length is what produces spurs and re-entrants.
func _build_columns(river: Dictionary, profile: Dictionary, noise_settings: Dictionary) -> void:
	_river_centre.resize(_cells_across)
	_north_slope_half.resize(_cells_across)
	_north_slope_rise.resize(_cells_across)
	_south_slope_half.resize(_cells_across)
	_south_slope_rise.resize(_cells_across)

	var shape := FastNoiseLite.new()
	shape.seed = int(noise_settings["seed"]) + 2
	shape.frequency = float(noise_settings["profile_frequency"])

	var north: Dictionary = profile["north"]
	var south: Dictionary = profile["south"]
	var width_variation: float = float(profile["width_variation"])
	var rise_variation: float = float(profile["rise_variation"])

	var centre: float = float(river["centre_cell"])
	var meander_amplitude: float = float(river["meander_amplitude_cells"])
	var meander_wavelength: float = float(river["meander_wavelength_cells"])

	var north_half: float = float(north["slope_half_width_cells"])
	var north_rise: float = float(north["slope_rise_m"])
	var south_half: float = float(south["slope_half_width_cells"])
	var south_rise: float = float(south["slope_rise_m"])

	for x in _cells_across:
		_river_centre[x] = centre + ValleyShape.meander_offset(
			x, meander_amplitude, meander_wavelength
		)

		# Sampled far apart in the noise field so the four quantities vary independently rather
		# than in lockstep.
		var along: float = float(x)
		_north_slope_half[x] = north_half * (1.0 + width_variation * shape.get_noise_2d(along, 0.0))
		_north_slope_rise[x] = north_rise * (1.0 + rise_variation * shape.get_noise_2d(along, 128.0))
		_south_slope_half[x] = south_half * (1.0 + width_variation * shape.get_noise_2d(along, 512.0))
		_south_slope_rise[x] = south_rise * (1.0 + rise_variation * shape.get_noise_2d(along, 768.0))


func _build_elevation(
	profile: Dictionary,
	noise_settings: Dictionary,
	broad: FastNoiseLite,
	detail: FastNoiseLite
) -> void:
	var floor_half: float = float(profile["floor_half_width_cells"])
	var moor_ramp: float = float(profile["moor_ramp_cells"])
	var floor_elevation: float = float(profile["floor_elevation_m"])
	var fall: float = float(profile["downstream_fall_m"])
	var north_moor_rise: float = float(profile["north"]["moor_rise_m"])
	var south_moor_rise: float = float(profile["south"]["moor_rise_m"])

	var detail_amplitude: float = float(noise_settings["detail_amplitude_m"])
	var floor_amplitude: float = float(noise_settings["floor_amplitude_m"])
	var slope_amplitude: float = float(noise_settings["slope_amplitude_m"])
	var moor_amplitude: float = float(noise_settings["moor_amplitude_m"])

	for y in _cells_across:
		for x in _cells_across:
			var signed_distance: float = float(y) - _river_centre[x]
			var distance: float = absf(signed_distance)
			var is_north: bool = signed_distance < 0.0
			var slope_half: float = _north_slope_half[x] if is_north else _south_slope_half[x]
			var slope_rise: float = _north_slope_rise[x] if is_north else _south_slope_rise[x]
			var moor_rise: float = north_moor_rise if is_north else south_moor_rise

			var base: float = floor_elevation - ValleyShape.downstream_fall(x, _cells_across, fall)
			var rise: float = ValleyShape.cross_section_rise(
				distance, floor_half, slope_half, slope_rise, moor_ramp, moor_rise
			)
			var amplitude: float = ValleyShape.noise_amplitude(
				distance, floor_half, slope_half, floor_amplitude, slope_amplitude, moor_amplitude
			)
			var undulation: float = (
				broad.get_noise_2d(float(x), float(y)) * amplitude
				+ detail.get_noise_2d(float(x), float(y)) * detail_amplitude
			)
			var depth: float = ValleyShape.river_depth(
				distance, _river_half_width, _bed_depth_m, _bank_blend_cells
			)

			var index: int = y * _cells_across + x
			_elevation[index] = base + rise + undulation - depth
			_water_level[index] = base - _bed_depth_m + _water_depth_m


func _build_cover(
	river: Dictionary,
	profile: Dictionary,
	cover: Dictionary,
	detail: FastNoiseLite
) -> void:
	var floor_half: float = float(profile["floor_half_width_cells"])
	var river_half: float = float(river["half_width_cells"])
	var rock_slope: float = deg_to_rad(float(cover["rock_slope_degrees"]))
	var treeline: float = float(cover["treeline_elevation_m"])
	var woodland_density: float = float(cover["woodland_density"])
	var density_variation: float = float(cover["woodland_density_variation"])
	var moor_density: float = float(cover["moor_density"])

	for y in _cells_across:
		for x in _cells_across:
			var index: int = y * _cells_across + x
			var signed_distance: float = float(y) - _river_centre[x]
			var distance: float = absf(signed_distance)
			var slope_half: float = (
				_north_slope_half[x] if signed_distance < 0.0 else _south_slope_half[x]
			)

			var kind: TerrainTypes.Terrain = ValleyShape.terrain_for_distance(
				distance, floor_half, slope_half
			)

			# Bare stone wherever the ground is too steep to hold cover. This is what puts
			# outcrops and scree on the valley sides without any of them being authored.
			if slope_radians_at(x, y) > rock_slope:
				kind = TerrainTypes.Terrain.ROCK

			var is_river: bool = distance <= river_half
			_water[index] = TerrainTypes.Water.RIVER if is_river else TerrainTypes.Water.NONE
			_terrain[index] = kind

			var density: float = 0.0
			if kind == TerrainTypes.Terrain.WOODLAND and _elevation[index] < treeline:
				density = clampf(
					woodland_density + detail.get_noise_2d(float(x), float(y)) * density_variation,
					0.0,
					1.0
				)
			elif kind == TerrainTypes.Terrain.MOOR:
				density = moor_density
			_forest_density[index] = 0.0 if is_river else density


# --- save / load ---------------------------------------------------------------------------

## Only the roads — every other array is deterministically rebuilt by `build_preset`, per this
## file's own doc comment. A sparse cell list rather than the full grid, since roads are a small
## fraction of a 192² map even in a mature precinct.
func serialize() -> Dictionary:
	var cells: Array = []
	for cell in road_cells():
		cells.append([cell.x, cell.y])
	return {"roads": cells}


func deserialize(data: Dictionary) -> void:
	for cell in road_cells():
		set_road(cell.x, cell.y, false)
	for pair in data.get("roads", []):
		set_road(int(pair[0]), int(pair[1]), true)
