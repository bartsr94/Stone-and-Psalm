## The crew panel actually responds to input and its buttons actually drive `Buildings`, over
## real frames in the tree — the same gap `test_building_placement_runtime.gd` closes for
## placement. The assignment rules themselves have their own headless tests
## (`test_buildings.gd`, `test_labour.gd`); this proves the panel is wired to them.
extends GutTest

const MAIN_SCENE := "res://scenes/world/main.tscn"

var _panel: CrewPanel = null


func before_each() -> void:
	# See test_building_placement_runtime.gd: the headless dummy viewport defaults to 64x64,
	# small enough for a corner-anchored panel sized for a real window to swallow every click.
	get_tree().root.size = Vector2i(1600, 900)
	Buildings.clear()
	Population.clear()
	var scene: Node = add_child_autofree(load(MAIN_SCENE).instantiate())
	_panel = scene.find_child("CrewPanel", true, false) as CrewPanel
	await wait_process_frames(2)


func _key_press(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await wait_process_frames(2)


func _open_site(type_id: String) -> Vector2i:
	for radius in range(0, 60):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := Vector2i(100, 100) + Vector2i(dx, dy)
				if Buildings.can_place(type_id, cell):
					return cell
	fail_test("no buildable site found near (100, 100) for %s" % type_id)
	return Vector2i(-1, -1)


func _under_construction_site() -> int:
	var site := _open_site("masons_lodge")
	var id := Buildings.place_building("masons_lodge", site)
	Buildings.deliver_material(id, "sawn_timber", 40)
	Buildings.deliver_material(id, "nails", 8)
	assert_eq(Buildings.get_building(id).construction_state, Building.State.UNDER_CONSTRUCTION)
	return id


func test_c_toggles_the_panel() -> void:
	assert_false(_panel.is_open())
	await _send(_key_press(KEY_C))
	assert_true(_panel.is_open())
	await _send(_key_press(KEY_C))
	assert_false(_panel.is_open())


func test_a_site_under_construction_is_listed_once_open() -> void:
	var id := _under_construction_site()
	await _send(_key_press(KEY_C))
	assert_true(_panel.site_ids().has(id))


func test_a_planned_site_with_no_materials_is_not_listed() -> void:
	var id := Buildings.place_building("masons_lodge", _open_site("masons_lodge"))
	await _send(_key_press(KEY_C))
	assert_false(_panel.site_ids().has(id))


func test_the_plus_button_assigns_a_pool_worker_and_shrinks_the_pool() -> void:
	var id := _under_construction_site()
	Population.add_person("Brother Osric", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, Vector2i(100, 100))
	await _send(_key_press(KEY_C))

	var pool_before := _panel.pool_size()
	assert_eq(Buildings.worker_count(id), 0)

	_panel.assign_button_for(id).pressed.emit()
	await wait_process_frames(2)

	assert_eq(Buildings.worker_count(id), 1, "the button's handler called Buildings.assign_worker")
	assert_eq(_panel.pool_size(), pool_before - 1, "the assigned worker left the pool")


func test_the_minus_button_returns_a_worker_to_the_pool() -> void:
	var id := _under_construction_site()
	var worker_id := Population.add_person(
		"Brother Osric", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, Vector2i(100, 100)
	)
	Buildings.assign_worker(id, worker_id)
	await _send(_key_press(KEY_C))

	var pool_before := _panel.pool_size()
	_panel.unassign_button_for(id).pressed.emit()
	await wait_process_frames(2)

	assert_eq(Buildings.worker_count(id), 0)
	assert_eq(_panel.pool_size(), pool_before + 1, "the freed worker rejoined the pool")


func test_the_plus_button_is_disabled_once_the_pool_is_empty() -> void:
	var id := _under_construction_site()
	# `Population.clear()` in before_each leaves no one at all — the pool starts empty.
	await _send(_key_press(KEY_C))
	assert_eq(_panel.pool_size(), 0)
	assert_true(_panel.assign_button_for(id).disabled)
