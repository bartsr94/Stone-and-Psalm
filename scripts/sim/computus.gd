## The computus: Easter, and the moveable feasts that hang off it. `SIMULATION_SPEC.md` §2.4.
##
## The game runs 1132–1348, four centuries before the Gregorian reform, so this is the **Julian**
## computus — the method a medieval house actually used (Meeus's Julian algorithm). Leap days
## are ignored to match the rest of the calendar, so a date is turned into a day of year with
## the fixed 365-day month table.
##
## Pure static maths. `year → Easter → every moveable feast` with no state and no RNG.
class_name Computus
extends RefCounted

## Day of year (non-leap) each month begins on: Jan = 1, Feb = 32, … Dec = 335.
const _MONTH_FIRST_DAY := [1, 32, 60, 91, 121, 152, 182, 213, 244, 274, 305, 335]

## Moveable feasts, as day offsets from Easter Sunday. `HISTORICAL_REFERENCE.md` §4, and the
## fast seasons in `SIMULATION_SPEC.md` §2.4.
enum Feast {
	SEPTUAGESIMA,   ## -63: the pre-Lent shift in the liturgy
	ASH_WEDNESDAY,  ## -46: Lent begins
	PALM_SUNDAY,    ## -7
	MAUNDY_THURSDAY,## -3
	GOOD_FRIDAY,    ## -2
	EASTER,         ## 0
	ROGATION,       ## +35: Rogation Monday
	ASCENSION,      ## +39: the Thursday
	PENTECOST,      ## +49: Whitsun
	TRINITY,        ## +56
	CORPUS_CHRISTI, ## +60: Thursday after Trinity
}

const _FEAST_OFFSET := {
	Feast.SEPTUAGESIMA: -63,
	Feast.ASH_WEDNESDAY: -46,
	Feast.PALM_SUNDAY: -7,
	Feast.MAUNDY_THURSDAY: -3,
	Feast.GOOD_FRIDAY: -2,
	Feast.EASTER: 0,
	Feast.ROGATION: 35,
	Feast.ASCENSION: 39,
	Feast.PENTECOST: 49,
	Feast.TRINITY: 56,
	Feast.CORPUS_CHRISTI: 60,
}


## Julian Easter Sunday for a year, as [month, day] (month 3 = March, 4 = April).
static func easter_month_day(year: int) -> Array:
	var a := year % 4
	var b := year % 7
	var c := year % 19
	var d := (19 * c + 15) % 30
	var e := (2 * a + 4 * b - d + 34) % 7
	@warning_ignore("integer_division")
	var month := (d + e + 114) / 31
	var day := (d + e + 114) % 31 + 1
	return [month, day]


## Julian Easter Sunday as a day of year (1–365) in the game's fixed 365-day calendar.
static func easter_day_of_year(year: int) -> int:
	var month_day := easter_month_day(year)
	return month_day_to_day_of_year(month_day[0], month_day[1])


## The day of year of a moveable feast. Values are clamped into 1…365; feasts never leave the
## year in this date range, but Septuagesima in a very early Easter sits in late January and the
## clamp keeps callers safe.
static func feast_day_of_year(year: int, feast: Feast) -> int:
	return clampi(easter_day_of_year(year) + int(_FEAST_OFFSET[feast]), 1, 365)


## True if `day_of_year` falls in Lent — Ash Wednesday through the day before Easter.
static func is_in_lent(year: int, day_of_year: int) -> bool:
	var ash := feast_day_of_year(year, Feast.ASH_WEDNESDAY)
	var easter := easter_day_of_year(year)
	return day_of_year >= ash and day_of_year < easter


## The number of days from `day_of_year` until Easter (negative once Easter has passed). Lets
## `horarium.gd` lengthen lectio through Lent without another Easter computation.
static func days_until_easter(year: int, day_of_year: int) -> int:
	return easter_day_of_year(year) - day_of_year


## Turns a Julian month and day into a day of year in the fixed 365-day calendar.
## (Advent, which needs a weekday, is `Liturgy`'s job — it has the clock.)
static func month_day_to_day_of_year(month: int, day: int) -> int:
	return _MONTH_FIRST_DAY[month - 1] + day - 1
