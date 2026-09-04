## Placement, footprint occupancy, the construction state machine, the frost gate, and local
## inventories with no global pool. `SIMULATION_SPEC.md` §7, §10, §11.
extends GutTest


func before_each() -> void:
	Terrain.build_preset("founding_valley")
	Buildings.clear()
	Weather.set_dice(Dice.new(1))
	Weather.roll_day(152)   # a plain summer day; frost tests override this explicitly


## Searches outward from `target` for a cell this type can actually be placed on, rather than
## hardcoding coordinates that would silently rot if the terrain preset changes. Ring-order search
## means the result is the closest valid site to `target` — load-bearing for the tests below that
## need two sites a known distance apart.
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


# --- placement and footprint --------------------------------------------------------------

func test_placement_claims_its_footprint() -> void:
	var site := _open_site("woodcutters_hut")
	var id := Buildings.place_building("woodcutters_hut", site)
	assert_gt(id, 0)
	assert_false(Buildings.can_place("woodcutters_hut", site), "the same site is now occupied")


func test_placement_on_an_unwalkable_cell_fails() -> void:
	assert_false(Buildings.can_place("woodcutters_hut", Vector2i(-5, -5)), "off the map")


func test_rotation_swaps_the_footprint_axes() -> void:
	assert_eq(Buildings.footprint_for("granary", 0), Vector2i(4, 6))
	assert_eq(Buildings.footprint_for("granary", 90), Vector2i(6, 4))
	assert_eq(Buildings.footprint_for("granary", 180), Vector2i(4, 6))
	assert_eq(Buildings.footprint_for("granary", 270), Vector2i(6, 4))


func test_an_invalid_rotation_falls_back_to_zero() -> void:
	assert_eq(Buildings.footprint_for("granary", 45), Vector2i(4, 6))


func test_door_cell_is_walkable_and_outside_the_footprint() -> void:
	var id := Buildings.place_building("granary", _open_site("granary"))
	var b := Buildings.get_building(id)
	var door := Buildings.door_cell(id)
	assert_true(Terrain.is_walkable(door.x, door.y))
	assert_false(b.contains_cell(door), "the door is not inside the building's own footprint")


# --- construction state machine -----------------------------------------------------------

func test_a_type_needing_materials_starts_planned() -> void:
	var id := Buildings.place_building("granary", _open_site("granary"))
	assert_eq(Buildings.get_building(id).construction_state, Building.State.PLANNED)


func test_delivering_materials_progresses_planned_to_pending_to_under_construction() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))

	assert_eq(Buildings.deliver_material(id, "sawn_timber", 20), 20)
	assert_eq(Buildings.get_building(id).construction_state, Building.State.MATERIALS_PENDING)
	assert_false(Buildings.is_materials_complete(id), "nails are still owed")

	assert_eq(Buildings.deliver_material(id, "nails", 4), 4)
	assert_true(Buildings.is_materials_complete(id))
	assert_eq(Buildings.get_building(id).construction_state, Building.State.UNDER_CONSTRUCTION)


func test_delivery_never_exceeds_what_is_owed() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	assert_eq(Buildings.deliver_material(id, "sawn_timber", 999), 20, "only what the type needs is accepted")
	assert_eq(Buildings.deliver_material(id, "sawn_timber", 1), 0, "nothing more is owed")


func test_labour_before_materials_arrive_does_nothing() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	assert_false(Buildings.contribute_labour(id, 10.0))
	assert_eq(Buildings.get_building(id).build_progress, 0.0)


func test_labour_completes_construction_at_its_full_hours() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(id, "sawn_timber", 20)
	Buildings.deliver_material(id, "nails", 4)

	assert_true(Buildings.contribute_labour(id, 79.0, 1.0))
	assert_lt(Buildings.get_building(id).build_progress, 1.0)
	assert_eq(Buildings.get_building(id).construction_state, Building.State.UNDER_CONSTRUCTION)

	assert_true(Buildings.contribute_labour(id, 1.0, 1.0))
	assert_eq(Buildings.get_building(id).construction_state, Building.State.COMPLETE)


