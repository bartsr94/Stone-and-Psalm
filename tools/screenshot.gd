## Renders a scene and writes a PNG, for the screenshot that every phase's exit criteria require
## (docs/planning/ROADMAP.md — "a phase with no visual output is not finished").
##
##     godot --path . -s tools/screenshot.gd -- [scene] [output] [settle_frames]
##
## Defaults to the main scene, `docs/screenshots/latest.png`, and 45 frames.
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

	var scene: PackedScene = load(scene_path)
	if scene == null:
		push_error("screenshot: cannot load %s" % scene_path)
		quit(1)
		return

	DisplayServer.window_set_size(WINDOW_SIZE)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output).get_base_dir())
	root.add_child(scene.instantiate())

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
