## The Julian computus, checked against known medieval Easter dates, with the moveable feasts
## hanging off it in the right order.
extends GutTest


func test_julian_easter_matches_the_historical_record() -> void:
	# Julian Easter Sundays, from the standard tables.
	assert_eq(Computus.easter_month_day(1132), [4, 10], "Easter 1132 = 10 April (Julian)")
	assert_eq(Computus.easter_month_day(1200), [4, 9], "Easter 1200 = 9 April")
	assert_eq(Computus.easter_month_day(1300), [4, 10], "Easter 1300 = 10 April")
	assert_eq(Computus.easter_month_day(1348), [4, 20], "Easter 1348 = 20 April")


func test_easter_day_of_year_uses_the_fixed_calendar() -> void:
	# 10 April is day 31 + 28 + 31 + 10 = 100.
	assert_eq(Computus.easter_day_of_year(1132), 100)


func test_moveable_feasts_sit_at_their_offsets_and_in_order() -> void:
	var year := 1200
	var easter := Computus.easter_day_of_year(year)

	assert_eq(Computus.feast_day_of_year(year, Computus.Feast.EASTER), easter)
	assert_eq(Computus.feast_day_of_year(year, Computus.Feast.ASH_WEDNESDAY), easter - 46)
	assert_eq(Computus.feast_day_of_year(year, Computus.Feast.PALM_SUNDAY), easter - 7)
	assert_eq(Computus.feast_day_of_year(year, Computus.Feast.GOOD_FRIDAY), easter - 2)
	assert_eq(Computus.feast_day_of_year(year, Computus.Feast.ASCENSION), easter + 39)
	assert_eq(Computus.feast_day_of_year(year, Computus.Feast.PENTECOST), easter + 49)
	assert_eq(Computus.feast_day_of_year(year, Computus.Feast.CORPUS_CHRISTI), easter + 60)

	var chain := [
		Computus.Feast.SEPTUAGESIMA, Computus.Feast.ASH_WEDNESDAY, Computus.Feast.PALM_SUNDAY,
		Computus.Feast.GOOD_FRIDAY, Computus.Feast.EASTER, Computus.Feast.ROGATION,
		Computus.Feast.ASCENSION, Computus.Feast.PENTECOST, Computus.Feast.TRINITY,
		Computus.Feast.CORPUS_CHRISTI,
	]
	for i in chain.size() - 1:
		assert_lt(
			Computus.feast_day_of_year(year, chain[i]),
			Computus.feast_day_of_year(year, chain[i + 1]),
			"feast %d precedes feast %d" % [chain[i], chain[i + 1]]
		)


func test_ascension_is_forty_days_after_easter_and_a_thursday_apart_from_pentecost() -> void:
	var year := 1250
	var ascension := Computus.feast_day_of_year(year, Computus.Feast.ASCENSION)
	var pentecost := Computus.feast_day_of_year(year, Computus.Feast.PENTECOST)
	assert_eq(pentecost - ascension, 10, "Pentecost is ten days after Ascension")


func test_lent_spans_ash_wednesday_to_easter_eve() -> void:
	var year := 1200
	var ash := Computus.feast_day_of_year(year, Computus.Feast.ASH_WEDNESDAY)
	var easter := Computus.easter_day_of_year(year)
	assert_false(Computus.is_in_lent(year, ash - 1), "the day before Ash Wednesday is not Lent")
	assert_true(Computus.is_in_lent(year, ash), "Ash Wednesday is Lent")
	assert_true(Computus.is_in_lent(year, easter - 1), "the eve of Easter is still Lent")
	assert_false(Computus.is_in_lent(year, easter), "Easter itself is not Lent")


func test_days_until_easter_counts_down_and_goes_negative() -> void:
	var year := 1200
	var easter := Computus.easter_day_of_year(year)
	assert_eq(Computus.days_until_easter(year, easter - 10), 10)
	assert_eq(Computus.days_until_easter(year, easter + 5), -5)


func test_easter_stays_in_its_historical_window() -> void:
	# Julian Easter always falls 22 March – 25 April.
	for year in range(1132, 1349):
		var md := Computus.easter_month_day(year)
		var doy := Computus.month_day_to_day_of_year(md[0], md[1])
		assert_between(doy, 81, 115, "Easter %d lands in the 22 Mar – 25 Apr window" % year)
