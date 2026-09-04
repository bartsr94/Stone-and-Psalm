## Drives the sun and the sky from the clock: the day/night cycle (Phase 2.3) laid over the
## seasonal parameter set (Phase 2.4).
##
## Presentation only. It reads `SimClock` and the pure `Daylight` model, it owns no
## authoritative state, and everything it touches — the `DirectionalLight3D`, the
## `WorldEnvironment`, the sky material — could be deleted and rebuilt from the clock.
##
## The environment resource is deep-duplicated on ready so this writes a private copy and never
## the `.tres` on disk. Diurnal values are sampled every frame (a few lerps); the seasonal set
## changes slowly, so it is resampled only when the day rolls over.
##
## The sun's altitude and compass bearing come straight from `Daylight`, so it rises in the
## east, crosses due south, sits ~59° up at midsummer noon and ~13° at midwinter noon, and the
## day is visibly shorter in winter. Below the horizon the light is pinned just above it at
## near-zero energy — a directional light shining up through the ground looks wrong, and at
## this energy its direction barely reads anyway.
extends Node3D

const SKY_CONFIG_PATH := "res://data/sky.json"
## World north is −Z and east is +X, so a compass bearing maps to this horizontal direction.
const _NORTH := Vector3(0.0, 0.0, -1.0)

@onready var _sun: DirectionalLight3D = $Sun
@onready var _world_environment: WorldEnvironment = $WorldEnvironment

var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _sky_keyframes: Array = []
var _seasons := SeasonBlender.new()
var _season_state: Dictionary = {}

var _latitude: float = 54.0
var _tilt: float = 23.44
var _solar_noon: float = 720.0
var _min_rendered_altitude: float = 0.4


func _ready() -> void:
	_latitude = Tuning.get_num("world.latitude_deg")
	_tilt = Tuning.get_num("sky.axial_tilt_deg")
	_solar_noon = Tuning.get_num("sky.solar_noon_minute")
	_min_rendered_altitude = Tuning.get_num("sky.min_rendered_sun_altitude_deg")

	_load_sky_config()
	_clone_environment()

	SimClock.day_passed.connect(_on_day_passed)
	_season_state = _seasons.sample(SimClock.day_of_year())
	_apply()


func _process(_delta: float) -> void:
	_apply()


func _on_day_passed(_day_of_year: int) -> void:
	_season_state = _seasons.sample(SimClock.day_of_year())


# --- the per-frame update ----------------------------------------------------------------

func current_sun_altitude_deg() -> float:
	return Daylight.solar_altitude_deg(
		SimClock.day_of_year(), _minute_now(), _latitude, _tilt, _solar_noon
	)


func season_state() -> Dictionary:
	return _season_state


## Continuous minute of day (0…1440), so the sun moves smoothly between whole sim-minutes.
func _minute_now() -> float:
	return SimClock.day_fraction() * 1440.0


func _apply() -> void:
	if _season_state.is_empty():
		return

	var day := SimClock.day_of_year()
	var minute := _minute_now()
	var altitude := Daylight.solar_altitude_deg(day, minute, _latitude, _tilt, _solar_noon)
	var azimuth := Daylight.solar_azimuth_deg(day, minute, _latitude, _tilt, _solar_noon)

	_orient_sun(maxf(altitude, _min_rendered_altitude), azimuth)

	var sky := _sample_sky(altitude)
	var season := _season_state

	# Sun: diurnal colour and energy, tinted and scaled by the season.
	_sun.light_color = _multiply(sky["sun_color"], season["sun_tint"])
	_sun.light_energy = float(sky["sun_energy"]) * float(season["sun_energy_scale"])

	# Sky dome: diurnal tint carrying the seasonal cast.
	if _sky_material != null:
		_sky_material.sky_top_color = _multiply(sky["sky_top"], _bias(season["sky_top"]))
		_sky_material.sky_horizon_color = _multiply(sky["sky_horizon"], _bias(season["sky_horizon"]))
		_sky_material.ground_horizon_color = _sky_material.sky_horizon_color

	# Fog: seasonal density, thickened at dawn and dusk; seasonal colour.
	_environment.volumetric_fog_density = float(season["fog_density"]) * float(sky["fog_density_scale"])
	_environment.volumetric_fog_albedo = season["fog_color"]

	# Ambient: diurnal level scaled by the season, tinted toward the horizon.
	_environment.ambient_light_energy = float(sky["ambient_energy"]) * float(season["ambient_energy_scale"])
	_environment.ambient_light_color = (_sky_material.sky_horizon_color if _sky_material != null
		else Color(0.6, 0.65, 0.72))


