## Terrain enum values are stored in PackedByteArray cells, so their ordering is part of the
## save format. New members may be appended, but existing members must never be reordered.
extends GutTest


func test_ground_values_are_stable() -> void:
	assert_eq(TerrainTypes.Terrain.MEADOW, 0, "meadow is the first stored ground value")
	assert_eq(TerrainTypes.Terrain.WOODLAND, 1, "woodland keeps its stored value")
	assert_eq(TerrainTypes.Terrain.MOOR, 2, "moor keeps its stored value")
	assert_eq(TerrainTypes.Terrain.ROCK, 3, "rock keeps its stored value")
	assert_eq(TerrainTypes.Terrain.ARABLE, 4, "arable keeps its stored value")
	assert_eq(TerrainTypes.Terrain.BUILT, 5, "built keeps its stored value")


func test_water_values_are_stable() -> void:
	assert_eq(TerrainTypes.Water.NONE, 0, "none is the first stored water value")
	assert_eq(TerrainTypes.Water.RIVER, 1, "river keeps its stored value")
	assert_eq(TerrainTypes.Water.POND, 2, "pond keeps its stored value")
	assert_eq(TerrainTypes.Water.MARSH, 3, "marsh keeps its stored value")
