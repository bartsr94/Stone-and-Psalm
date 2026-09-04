## The placement controller actually responds to input, in the tree, over real frames — the
## same gap `test_camera_rig_runtime.gd` closes for the camera. The pure ray maths has its own
## unit tests (`test_terrain_ray.gd`); this proves the controller is wired to real mouse/keyboard
## events and to `Buildings`.
extends GutTest

const MAIN_SCENE := "res://scenes/world/main.tscn"

var _placement: BuildingPlacement = null
var _camera: Camera3D = null


func before_each() -> void:
	var scene: Node = add_child_autofree(load(MAIN_SCENE).instantiate())
	_placement = scene.find_child("BuildingPlacement", true, false) as BuildingPlacement
	_camera = scene.find_child("Camera3D", true, false) as Camera3D
	await wait_process_frames(2)


func after_each() -> void:
	if _placement.is_active():
		Input.parse_input_event(_key_press(KEY_ESCAPE))


func _key_press(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	# The custom build_* actions are bound by physical_keycode (project.godot, like the camera
	# actions); the built-in ui_cancel is bound by logical keycode. Setting both lets one event
	# match either kind of binding.
	event.keycode = code
	event.pressed = true
	return event


func _mouse_click(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _mouse_move(pos: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = pos
	return event


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await wait_process_frames(2)


func _screen_centre() -> Vector2:
	return _camera.get_viewport().get_visible_rect().size * 0.5


func test_b_toggles_placement_mode() -> void:
	assert_false(_placement.is_active())
	await _send(_key_press(KEY_B))
	assert_true(_placement.is_active())
	await _send(_key_press(KEY_B))
	assert_false(_placement.is_active())


func test_escape_cancels_placement_mode() -> void:
	await _send(_key_press(KEY_B))
	assert_true(_placement.is_active())
	await _send(_key_press(KEY_ESCAPE))
	assert_false(_placement.is_active())


func test_tab_cycles_the_building_type() -> void:
	await _send(_key_press(KEY_B))
	var first := _placement.current_type_id()
	await _send(_key_press(KEY_TAB))
	assert_ne(_placement.current_type_id(), first, "cycling moved to a different type")


func test_hovering_the_valley_finds_a_ground_cell() -> void:
	await _send(_key_press(KEY_B))
	await _send(_mouse_move(_screen_centre()))
	assert_true(_placement.has_hover(), "the ray from the centre of the screen hits the ground")


func test_clicking_agrees_with_buildings_can_place() -> void:
	Buildings.clear()
	await _send(_key_press(KEY_B))
	await _send(_mouse_move(_screen_centre()))
	assert_true(_placement.has_hover(), "need a hover to test placement at all")

	var type_id := _placement.current_type_id()
	var cell := _placement.hover_cell()
	var expected_valid := Buildings.can_place(type_id, cell)
	var before := Buildings.building_ids().size()

	await _send(_mouse_click(MOUSE_BUTTON_LEFT))

	var after := Buildings.building_ids().size()
	if expected_valid:
		assert_eq(after, before + 1, "a valid site places a building")
	else:
		assert_eq(after, before, "an invalid site places nothing")


func test_clicks_before_b_are_ignored() -> void:
	Buildings.clear()
	var before := Buildings.building_ids().size()
	await _send(_mouse_move(_screen_centre()))
	await _send(_mouse_click(MOUSE_BUTTON_LEFT))
	assert_eq(Buildings.building_ids().size(), before, "clicking without entering placement mode does nothing")
