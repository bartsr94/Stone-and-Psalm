## Renders a frame sequence for the Phase 2 exit clip: one year of the valley, or one day.
##
##     godot --path . -s tools/timelapse.gd -- [mode] [frames] [out_dir] [settle]
##
## mode   "year" (default) sweeps day-of-year 1→365 at fixed local noon;
##        "day" sweeps minute-of-day across a single midsummer day.
## frames number of PNGs to write (default 240).
## out_dir default "res://docs/screenshots/timelapse/". Files are frame_0001.png …
## settle  frames to let SSAO/SSIL/fog converge between captures (default 6).
##
## Assemble with e.g.  ffmpeg -framerate 30 -i frame_%04d.png -pix_fmt yuv420p year.mp4
##
## Must run **windowed, not --headless** — the dummy renderer writes nothing. Like
## `tools/screenshot.gd`, `_process` is left alone so the scene keeps animating.
extends SceneTree

const SCENE := "res://scenes/world/main.tscn"
const DEFAULT_FRAMES := 240
const DEFAULT_OUT := "res://docs/screenshots/timelapse/"
const DEFAULT_SETTLE := 6
const WINDOW_SIZE := Vector2i(1600, 900)
const NOON := 720.0
const START_DAY_OF_YEAR := 75  # matches time.start_day_of_year in tuning


func _initialize() -> void:
	_run()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "year"
	var frames: int = int(args[1]) if args.size() > 1 else DEFAULT_FRAMES
	var out_dir: String = args[2] if args.size() > 2 else DEFAULT_OUT
	var settle: int = int(args[3]) if args.size() > 3 else DEFAULT_SETTLE

	var scene: PackedScene = load(SCENE)
	if scene == null:
		push_error("timelapse: cannot load %s" % SCENE)
		quit(1)
		return

	DisplayServer.window_set_size(WINDOW_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	root.add_child(scene.instantiate())

	var clock := root.get_node_or_null("/root/SimClock")
	if clock == null:
		push_error("timelapse: SimClock autoload missing")
		quit(1)
		return
	# Hold time still; this tool sets the instant for each frame itself.
	clock.set_speed_index(0)

	# Let the first frame converge fully before the sequence starts.
	for _i in 40:
		await process_frame

	for frame in frames:
		var t := float(frame) / float(maxi(frames - 1, 1))
		_set_instant(clock, mode, t)
		for _s in settle:
			await process_frame
		await RenderingServer.frame_post_draw

		var path := "%sframe_%04d.png" % [out_dir, frame + 1]
		var image := root.get_texture().get_image()
		var err := image.save_png(path)
		if err != OK:
			push_error("timelapse: could not write %s (%s)" % [path, error_string(err)])
			quit(1)
			return
		if frame % 20 == 0:
			print("timelapse: %d / %d" % [frame + 1, frames])

	print("timelapse: wrote %d frames to %s" % [frames, out_dir])
	quit()


func _set_instant(clock: Node, mode: String, t: float) -> void:
	var start_index := START_DAY_OF_YEAR - 1  # SimClock's _start_day_index
	if mode == "day":
		# One midsummer day, midnight to midnight.
		var day_offset := 172 - START_DAY_OF_YEAR
		clock.deserialize({"abs_minute": float(day_offset) * 1440.0 + t * 1440.0, "speed_index": 0})
		return

	# One year at local noon: pick total_days so that day_of_year() lands on the target.
	var target_index := int(round(t * 364.0))  # 0 .. 364, i.e. day_of_year 1 .. 365
	var total_days := posmod(target_index - start_index, 365) + 365  # kept positive
	clock.deserialize({"abs_minute": float(total_days) * 1440.0 + NOON, "speed_index": 0})
