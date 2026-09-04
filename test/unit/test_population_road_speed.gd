## A person on a road covers more ground per substep — `Population._effective_move_cells`,
## `SIMULATION_SPEC.md` §10. Calls the private method directly, the same way
## `test_camera_rig_runtime.gd` drives `CameraRig._process` — there is no public API for "how far
## would this substep move someone", only the effect of it.
extends GutTest


func before_each() -> void:
	Terrain.build_preset("founding_valley")
	Weather.set_dice(ScriptedDice.new([0.5, 0.5, 0.99]))
	Weather.roll_day(152)   # a plain, dry, non-snowing day


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


func test_standing_on_a_road_moves_faster_than_open_ground() -> void:
	var cell := _walkable_cell()
	var person := Person.new()
	person.grid_pos = cell

	var off_road := Population._effective_move_cells(person)

	Terrain.set_road(cell.x, cell.y, true)
	var on_road := Population._effective_move_cells(person)

	assert_gt(on_road, off_road, "the tuned road speed bonus is greater than one")


func test_the_road_bonus_and_the_loaded_penalty_both_apply() -> void:
	var cell := _walkable_cell()
	Terrain.set_road(cell.x, cell.y, true)

	var empty_handed := Person.new()
	empty_handed.grid_pos = cell

	var carrying := Person.new()
	carrying.grid_pos = cell
	carrying.carrying_qty = 10

	assert_lt(
		Population._effective_move_cells(carrying), Population._effective_move_cells(empty_handed),
		"loaded is still slower than empty-handed, road or not"
	)
