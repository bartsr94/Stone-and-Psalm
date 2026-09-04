## Renders a scene and writes a PNG, for the screenshot that every phase's exit criteria require
## (docs/planning/ROADMAP.md — "a phase with no visual output is not finished").
##
##     godot --path . -s tools/screenshot.gd -- [scene] [output] [settle_frames] [day] [minute] [pre_run_days]
##
## Defaults to the main scene, `docs/screenshots/latest.png`, 45 frames, and — if a `SimClock`
## autoload is present — day-of-year 172 (midsummer) at minute 780 (13:00), so a phase shot is
## a lit daytime valley rather than whatever instant the clock happens to start on. Pass `day`
## and `minute` to capture another time; the clock is held still for the capture either way.
##
## `pre_run_days` (default 0) runs the clock forward that many real days *before* pinning to the
## capture instant — one `advance_minutes(10.0)` per substep, never `SimClock.advance_days`,
## whose substep count is capped per call (`MAX_SUBSTEPS_PER_ADVANCE`, sim_clock.gd) and would
## silently under-run Population's per-substep decisions. Use this to let something with a state
## that accumulates over days — a haul, a construction site — actually progress before the shot,
## rather than only ever capturing the instant the world was founded.
##
## Two things this has to get right:
##
## - **It must run windowed, not `--headless`.** The dummy renderer produces no image.
## - **It waits before capturing.** SSAO, SSIL and volumetric fog all converge over several
##   frames, so a capture on frame one looks nothing like the game.
##
## `_process` is deliberately not overridden: doing so suppresses the normal scene-tree
## processing, and any scene with movement in it would then be captured frozen on its first
## frame.
extends SceneTree

const DEFAULT_SCENE := "res://scenes/world/main.tscn"
const DEFAULT_OUTPUT := "res://docs/screenshots/latest.png"
const DEFAULT_SETTLE_FRAMES := 45
const WINDOW_SIZE := Vector2i(1600, 900)


func _initialize() -> void:
	_capture()


func _capture() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else DEFAULT_SCENE
	var output: String = args[1] if args.size() > 1 else DEFAULT_OUTPUT
	var settle_frames: int = int(args[2]) if args.size() > 2 else DEFAULT_SETTLE_FRAMES
	var day_of_year: int = int(args[3]) if args.size() > 3 else 172
	var minute_of_day: float = float(args[4]) if args.size() > 4 else 780.0
	var pre_run_days: int = int(args[5]) if args.size() > 5 else 0

	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_error("screenshot: cannot load %s" % scene_path)
		quit(1)
		return

	DisplayServer.window_set_size(WINDOW_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	root.add_child(scene.instantiate())

	# One frame so autoloads and the HUD's _ready (which starts the clock) have run.
	await process_frame

	# Pin the clock to a chosen daytime instant and stop it, so the capture is deterministic.
	var clock := root.get_node_or_null("SimClock")
	if clock != null:
		if pre_run_days > 0:
			for _i in pre_run_days * 144:   # 144 substeps/day at MINUTES_PER_SUBSTEP = 10
				clock.advance_minutes(10.0)
			await process_frame   # let the scene tree pick up wherever pre_run_days left the world
		var start_day: int = 74  # SimClock._start_day_index; day-of-year 75 is the epoch
		var total_days: int = posmod(day_of_year - 1 - start_day, 365) + 365
		clock.deserialize({"abs_minute": float(total_days) * 1440.0 + minute_of_day, "speed_index": 0})
	else:
		push_warning("screenshot: no SimClock autoload — capturing at the default instant")

	for _i in settle_frames:
		await process_frame
	await RenderingServer.frame_post_draw

	var texture := root.get_texture()
	if texture == null:
		push_error("screenshot: no viewport texture — is this running with --headless?")
		quit(1)
		return

	var err := texture.get_image().save_png(output)
	if err != OK:
		push_error("screenshot: could not write %s (%s)" % [output, error_string(err)])
		quit(1)
		return

	print("screenshot: wrote %s" % output)
	quit()
