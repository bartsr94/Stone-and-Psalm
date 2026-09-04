## Medieval unequal hours: daylight split into twelve regardless of season, the night into four
## watches. `SIMULATION_SPEC.md` §2.3, `HISTORICAL_REFERENCE.md` §4.3 — this is the engine of
## the whole simulation. A day hour runs ~84 min at midsummer and ~36 at midwinter; the eight
## offices are pinned to it, so winter loses daylight and keeps every interruption.
##
## Pure static maths. It takes the daylight figures from `Daylight` (minutes of daylight,
## sunrise, sunset) rather than recomputing them, so the two never drift.
##
## The seven day offices sit on the daylight scaffold at their canonical "hora N" positions.
## **Vigils is not here** — it is timed to end near dawn, which depends on how long the office
## runs, so `horarium.gd` places it backward from sunrise with `vigils_start`.
class_name UnequalHours
extends RefCounted

const MINUTES_PER_DAY := 1440.0
const DAY_HOURS := 12
const NIGHT_WATCHES := 4

## The seven daytime offices, in the order they occur. Vigils (the night office) is handled
## separately; see the class doc.
enum Office { LAUDS, PRIME, TERCE, SEXT, NONE, VESPERS, COMPLINE }

## Which "hora" each office is anchored to, counting unequal hours from sunrise. Lauds is first
## light (sunrise); Compline is nightfall (sunset). `HISTORICAL_REFERENCE.md` §4.2.
const _OFFICE_HORA := {
	Office.LAUDS: 0.0,
	Office.PRIME: 1.0,
	Office.TERCE: 3.0,
	Office.SEXT: 6.0,
	Office.NONE: 9.0,
	Office.VESPERS: 11.0,
	Office.COMPLINE: 12.0,
}


## The length of one unequal daylight hour, in minutes.
static func hour_length(daylight_minutes: float) -> float:
	return daylight_minutes / float(DAY_HOURS)


## The length of one night watch (vigilia), in minutes.
static func watch_length(daylight_minutes: float) -> float:
	return (MINUTES_PER_DAY - daylight_minutes) / float(NIGHT_WATCHES)


## The minute of day the n-th unequal daylight hour begins (n = 1…12). n = 1 is sunrise; the
## start of the 7th hour is solar noon.
static func hour_start(sunrise_minute: float, daylight_minutes: float, n: int) -> float:
	return sunrise_minute + float(n - 1) * hour_length(daylight_minutes)


## The minute of day the n-th night watch begins (n = 1…4). n = 1 is sunset. Watches after the
## fourth wrap past midnight; the value can exceed 1440 and the caller should take it mod 1440.
static func watch_start(sunset_minute: float, daylight_minutes: float, n: int) -> float:
	return sunset_minute + float(n - 1) * watch_length(daylight_minutes)


## The canonical minute of day a daytime office begins, on the unequal-hour scaffold.
static func canonical_minute(
	office: Office, sunrise_minute: float, daylight_minutes: float
) -> float:
	var hora: float = _OFFICE_HORA[office]
	return sunrise_minute + hora * hour_length(daylight_minutes)


## The minute Vigils begins, timed to finish at first light: `sunrise - block`, where `block`
## is the office plus the interval before Lauds (an order-specific figure `horarium.gd` knows).
## May be negative, meaning "yesterday evening"; the caller takes it mod 1440.
static func vigils_start(sunrise_minute: float, vigils_block_minutes: float) -> float:
	return sunrise_minute - vigils_block_minutes


## The seven daytime office minutes for a day, as a Dictionary keyed by `Office`. Convenience
## for `horarium.gd`, which then subtracts durations and the night office.
static func day_office_minutes(sunrise_minute: float, daylight_minutes: float) -> Dictionary:
	var out := {}
	for office in _OFFICE_HORA:
		out[office] = canonical_minute(office, sunrise_minute, daylight_minutes)
	return out
