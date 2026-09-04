## Phase 4 exit criteria, run headlessly: conversi haul materials from a stocked store and raise
## a building; a mortar building stalls in a hard frost and resumes once it passes.
## `SIMULATION_SPEC.md` §10, §11; roadmap Phase 4.
##
## Advances time one substep at a time (`SimClock.advance_minutes(10.0)`), not via
## `SimClock.advance_days` — that call's doc comment promises `day_passed` fires for every day,
## but its `substep_passed` count is capped per call (`MAX_SUBSTEPS_PER_ADVANCE`, sim_clock.gd),
## which is the right trade-off for a coarse multi-year soak and the wrong one for a test that
## needs Population's per-substep decisions to actually run across every simulated day.
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


## Forces a specific, known weather draw for "today" — see test_weather.gd for the same pattern.
## Called once per simulated day so the daily automatic re-roll (SimClock's day_passed) never
## sneaks an uncontrolled value into a frost/no-frost assertion.
func _force_weather(scripted: Array, day: int) -> void:
	Weather.set_dice(ScriptedDice.new(scripted))
	Weather.roll_day(day)


func _advance_one_day() -> void:
	for _i in SUBSTEPS_PER_DAY:
		SimClock.advance_minutes(10.0)


func test_conversi_haul_materials_and_raise_a_granary() -> void:
	var stockpile := Buildings.seed_building(
		"open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 200, "nails": 40}
	)
	var granary := Buildings.place_building("granary", _open_site("granary"))
	assert_eq(Buildings.get_building(granary).construction_state, Building.State.PLANNED)

	var stockpile_door: Vector2i = Buildings.door_cell(stockpile)
	Population.add_person("Brother Osric", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, stockpile_door)
	Population.add_person("Brother Ediva", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, stockpile_door)

	SimClock.deserialize({"abs_minute": (152 - 75) * 1440.0, "speed_index": 0})   # a mild summer day

	var completed := false
	for _day in 60:
		_force_weather([0.5, 0.5, 0.99], SimClock.day_of_year())
		_advance_one_day()
		if Buildings.get_building(granary).construction_state == Building.State.COMPLETE:
			completed = true
			break

	assert_true(completed, "two conversi hauling and building should raise a granary within sixty days")
	assert_true(Buildings.is_materials_complete(granary))


func test_frost_halts_a_mortar_building_and_it_resumes_once_it_passes() -> void:
	var undercroft := Buildings.place_building("cellarers_undercroft", _open_site("cellarers_undercroft"))
	Buildings.deliver_material(undercroft, "building_stone", 200)
	Buildings.deliver_material(undercroft, "mortar", 100)
	Buildings.deliver_material(undercroft, "sawn_timber", 20)
	assert_eq(Buildings.get_building(undercroft).construction_state, Building.State.UNDER_CONSTRUCTION)

	var site_door: Vector2i = Buildings.door_cell(undercroft)
	Population.add_person("Brother Osric", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, site_door)

	# day_of_year 20 is before time.start_day_of_year (75), so it falls in the *next* wrap of the
	# year, not a negative offset — abs_minute must stay non-negative or SimClock's minute-of-day
	# arithmetic (`%` on a negative dividend) comes out wrong.
	SimClock.deserialize({"abs_minute": ((20 - 75 + 365) % 365) * 1440.0, "speed_index": 0})   # deep winter

	for _day in 10:
		_force_weather([0.0, 0.5, 0.99], 20)   # hard frost, every day
		_advance_one_day()

	assert_eq(Buildings.get_building(undercroft).build_progress, 0.0, "no mortar work happens in a hard frost")

	for _day in 10:
		_force_weather([0.5, 0.5, 0.99], 152)   # a mild day, every day from here
		_advance_one_day()

	assert_gt(Buildings.get_building(undercroft).build_progress, 0.0, "work resumes once the frost gate lifts")
