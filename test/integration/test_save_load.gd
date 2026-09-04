## The save/load acceptance test. SIMULATION_SPEC.md §19: save → load → run N ticks must land
## on the same state as running N ticks straight through.
extends GutTest


func before_each() -> void:
	SimClock.deserialize({"abs_minute": (100 - 75) * 1440.0, "speed_index": 0})
	Weather.set_dice(Dice.new(90210))
	Weather.roll_day(SimClock.day_of_year())
	Terrain.build_preset("founding_valley")
	Buildings.clear()
	Hauling.clear()
	Population.clear()
	Population.found_demo_house()
	# Walk the monk a little way into his day so the saved state is non-trivial.
	for _i in 40:
		SimClock.advance_minutes(10.0)


func _advance(substeps: int) -> void:
	for _i in substeps:
		SimClock.advance_minutes(10.0)


func test_capture_then_restore_is_a_no_op() -> void:
	var before := SaveManager.state_hash()
	var snapshot := SaveManager.capture()
	SaveManager.restore(snapshot)
	assert_eq(SaveManager.state_hash(), before, "restoring the state you just captured changes nothing")


func test_load_then_run_equals_run_straight_through() -> void:
	var snapshot := SaveManager.capture()

	_advance(120)  # 20 sim-hours
	var straight_through := SaveManager.state_hash()

	SaveManager.restore(snapshot)
	assert_ne(SaveManager.state_hash(), straight_through, "the restore rewound us")

	_advance(120)
	assert_eq(
		SaveManager.state_hash(), straight_through,
		"running forward from a restored save reproduces the un-saved run exactly"
	)


func test_slot_round_trip_through_disk() -> void:
	var live := SaveManager.state_hash()
	assert_eq(SaveManager.save_to_slot("test_slot"), OK)

	_advance(80)
	assert_ne(SaveManager.state_hash(), live, "state moved on")

	assert_true(SaveManager.load_from_slot("test_slot"))
	assert_eq(SaveManager.state_hash(), live, "the file restored the exact state")


func test_a_future_schema_is_refused() -> void:
	var snapshot := SaveManager.capture()
	snapshot["schema_version"] = SaveManager.SCHEMA_VERSION + 5
	assert_false(SaveManager.restore(snapshot), "a newer save is not half-applied")
	assert_push_error("SaveManager: save is schema v%d" % (SaveManager.SCHEMA_VERSION + 5))


func test_the_monk_survives_the_round_trip() -> void:
	var ids := Population.person_ids()
	assert_eq(ids.size(), 1)
	var before := Population.get_person(ids[0])
	var name := before.given_name
	var pos := before.grid_pos

	var snapshot := SaveManager.capture()
	_advance(200)
	SaveManager.restore(snapshot)

	var after := Population.get_person(Population.person_ids()[0])
	assert_eq(after.given_name, name, "same brother")
	assert_eq(after.grid_pos, pos, "back where he was")
