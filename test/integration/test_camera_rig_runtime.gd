## The camera actually responds to input, in the tree, over real frames.
##
## The unit tests prove the rig's arithmetic and `test_input_map` proves the bindings; neither
## would catch the rig never being wired to them — an unconnected `_unhandled_input`, a
## `_process` that does not pan, or a yaw that eases toward the wrong place. That gap is the
## whole point of this file.
##
## Yaw is advanced by calling `_process` with explicit deltas rather than waiting on real time,
## so the assertions are about the animation's arithmetic rather than about how fast the test
## machine happens to be.
extends GutTest

const MAIN_SCENE := "res://scenes/world/main.tscn"

var _rig: Node3D = null
var _camera: Camera3D = null


func before_each() -> void:
	# Mouse buttons route through Control hit-testing before `_unhandled_input`; use a real-sized
	# viewport so a fixed HUD panel cannot cover the whole headless runner's 64x64 default.
	get_tree().root.size = Vector2i(1600, 900)
	var scene: Node = add_child_autofree(load(MAIN_SCENE).instantiate())
	_rig = scene.find_child("CameraRig", true, false) as Node3D
	_camera = scene.find_child("Camera3D", true, false) as Camera3D
	# Let the rig run a frame before anything is measured against it.
	await wait_process_frames(2)


func after_each() -> void:
	for action in ["cam_pan_forward", "cam_pan_right"]:
		if Input.is_action_pressed(action):
			Input.action_release(action)


func _yaw_degrees() -> float:
	# Euler extraction chooses an equivalent representation past 90°. The camera's orbit
	# position gives an unambiguous full-circle yaw instead.
	return rad_to_deg(fposmod(atan2(_camera.position.x, _camera.position.z), TAU))


func _pitch_degrees() -> float:
	var forward: Vector3 = -_camera.global_transform.basis.z
	return rad_to_deg(asin(-forward.y))


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await wait_process_frames(2)


func _key_press(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _middle_button(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_MIDDLE
	event.pressed = pressed
	event.position = Vector2(800.0, 450.0)
	return event


func _middle_drag(relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = Vector2(800.0, 450.0) + relative
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	return event


func test_holding_forward_pans_the_focus() -> void:
	var before: Vector3 = _rig.position
	Input.action_press("cam_pan_forward")
	await wait_process_frames(5)
	Input.action_release("cam_pan_forward")

	assert_lt(_rig.position.z, before.z, "the focus moved away from the viewer")
	assert_almost_eq(_rig.position.y, before.y, 0.0001, "and stayed on the ground")


func test_panning_right_moves_across_the_screen() -> void:
	var before: Vector3 = _rig.position
	Input.action_press("cam_pan_right")
	await wait_process_frames(5)
	Input.action_release("cam_pan_right")

	assert_gt(_rig.position.x, before.x, "the focus moved to the camera's right")


func test_wheel_zooms_in_and_stays_inside_the_clamp() -> void:
	var before: float = _camera.size
	await _send(_wheel(MOUSE_BUTTON_WHEEL_UP))
	await wait_process_frames(20)

	assert_lt(_camera.size, before, "the view got closer")
	assert_gte(_camera.size, Tuning.get_num("camera.ortho_size_min_m"), "and respects the clamp")


func test_wheel_out_zooms_out() -> void:
	var before: float = _camera.size
	await _send(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	await wait_process_frames(20)

	assert_gt(_camera.size, before, "the view got wider")
	assert_lte(_camera.size, Tuning.get_num("camera.ortho_size_max_m"), "and respects the clamp")


func test_turning_settles_on_exactly_ninety_degrees() -> void:
	assert_almost_eq(_yaw_degrees(), 0.0, 0.01, "starts square")

	await _send(_key_press(KEY_E))
	# Advance past the turn duration so the animation has certainly finished.
	_rig._process(Tuning.get_num("camera.yaw_turn_seconds") + 0.05)

	assert_almost_eq(_yaw_degrees(), 90.0, 0.01, "one turn is exactly a quarter")


func test_holding_middle_mouse_and_dragging_rotates_freely() -> void:
	await _send(_middle_button(true))
	await _send(_middle_drag(Vector2(-180.0, 0.0)))
	await _send(_middle_button(false))

	assert_almost_eq(_yaw_degrees(), 45.0, 0.01, "middle-drag can leave the camera between steps")


func test_upward_middle_mouse_drag_lowers_the_camera_tilt() -> void:
	await _send(_middle_button(true))
	await _send(_middle_drag(Vector2(0.0, -80.0)))
	await _send(_middle_button(false))

	assert_almost_eq(_pitch_degrees(), 20.0, 0.01, "vertical drag freely changes the pitch")


func test_qe_turns_from_the_mouse_selected_angle() -> void:
	await _send(_middle_button(true))
	await _send(_middle_drag(Vector2(-180.0, 0.0)))
	await _send(_middle_button(false))
	await _send(_key_press(KEY_E))
	_rig._process(Tuning.get_num("camera.yaw_turn_seconds") + 0.05)

	assert_almost_eq(_yaw_degrees(), 135.0, 0.01, "Q/E continues 90 degrees from free yaw")


func test_turning_the_other_way_wraps_to_two_seventy() -> void:
	await _send(_key_press(KEY_Q))
	_rig._process(Tuning.get_num("camera.yaw_turn_seconds") + 0.05)

	assert_almost_eq(_yaw_degrees(), 270.0, 0.01, "turning back from square wraps round")


func test_four_turns_return_to_the_start() -> void:
	# The drift case: a rig that eased by a fraction each frame instead of settling would end
	# up near 0 but not on it, and would keep sliding with every further turn.
	for _i in 4:
		await _send(_key_press(KEY_E))
		_rig._process(Tuning.get_num("camera.yaw_turn_seconds") + 0.05)

	assert_almost_eq(_yaw_degrees(), 0.0, 0.01, "back to square after four turns")


func test_mouse_selected_pitch_holds_through_turning_and_zooming() -> void:
	await _send(_middle_button(true))
	await _send(_middle_drag(Vector2(0.0, -80.0)))
	await _send(_middle_button(false))
	await _send(_key_press(KEY_E))
	_rig._process(Tuning.get_num("camera.yaw_turn_seconds") + 0.05)
	await _send(_wheel(MOUSE_BUTTON_WHEEL_UP))
	await wait_process_frames(10)

	assert_almost_eq(
		_pitch_degrees(), 20.0, 0.01,
		"keyboard turning and zooming preserve the mouse-selected pitch"
	)
