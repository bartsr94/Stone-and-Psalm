## Pure, deterministic placement rules for Phase 1.6 vegetation.
##
## This script decides which visual candidate belongs on a terrain cell. It does not read the
## Terrain autoload or touch the scene tree; the view renderer supplies all cell values and later
## turns the result into MultiMesh transforms. The integer hash is deliberate: vegetation must
## rebuild identically after loading a save and must not depend on random stream state.
class_name VegetationLayout
extends RefCounted

enum Placement {
	NONE,
	TREE,
	SCRUB,
	ROCK,
}

const _UINT_MASK: int = 0xFFFFFFFF
const _POSITIVE_MASK: int = 0x7FFFFFFF
const _TREE_SALT: int = 0x1F123BB5
const _SCRUB_SALT: int = 0x3A5F0C71
const _ROCK_SALT: int = 0x6D2B79F5
const _HASH_X: int = 374761393
const _HASH_Y: int = 668265263
const _HASH_SEED: int = 1442695041
const _HASH_MIX: int = 1274126177


## Returns the single vegetation candidate for a cell, or NONE when the cell stays clear.
static func placement_for_cell(
	terrain: TerrainTypes.Terrain,
	water: TerrainTypes.Water,
	forest_density: float,
	slope_radians: float,
	elevation_m: float,
	seed: int,
	cell_x: int,
	cell_y: int,
	tree_max_slope_radians: float,
	tree_max_elevation_m: float,
	scrub_max_slope_radians: float,
	rock_density: float
) -> Placement:
	if water != TerrainTypes.Water.NONE:
		return Placement.NONE

	if terrain == TerrainTypes.Terrain.WOODLAND:
		if elevation_m <= tree_max_elevation_m and slope_radians <= tree_max_slope_radians:
			if should_place(forest_density, seed, cell_x, cell_y, _TREE_SALT):
				return Placement.TREE

	if terrain == TerrainTypes.Terrain.MOOR:
		if slope_radians <= scrub_max_slope_radians:
			if should_place(forest_density, seed, cell_x, cell_y, _SCRUB_SALT):
				return Placement.SCRUB

	if terrain == TerrainTypes.Terrain.ROCK:
		if should_place(rock_density, seed, cell_x, cell_y, _ROCK_SALT):
			return Placement.ROCK

	return Placement.NONE


## A stable probability for one cell and one vegetation category.
static func cell_value(seed: int, cell_x: int, cell_y: int, category_salt: int) -> float:
	return float(cell_hash(seed, cell_x, cell_y, category_salt)) / float(_POSITIVE_MASK)


## Returns true according to density without consuming shared random state.
static func should_place(
	density: float,
	seed: int,
	cell_x: int,
	cell_y: int,
	category_salt: int
) -> bool:
	return cell_value(seed, cell_x, cell_y, category_salt) < clampf(density, 0.0, 1.0)


## Integer coordinate hash. Constants are part of this algorithm, not game tuning values.
static func cell_hash(seed: int, cell_x: int, cell_y: int, category_salt: int) -> int:
	var value: int = (seed * _HASH_SEED) & _UINT_MASK
	value = (value ^ (cell_x * _HASH_X)) & _UINT_MASK
	value = (value ^ (cell_y * _HASH_Y)) & _UINT_MASK
	value = (value ^ category_salt) & _UINT_MASK
	value = (value ^ (value >> 13)) & _UINT_MASK
	value = (value * _HASH_MIX) & _UINT_MASK
	value = (value ^ (value >> 16)) & _UINT_MASK
	return value & _POSITIVE_MASK
