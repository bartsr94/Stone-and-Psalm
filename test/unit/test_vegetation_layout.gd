## Placement rules must stay deterministic because the view can rebuild all vegetation at any time.
extends GutTest

const SEED := 20260904
const TREE_SLOPE := deg_to_rad(28.0)
const SCRUB_SLOPE := deg_to_rad(40.0)
const TREE_LINE := 46.0


func test_same_cell_and_inputs_always_return_the_same_candidate() -> void:
	var first := _placement(TerrainTypes.Terrain.WOODLAND, TerrainTypes.Water.NONE, 1.0, deg_to_rad(12.0), 30.0, 14, 22)
	var second := _placement(TerrainTypes.Terrain.WOODLAND, TerrainTypes.Water.NONE, 1.0, deg_to_rad(12.0), 30.0, 14, 22)
	assert_eq(first, VegetationLayout.Placement.TREE, "eligible woodland places a tree at density one")
	assert_eq(second, first, "rebuilding the same cell is identical")
	assert_eq(
		VegetationLayout.cell_value(SEED, 14, 22, 17),
		VegetationLayout.cell_value(SEED, 14, 22, 17),
		"the coordinate hash is stable"
	)


func test_zero_density_never_places_and_one_density_always_places() -> void:
	assert_false(VegetationLayout.should_place(0.0, SEED, 14, 22, 17), "zero is empty")
	assert_true(VegetationLayout.should_place(1.0, SEED, 14, 22, 17), "one is full")
	assert_true(VegetationLayout.should_place(2.0, SEED, 14, 22, 17), "density clamps above one")
	assert_false(VegetationLayout.should_place(-1.0, SEED, 14, 22, 17), "density clamps below zero")


func test_water_suppresses_every_candidate_category() -> void:
	for terrain in [
		TerrainTypes.Terrain.WOODLAND,
		TerrainTypes.Terrain.MOOR,
		TerrainTypes.Terrain.ROCK,
	]:
		assert_eq(
			_placement(terrain, TerrainTypes.Water.RIVER, 1.0, 0.0, 20.0, 14, 22),
			VegetationLayout.Placement.NONE,
			"water suppresses %s" % terrain
		)


func test_trees_require_woodland_slope_and_tree_line() -> void:
	assert_eq(
		_placement(TerrainTypes.Terrain.WOODLAND, TerrainTypes.Water.NONE, 1.0, TREE_SLOPE, TREE_LINE, 14, 22),
		VegetationLayout.Placement.TREE,
		"eligible woodland places a tree"
	)
	assert_eq(
		_placement(TerrainTypes.Terrain.MEADOW, TerrainTypes.Water.NONE, 1.0, 0.0, 20.0, 14, 22),
		VegetationLayout.Placement.NONE,
		"meadow does not place a tree"
	)
	assert_eq(
		_placement(TerrainTypes.Terrain.WOODLAND, TerrainTypes.Water.NONE, 1.0, TREE_SLOPE + 0.01, 20.0, 14, 22),
		VegetationLayout.Placement.NONE,
		"over-steep woodland does not place a tree"
	)
	assert_eq(
		_placement(TerrainTypes.Terrain.WOODLAND, TerrainTypes.Water.NONE, 1.0, 0.0, TREE_LINE + 0.01, 14, 22),
		VegetationLayout.Placement.NONE,
		"above-tree-line woodland does not place a tree"
	)


func test_moor_places_scrub_but_respects_its_slope_limit() -> void:
	assert_eq(
		_placement(TerrainTypes.Terrain.MOOR, TerrainTypes.Water.NONE, 1.0, SCRUB_SLOPE, 50.0, 14, 22),
		VegetationLayout.Placement.SCRUB,
		"eligible moor places scrub"
	)
	assert_eq(
		_placement(TerrainTypes.Terrain.MOOR, TerrainTypes.Water.NONE, 1.0, SCRUB_SLOPE + 0.01, 50.0, 14, 22),
		VegetationLayout.Placement.NONE,
		"over-steep moor stays clear"
	)


func test_rock_cells_use_their_own_density() -> void:
	assert_eq(
		_placement(TerrainTypes.Terrain.ROCK, TerrainTypes.Water.NONE, 0.0, 1.0, 50.0, 14, 22, 1.0),
		VegetationLayout.Placement.ROCK,
		"rock density is independent of forest density"
	)
	assert_eq(
		_placement(TerrainTypes.Terrain.ROCK, TerrainTypes.Water.NONE, 1.0, 1.0, 50.0, 14, 22, 0.0),
		VegetationLayout.Placement.NONE,
		"zero rock density leaves rock cells empty"
	)


func _placement(
	terrain: TerrainTypes.Terrain,
	water: TerrainTypes.Water,
	forest_density: float,
	slope_radians: float,
	elevation_m: float,
	cell_x: int,
	cell_y: int,
	rock_density: float = 0.5
) -> VegetationLayout.Placement:
	return VegetationLayout.placement_for_cell(
		terrain,
		water,
		forest_density,
		slope_radians,
		elevation_m,
		SEED,
		cell_x,
		cell_y,
		TREE_SLOPE,
		TREE_LINE,
		SCRUB_SLOPE,
		rock_density
	)
