## Task assignment policy: haul work outranks construction labour, and a frost-gated site is
## skipped rather than sending someone to stand at a stalled wall. `SIMULATION_SPEC.md` §6.5.
extends GutTest


func before_each() -> void:
	Terrain.build_preset("founding_valley")
	Buildings.clear()
	Hauling.clear()
	Weather.set_dice(Dice.new(1))
	Weather.roll_day(152)   # a plain summer day; the frost test overrides this


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


func _person_at(cell: Vector2i) -> Person:
	var p := Person.new()
	p.id = 1
	p.grid_pos = cell
	return p


func test_no_work_available_returns_empty() -> void:
	assert_true(Labour.request_task(_person_at(Vector2i(100, 100))).is_empty())


func test_a_haul_task_outranks_construction_labour() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	Hauling.rebuild_tasks()

	var lodge_site := _open_site("masons_lodge")
	var lodge := Buildings.place_building("masons_lodge", lodge_site)
	Buildings.deliver_material(lodge, "sawn_timber", 40)
	Buildings.deliver_material(lodge, "nails", 8)
	assert_eq(Buildings.get_building(lodge).construction_state, Building.State.UNDER_CONSTRUCTION)

	var task := Labour.request_task(_person_at(lodge_site))
	assert_eq(task["kind"], "haul", "haul delivery (priority 70) outranks construction labour (40)")


func test_falls_back_to_construction_labour_with_no_haul_work() -> void:
	var site := _open_site("masons_lodge")
	var lodge := Buildings.place_building("masons_lodge", site)
	Buildings.deliver_material(lodge, "sawn_timber", 40)
	Buildings.deliver_material(lodge, "nails", 8)

	assert_eq(Labour.request_task(_person_at(site)), {"kind": "build", "building_id": lodge})


func test_a_frost_gated_site_is_skipped_for_construction_labour() -> void:
	var site := _open_site("cellarers_undercroft")
	var undercroft := Buildings.place_building("cellarers_undercroft", site)
	Buildings.deliver_material(undercroft, "building_stone", 200)
	Buildings.deliver_material(undercroft, "mortar", 100)
	Buildings.deliver_material(undercroft, "sawn_timber", 20)
	assert_eq(Buildings.get_building(undercroft).construction_state, Building.State.UNDER_CONSTRUCTION)

	Weather.set_dice(ScriptedDice.new([0.0, 0.5, 0.99]))
	Weather.roll_day(20)

	assert_true(Labour.request_task(_person_at(site)).is_empty(), "frost-gated, and nothing else queued")


func test_an_assigned_worker_always_returns_to_their_own_site_even_with_haul_work_open() -> void:
	Buildings.seed_building("open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 100})
	var lodge_site := _open_site("masons_lodge")
	var lodge := Buildings.place_building("masons_lodge", lodge_site)
	Buildings.deliver_material(lodge, "sawn_timber", 40)
	Buildings.deliver_material(lodge, "nails", 8)
	Hauling.rebuild_tasks()   # a delivery task now exists elsewhere

	Buildings.assign_worker(lodge, 1)
	var task := Labour.request_task(_person_at(lodge_site))
	assert_eq(task, {"kind": "build", "building_id": lodge}, "assigned outranks the queue, haul work notwithstanding")


func test_an_assigned_worker_falls_back_to_the_pool_while_their_site_awaits_materials() -> void:
	var hut_site := _open_site("woodcutters_hut")
	var hut := Buildings.place_building("woodcutters_hut", hut_site)   # PLANNED, no materials yet
	Buildings.assign_worker(hut, 1)   # refused — not yet UNDER_CONSTRUCTION — the crew is empty

	assert_eq(Buildings.building_for_worker(1), -1)
	assert_true(Labour.request_task(_person_at(hut_site)).is_empty(), "nothing else queued either")


func test_the_nearest_construction_site_wins_when_several_are_open() -> void:
	var near_site := _open_site("woodcutters_hut")
	var near := Buildings.place_building("woodcutters_hut", near_site)
	Buildings.deliver_material(near, "sawn_timber", 20)
	Buildings.deliver_material(near, "nails", 4)

	# Well clear of the near site, so this cannot resolve next door to it by coincidence of scan order.
	var far_site := _site_near("masons_lodge", near_site + Vector2i(40, 0))
	var far := Buildings.place_building("masons_lodge", far_site)
	Buildings.deliver_material(far, "sawn_timber", 40)
	Buildings.deliver_material(far, "nails", 8)

	var task := Labour.request_task(_person_at(near_site))
	assert_eq(task, {"kind": "build", "building_id": near})
