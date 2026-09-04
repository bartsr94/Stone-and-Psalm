## The liturgical calendar and the day it produces. The worked example in SIMULATION_SPEC.md
## §6.4 — a Cistercian house at the two solstices — is the anchor.
extends GutTest

const CISTERCIAN := Monastic.Order.CISTERCIAN
const CHOIR := Monastic.Class.CHOIR_MONK
const CONVERSUS := Monastic.Class.CONVERSUS
const FAMULUS := Monastic.Class.FAMULUS

const YEAR := 1200


## The nearest day to `near` that is an ordinary working weekday: no feast, not a Sunday, not a
## fast day. The worked example assumes a plain day; Sundays and feasts have their own maths.
func _plain_working_day(year: int, near: int) -> int:
	for offset in range(0, 40):
		for day in [near + offset, near - offset]:
			if day < 5 or day > 360:
				continue
			if Liturgy.rank_for_day(year, day) == "ferial" and not Liturgy.is_fast_day(year, day):
				return day
	return near


var MIDSUMMER: int
var MIDWINTER: int


func before_all() -> void:
	MIDSUMMER = _plain_working_day(YEAR, 172)
	# December is mostly Advent, so "midwinter" for the worked example is the shortest plain
	# working day we can find before Advent starts.
	MIDWINTER = _plain_working_day(YEAR, 325)


func test_fixed_and_moveable_feasts_are_recognised() -> void:
	assert_eq(Liturgy.feast_for_day(YEAR, Computus.month_day_to_day_of_year(12, 25))["name"], "Christmas")
	assert_eq(Liturgy.rank_for_day(YEAR, Computus.month_day_to_day_of_year(8, 15)), "solemnity", "Assumption")

	var easter := Computus.easter_day_of_year(YEAR)
	assert_eq(Liturgy.feast_for_day(YEAR, easter)["name"], "Easter Sunday")
	assert_eq(Liturgy.rank_for_day(YEAR, easter), "solemnity")


func test_sundays_are_simplex_when_no_feast_falls() -> void:
	# Walk a week and find the Sunday.
	var sunday := -1
	for doy in range(40, 48):
		if Liturgy.is_sunday(YEAR, doy):
			sunday = doy
	assert_gt(sunday, 0, "there is a Sunday in any week")
	assert_eq(Liturgy.rank_for_day(YEAR, sunday), "simplex")
	assert_true(Liturgy.is_labour_restricted(YEAR, sunday), "no manual labour on a Sunday")


func test_fridays_and_lent_and_advent_are_fast_days() -> void:
	var friday := -1
	for doy in range(40, 48):
		if Liturgy.weekday(YEAR, doy) == 5:
			friday = doy
	assert_true(Liturgy.is_fast_day(YEAR, friday), "every Friday is a fast day")

	var mid_lent := Computus.easter_day_of_year(YEAR) - 20
	assert_true(Liturgy.is_fast_day(YEAR, mid_lent), "Lent is a fast season")

	assert_true(Liturgy.is_fast_day(YEAR, Liturgy.advent_sunday(YEAR) + 3), "so is Advent")


func test_labour_is_restricted_on_major_feasts() -> void:
	var assumption := Computus.month_day_to_day_of_year(8, 15)
	assert_true(Liturgy.is_labour_restricted(YEAR, assumption), "a solemnity forbids manual labour")
	# A duplex (minor double) does not, unless it also lands on a Sunday.
	var st_nicholas := Computus.month_day_to_day_of_year(12, 6)
	if not Liturgy.is_sunday(YEAR, st_nicholas):
		assert_false(Liturgy.is_labour_restricted(YEAR, st_nicholas), "a simplex feast still allows work")


func test_cistercian_office_durations_come_from_the_order_table() -> void:
	assert_almost_eq(Liturgy.office_duration(CISTERCIAN, "vigils", "ferial"), 75.0, 0.001)
	assert_almost_eq(Liturgy.office_duration(CISTERCIAN, "vigils", "solemnity"), 150.0, 0.001, "x2 on a solemnity")
	assert_almost_eq(Liturgy.office_duration(Monastic.Order.BENEDICTINE, "vigils", "ferial"), 90.0, 0.001)


