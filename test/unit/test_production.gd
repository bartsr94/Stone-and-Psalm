## Recipes and batches: starting one, running one, and what it leaves in a building's own
## inventory when it finishes. `SIMULATION_SPEC.md` §9, roadmap 5.1.
extends GutTest


func before_each() -> void:
	Terrain.build_preset("founding_valley")
	Buildings.clear()


func _site_near(type_id: String, target: Vector2i, max_radius: int = 60) -> Vector2i:
	for radius in range(0, max_radius):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := target + Vector2i(dx, dy)
				if Buildings.can_place(type_id, cell):
					return cell
	fail_test("no buildable site found near %s for %s" % [target, type_id])
	return Vector2i(-1, -1)


func _open_site(type_id: String) -> Vector2i:
	return _site_near(type_id, Vector2i(100, 100))


## Places, fully stocks and finishes a woodcutters' hut in one call, the way `test_buildings.gd`'s
## `test_completion_clears_the_crew` reaches `COMPLETE`.
func _completed_woodcutters_hut() -> int:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(id, "sawn_timber", 20)
	Buildings.deliver_material(id, "nails", 4)
	Buildings.contribute_labour(id, 200.0)   # far more than the 80h it needs
	assert_eq(Buildings.get_building(id).construction_state, Building.State.COMPLETE)
	return id


# --- recipe lookup -------------------------------------------------------------------------

func test_a_known_recipe_resolves() -> void:
	assert_true(Production.has_recipe("felling"))
	assert_eq(Production.get_recipe("felling")["building_type"], "woodcutters_hut")


func test_an_unknown_recipe_does_not_exist() -> void:
	assert_false(Production.has_recipe("no_such_recipe"))


func test_recipe_ids_for_filters_by_building_type() -> void:
	assert_true(Production.recipe_ids_for("woodcutters_hut").has("felling"))
	assert_false(Production.recipe_ids_for("quarry").has("felling"))
	assert_true(Production.recipe_ids_for("quarry").has("quarrying"))


func test_every_recipe_names_a_real_building_type_and_real_goods() -> void:
	for recipe_id in Production.recipe_ids():
		var recipe := Production.get_recipe(recipe_id)
		assert_true(Buildings.has_type(recipe["building_type"]), "%s names unknown building type" % recipe_id)
		for good_id in recipe.get("inputs", {}).keys():
			assert_true(Goods.exists(good_id), "%s's input names unknown good %s" % [recipe_id, good_id])
		for good_id in recipe.get("outputs", {}).keys():
			assert_true(Goods.exists(good_id), "%s's output names unknown good %s" % [recipe_id, good_id])


# --- starting a batch -----------------------------------------------------------------------

func test_a_no_input_recipe_can_always_start_once_the_building_is_complete() -> void:
	var id := _completed_woodcutters_hut()
	assert_true(Production.can_start(id, "felling"))


func test_a_recipe_cannot_start_before_the_building_is_complete() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	assert_false(Production.can_start(id, "felling"))


func test_a_recipe_refuses_the_wrong_building_type() -> void:
	var id := _completed_woodcutters_hut()
	assert_false(Production.can_start(id, "quarrying"), "quarrying does not run at a woodcutters' hut")


func test_starting_marks_the_active_recipe_and_zeroes_progress() -> void:
	var id := _completed_woodcutters_hut()
	assert_true(Production.start(id, "felling"))
	var b := Buildings.get_building(id)
	assert_eq(b.active_recipe, "felling")
	assert_eq(b.recipe_progress, 0.0)


func test_a_second_batch_cannot_start_while_one_is_already_active() -> void:
	var id := _completed_woodcutters_hut()
	Production.start(id, "felling")
	assert_false(Production.can_start(id, "felling"), "one batch at a time")


# --- running a batch to completion ----------------------------------------------------------

func test_contribute_labour_auto_starts_the_only_recipe() -> void:
	var id := _completed_woodcutters_hut()
	assert_true(Production.contribute_labour(id, 2.0))
	assert_eq(Buildings.get_building(id).active_recipe, "felling")


func test_contribute_labour_accumulates_progress() -> void:
	var id := _completed_woodcutters_hut()
	Production.contribute_labour(id, 2.0)   # felling needs 4h
	assert_almost_eq(Buildings.get_building(id).recipe_progress, 0.5, 0.0001)


func test_a_finished_batch_deposits_its_output_and_clears_for_the_next_one() -> void:
	var id := _completed_woodcutters_hut()
	Production.contribute_labour(id, 4.0)   # exactly felling's 4h
	var b := Buildings.get_building(id)
	assert_eq(b.active_recipe, "", "clear to start the next batch")
	assert_eq(b.recipe_progress, 0.0)
	assert_eq(Buildings.inventory_of(id, "timber"), 10)


func test_batch_completed_fires_with_the_building_and_recipe() -> void:
	var id := _completed_woodcutters_hut()
	var seen: Array = []
	var on_completed := func(building_id: int, recipe_id: String) -> void:
		seen.append([building_id, recipe_id])
	Production.batch_completed.connect(on_completed)
	Production.contribute_labour(id, 4.0)
	Production.batch_completed.disconnect(on_completed)
	assert_eq(seen, [[id, "felling"]])


func test_contribute_labour_refuses_a_building_that_is_not_complete() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	assert_false(Production.contribute_labour(id, 1.0))


func test_can_produce_is_true_once_a_recipe_is_startable() -> void:
	var id := _completed_woodcutters_hut()
	assert_true(Production.can_produce(id))


func test_can_produce_is_false_for_a_type_with_no_recipe() -> void:
	var id := Buildings.place_building("masons_lodge", _open_site("masons_lodge"))
	Buildings.deliver_material(id, "sawn_timber", 40)
	Buildings.deliver_material(id, "nails", 8)
	Buildings.contribute_labour(id, 500.0)
	assert_eq(Buildings.get_building(id).construction_state, Building.State.COMPLETE)
	assert_false(Production.can_produce(id), "no recipe targets masons_lodge yet")


func test_repeated_contributions_across_batches_keep_producing() -> void:
	var id := _completed_woodcutters_hut()
	Production.contribute_labour(id, 4.0)   # finishes batch 1: +10 timber
	Production.contribute_labour(id, 4.0)   # auto-starts and finishes batch 2: +10 more
	assert_eq(Buildings.inventory_of(id, "timber"), 20)
