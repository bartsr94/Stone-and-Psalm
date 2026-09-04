## Rain and snow over the camera, driven by the Weather autoload.
##
## Presentation only. Two GPU particle emitters follow the camera focus on the ground plane and
## fall in world space, so panning does not smear them. Which one runs, and how hard, comes
## straight from `Weather.sky()` and `Weather.precip_amount()` — this owns nothing.
extends Node3D

## Half-extents of the volume that particles spawn in, centred over the camera focus.
const _AREA := Vector3(38.0, 13.0, 38.0)
const _RAIN_MAX := 1400
const _SNOW_MAX := 1100

var _rain: GPUParticles3D
var _snow: GPUParticles3D
var _focus: Node3D


func _ready() -> void:
	_focus = _find_focus()

	_rain = _make_emitter("Rain", _RAIN_MAX, 1.4, _rain_process(), _drop_mesh(
		Vector3(0.012, 0.42, 0.012), Color(0.72, 0.78, 0.86, 0.65)
	))
	_snow = _make_emitter("Snow", _SNOW_MAX, 12.0, _snow_process(), _drop_mesh(
		Vector3(0.06, 0.06, 0.06), Color(0.96, 0.97, 0.99, 0.9)
	))
	add_child(_rain)
	add_child(_snow)

	Weather.weather_changed.connect(_apply)
	_apply()


func _process(_delta: float) -> void:
	if _focus != null:
		global_position = Vector3(_focus.global_position.x, 0.0, _focus.global_position.z)


func _apply() -> void:
	var amount := clampf(Weather.precip_amount(), 0.08, 1.0)
	_rain.emitting = Weather.is_raining()
	_snow.emitting = Weather.is_snowing()
	_rain.amount_ratio = amount
	_snow.amount_ratio = amount


func _find_focus() -> Node3D:
	var parent := get_parent()
	if parent == null:
		return null
	return parent.find_child("CameraRig", true, false) as Node3D


func _make_emitter(
	node_name: String, count: int, lifetime: float,
	process_material: ParticleProcessMaterial, mesh: Mesh
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.amount = count
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.local_coords = false
	particles.visibility_aabb = AABB(-_AREA, _AREA * 2.0)
	particles.process_material = process_material
	particles.draw_pass_1 = mesh
	particles.emitting = false
	return particles


func _drop_mesh(size: Vector3, color: Color) -> Mesh:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	box.material = material
	return box


func _rain_process() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = _AREA
	material.direction = Vector3(0.06, -1.0, 0.02)
	material.spread = 2.0
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 24.0
	material.gravity = Vector3(0.6, -32.0, 0.0)
	material.scale_min = 0.7
	material.scale_max = 1.3
	return material


func _snow_process() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = _AREA
	material.direction = Vector3(0.2, -1.0, 0.1)
	material.spread = 12.0
	material.initial_velocity_min = 1.2
	material.initial_velocity_max = 2.6
	material.gravity = Vector3(0.4, -1.4, 0.2)
	material.turbulence_enabled = true
	material.turbulence_noise_strength = 1.4
	material.turbulence_noise_scale = 1.8
	material.scale_min = 0.8
	material.scale_max = 1.6
	return material