func test_frost_blocks_a_mortar_building_but_not_a_timber_one() -> void:
	var timber_id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(timber_id, "sawn_timber", 20)
	Buildings.deliver_material(timber_id, "nails", 4)

	var stone_id := Buildings.place_building("cellarers_undercroft", _open_site("cellarers_undercroft"))
	Buildings.deliver_material(stone_id, "building_stone", 200)
	Buildings.deliver_material(stone_id, "mortar", 100)
	Buildings.deliver_material(stone_id, "sawn_timber", 20)
	assert_eq(Buildings.get_building(stone_id).construction_state, Building.State.UNDER_CONSTRUCTION)

	# Same draw as test_weather.gd's hard-frost case: coldest day, coldest end of the noise band.
	Weather.set_dice(ScriptedDice.new([0.0, 0.5, 0.99]))
	Weather.roll_day(20)
	assert_lt(Weather.temperature_c(), Tuning.get_num("construction.frost_gate_temp_c"))

	assert_true(Buildings.contribute_labour(timber_id, 10.0), "timber framing is never frost-gated")
	assert_false(Buildings.contribute_labour(stone_id, 10.0), "mortar work stops in a hard frost")
	assert_true(Buildings.is_frost_gated(stone_id))
	assert_eq(Buildings.get_building(stone_id).build_progress, 0.0)


# --- local inventory: no global pool --------------------------------------------------------

func test_inventory_add_and_remove_respect_capacity() -> void:
	var id := Buildings.seed_building("granary", _open_site("granary"))
	assert_eq(Buildings.add_to_inventory(id, "barley", 4000), 4000)
	assert_eq(Buildings.add_to_inventory(id, "barley", 500), 0, "already at capacity")
	assert_eq(Buildings.remove_from_inventory(id, "barley", 4001), 4000, "never removes more than is held")
	assert_eq(Buildings.inventory_of(id, "barley"), 0)


func test_seed_building_starts_complete_with_its_stock() -> void:
	var id := Buildings.seed_building(
		"open_stockpile", _open_site("open_stockpile"), 0, {"timber": 50, "sawn_timber": 30}
	)
	assert_eq(Buildings.get_building(id).construction_state, Building.State.COMPLETE)
	assert_eq(Buildings.inventory_of(id, "timber"), 50)
	assert_eq(Buildings.inventory_of(id, "sawn_timber"), 30)


func test_find_source_of_prefers_the_nearest_stocked_building() -> void:
	var near := Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"timber": 10})
	var near_door: Vector2i = Buildings.door_cell(near)

	# Well clear of the near stockpile's footprint and search radius, so this cannot resolve to
	# a neighbouring cell of the same site by coincidence of scan order.
	Buildings.seed_building("open_stockpile", _site_near("open_stockpile", near_door + Vector2i(40, 0)), 0, {"timber": 10})

	assert_eq(Buildings.find_source_of("timber", 1, near_door), near)


func test_find_source_of_ignores_a_building_without_enough_stock() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"timber": 3})
	assert_eq(Buildings.find_source_of("timber", 10, Vector2i.ZERO), -1)


func test_find_storage_accepting_respects_the_goods_mapping() -> void:
	var stockpile := Buildings.seed_building("open_stockpile", _open_site("open_stockpile"))
	var door := Buildings.door_cell(stockpile)
	assert_eq(Buildings.find_storage_accepting("timber", door), stockpile, "timber is storable_in open_stockpile")
	assert_eq(Buildings.find_storage_accepting("wool_fleece", door), -1, "no wool_store has been built")


func test_find_storage_accepting_skips_an_incomplete_building() -> void:
	Buildings.place_building("open_stockpile", _open_site("open_stockpile"))   # PLANNED, not COMPLETE
	assert_eq(Buildings.find_storage_accepting("timber", Vector2i.ZERO), -1)


# --- worker assignment (roadmap 4.9) --------------------------------------------------------

func test_assigning_a_worker_pins_them_to_the_site() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(id, "sawn_timber", 20)
	Buildings.deliver_material(id, "nails", 4)

	assert_true(Buildings.assign_worker(id, 1))
	assert_eq(Buildings.building_for_worker(1), id)
	assert_eq(Buildings.worker_count(id), 1)


