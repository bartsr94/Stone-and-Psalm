## The in-world HUD: the date and time, the season and weather, and the speed control.
##
## Presentation only. It reads `SimClock` and `Weather` and writes nothing back except the play
## speed, which is the clock's own control. Built in code the way `site_status_overlay.gd` is,
## rather than as a scene, so the panel layout stays in one readable place.
##
## The clock starts paused (so headless tests never tick unbidden); this HUD is the thing that
## sets it running, at 1×, once the world is on screen. Space toggles pause; the four buttons
## are pause / 1× / 3× / 10×, matching `time.speed_multipliers` in tuning.
extends CanvasLayer

const THEME_PATH := "res://ui/theme/stone_and_psalm_theme.tres"
const _SPEED_LABELS := ["❙❙", "1×", "3×", "10×"]

var _date_label: Label
var _detail_label: Label
var _speed_buttons: Array[Button] = []


func _ready() -> void:
	layer = 15

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = load(THEME_PATH)
	add_child(root)

	_build_clock_panel(root)
	_build_speed_panel(root)

	SimClock.speed_changed.connect(_on_speed_changed)

	# The world is up: start time running.
	SimClock.set_speed_index(1)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		SimClock.toggle_pause()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	_date_label.text = SimClock.date_string()
	_detail_label.text = "%s  ·  %s  ·  %d°C  ·  %s" % [
		SimClock.time_string(),
		SimClock.season_string(),
		roundi(Weather.temperature_c()),
		Weather.sky_string(),
	]


func _on_speed_changed(speed_index: int) -> void:
	for i in _speed_buttons.size():
		_speed_buttons[i].button_pressed = (i == speed_index)


func _build_clock_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-296.0, 24.0)
	panel.custom_minimum_size = Vector2(272.0, 0.0)
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 16)
	_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_date_label)

	_detail_label = Label.new()
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.add_theme_color_override("font_color", Color(0.71, 0.69, 0.62))
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_detail_label)


func _build_speed_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.position = Vector2(-232.0, -64.0)
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)

	for i in _SPEED_LABELS.size():
		var button := Button.new()
		button.text = _SPEED_LABELS[i]
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(46.0, 0.0)
		var speed_index := i
		button.pressed.connect(func() -> void: SimClock.set_speed_index(speed_index))
		row.add_child(button)
		_speed_buttons.append(button)


## The current speed buttons, for tests.
func speed_buttons() -> Array[Button]:
	return _speed_buttons
