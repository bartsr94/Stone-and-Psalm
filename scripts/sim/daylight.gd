## Where the sun is, and how long it is up, on a given day at a given latitude.
##
## Pure static maths over numbers. No state, no scene tree, no RNG — the same day always gives
## the same sun. `SIMULATION_SPEC.md` §2.2.
##
## This is the model the whole game rests on: at 54°N the day runs about 16 h 53 m at
## midsummer and 7 h 06 m at midwinter, and the eight offices are anchored to twelfths of
## whatever daylight there is (`scripts/sim/unequal_hours.gd`, Phase 3). Everything about the
## winter economy is downstream of the `daylight_minutes` curve.
##
## The model deliberately ignores the equation of time, atmospheric refraction and the
## observer's altitude: solar noon is fixed at `sky.solar_noon_minute` and the sun is treated
## as a point on the horizon at sunrise. That is within a couple of minutes across the year,
## which is well inside anything the game can show.
class_name Daylight
extends RefCounted

const _MINUTES_PER_DAY := 1440.0
const _DEGREES_PER_HOUR := 15.0


## The sun's declination in degrees for a day of year (1–365): +23.44° at midsummer, −23.44°
## at midwinter, zero at the equinoxes. Day 81 (≈21 March) is the spring equinox in this model.
static func declination_deg(day_of_year: int, axial_tilt_deg: float) -> float:
	return axial_tilt_deg * sin(deg_to_rad(360.0 * float(day_of_year - 81) / 365.0))


## The half-day hour angle in degrees — how far the sun travels from the horizon to solar noon.
## Clamped to a full day / full night at latitudes and seasons that reach the polar circles;
## 54°N never does, but the clamp keeps the function total for any latitude.
static func half_day_arc_deg(day_of_year: int, latitude_deg: float, axial_tilt_deg: float) -> float:
	var declination := deg_to_rad(declination_deg(day_of_year, axial_tilt_deg))
	var cosine := -tan(deg_to_rad(latitude_deg)) * tan(declination)
	return rad_to_deg(acos(clampf(cosine, -1.0, 1.0)))


## Minutes of daylight on a day of year.
static func daylight_minutes(day_of_year: int, latitude_deg: float, axial_tilt_deg: float) -> float:
	var daylight_hours := 2.0 * half_day_arc_deg(day_of_year, latitude_deg, axial_tilt_deg) / _DEGREES_PER_HOUR
	return daylight_hours * 60.0


## Minute of day the sun rises, measured from midnight. Solar noon is fixed, so sunrise and
## sunset are symmetric about `solar_noon_minute`.
static func sunrise_minute(
	day_of_year: int, latitude_deg: float, axial_tilt_deg: float, solar_noon_minute: float
) -> float:
	return solar_noon_minute - daylight_minutes(day_of_year, latitude_deg, axial_tilt_deg) * 0.5


static func sunset_minute(
	day_of_year: int, latitude_deg: float, axial_tilt_deg: float, solar_noon_minute: float
) -> float:
	return solar_noon_minute + daylight_minutes(day_of_year, latitude_deg, axial_tilt_deg) * 0.5


## True when the sun is above the horizon at this minute of day.
static func is_daytime(
	day_of_year: int, minute_of_day: float, latitude_deg: float,
	axial_tilt_deg: float, solar_noon_minute: float
) -> bool:
	return (
		minute_of_day >= sunrise_minute(day_of_year, latitude_deg, axial_tilt_deg, solar_noon_minute)
		and minute_of_day <= sunset_minute(day_of_year, latitude_deg, axial_tilt_deg, solar_noon_minute)
	)


## The sun's altitude above the horizon in degrees at a given minute of day. Negative at night.
## Peaks around 59° at midsummer noon and around 12° at midwinter noon at 54°N.
static func solar_altitude_deg(
	day_of_year: int, minute_of_day: float, latitude_deg: float,
	axial_tilt_deg: float, solar_noon_minute: float
) -> float:
	var latitude := deg_to_rad(latitude_deg)
	var declination := deg_to_rad(declination_deg(day_of_year, axial_tilt_deg))
	var hour_angle := _hour_angle_rad(minute_of_day, solar_noon_minute)
	var sin_altitude := (
		sin(latitude) * sin(declination)
		+ cos(latitude) * cos(declination) * cos(hour_angle)
	)
	return rad_to_deg(asin(clampf(sin_altitude, -1.0, 1.0)))


## The sun's compass bearing in degrees, 0° = north, 90° = east, 180° = south, 270° = west.
## Morning bearings are east of south, afternoon bearings west of south.
static func solar_azimuth_deg(
	day_of_year: int, minute_of_day: float, latitude_deg: float,
	axial_tilt_deg: float, solar_noon_minute: float
) -> float:
	var latitude := deg_to_rad(latitude_deg)
	var declination := deg_to_rad(declination_deg(day_of_year, axial_tilt_deg))
	var hour_angle := _hour_angle_rad(minute_of_day, solar_noon_minute)
	var altitude := deg_to_rad(
		solar_altitude_deg(day_of_year, minute_of_day, latitude_deg, axial_tilt_deg, solar_noon_minute)
	)

	var cos_azimuth := 1.0
	var denominator := cos(latitude) * cos(altitude)
	if absf(denominator) > 0.000001:
		cos_azimuth = (sin(declination) - sin(latitude) * sin(altitude)) / denominator
	# This formula measures the bearing from due north, so it is correct for the morning half
	# (0°–180°) and acos cannot tell morning from afternoon — the hour angle does that.
	var bearing_from_north := rad_to_deg(acos(clampf(cos_azimuth, -1.0, 1.0)))

	if hour_angle > 0.0:
		return 360.0 - bearing_from_north
	return bearing_from_north


## Hour angle in radians: 0 at solar noon, negative before, positive after, ±180° at midnight.
static func _hour_angle_rad(minute_of_day: float, solar_noon_minute: float) -> float:
	var minutes_from_noon := minute_of_day - solar_noon_minute
	return deg_to_rad(minutes_from_noon / _MINUTES_PER_DAY * 360.0)