func test_assignment_is_refused_beyond_the_type_worker_slots() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))   # 2 slots
	Buildings.deliver_material(id, "sawn_timber", 20)
	Buildings.deliver_material(id, "nails", 4)

	assert_true(Buildings.assign_worker(id, 1))
	assert_true(Buildings.assign_worker(id, 2))
	assert_false(Buildings.assign_worker(id, 3), "the hut only has 2 slots")
	assert_eq(Buildings.worker_count(id), 2)


func test_a_worker_cannot_be_assigned_to_a_building_that_is_not_under_construction() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	assert_eq(Buildings.get_building(id).construction_state, Building.State.PLANNED)
	assert_false(Buildings.assign_worker(id, 1), "no materials delivered yet")


func test_assigning_elsewhere_releases_the_previous_site() -> void:
	var first := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(first, "sawn_timber", 20)
	Buildings.deliver_material(first, "nails", 4)

	var second := Buildings.place_building("masons_lodge", _open_site("masons_lodge"))
	Buildings.deliver_material(second, "sawn_timber", 40)
	Buildings.deliver_material(second, "nails", 8)

	Buildings.assign_worker(first, 1)
	Buildings.assign_worker(second, 1)

	assert_eq(Buildings.building_for_worker(1), second)
	assert_eq(Buildings.worker_count(first), 0, "no longer pinned to the first site")


func test_unassign_returns_a_worker_to_the_pool() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(id, "sawn_timber", 20)
	Buildings.deliver_material(id, "nails", 4)

	Buildings.assign_worker(id, 1)
	Buildings.unassign_worker(1)
	assert_eq(Buildings.building_for_worker(1), -1)
	assert_eq(Buildings.worker_count(id), 0)


func test_completion_clears_the_crew() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(id, "sawn_timber", 20)
	Buildings.deliver_material(id, "nails", 4)
	Buildings.assign_worker(id, 1)

	Buildings.contribute_labour(id, 200.0)   # far more than the 80h it needs
	assert_eq(Buildings.get_building(id).construction_state, Building.State.COMPLETE)
	assert_eq(Buildings.building_for_worker(1), -1, "a finished site has no crew left to show")


func test_a_complete_production_building_accepts_a_crew() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(id, "sawn_timber", 20)
	Buildings.deliver_material(id, "nails", 4)
	Buildings.contribute_labour(id, 200.0)
	assert_eq(Buildings.get_building(id).construction_state, Building.State.COMPLETE)

	assert_true(Buildings.assign_worker(id, 1), "a finished woodcutters' hut can now run a recipe")
	assert_eq(Buildings.building_for_worker(1), id)


func test_a_complete_storage_building_still_refuses_a_crew() -> void:
	var id := Buildings.seed_building("open_stockpile", _open_site("open_stockpile"))
	assert_eq(Buildings.get_building(id).construction_state, Building.State.COMPLETE)
	assert_false(Buildings.assign_worker(id, 1), "storage has no crew concept, complete or not")


# --- referential integrity, Architecture Guide §6 --------------------------------------------

func test_every_build_material_names_a_real_good() -> void:
	for type_id in Buildings.type_ids():
		for good_id in Buildings.get_type(type_id).get("build_materials", {}).keys():
			assert_true(Goods.exists(good_id), "%s's build cost names unknown good %s" % [type_id, good_id])


# --- save / load ---------------------------------------------------------------------------

func test_serialize_round_trip() -> void:
	var id := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.deliver_material(id, "sawn_timber", 20)
	Buildings.deliver_material(id, "nails", 4)
	Buildings.contribute_labour(id, 40.0)
	Buildings.add_to_inventory(id, "timber", 3)
	Buildings.door_cell(id)   # force it to be cached before the snapshot

	var saved := Buildings.serialize()
	var before := Buildings.get_building(id).to_dict()
	var anchor := Buildings.get_building(id).anchor

	Buildings.clear()
	assert_eq(Buildings.building_ids().size(), 0)

	Buildings.deserialize(saved)
	assert_eq(Buildings.get_building(id).to_dict(), before)
	assert_false(Buildings.can_place("woodcutters_hut", anchor), "footprint occupancy is restored too")
