## The orthographic camera the whole game is viewed through: fixed 40° pitch, yaw locked to four
## 90° positions, zoom clamped to the ortho range (Architecture Guide §4).
##
## A view node. It owns no simulation state, and its transform is transient by the Fundamental
## Rule. Every number it uses comes from `data/tuning.json`.
##
## Three choices worth knowing:
##
## - **Yaw is stored as a step index, not an angle.** The visible angle eases toward the step's
##   angle along the shortest arc, so repeated turns can never accumulate drift off the four
##   cardinal positions.
## - **Pan speed is screens-per-second, not metres-per-second.** Panning therefore feels the same
##   zoomed in at 20 m as zoomed out at 160 m, where a fixed metre rate would crawl.
## - **The rig node is the focus point on the ground**; the single `Camera3D` child is placed
##   entirely from code each frame and carries no authored transform of its own. Because the
##   projection is orthographic, `distance_m` only has to clear the scene — it does not affect
##   apparent size.
class_name CameraRig
extends Node3D

var _yaw_step: int = 0
var _yaw_radians: float = 0.0
var _yaw_from: float = 0.0
var _yaw_to: float = 0.0
var _yaw_elapsed: float = 0.0

var _ortho_target: float = 0.0
var _ortho_current: float = 0.0

var _pitch_radians: float = 0.0
var _yaw_step_degrees: float = 0.0
var _yaw_step_count: int = 0
var _yaw_turn_seconds: float = 0.0
var _ortho_min: float = 0.0
var _ortho_max: float = 0.0
var _zoom_step_factor: float = 0.0
var _zoom_smoothing_rate: float = 0.0
var _pan_screens_per_sec: float = 0.0
var _camera_distance: float = 0.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_pitch_radians = deg_to_rad(Tuning.get_num("camera.pitch_deg"))
	_yaw_step_degrees = Tuning.get_num("camera.yaw_step_deg")
	_yaw_step_count = Tuning.get_int("camera.yaw_step_count")
	_yaw_turn_seconds = Tuning.get_num("camera.yaw_turn_seconds")
	_ortho_min = Tuning.get_num("camera.ortho_size_min_m")
	_ortho_max = Tuning.get_num("camera.ortho_size_max_m")
	_zoom_step_factor = Tuning.get_num("camera.zoom_step_factor")
	_zoom_smoothing_rate = Tuning.get_num("camera.zoom_smoothing_rate")
	_pan_screens_per_sec = Tuning.get_num("camera.pan_screens_per_sec")
	_camera_distance = Tuning.get_num("camera.distance_m")

	_ortho_target = clamp_ortho(Tuning.get_num("camera.ortho_size_start_m"), _ortho_min, _ortho_max)
	_ortho_current = _ortho_target

	_yaw_radians = yaw_for_step(_yaw_step, _yaw_step_degrees)
	_yaw_from = _yaw_radians
	_yaw_to = _yaw_radians

	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = Tuning.get_num("camera.near_m")
	_camera.far = _camera_distance + Tuning.get_num("camera.far_margin_m")
	_apply()


func _process(delta: float) -> void:
	_pan(delta)
	_advance(delta)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_yaw_left"):
		_turn(-1)
	elif event.is_action_pressed("cam_yaw_right"):
		_turn(1)
	elif event.is_action_pressed("cam_zoom_in"):
		_zoom(1)
	elif event.is_action_pressed("cam_zoom_out"):
		_zoom(-1)


func _pan(delta: float) -> void:
	var input := Vector2(
		Input.get_axis("cam_pan_left", "cam_pan_right"),
		Input.get_axis("cam_pan_back", "cam_pan_forward")
	)
	if input == Vector2.ZERO:
		return
	position += pan_offset(input, _yaw_radians, _ortho_current, _pan_screens_per_sec, delta)


func _turn(direction: int) -> void:
	_yaw_step = wrapped_step(_yaw_step + direction, _yaw_step_count)
	_yaw_from = _yaw_radians
	_yaw_to = _yaw_radians + shortest_arc(_yaw_radians, yaw_for_step(_yaw_step, _yaw_step_degrees))
	_yaw_elapsed = 0.0


func _zoom(direction: int) -> void:
	_ortho_target = zoomed(_ortho_target, _zoom_step_factor, direction, _ortho_min, _ortho_max)


func _advance(delta: float) -> void:
	if not is_equal_approx(_yaw_radians, _yaw_to):
		_yaw_elapsed += delta
		var t := clampf(_yaw_elapsed / _yaw_turn_seconds, 0.0, 1.0)
		_yaw_radians = lerpf(_yaw_from, _yaw_to, smoothstep(0.0, 1.0, t))
		if t >= 1.0:
			# Re-wrap once settled so the angle cannot grow without bound over many turns.
			_yaw_radians = fposmod(_yaw_to, TAU)
			_yaw_from = _yaw_radians
			_yaw_to = _yaw_radians

	_ortho_current = lerpf(_ortho_current, _ortho_target, 1.0 - exp(-_zoom_smoothing_rate * delta))


func _apply() -> void:
	_camera.size = _ortho_current
	# EULER_ORDER_YXZ (the default) yaws first and then pitches about the camera's own X, which
	# is what makes this an orbit rather than a tumble.
	var orientation := Basis.from_euler(Vector3(-_pitch_radians, _yaw_radians, 0.0))
	_camera.transform = Transform3D(orientation, orientation * Vector3(0.0, 0.0, _camera_distance))


## The angle of a yaw step, in radians.
static func yaw_for_step(step: int, step_degrees: float) -> float:
	return deg_to_rad(float(step) * step_degrees)


## Wraps a step index into `0..count - 1`, so turning past either end comes round again.
static func wrapped_step(step: int, count: int) -> int:
	return posmod(step, count)


## The signed shortest way round from one angle to another, in radians (−PI..PI).
static func shortest_arc(from_radians: float, to_radians: float) -> float:
	return fposmod(to_radians - from_radians + PI, TAU) - PI


static func clamp_ortho(size: float, min_size: float, max_size: float) -> float:
	return clampf(size, min_size, max_size)


## One zoom notch. `direction` +1 zooms in (a smaller ortho size), −1 zooms out.
static func zoomed(size: float, factor: float, direction: int, min_size: float, max_size: float) -> float:
	return clampf(size * pow(factor, float(-direction)), min_size, max_size)


## Ground-plane pan for one frame. `input` is (right, forward) in the −1..1 range; the result is
## rotated into the camera's yaw so that "forward" always means away from the viewer.
static func pan_offset(
	input: Vector2,
	yaw_radians: float,
	ortho_size: float,
	screens_per_sec: float,
	delta: float
) -> Vector3:
	var direction := Vector3(input.x, 0.0, -input.y)
	if direction.length_squared() > 1.0:
		direction = direction.normalized()
	return direction.rotated(Vector3.UP, yaw_radians) * (screens_per_sec * ortho_size * delta)