func _orient_sun(altitude_deg: float, azimuth_deg: float) -> void:
	var altitude := deg_to_rad(altitude_deg)
	var bearing := _NORTH.rotated(Vector3.UP, deg_to_rad(azimuth_deg))
	# Direction from the ground toward the sun.
	var to_sun := (bearing * cos(altitude) + Vector3.UP * sin(altitude)).normalized()
	var sun_position := to_sun * 100.0
	var up := Vector3.UP if absf(to_sun.dot(Vector3.UP)) < 0.98 else Vector3(0.0, 0.0, 1.0)
	# look_at points the node's −Z at the target, i.e. the light travels from the sun to origin.
	_sun.global_position = sun_position
	_sun.look_at(Vector3.ZERO, up)


## Interpolates the diurnal keyframes in `data/sky.json` by the sun's altitude. Below the
## lowest keyframe and above the highest, the values hold flat.
func _sample_sky(altitude_deg: float) -> Dictionary:
	var count := _sky_keyframes.size()
	var first: Dictionary = _sky_keyframes[0]
	if altitude_deg <= float(first["at_altitude_deg"]):
		return _resolve_sky(first)
	var last: Dictionary = _sky_keyframes[count - 1]
	if altitude_deg >= float(last["at_altitude_deg"]):
		return _resolve_sky(last)

	for i in count - 1:
		var low: Dictionary = _sky_keyframes[i]
		var high: Dictionary = _sky_keyframes[i + 1]
		var low_alt := float(low["at_altitude_deg"])
		var high_alt := float(high["at_altitude_deg"])
		if altitude_deg >= low_alt and altitude_deg <= high_alt:
			var t := (altitude_deg - low_alt) / (high_alt - low_alt)
			return {
				"sun_energy": lerpf(float(low["sun_energy"]), float(high["sun_energy"]), t),
				"sun_color": Color.html(str(low["sun_color"])).lerp(Color.html(str(high["sun_color"])), t),
				"sky_top": Color.html(str(low["sky_top"])).lerp(Color.html(str(high["sky_top"])), t),
				"sky_horizon": Color.html(str(low["sky_horizon"])).lerp(Color.html(str(high["sky_horizon"])), t),
				"ambient_energy": lerpf(float(low["ambient_energy"]), float(high["ambient_energy"]), t),
				"fog_density_scale": lerpf(float(low["fog_density_scale"]), float(high["fog_density_scale"]), t),
			}
	return _resolve_sky(last)


func _resolve_sky(keyframe: Dictionary) -> Dictionary:
	return {
		"sun_energy": float(keyframe["sun_energy"]),
		"sun_color": Color.html(str(keyframe["sun_color"])),
		"sky_top": Color.html(str(keyframe["sky_top"])),
		"sky_horizon": Color.html(str(keyframe["sky_horizon"])),
		"ambient_energy": float(keyframe["ambient_energy"]),
		"fog_density_scale": float(keyframe["fog_density_scale"]),
	}


func _load_sky_config() -> void:
	var file := FileAccess.open(SKY_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("SkyCycle: cannot open %s" % SKY_CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary and parsed.has("keyframes")):
		push_error("SkyCycle: %s has no keyframes" % SKY_CONFIG_PATH)
		return
	_sky_keyframes = parsed["keyframes"]


func _clone_environment() -> void:
	if _world_environment.environment == null:
		push_error("SkyCycle: the WorldEnvironment has no environment resource")
		return
	_environment = _world_environment.environment.duplicate(true)
	_world_environment.environment = _environment
	if _environment.sky != null and _environment.sky.sky_material is ProceduralSkyMaterial:
		_sky_material = _environment.sky.sky_material


## Component-wise colour multiply, for layering a tint over a base colour.
func _multiply(base: Color, tint: Color) -> Color:
	return Color(base.r * tint.r, base.g * tint.g, base.b * tint.b, 1.0)


## Pulls a seasonal sky colour toward white so it reads as a cast over the diurnal colour
## rather than replacing it.
func _bias(color: Color) -> Color:
	return color.lerp(Color.WHITE, 0.5)
