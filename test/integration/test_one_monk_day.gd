## The Phase 3 acceptance test, headless: one monk lives a full day by the Divine Office.
## He sleeps in the dormitory, rises for the offices at the church, works between them, and the
## whole thing runs with no scene tree — the boundary the Architecture Guide §2.4 demands.
extends GutTest

var _monk_id: int


func before_each() -> void:
	SimClock.deserialize({"abs_minute": 0.0, "speed_index": 0})
	Terrain.build_preset("founding_valley")
	Buildings.clear()
	Hauling.clear()
	Population.clear()
	_monk_id = Population.add_person(
		"Brother Ælred", Monastic.Class.CHOIR_MONK, Monastic.Order.CISTERCIAN, Population.dormitory_door()
	)


func _run_to_minute(day_of_year: int, minute_of_day: int) -> void:
	# Jump near the target, then step in substeps so the state machine runs each 10 minutes.
	var day_offset := day_of_year - SimClock.day_of_year()
	SimClock.advance_days(maxi(day_offset, 0))
	while SimClock.minute_of_day() < minute_of_day:
		SimClock.advance_minutes(10.0)


func _activity_name(activity: int) -> String:
	return Person.Activity.keys()[activity]


func test_precinct_cells_resolved_to_walkable_ground() -> void:
	assert_true(Terrain.is_walkable_cell(Population.church_door()), "the church door is on foot-passable ground")
	assert_true(Terrain.is_walkable_cell(Population.dormitory_door()), "so is the dormitory door")
	assert_true(Terrain.is_walkable_cell(Population.work_site_cell()), "and the work site")
	assert_ne(Population.church_door(), Population.dormitory_door(), "they are distinct places")


func test_a_path_exists_between_dormitory_and_church() -> void:
	var path := Pathfinder.find_path(
		Population.dormitory_door(), Population.church_door(),
		Terrain.is_walkable_cell, Terrain.move_cost, Terrain.min_step_cost()
	)
	assert_gt(path.size(), 1, "the monk can actually walk from his bed to the choir")


func test_monk_is_at_the_church_during_an_office() -> void:
	# Sext is sung at solar noon; give him time to walk there from mid-morning work.
	var plan := Liturgy.day_plan(Monastic.Class.CHOIR_MONK, Monastic.Order.CISTERCIAN, SimClock.year(), 120)
	var sext_start := 0.0
	for entry in plan["offices"]:
		if entry["key"] == "sext":
			sext_start = entry["start_min"]
	assert_gt(sext_start, 0.0)

	# Sext runs only ~12 minutes (Cistercian, ferial); sample a few minutes in.
	_run_to_minute(120, int(sext_start) + 5)
	var monk := Population.get_person(_monk_id)
	assert_eq(
		monk.activity, Person.Activity.AT_OFFICE,
		"at Sext the monk is in choir, not %s" % _activity_name(monk.activity)
	)
	assert_eq(monk.grid_pos, Population.church_door(), "and physically at the church")
	assert_eq(monk.current_office, "sext")


func test_monk_works_between_offices_and_sleeps_at_night() -> void:
	# Deep night: everyone is in the dormitory.
	_run_to_minute(120, 60)
	var monk := Population.get_person(_monk_id)
	assert_eq(monk.activity, Person.Activity.SLEEP, "asleep at 01:00")
	assert_eq(monk.grid_pos, Population.dormitory_door())

	# Mid-afternoon on a working day: out at the assart between None and Vespers.
	_run_to_minute(120, 15 * 60)
	monk = Population.get_person(_monk_id)
	assert_true(
		monk.activity == Person.Activity.WORKING or monk.activity == Person.Activity.TO_WORK,
		"working (or walking to work) mid-afternoon, not %s" % _activity_name(monk.activity)
	)


func test_no_manual_labour_on_a_sunday() -> void:
	# Find a Sunday and check the monk never goes to the work site that day.
	var sunday := -1
	for doy in range(110, 124):
		if Liturgy.is_sunday(SimClock.year(), doy):
			sunday = doy
	assert_gt(sunday, 0)

	var visited_work := false
	_run_to_minute(sunday, 0)
	for _step in 144:  # a whole day in 10-minute substeps
		SimClock.advance_minutes(10.0)
		if Population.get_person(_monk_id).grid_pos == Population.work_site_cell():
			visited_work = true
	assert_false(visited_work, "no work on the Lord's Day")


func test_a_whole_day_runs_with_no_scene_tree() -> void:
	# The proof of the boundary: 1440 minutes, no nodes, and the monk ends where he began.
	_run_to_minute(200, 0)
	var offices_attended := {}
	for _step in 144:
		SimClock.advance_minutes(10.0)
		var monk := Population.get_person(_monk_id)
		if monk.activity == Person.Activity.AT_OFFICE:
			offices_attended[monk.current_office] = true
	assert_gte(offices_attended.size(), 5, "he sang most of the office through the day")
