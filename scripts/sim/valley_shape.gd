## The geometry of the dale: pure functions from a cell coordinate to a shape.
##
## Every number these take comes from `data/terrain_presets.json`. Nothing here holds state,
## touches the scene tree, or draws a random number — the same preset always produces the same
## valley, which is what lets `Terrain` be rebuilt from a save rather than stored cell by cell.
##
## The cross-section is described from the river outwards, and each side of the valley is
## evaluated separately with its own numbers, because a real dale is not symmetric.
##
##     river bed      flat floor          wooded slope           moor
##     |<-- half -->|<-- floor_half -->|<-- to slope_half -->|<-- moor_ramp -->
class_name ValleyShape
extends RefCounted


## How far the river's centreline sits from the map's centre line at this point along the dale,
## in cells. A single sine is deliberate: it reads as a meander without needing control points,
## and it keeps the whole river describable by two numbers.
static func meander_offset(
	along_cells: int,
	amplitude_cells: float,
	wavelength_cells: float
) -> float:
	if wavelength_cells <= 0.0:
		return 0.0
	return amplitude_cells * sin(TAU * float(along_cells) / wavelength_cells)


## The fall of the valley floor from the head of the dale to its mouth, in metres. Linear, and
## the reason the river has a downstream direction at all.
static func downstream_fall(along_cells: int, cells_across: int, total_fall_m: float) -> float:
	if cells_across <= 1:
		return 0.0
	var t: float = clampf(float(along_cells) / float(cells_across - 1), 0.0, 1.0)
	return total_fall_m * t


## Height above the valley floor at a distance from the river, in metres.
##
## Flat across the floor, easing up the valley side, then easing again onto the moor. Both
## transitions are smoothstepped so the slope has no crease at either end — a crease reads
## immediately as a mistake once there is a low sun on it.
static func cross_section_rise(
	distance_cells: float,
	floor_half_width_cells: float,
	slope_half_width_cells: float,
	slope_rise_m: float,
	moor_ramp_cells: float,
	moor_rise_m: float
) -> float:
	if distance_cells <= floor_half_width_cells:
		return 0.0

	if distance_cells < slope_half_width_cells:
		return slope_rise_m * smoothstep(floor_half_width_cells, slope_half_width_cells, distance_cells)

	var moor_end: float = slope_half_width_cells + moor_ramp_cells
	return slope_rise_m + moor_rise_m * smoothstep(slope_half_width_cells, moor_end, distance_cells)


## How deep the river has cut below the valley floor at this distance from its centreline, in
## metres. Full depth across the channel, easing out through the banks so the bed joins the
## floor smoothly instead of as a trench.
static func river_depth(
	distance_cells: float,
	half_width_cells: float,
	bed_depth_m: float,
	bank_blend_cells: float
) -> float:
	if distance_cells <= half_width_cells:
		return bed_depth_m
	var bank_end: float = half_width_cells + bank_blend_cells
	return bed_depth_m * (1.0 - smoothstep(half_width_cells, bank_end, distance_cells))


## Which band of the valley a distance from the river falls in.
static func terrain_for_distance(
	distance_cells: float,
	floor_half_width_cells: float,
	slope_half_width_cells: float
) -> TerrainTypes.Terrain:
	if distance_cells <= floor_half_width_cells:
		return TerrainTypes.Terrain.MEADOW
	if distance_cells < slope_half_width_cells:
		return TerrainTypes.Terrain.WOODLAND
	return TerrainTypes.Terrain.MOOR


## How much of the terrain detail noise applies here, in metres of amplitude. The floor stays
## nearly flat because the monastery has to be built on it; the moor is the roughest ground.
static func noise_amplitude(
	distance_cells: float,
	floor_half_width_cells: float,
	slope_half_width_cells: float,
	floor_amplitude_m: float,
	slope_amplitude_m: float,
	moor_amplitude_m: float
) -> float:
	if distance_cells <= floor_half_width_cells:
		return floor_amplitude_m
	if distance_cells < slope_half_width_cells:
		return lerpf(
			floor_amplitude_m,
			slope_amplitude_m,
			smoothstep(floor_half_width_cells, slope_half_width_cells, distance_cells)
		)
	return moor_amplitude_m
