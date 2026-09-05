## Small presentation overlay for the first rendered vertical slice.
##
## It is intentionally a scene-status card, not a gameplay HUD. Its job is to establish place and
## communicate the current controls while the simulation systems are still being built.
extends CanvasLayer

const SETTINGS_PATH := "res://data/founding_site.json"
const PANEL_COLOR := Color("#18201ddd")
const PANEL_EDGE := Color("#c9c2b288")
const TEXT_MAIN := Color("#e8e4d8")
const TEXT_MUTED := Color("#b5b09f")
const ACCENT := Color("#d5a45e")
var _site: Dictionary = {}
var _landmark_count: int = 0


func _ready() -> void:
	layer = 20
	_load_site_data()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_title_card(root)
	_build_controls(root)
	_build_site_badge(root)


func _load_site_data() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("SiteStatusOverlay: cannot open %s" % SETTINGS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary and parsed.has("site") and parsed.has("landmarks")):
		push_error("SiteStatusOverlay: invalid settings in %s" % SETTINGS_PATH)
		return
	var settings := parsed as Dictionary
	_site = settings["site"] as Dictionary
	_landmark_count = (settings["landmarks"] as Array).size()


func _label(text: String, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = PANEL_EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _build_title_card(root: Control) -> void:
	var panel := _panel()
	panel.position = Vector2(24.0, 24.0)
	panel.size = Vector2(360.0, 126.0)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	column.add_child(_label(str(_site.get("name", "The Founding Site")).to_upper(), 22, ACCENT))
	column.add_child(_label("Yorkshire dale  ·  %s" % _site.get("date", "AD 1132"), 14, TEXT_MAIN))
	var separator := HSeparator.new()
	separator.modulate = PANEL_EDGE
	column.add_child(separator)
	column.add_child(_label(str(_site.get("description", "")), 13, TEXT_MUTED))


func _build_site_badge(root: Control) -> void:
	var panel := _panel()
	panel.position = Vector2(24.0, 166.0)
	panel.size = Vector2(226.0, 42.0)
	root.add_child(panel)
	var label := _label("●  %d foundation landmarks" % _landmark_count, 13, TEXT_MAIN)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)


func _build_controls(root: Control) -> void:
	var panel := _panel()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.position = Vector2(-315.0, -58.0)
	panel.size = Vector2(630.0, 38.0)
	root.add_child(panel)
	var label := _label(
		"WASD / arrows  pan     middle-drag / Q / E  rotate     wheel  zoom", 13, TEXT_MUTED
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
