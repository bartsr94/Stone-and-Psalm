## The cell vocabulary shared by the terrain data and everything that reads it.
##
## Lives on its own so that the authoritative grid (`autoloads/terrain.gd`) and the pure
## calculators that build it do not have to depend on each other to agree on what a cell is.
## Values are stored per cell as bytes, so the ordering here is part of the save format —
## **append new members, never reorder them.**
class_name TerrainTypes
extends RefCounted

## Ground cover. `SIMULATION_SPEC.md` §3.1.
enum Terrain {
	MEADOW,
	WOODLAND,
	MOOR,
	ROCK,
	ARABLE,
	BUILT,
}

## Standing or running water on a cell. `SIMULATION_SPEC.md` §3.2.
enum Water {
	NONE,
	RIVER,
	POND,
	MARSH,
}
