## Phase 5.1 exit criteria, run headlessly: a conversus raises a woodcutters' hut, is pinned to
## its crew once it is complete, and fells timber that a second conversus then hauls out to
## storage — the whole build → produce → haul-out loop with no code path specific to this chain
## (`Hauling.rebuild_tasks`'s "haul produced goods to storage" scan already covers it).
## `SIMULATION_SPEC.md` §9, §10; roadmap 5.1.
extends GutTest

const SUBSTEPS_PER_DAY := 144   ## 1440 minutes / SimClock.MINUTES_PER_SUBSTEP


func before_each() -> void:
	Terrain.build_preset("founding_valley")
	Buildings.clear()
	Hauling.clear()
	Population.clear()


func _open_site(type_id: String, target: Vector2i = Vector2i(100, 100), max_radius: int = 60) -> Vector2i:
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


func _force_weather(scripted: Array, day: int) -> void:
	Weather.set_dice(ScriptedDice.new(scripted))
	Weather.roll_day(day)


func _advance_one_day() -> void:
	for _i in SUBSTEPS_PER_DAY:
		SimClock.advance_minutes(10.0)


func test_a_hut_is_raised_then_its_crew_fells_timber_that_gets_hauled_to_storage() -> void:
	var stockpile := Buildings.seed_building(
		"open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 20, "nails": 4}
	)
	var hut := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	assert_eq(Buildings.get_building(hut).construction_state, Building.State.PLANNED)

	var stockpile_door: Vector2i = Buildings.door_cell(stockpile)
	Population.add_person("Brother Osric", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, stockpile_door)
	var faller := Population.add_person(
		"Brother Ediva", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, stockpile_door
	)

	SimClock.deserialize({"abs_minute": (152 - 75) * 1440.0, "speed_index": 0})   # a mild summer day

	var raised := false
	for _day in 30:
		_force_weather([0.5, 0.5, 0.99], SimClock.day_of_year())
		_advance_one_day()
		if Buildings.get_building(hut).construction_state == Building.State.COMPLETE:
			raised = true
			break
	assert_true(raised, "two conversi hauling and building should raise the hut within thirty days")

	# Pin the crew explicitly (roadmap 4.9/5.1) rather than relying on the unassigned pool
	# fallback — this is the path a player actually takes from the crews panel.
	assert_true(Buildings.assign_worker(hut, faller))

	var timber_ever_produced := false
	var timber_ever_stored := false
	for _day in 30:
		_force_weather([0.5, 0.5, 0.99], SimClock.day_of_year())
		_advance_one_day()
		if Buildings.inventory_of(hut, "timber") > 0:
			timber_ever_produced = true
		if Buildings.inventory_of(stockpile, "timber") > 0:
			timber_ever_stored = true
			break

	assert_true(timber_ever_produced, "the crew should have felled at least one batch of timber")
	assert_true(timber_ever_stored, "surplus timber at the hut should get hauled out to the stockpile")
	assert_eq(Buildings.building_for_worker(faller), hut, "the crew stays pinned across batches")
	# Osric, never pinned, is free to do whatever the pool sends him — no assertion on his state;
	# this only pins down the assigned worker's behaviour.