func test_worked_example_choir_monk_labour_budget() -> void:
	# SIMULATION_SPEC.md §6.4: a Cistercian choir monk, ferial day, ~529 min of manual labour
	# budget in both seasons (the budget is season-independent; only its daylight portion moves).
	var summer := Liturgy.day_plan(CHOIR, CISTERCIAN, YEAR, MIDSUMMER)
	var winter := Liturgy.day_plan(CHOIR, CISTERCIAN, YEAR, MIDWINTER)

	assert_false(summer["labour_restricted"], "midsummer 1200 is a working day")
	assert_between(summer["labour_budget_min"], 480.0, 580.0, "~529 min manual labour budget")
	assert_almost_eq(
		winter["labour_budget_min"], summer["labour_budget_min"], 1.0,
		"the budget does not change with the season"
	)


func test_worked_example_winter_daylight_labour_collapses() -> void:
	var summer := Liturgy.day_plan(CHOIR, CISTERCIAN, YEAR, MIDSUMMER)
	var winter := Liturgy.day_plan(CHOIR, CISTERCIAN, YEAR, MIDWINTER)

	# §6.4: usable outdoor labour falls sharply from summer toward winter as the daylight window
	# shrinks around a fixed set of offices, meals and lectio.
	assert_gt(summer["daylight_labour_min"], 420.0, "a long summer working day outdoors")
	assert_lt(
		winter["daylight_labour_min"], summer["daylight_labour_min"] * 0.7,
		"winter outdoor labour is well down on summer"
	)


func test_unequal_hour_length_in_the_plan_tracks_the_season() -> void:
	# The true solstices, regardless of what feast falls on them — this checks the arithmetic
	# passthrough, not the calendar.
	var summer := Liturgy.day_plan(CHOIR, CISTERCIAN, YEAR, 172)
	var winter := Liturgy.day_plan(CHOIR, CISTERCIAN, YEAR, 355)
	assert_almost_eq(summer["hour_length_min"], 84.0, 2.0)
	assert_almost_eq(winter["hour_length_min"], 36.0, 2.0)


func test_a_conversus_has_far_more_labour_than_a_choir_monk() -> void:
	var monk := Liturgy.day_plan(CHOIR, CISTERCIAN, YEAR, MIDSUMMER)
	var brother := Liturgy.day_plan(CONVERSUS, CISTERCIAN, YEAR, MIDSUMMER)
	assert_gt(
		brother["labour_budget_min"], monk["labour_budget_min"] + 250.0,
		"the lay brother is not in choir all day and does no lectio"
	)


func test_a_conversus_joins_choir_on_a_feast() -> void:
	var assumption := Computus.month_day_to_day_of_year(8, 15)
	var ferial_day := assumption + 3
	var on_feast := Liturgy.day_plan(CONVERSUS, CISTERCIAN, YEAR, assumption)
	var on_ferial := Liturgy.day_plan(CONVERSUS, CISTERCIAN, YEAR, ferial_day)
	# On the solemnity all labour is off anyway, so compare office attendance via the entries.
	var feast_attended := 0
	for entry in on_feast["offices"]:
		if entry["attends"]:
			feast_attended += 1
	var ferial_attended := 0
	for entry in on_ferial["offices"]:
		if entry["attends"]:
			ferial_attended += 1
	assert_eq(feast_attended, 8, "a conversus sings all eight offices on a feast")
	assert_eq(ferial_attended, 0, "and none of them on a working weekday")


func test_famulus_keeps_no_office() -> void:
	var hand := Liturgy.day_plan(FAMULUS, CISTERCIAN, YEAR, MIDSUMMER)
	assert_eq(hand["offices"].size(), 0, "a hired servant has no horarium")
	assert_gt(hand["labour_budget_min"], 600.0, "and the longest working day of anyone")
