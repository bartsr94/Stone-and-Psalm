## Renders a scene and writes a PNG, for the screenshot that every phase's exit criteria require
## (docs/planning/ROADMAP.md — "a phase with no visual output is not finished").
##
##     godot --path . -s tools/screenshot.gd -- [scene] [output] [settle_frames] [day] [minute] [pre_run_days] [input_actions] [ortho_size_m] [pitch_deg]
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
## `input_actions` (default "", 7th arg) is a comma-separated list of input action names
## (`project.godot`'s `[input]` map) simulated as a press-then-release, in order, right after
## `pre_run_days` and before the clock is pinned — for capturing a toggled UI panel (`crew_toggle`,
## `build_toggle`) without a bespoke script per feature.
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
	var input_actions: String = args[6] if args.size() > 6 else ""
	var ortho_size_m: float = float(args[7]) if args.size() > 7 else 0.0
	var pitch_deg: float = float(args[8]) if args.size() > 8 else 0.0

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

	# `ortho_size_m` (8th arg, default 0 = tuning's start size) widens or tightens the rig's zoom
	# for the capture. A precinct overview and a close look at one building are both things a
	# phase shot needs, and neither should mean editing tuning.json for the run.
	# `pitch_deg` (9th arg, default 0 = tuning's start pitch) tilts the rig for the capture — a
	# low pitch is the only way to see the fells beyond the map edge in a shot.
	if ortho_size_m > 0.0 or pitch_deg > 0.0:
		# The scene was added straight under `root`, so search each of root's children rather than
		# `current_scene`, which is unset for a tree built this way.
		var rig: Node = null
		for child in root.get_children():
			rig = child.find_child("CameraRig", true, false)
			if rig != null:
				break
		if rig != null:
			if ortho_size_m > 0.0:
				rig.set("_ortho_target", ortho_size_m)
				rig.set("_ortho_current", ortho_size_m)
			if pitch_deg > 0.0:
				rig.set("_pitch_radians", deg_to_rad(pitch_deg))
		else:
			push_warning("screenshot: no CameraRig found to apply the camera arguments")

	# Pin the clock to a chosen daytime instant and stop it, so the capture is deterministic.
	var clock := root.get_node_or_null("SimClock")
	if clock != null:
		if pre_run_days > 0:
			for _i in pre_run_days * 144:   # 144 substeps/day at MINUTES_PER_SUBSTEP = 10
				clock.advance_minutes(10.0)
			await process_frame   # let the scene tree pick up wherever pre_run_days left the world

		# `Input.action_press` only sets polling state, not a real `InputEvent` — panels like
		# `CrewPanel`/`BuildingPlacement` toggle on `_unhandled_input`, so this replays the
		# actual bound event instead, the same shape the runtime input tests use.
		for action in input_actions.split(",", false):
			var bound := InputMap.action_get_events(action)
			if bound.is_empty():
				push_warning("screenshot: no bound event for action '%s'" % action)
				continue
			var press: InputEvent = bound[0].duplicate()
			press.set("pressed", true)
			Input.parse_input_event(press)
			await process_frame
			await process_frame
			var release: InputEvent = bound[0].duplicate()
			release.set("pressed", false)
			Input.parse_input_event(release)
			await process_frame

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
