## The placement controller actually responds to input, in the tree, over real frames — the
## same gap `test_camera_rig_runtime.gd` closes for the camera. The pure ray maths has its own
## unit tests (`test_terrain_ray.gd`); this proves the controller is wired to real mouse/keyboard
## events and to `Buildings`.
extends GutTest

const MAIN_SCENE := "res://scenes/world/main.tscn"

var _placement: BuildingPlacement = null
var _camera: Camera3D = null


func before_each() -> void:
	# The headless test runner's dummy viewport defaults to a tiny 64x64 — small enough that a
	# corner-anchored HUD panel sized for a real window can cover the whole thing and swallow a
	## screen-centre click before it ever reaches _unhandled_input. Match the real window size.
	get_tree().root.size = Vector2i(1600, 900)
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
	# A mouse button, unlike the wheel, has real sustained "held" state — Godot never sees this
	# one released, so a second synthetic click later in the same test (or in the next test:
	# Input's button state is not scene-scoped) can silently fail to re-report as "just pressed".
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var release := event.duplicate() as InputEventMouseButton
		release.pressed = false
		Input.parse_input_event(release)
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


func test_cycling_all_the_way_round_reaches_the_road_type() -> void:
	await _send(_key_press(KEY_B))
	var ids := _placement.type_ids()
	for _i in ids.size() - 1:
		await _send(_key_press(KEY_TAB))
	assert_eq(_placement.current_type_id(), BuildingPlacement.ROAD_TYPE_ID, "the road is last in the cycle")
	assert_true(_placement.is_road_selected())


func test_clicking_with_the_road_type_selected_agrees_with_terrain_is_walkable() -> void:
	await _send(_key_press(KEY_B))
	var ids := _placement.type_ids()
	for _i in ids.size() - 1:
		await _send(_key_press(KEY_TAB))
	await _send(_mouse_move(_screen_centre()))
	assert_true(_placement.has_hover())
	assert_true(_placement.is_road_selected())

	# The ray hits the ground surface regardless of walkability (a road ghost can still hover
	# over the river or a steep slope, coloured invalid) — only a walkable cell can actually
	# become a road, the same "agrees with the headless rule" shape as the building click test.
	var cell := _placement.hover_cell()
	var was_road := Terrain.is_road(cell.x, cell.y)
	var walkable := Terrain.is_walkable(cell.x, cell.y)

	await _send(_mouse_click(MOUSE_BUTTON_LEFT))

	if walkable:
		assert_eq(Terrain.is_road(cell.x, cell.y), not was_road, "a walkable cell's road toggled")
	else:
		assert_eq(Terrain.is_road(cell.x, cell.y), was_road, "an unwalkable cell never becomes a road")

	# Leave the terrain as this test found it.
	Terrain.set_road(cell.x, cell.y, was_road)


func test_clicks_before_b_are_ignored() -> void:
	Buildings.clear()
	var before := Buildings.building_ids().size()
	await _send(_mouse_move(_screen_centre()))
	await _send(_mouse_click(MOUSE_BUTTON_LEFT))
	assert_eq(Buildings.building_ids().size(), before, "clicking without entering placement mode does nothing")
