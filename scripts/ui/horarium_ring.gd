## The Horarium — the day as a ring. The signature screen (Roadmap 3.9): it teaches the core
## mechanic without words. The outer band is daylight; the eight offices are pinned around the
## circle at their canonical hours; the green arcs are the work blocks left between them; the
## hand is now. Move the clock from midsummer to midwinter and the daylight band and the work
## arcs visibly contract while the eight office marks stay put — the winter squeeze, drawn.
##
## Presentation only. It reads the demo monk's `Liturgy.day_plan` each frame. Toggle with H.
extends CanvasLayer

const _RADIUS := 108.0
const _MARGIN := Vector2(28.0, 28.0)
const _OFFICE_LABEL := {
	"vigils": "Vig", "lauds": "Ld", "prime": "Pr", "terce": "Tc",
	"sext": "Sx", "none": "Nn", "vespers": "Vsp", "compline": "Cp",
}

var _canvas: Control
var _font: Font


func _ready() -> void:
	layer = 16
	_font = ThemeDB.fallback_font
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_canvas.custom_minimum_size = Vector2(2.0 * _RADIUS + 2.0 * _MARGIN.x, 2.0 * _RADIUS + 110.0)
	_canvas.position = Vector2(_MARGIN.x, -(2.0 * _RADIUS + 132.0))
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_ring)
	add_child(_canvas)


func _process(_delta: float) -> void:
	if _canvas.visible:
		_canvas.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_canvas.visible = not _canvas.visible
		get_viewport().set_input_as_handled()


func _plan() -> Dictionary:
	var ids := Population.person_ids()
	if ids.is_empty():
		return {}
	var monk: Person = Population.get_person(ids[0])
	return Liturgy.day_plan(monk.person_class, monk.order, SimClock.year(), SimClock.day_of_year())


func _minute_angle(minute: float) -> float:
	# Midnight at the top, clockwise.
	return -PI / 2.0 + (minute / 1440.0) * TAU


func _on_ring(minute: float, radius: float) -> Vector2:
	var a := _minute_angle(minute)
	return _centre() + Vector2(cos(a), sin(a)) * radius


func _centre() -> Vector2:
	return Vector2(_MARGIN.x + _RADIUS, _MARGIN.y + _RADIUS)


func _draw_ring() -> void:
	var plan := _plan()
	if plan.is_empty():
		return

	var centre := _centre()
	var bg := Color("#12140fdd")
	var ring_col := Color("#4a4636")
	var night_col := Color("#1c2436")
	var day_col := Color("#caa25f")
	var work_col := Color("#7c9a4e")
	var office_col := Color("#d8d3c4")
	var hand_col := Color("#e8846a")
	var text_main := Color("#e8e4d8")
	var text_dim := Color("#b0ab99")

	_canvas.draw_circle(centre, _RADIUS + 14.0, bg)

	var sunrise: float = plan["sunrise_min"]
	var sunset: float = plan["sunset_min"]

	# Night, then the daylight band over it.
	_canvas.draw_arc(centre, _RADIUS, 0.0, TAU, 96, night_col, 12.0)
	_canvas.draw_arc(centre, _RADIUS, _minute_angle(sunrise), _minute_angle(sunset), 96, day_col, 12.0)
	_canvas.draw_arc(centre, _RADIUS, 0.0, TAU, 96, ring_col, 1.5)

	# Work blocks, on an inner track.
	for block in plan.get("work_blocks", []):
		_canvas.draw_arc(
			centre, _RADIUS - 12.0,
			_minute_angle(float(block[0])), _minute_angle(float(block[1])),
			48, work_col, 7.0
		)

	# Office marks and their labels.
	for entry in plan.get("offices", []):
		var minute: float = fposmod(float(entry["start_min"]), 1440.0)
		var inner := _on_ring(minute, _RADIUS - 6.0)
		var outer := _on_ring(minute, _RADIUS + 8.0)
		var attends: bool = entry["attends"]
		_canvas.draw_line(inner, outer, office_col if attends else ring_col, 2.0)
		var label: String = _OFFICE_LABEL.get(entry["key"], "?")
		var label_pos := _on_ring(minute, _RADIUS + 22.0) - Vector2(_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x * 0.5, -4.0)
		_canvas.draw_string(_font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			text_dim if not attends else office_col)

	# The hand: now.
	var now := float(SimClock.minute_of_day())
	_canvas.draw_line(centre, _on_ring(now, _RADIUS - 2.0), hand_col, 2.5)
	_canvas.draw_circle(centre, 3.0, hand_col)

	# Centre readout.
	var time_str := SimClock.time_string()
	var time_size := _font.get_string_size(time_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 26)
	_canvas.draw_string(_font, centre - Vector2(time_size.x * 0.5, -8.0), time_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, text_main)

	# Caption below the dial.
	var line_y := _MARGIN.y + 2.0 * _RADIUS + 24.0
	var daylight_min: int = int(round(plan["daylight_min"]))
	@warning_ignore("integer_division")
	var caption := "%s  ·  %s" % [SimClock.date_string(), SimClock.season_string()]
	var detail := "unequal hour  %d min      daylight  %dh %02dm" % [
		int(round(plan["hour_length_min"])), daylight_min / 60, daylight_min % 60
	]
	var labour := "labour budget  %dh %02dm      in daylight  %dh %02dm" % [
		int(plan["labour_budget_min"]) / 60, int(plan["labour_budget_min"]) % 60,
		int(plan["daylight_labour_min"]) / 60, int(plan["daylight_labour_min"]) % 60,
	]
	_canvas.draw_string(_font, Vector2(_MARGIN.x, line_y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, text_main)
	_canvas.draw_string(_font, Vector2(_MARGIN.x, line_y + 20.0), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_dim)
	_canvas.draw_string(_font, Vector2(_MARGIN.x, line_y + 38.0), labour, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, text_dim)
	if plan.get("labour_restricted", false):
		_canvas.draw_string(_font, Vector2(_MARGIN.x, line_y + 58.0),
			"no manual labour today — %s" % plan.get("feast_name", "Sunday"),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#caa25f"))
