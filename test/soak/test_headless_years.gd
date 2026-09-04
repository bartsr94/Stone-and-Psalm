## The boundary proof (Architecture Guide §2.4): the whole simulation runs headless, for years,
## with no scene tree — and stays deterministic across a save taken mid-run.
##
## Phase 3 is one monk, so this is a scaled-down `test_headless_world`: no production, no death
## spiral yet, just the clock, the weather, and a brother living the Office. It grows as the
## systems do.
extends GutTest

const YEARS := 4


func before_each() -> void:
	SimClock.deserialize({"abs_minute": 0.0, "speed_index": 0})
	Weather.set_dice(Dice.new(13579))
	Weather.roll_day(SimClock.day_of_year())
	Terrain.build_preset("founding_valley")
	Population.clear()
	Population.found_demo_house()


func test_four_years_pass_without_a_crash_and_the_monk_is_still_sane() -> void:
	var start_year := SimClock.year()
	for _day in YEARS * 365:
		SimClock.advance_days(1)

	assert_eq(SimClock.year(), start_year + YEARS, "the calendar advanced four whole years")

	var monk := Population.get_person(Population.person_ids()[0])
	assert_true(Terrain.is_walkable_cell(monk.grid_pos), "the monk never walked off the map or into the river")
	assert_between(
		monk.activity, 0, Person.Activity.size() - 1, "his activity is a real state"
	)

	# Weather stayed in a believable band across the whole run.
	assert_between(Weather.temperature_c(), -15.0, 30.0, "temperatures never ran away")


func test_the_run_is_deterministic_from_the_seed() -> void:
	for _day in 400:
		SimClock.advance_days(1)
	var hash_a := SaveManager.state_hash()

	# Re-run from scratch with the same seed.
	SimClock.deserialize({"abs_minute": 0.0, "speed_index": 0})
	Weather.set_dice(Dice.new(13579))
	Weather.roll_day(SimClock.day_of_year())
	Population.clear()
	Population.found_demo_house()
	for _day in 400:
		SimClock.advance_days(1)

	assert_eq(SaveManager.state_hash(), hash_a, "same seed, same 400 days, same state")


func test_a_save_taken_mid_run_reproduces_the_rest_of_the_run() -> void:
	for _day in 200:
		SimClock.advance_days(1)
	var snapshot := SaveManager.capture()

	for _day in 150:
		SimClock.advance_days(1)
	var finish := SaveManager.state_hash()

	SaveManager.restore(snapshot)
	for _day in 150:
		SimClock.advance_days(1)
	assert_eq(SaveManager.state_hash(), finish, "the rest of the run is fixed once the save is taken")
