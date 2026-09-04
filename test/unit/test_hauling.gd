## The haul task queue: rebuilding, claiming, and the pickup/dropoff transfer between two
## buildings' local inventories. `SIMULATION_SPEC.md` §10.
extends GutTest


func before_each() -> void:
	Terrain.build_preset("founding_valley")
	Buildings.clear()
	Hauling.clear()


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


func test_rebuild_queues_a_delivery_task_from_a_stocked_source() -> void:
	var stockpile := Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	var hut := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))

	Hauling.rebuild_tasks()

	var ids := Hauling.open_task_ids()
	assert_eq(ids.size(), 1)
	var task := Hauling.get_task(ids[0])
	assert_eq(task["good_id"], "sawn_timber")
	assert_eq(task["from_id"], stockpile)
	assert_eq(task["to_id"], hut)
	assert_eq(task["purpose"], "delivery")
	assert_eq(task["priority"], Hauling.PRIORITY_DELIVERY)


func test_rebuild_does_not_duplicate_an_open_task() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Hauling.rebuild_tasks()
	Hauling.rebuild_tasks()
	assert_eq(Hauling.open_task_ids().size(), 1)


func test_a_building_with_no_source_gets_no_task() -> void:
	Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Hauling.rebuild_tasks()
	assert_eq(Hauling.open_task_ids().size(), 0)


func test_claim_hides_an_assigned_task_from_a_second_claim() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Hauling.rebuild_tasks()

	assert_false(Hauling.claim_task(Vector2i(0, 0)).is_empty())
	assert_true(Hauling.claim_task(Vector2i(0, 0)).is_empty(), "already assigned")


func test_release_returns_an_unstarted_task_to_the_queue() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Hauling.rebuild_tasks()

	var task_id := int(Hauling.claim_task(Vector2i(0, 0))["id"])
	Hauling.release_task(task_id)
	assert_false(Hauling.claim_task(Vector2i(0, 0)).is_empty(), "released back onto the queue")


func test_pickup_is_capped_at_the_carry_max() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	Buildings.place_building("masons_lodge", _open_site("masons_lodge"))   # needs 40, more than the carry cap
	Hauling.rebuild_tasks()

	var task_id := int(Hauling.claim_task(Vector2i(0, 0))["id"])
	var got := Hauling.pickup(task_id)
	assert_eq(got["good_id"], "sawn_timber")
	assert_eq(got["qty"], Tuning.get_int("hauling.carry_max_units"))


func test_dropoff_delivers_and_closes_the_task_once_fully_hauled() -> void:
	var stockpile := Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	var hut := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Hauling.rebuild_tasks()

	var task_id := int(Hauling.claim_task(Vector2i(0, 0))["id"])
	var got := Hauling.pickup(task_id)
	assert_eq(got["qty"], 20, "the hut only needs 20, less than the carry cap")
	assert_true(Hauling.dropoff(task_id))

	assert_eq(Buildings.materials_needed(hut).get("sawn_timber", 0), 0)
	assert_true(Hauling.get_task(task_id).is_empty(), "closed once fully delivered")
	assert_eq(Buildings.inventory_of(stockpile, "sawn_timber"), 80)


func test_a_partial_delivery_leaves_the_task_open_for_another_trip() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	var lodge := Buildings.place_building("masons_lodge", _open_site("masons_lodge"))   # needs 40
	Hauling.rebuild_tasks()

	var task_id := int(Hauling.claim_task(Vector2i(0, 0))["id"])
	var first := Hauling.pickup(task_id)
	assert_eq(first["qty"], 25)
	Hauling.dropoff(task_id)
	assert_false(Hauling.get_task(task_id).is_empty(), "15 units still owed")
	assert_eq(Buildings.materials_needed(lodge).get("sawn_timber", 0), 15)

	var second := Hauling.pickup(task_id)
	assert_eq(second["qty"], 15)
	Hauling.dropoff(task_id)
	assert_true(Hauling.get_task(task_id).is_empty())
	assert_eq(Buildings.materials_needed(lodge).get("sawn_timber", 0), 0)


func test_haul_out_moves_produced_goods_to_an_accepting_store() -> void:
	var producer := Buildings.seed_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.add_to_inventory(producer, "timber", 10)
	var store := Buildings.seed_building("open_stockpile", _open_site("open_stockpile"))

	Hauling.rebuild_tasks()
	var ids := Hauling.open_task_ids()
	assert_eq(ids.size(), 1)
	var task := Hauling.get_task(ids[0])
	assert_eq(task["purpose"], "storage")
	assert_eq(task["from_id"], producer)
	assert_eq(task["to_id"], store)

	var task_id := int(task["id"])
	Hauling.pickup(task_id)
	Hauling.dropoff(task_id)
	assert_eq(Buildings.inventory_of(store, "timber"), 10)
	assert_eq(Buildings.inventory_of(producer, "timber"), 0)


func test_rebuild_queues_a_production_input_task_from_a_stocked_source() -> void:
	var hut := Buildings.seed_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.add_to_inventory(hut, "timber", 30)   # more than sawing's own 10-unit need
	var sawpit := Buildings.seed_building("sawpit", _open_site("sawpit"))

	Hauling.rebuild_tasks()

	var ids := Hauling.open_task_ids()
	assert_eq(ids.size(), 1)
	var task := Hauling.get_task(ids[0])
	assert_eq(task["good_id"], "timber")
	assert_eq(task["from_id"], hut)
	assert_eq(task["to_id"], sawpit)
	assert_eq(task["purpose"], "input")
	assert_eq(task["priority"], Hauling.PRIORITY_INPUT)
	assert_eq(int(task["qty_remaining"]), 10, "only what the batch needs, not the source's whole stock")


func test_a_no_input_recipe_never_queues_a_production_input_task() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	Buildings.seed_building("woodcutters_hut", _open_site("woodcutters_hut"))   # felling needs no inputs
	Hauling.rebuild_tasks()
	assert_eq(Hauling.open_task_ids().size(), 0, "both are already COMPLETE and stocked; nothing to haul at all")


func test_a_production_building_never_hauls_its_own_partial_stock_to_itself() -> void:
	var sawpit := Buildings.seed_building("sawpit", _open_site("sawpit"))
	Buildings.add_to_inventory(sawpit, "timber", 3)   # short of sawing's 10, and nowhere else has any
	Hauling.rebuild_tasks()
	assert_eq(Hauling.open_task_ids().size(), 0)


func test_input_delivery_outranks_hauling_produced_goods_to_storage() -> void:
	var hut := Buildings.seed_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Buildings.add_to_inventory(hut, "timber", 30)
	Buildings.seed_building("sawpit", _open_site("sawpit"))
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"))

	Hauling.rebuild_tasks()
	var ids := Hauling.open_task_ids()
	assert_eq(ids.size(), 1, "the sawpit's need absorbs the hut's timber before any goes to storage")
	assert_eq(Hauling.get_task(ids[0])["purpose"], "input")


func test_serialize_round_trip() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Hauling.rebuild_tasks()
	var before := Hauling.get_task(Hauling.open_task_ids()[0])

	var saved := Hauling.serialize()
	Hauling.clear()
	assert_eq(Hauling.open_task_ids().size(), 0)

	Hauling.deserialize(saved)
	assert_eq(Hauling.get_task(int(before["id"])), before)
