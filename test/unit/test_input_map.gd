## The camera actions exist and the keys and wheel actually match them.
##
## Worth testing because the input map is the one part of `project.godot` that is neither
## readable at a glance nor exercised by anything else headless: a wrong keycode or a device
## mismatch produces a camera that simply does not respond, with no error anywhere.
extends GutTest

const CAMERA_ACTIONS := [
	"cam_pan_left",
	"cam_pan_right",
	"cam_pan_forward",
	"cam_pan_back",
	"cam_yaw_left",
	"cam_yaw_right",
	"cam_zoom_in",
	"cam_zoom_out",
]


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _wheel_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func test_every_camera_action_is_registered() -> void:
	for action in CAMERA_ACTIONS:
		assert_true(InputMap.has_action(action), "%s exists" % action)


func test_wasd_pans() -> void:
	assert_true(_key_event(KEY_W).is_action_pressed("cam_pan_forward"), "W pans forward")
	assert_true(_key_event(KEY_A).is_action_pressed("cam_pan_left"), "A pans left")
	assert_true(_key_event(KEY_S).is_action_pressed("cam_pan_back"), "S pans back")
	assert_true(_key_event(KEY_D).is_action_pressed("cam_pan_right"), "D pans right")


func test_arrow_keys_pan_too() -> void:
	assert_true(_key_event(KEY_UP).is_action_pressed("cam_pan_forward"), "up arrow")
	assert_true(_key_event(KEY_LEFT).is_action_pressed("cam_pan_left"), "left arrow")
	assert_true(_key_event(KEY_DOWN).is_action_pressed("cam_pan_back"), "down arrow")
	assert_true(_key_event(KEY_RIGHT).is_action_pressed("cam_pan_right"), "right arrow")


func test_q_and_e_turn() -> void:
	assert_true(_key_event(KEY_Q).is_action_pressed("cam_yaw_left"), "Q turns anticlockwise")
	assert_true(_key_event(KEY_E).is_action_pressed("cam_yaw_right"), "E turns clockwise")


func test_mouse_wheel_zooms() -> void:
	assert_true(
		_wheel_event(MOUSE_BUTTON_WHEEL_UP).is_action_pressed("cam_zoom_in"),
		"wheel up zooms in"
	)
	assert_true(
		_wheel_event(MOUSE_BUTTON_WHEEL_DOWN).is_action_pressed("cam_zoom_out"),
		"wheel down zooms out"
	)


func test_pan_and_turn_are_not_bound_to_the_same_keys() -> void:
	# A key bound to two camera actions would fire both silently.
	assert_false(_key_event(KEY_W).is_action_pressed("cam_yaw_left"), "W does not also turn")
	assert_false(_key_event(KEY_Q).is_action_pressed("cam_pan_left"), "Q does not also pan")
