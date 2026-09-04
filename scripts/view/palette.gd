## Reads `data/palette.json`, the one place colour is decided.
##
## Everything visible takes its colour from here, painted into vertex colours rather than into
## per-model textures (Architecture Guide §4.1) — that is what makes the whole game look like
## one game by construction instead of by discipline.
##
## A missing key returns magenta and pushes an error, rather than a plausible grey: an unnamed
## colour should be obvious on screen the first time it is rendered.
class_name Palette
extends RefCounted

const PALETTE_PATH := "res://data/palette.json"
const MISSING := Color.MAGENTA

static var _colours: Dictionary = {}


## The colour named in the palette, exactly as authored, e.g. `Palette.of("limestone_mid")`.
##
## Use this for anything Godot treats as sRGB — `albedo_color`, UI, light colours.
static func of(key: String) -> Color:
	if _colours.is_empty():
		_load()
	if not _colours.has(key):
		push_error("Palette: no colour named %s" % key)
		return MISSING
	return _colours[key]


## The same colour converted to linear, for writing into a mesh's `ARRAY_COLOR`.
##
## **This conversion is not optional.** Vertex colours are handed to the shader unchanged and
## multiplied into albedo, which is linear — whereas `albedo_color` on a material is treated as
## sRGB and converted by Godot for you. Passing an authored hex straight into a vertex colour
## therefore renders it far too bright: it washed the entire first valley out to pastel, and
## looked like a tonemapping problem rather than a colour-space one.
static func vertex(key: String) -> Color:
	return of(key).srgb_to_linear()


static func _load() -> void:
	var file := FileAccess.open(PALETTE_PATH, FileAccess.READ)
	if file == null:
		push_error("Palette: cannot open %s" % PALETTE_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Palette: %s is not a JSON object" % PALETTE_PATH)
		return

	for key in parsed:
		# The file carries `_comment` strings alongside the colour entries.
		var entry: Variant = parsed[key]
		if entry is Dictionary and entry.has("hex"):
			_colours[key] = Color.html(entry["hex"])
