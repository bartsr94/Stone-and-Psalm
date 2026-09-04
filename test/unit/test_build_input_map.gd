## The building-placement actions exist and the keys actually match them. Same reasoning as
## `test_input_map.gd`: a wrong keycode here produces a placement mode that silently never
## responds, with no error anywhere.
extends GutTest

const BUILD_ACTIONS := ["build_toggle", "build_cycle", "build_rotate", "build_place"]


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _mouse_event(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func test_every_build_action_is_registered() -> void:
	for action in BUILD_ACTIONS:
		assert_true(InputMap.has_action(action), "%s exists" % action)


func test_b_toggles_placement() -> void:
	assert_true(_key_event(KEY_B).is_action_pressed("build_toggle"))


func test_tab_cycles_and_r_rotates() -> void:
	assert_true(_key_event(KEY_TAB).is_action_pressed("build_cycle"))
	assert_true(_key_event(KEY_R).is_action_pressed("build_rotate"))


func test_left_click_confirms_placement() -> void:
	assert_true(_mouse_event(MOUSE_BUTTON_LEFT).is_action_pressed("build_place"))


func test_build_actions_do_not_collide_with_camera_actions() -> void:
	assert_false(_key_event(KEY_B).is_action_pressed("cam_pan_left"), "B does not also pan")
	assert_false(_key_event(KEY_R).is_action_pressed("cam_yaw_left"), "R does not also turn")
