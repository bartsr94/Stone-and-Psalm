"""
Validate .blend source files against the Stone and Psalm asset conventions.

Enforces docs/ARCHITECTURE_GUIDE.md section 4.3. These are the errors that are invisible in
Blender and expensive in Godot: an unapplied scale, an origin in the wrong place, a colour
attribute with the wrong name, a stray camera, a second material.

Run headless:
    blender --background --python tools/blender/validate_assets.py -- assets/blend

Exits 1 if any asset fails, so it can gate a build.
"""

import sys
import os
import glob
import math

import bpy

# --- conventions (docs/ARCHITECTURE_GUIDE.md section 4.3) -------------------------------

SHARED_MATERIAL = "M_StoneAndPsalm"
COLOR_ATTR = "Col"
VALID_PREFIXES = ("bld_", "prop_", "agent_", "kit_")

# Triangle budgets per prefix. agent_ is tight on purpose: 250 of them are on screen at once.
TRI_BUDGET = {
    "bld_": 1500,
    "prop_": 400,
    "agent_": 600,
    "kit_": 500,
}

EPS_SCALE = 1e-4
EPS_ROT = 1e-4
EPS_ORIGIN = 1e-3


class Report:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.checked = 0

    def error(self, blend, obj, msg):
        self.errors.append(f"{blend} :: {obj} :: {msg}")

    def warn(self, blend, obj, msg):
        self.warnings.append(f"{blend} :: {obj} :: {msg}")


def tri_count(obj):
    mesh = obj.data
    mesh.calc_loop_triangles()
    return len(mesh.loop_triangles)


def prefix_of(name):
    for p in VALID_PREFIXES:
        if name.startswith(p):
            return p
    return None


def check_object(rep, blend_name, obj):
    name = obj.name

    prefix = prefix_of(name)
    if prefix is None:
        rep.error(blend_name, name, f"name must start with one of {VALID_PREFIXES}")
    if name != name.lower():
        rep.error(blend_name, name, "name must be snake_case (lower-case)")

    # Transforms applied. An unapplied scale silently breaks the 1 unit = 1 metre contract.
    s = obj.scale
    if any(abs(v - 1.0) > EPS_SCALE for v in s):
        rep.error(blend_name, name, f"scale not applied: {tuple(round(v, 4) for v in s)}")
    r = obj.rotation_euler
    if any(abs(v) > EPS_ROT for v in r):
        deg = tuple(round(math.degrees(v), 2) for v in r)
        rep.error(blend_name, name, f"rotation not applied: {deg} deg")

    # Origin at ground-centre of the footprint: bbox sits on z=0, centred on x/y.
    corners = [obj.matrix_world @ v.co for v in obj.data.vertices]
    if corners:
        min_z = min(c.z for c in corners)
        cx = (min(c.x for c in corners) + max(c.x for c in corners)) / 2.0
        cy = (min(c.y for c in corners) + max(c.y for c in corners)) / 2.0
        if abs(min_z) > EPS_ORIGIN:
            rep.error(blend_name, name, f"origin not on ground plane: bbox min z = {min_z:.4f}")
        if abs(cx) > EPS_ORIGIN or abs(cy) > EPS_ORIGIN:
            rep.error(
                blend_name, name,
                f"origin not centred on footprint: centre = ({cx:.4f}, {cy:.4f})"
            )

    # Vertex colours are the whole art pipeline. No Col attribute means an untextured grey box.
    attrs = obj.data.color_attributes
    if COLOR_ATTR not in attrs:
        found = [a.name for a in attrs]
        rep.error(blend_name, name, f"missing colour attribute '{COLOR_ATTR}' (found: {found})")
    else:
        a = attrs[COLOR_ATTR]
        if a.data_type != "BYTE_COLOR":
            rep.warn(blend_name, name, f"'{COLOR_ATTR}' is {a.data_type}, expected BYTE_COLOR")

    # One shared material, or the batching and palette coherence arguments both collapse.
    mats = [m.name for m in obj.data.materials if m is not None]
    if len(mats) == 0:
        rep.error(blend_name, name, "no material assigned")
    elif len(mats) > 1:
        rep.error(blend_name, name, f"multiple materials: {mats} (expected only {SHARED_MATERIAL})")
    elif mats[0] != SHARED_MATERIAL:
        rep.error(blend_name, name, f"material is '{mats[0]}', expected '{SHARED_MATERIAL}'")

    if prefix:
        budget = TRI_BUDGET[prefix]
        tris = tri_count(obj)
        if tris > budget:
            rep.error(blend_name, name, f"{tris} triangles exceeds {prefix} budget of {budget}")
        elif tris > budget * 0.85:
            rep.warn(blend_name, name, f"{tris} triangles is near the {prefix} budget of {budget}")

    for m in obj.modifiers:
        rep.warn(blend_name, name, f"unapplied modifier '{m.name}' ({m.type})")


def check_file(rep, path):
    blend_name = os.path.basename(path)
    bpy.ops.wm.open_mainfile(filepath=path)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        rep.error(blend_name, "-", "no mesh objects in file")

    # Lights and cameras travel into the .glb and fight the scene's own lighting rig.
    for o in bpy.data.objects:
        if o.type in {"LIGHT", "CAMERA"}:
            rep.error(blend_name, o.name, f"{o.type.lower()} must not be saved in an asset file")

    for o in meshes:
        rep.checked += 1
        check_object(rep, blend_name, o)


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    root = args[0] if args else "assets/blend"

    paths = sorted(glob.glob(os.path.join(root, "**", "*.blend"), recursive=True))
    if not paths:
        print(f"[validate] no .blend files found under '{root}' — nothing to check.")
        sys.exit(0)

    rep = Report()
    for p in paths:
        check_file(rep, p)

    print()
    print("=" * 72)
    print(f"[validate] {len(paths)} file(s), {rep.checked} mesh object(s) checked")
    print("=" * 72)

    for w in rep.warnings:
        print(f"  WARN   {w}")
    for e in rep.errors:
        print(f"  ERROR  {e}")

    print()
    if rep.errors:
        print(f"[validate] FAILED — {len(rep.errors)} error(s), {len(rep.warnings)} warning(s)")
        sys.exit(1)
    print(f"[validate] PASSED — 0 errors, {len(rep.warnings)} warning(s)")
    sys.exit(0)


if __name__ == "__main__":
    # Blender exits 0 even when a Python script raises. A validator that passes because it
    # crashed is worse than no validator, so force a non-zero exit on failure.
    # (SystemExit from main() is a BaseException and passes through untouched.)
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
