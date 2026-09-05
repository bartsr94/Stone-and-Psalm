"""Render a contact sheet of the authored assets, lit and angled like the game.

    blender --background --python tools/blender/preview_assets.py -- [glob] [output.png]

Defaults to every `bld_*.blend` in `assets/blend`, written to `docs/screenshots/asset_sheet.png`.
Pass a glob to preview a subset, e.g. `prop_tree_*`.

**Why this exists.** The only way to see a model before this was to export it, re-import the
Godot project, run the game, and go looking for the building — two minutes a look, and only for
whichever assets happen to be placed in the world. A contact sheet is a few seconds and shows
every asset side by side, which is what you actually want when the question is "do these read as
one set". It is a modelling aid, not a substitute for a screenshot in the game: the real
lighting rig, the terrain under the building and the seasonal tints all live in Godot, and
`docs/planning/ROADMAP.md`'s "a phase with no visual output is not finished" means a shot from
the game, not from here.

The camera matches the game's fixed 40 degree pitch and orthographic projection (Architecture
Guide 4), so a silhouette that reads here reads in game.
"""

import glob as globmod
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from meshkit import BLEND_DIR, ROOT, reset_scene  # noqa: E402

CAMERA_PITCH_DEG = 40.0
CAMERA_YAW_DEG = 35.0     # off the cardinal, so both a gable and a long wall are visible
MAX_COLUMNS = 4
CELL_M = 26.0             # grid spacing; must clear the largest asset


def _argv():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    pattern = args[0] if len(args) > 0 else "bld_*"
    output = args[1] if len(args) > 1 else os.path.join(ROOT, "docs", "screenshots",
                                                        "asset_sheet.png")
    return pattern, output


def _append_object(path, into_collection):
    """Link the first mesh object out of a .blend without opening it as the current file."""
    with bpy.data.libraries.load(path, link=False) as (source, target):
        target.objects = [name for name in source.objects]
    placed = None
    for obj in target.objects:
        if obj is not None and obj.type == "MESH":
            into_collection.objects.link(obj)
            placed = obj
            break
    return placed


def build_sheet(pattern):
    reset_scene()
    collection = bpy.context.collection

    paths = sorted(globmod.glob(os.path.join(BLEND_DIR, pattern + ".blend")))
    if not paths:
        print("[preview] no .blend matched %s" % pattern)
        return None, 0

    # Fewer assets get fewer columns, so previewing one building fills the frame instead of
    # sitting in the corner of a four-wide grid.
    columns = max(1, min(MAX_COLUMNS, len(paths)))

    placed = []
    for index, path in enumerate(paths):
        obj = _append_object(path, collection)
        if obj is None:
            continue
        column, row = index % columns, index // columns
        obj.location = (column * CELL_M, -row * CELL_M, 0.0)
        placed.append(obj)
        print("[preview] %s" % os.path.basename(path))

    rows = (len(placed) + columns - 1) // columns
    # A ground plane, so every model has something to cast a shadow onto and sit on.
    bpy.ops.mesh.primitive_plane_add(size=CELL_M * max(columns, rows) * 2.2)
    ground = bpy.context.active_object
    ground.location = ((columns - 1) * CELL_M * 0.5, -(rows - 1) * CELL_M * 0.5, 0.0)
    material = bpy.data.materials.new("PreviewGround")
    material.use_nodes = True
    material.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (
        0.16, 0.19, 0.09, 1.0)
    material.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.95
    ground.data.materials.append(material)

    return (columns, rows), len(placed)


def add_camera_and_light(grid):
    columns, rows = grid
    centre = ((columns - 1) * CELL_M * 0.5, -(rows - 1) * CELL_M * 0.5, 3.0)
    span = max(columns, rows) * CELL_M * 1.05

    pitch = math.radians(CAMERA_PITCH_DEG)
    yaw = math.radians(CAMERA_YAW_DEG)
    distance = span * 2.0
    direction = (math.cos(pitch) * math.sin(yaw), -math.cos(pitch) * math.cos(yaw),
                 math.sin(pitch))
    bpy.ops.object.camera_add(location=tuple(centre[i] + direction[i] * distance
                                             for i in range(3)))
    camera = bpy.context.active_object
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = span * 1.15
    # Point -Z at the centre of the grid.
    camera.rotation_mode = "QUATERNION"
    forward = tuple(-direction[i] for i in range(3))
    import mathutils
    camera.rotation_quaternion = mathutils.Vector(forward).to_track_quat("-Z", "Y")
    bpy.context.scene.camera = camera

    # One sun, roughly where the game's summer afternoon sun sits.
    bpy.ops.object.light_add(type="SUN", location=(centre[0], centre[1], 60.0))
    sun = bpy.context.active_object
    sun.data.energy = 3.4
    sun.data.angle = math.radians(2.0)
    sun.data.color = (1.0, 0.96, 0.88)
    sun.rotation_euler = (math.radians(52.0), 0.0, math.radians(-35.0))

    world = bpy.data.worlds.new("PreviewWorld")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.42, 0.48, 0.58, 1.0)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.42
    bpy.context.scene.world = world


def render(output):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1800
    scene.render.resolution_y = 1200
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.view_transform = "Standard"
    scene.render.filepath = output
    os.makedirs(os.path.dirname(output), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    print("[preview] wrote %s" % output)


def main():
    pattern, output = _argv()
    grid, count = build_sheet(pattern)
    if grid is None:
        sys.exit(1)
    add_camera_and_light(grid)
    render(output)
    print("[preview] %d asset(s)" % count)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
