## Roads (Phase 4.10): the one piece of terrain state that is edited rather than derived from the
## preset, so it is the one piece `Terrain` actually saves. `SIMULATION_SPEC.md` §10.
extends GutTest


func before_each() -> void:
	Terrain.build_preset("founding_valley")


func _walkable_cell() -> Vector2i:
	for radius in range(0, 60):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := Vector2i(100, 100) + Vector2i(dx, dy)
				if Terrain.is_walkable(cell.x, cell.y):
					return cell
	fail_test("no walkable cell found near (100, 100)")
	return Vector2i(-1, -1)


func test_a_fresh_preset_has_no_roads() -> void:
	assert_eq(Terrain.road_cells().size(), 0)


func test_set_road_builds_and_removes() -> void:
	var cell := _walkable_cell()
	assert_false(Terrain.is_road(cell.x, cell.y))

	Terrain.set_road(cell.x, cell.y, true)
	assert_true(Terrain.is_road(cell.x, cell.y))

	Terrain.set_road(cell.x, cell.y, false)
	assert_false(Terrain.is_road(cell.x, cell.y))


func test_a_road_cannot_be_built_on_unwalkable_ground() -> void:
	Terrain.set_road(-5, -5, true)   # off the map
	assert_false(Terrain.is_road(-5, -5))


func test_road_changed_fires_only_on_an_actual_change() -> void:
	var cell := _walkable_cell()
	# A lambda captures a local by value in GDScript, not by reference — an Array is captured by
	# value too, but it is a reference type, so mutating its *contents* still reaches the outer
	# scope. A bare `var fires := 0` incremented inside the lambda would silently only ever
	# update the lambda's own copy.
	var fires := [0]
	var counter := func(_x: int, _y: int, _is_road: bool) -> void:
		fires[0] += 1
	Terrain.road_changed.connect(counter)

	Terrain.set_road(cell.x, cell.y, true)
	Terrain.set_road(cell.x, cell.y, true)   # already a road; no second signal
	Terrain.set_road(cell.x, cell.y, false)
	Terrain.set_road(cell.x, cell.y, false)  # already gone; no second signal

	Terrain.road_changed.disconnect(counter)
	assert_eq(fires[0], 2, "one signal per actual state change")


func test_a_road_is_cheaper_to_cross_than_any_natural_terrain() -> void:
	var cell := _walkable_cell()
	var from := cell + Vector2i(-1, 0)
	var plain_cost := Terrain.move_cost(from, cell)

	Terrain.set_road(cell.x, cell.y, true)
	var road_cost := Terrain.move_cost(from, cell)

	assert_lt(road_cost, plain_cost, "a road is always at least as fast as the terrain it replaces")


func test_the_pathfinding_heuristic_stays_admissible_with_roads() -> void:
	# min_step_cost is the pathfinder's per-step lower bound; it must never exceed the true
	# cheapest cost anywhere on the map, and a road can be cheaper than the cheapest natural
	# terrain ("built").
	var cell := _walkable_cell()
	Terrain.set_road(cell.x, cell.y, true)
	var from := cell + Vector2i(-1, 0)
	assert_lte(Terrain.min_step_cost(), Terrain.move_cost(from, cell))


func test_a_new_preset_build_clears_any_roads() -> void:
	var cell := _walkable_cell()
	Terrain.set_road(cell.x, cell.y, true)
	assert_eq(Terrain.road_cells().size(), 1)

	Terrain.build_preset("founding_valley")
	assert_eq(Terrain.road_cells().size(), 0, "a fresh build starts with no roads, not the last world's")


func test_serialize_round_trip() -> void:
	var cell := _walkable_cell()
	Terrain.set_road(cell.x, cell.y, true)
	var saved := Terrain.serialize()

	Terrain.build_preset("founding_valley")
	assert_eq(Terrain.road_cells().size(), 0)

	Terrain.deserialize(saved)
	assert_true(Terrain.is_road(cell.x, cell.y))
	assert_eq(Terrain.road_cells().size(), 1)
