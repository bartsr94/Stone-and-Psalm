## The orthographic camera the whole game is viewed through: smooth yaw and pitch orbit while
## middle-mouse dragging, and zoom clamped to the ortho range (Architecture Guide §4).
##
## A view node. It owns no simulation state, and its transform is transient by the Fundamental
## Rule. Every number it uses comes from `data/tuning.json`.
##
## Three choices worth knowing:
##
## - **Middle-mouse dragging owns the orbit while held.** Horizontal motion changes yaw, vertical
##   motion changes pitch, and it interrupts a keyboard turn immediately. Q/E then begin a fresh
##   90° turn from the freely chosen yaw rather than snapping back to a cardinal view.
## - **Pan speed is screens-per-second, not metres-per-second.** Panning therefore feels the same
##   zoomed in at 20 m as zoomed out at 160 m, where a fixed metre rate would crawl.
## - **The rig node is the focus point on the ground**; the single `Camera3D` child is placed
##   entirely from code each frame and carries no authored transform of its own. Because the
##   projection is orthographic, `distance_m` only has to clear the scene — it does not affect
##   apparent size.
class_name CameraRig
extends Node3D

var _yaw_radians: float = 0.0
var _yaw_from: float = 0.0
var _yaw_to: float = 0.0
var _yaw_elapsed: float = 0.0
var _mouse_rotating: bool = false

var _ortho_target: float = 0.0
var _ortho_current: float = 0.0

var _pitch_radians: float = 0.0
var _pitch_min_radians: float = 0.0
var _pitch_max_radians: float = 0.0
var _yaw_step_degrees: float = 0.0
var _yaw_turn_seconds: float = 0.0
var _mouse_yaw_degrees_per_pixel: float = 0.0
var _mouse_pitch_degrees_per_pixel: float = 0.0
var _ortho_min: float = 0.0
var _ortho_max: float = 0.0
var _zoom_step_factor: float = 0.0
var _zoom_smoothing_rate: float = 0.0
var _pan_screens_per_sec: float = 0.0
var _camera_distance: float = 0.0

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_pitch_radians = deg_to_rad(Tuning.get_num("camera.pitch_deg"))
	_pitch_min_radians = deg_to_rad(Tuning.get_num("camera.pitch_min_deg"))
	_pitch_max_radians = deg_to_rad(Tuning.get_num("camera.pitch_max_deg"))
	_yaw_step_degrees = Tuning.get_num("camera.yaw_step_deg")
	_yaw_turn_seconds = Tuning.get_num("camera.yaw_turn_seconds")
	_mouse_yaw_degrees_per_pixel = Tuning.get_num("camera.mouse_yaw_degrees_per_pixel")
	_mouse_pitch_degrees_per_pixel = Tuning.get_num("camera.mouse_pitch_degrees_per_pixel")
	_ortho_min = Tuning.get_num("camera.ortho_size_min_m")
	_ortho_max = Tuning.get_num("camera.ortho_size_max_m")
	_zoom_step_factor = Tuning.get_num("camera.zoom_step_factor")
	_zoom_smoothing_rate = Tuning.get_num("camera.zoom_smoothing_rate")
	_pan_screens_per_sec = Tuning.get_num("camera.pan_screens_per_sec")
	_camera_distance = Tuning.get_num("camera.distance_m")

	_ortho_target = clamp_ortho(Tuning.get_num("camera.ortho_size_start_m"), _ortho_min, _ortho_max)
	_ortho_current = _ortho_target

	_yaw_radians = 0.0
	_yaw_from = _yaw_radians
	_yaw_to = _yaw_radians

	# Start looking at the founding precinct rather than the map's centre — the dale is centred
	# on the origin, but the house is off to one side of it.
	position = Vector3(
		Tuning.get_num("camera.start_focus_x_m"), 0.0, Tuning.get_num("camera.start_focus_z_m")
	)

	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = Tuning.get_num("camera.near_m")
	_camera.far = _camera_distance + Tuning.get_num("camera.far_margin_m")
	_apply()


func _process(delta: float) -> void:
	_pan(delta)
	_advance(delta)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_mouse_rotating = event.pressed
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _mouse_rotating:
		# A release over UI may be consumed before it reaches `_unhandled_input`. The mask on the
		# next motion prevents that missed release from leaving rotation stuck on.
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			_drag_orbit(event.relative)
			get_viewport().set_input_as_handled()
		else:
			_mouse_rotating = false
	elif event.is_action_pressed("cam_yaw_left"):
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
	_yaw_from = _yaw_radians
	_yaw_to = _yaw_radians + deg_to_rad(_yaw_step_degrees) * float(direction)
	_yaw_elapsed = 0.0


func _drag_orbit(mouse_delta: Vector2) -> void:
	_yaw_radians = yaw_after_mouse_drag(
		_yaw_radians, mouse_delta.x, _mouse_yaw_degrees_per_pixel
	)
	_pitch_radians = pitch_after_mouse_drag(
		_pitch_radians,
		mouse_delta.y,
		_mouse_pitch_degrees_per_pixel,
		_pitch_min_radians,
		_pitch_max_radians
	)
	# Cancel any in-flight Q/E easing so it cannot pull the camera away after the drag.
	_yaw_from = _yaw_radians
	_yaw_to = _yaw_radians
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


## Continuous yaw after a horizontal middle-mouse drag. The result is wrapped so any number of
## full rotations remains numerically stable.
static func yaw_after_mouse_drag(
	current_radians: float, horizontal_pixels: float, degrees_per_pixel: float
) -> float:
	return fposmod(current_radians - deg_to_rad(horizontal_pixels * degrees_per_pixel), TAU)


## Pitch after a vertical middle-mouse drag. Pulling upward lowers the camera toward the
## horizon; the limits prevent the orbit from flipping or becoming exactly horizontal.
static func pitch_after_mouse_drag(
	current_radians: float,
	vertical_pixels: float,
	degrees_per_pixel: float,
	min_radians: float,
	max_radians: float
) -> float:
	return clampf(
		current_radians + deg_to_rad(vertical_pixels * degrees_per_pixel),
		min_radians,
		max_radians
	)


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
