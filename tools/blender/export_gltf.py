"""
Batch-export .blend sources to Godot-ready .glb.

The export settings are the contract (docs/ARCHITECTURE_GUIDE.md section 4.3): +Y up,
-Z forward, transforms applied, vertex colours kept, no lights or cameras. Exporting by hand
from the GUI is how those silently drift, so nothing is exported by hand.

Run headless:
    blender --background --python tools/blender/export_gltf.py -- assets/blend assets/models

Only re-exports when the .blend is newer than the .glb, unless --force is passed.
"""

import sys
import os
import glob

import bpy

# Desired export settings. Filtered against the operator's actual properties before use, so a
# Blender upgrade that renames or drops an option degrades gracefully instead of hard-failing.
# (API drift between versions is the known failure mode for scripts like this.)
DESIRED = {
    "export_format": "GLB",
    "export_yup": True,              # +Y up, -Z forward — Godot's convention
    "export_apply": True,            # apply modifiers
    "use_selection": False,
    "use_visible": True,
    "export_cameras": False,
    "export_lights": False,
    "export_extras": False,
    "export_animations": False,
    "export_skins": False,
    "export_morph": False,
    "export_materials": "EXPORT",
    "export_vertex_color": "ACTIVE",  # the Col attribute
    "export_all_vertex_colors": False,
    "export_attributes": False,
    "export_normals": True,
    "export_tangents": False,
    "export_texcoords": False,        # we do not UV-unwrap; there is nothing to export
    "export_image_format": "NONE",
}


def supported_kwargs(desired):
    """Keep only the properties this Blender's glTF exporter actually understands."""
    try:
        props = bpy.ops.export_scene.gltf.get_rna_type().properties
        valid = {p.identifier for p in props}
    except Exception:
        return dict(desired)

    kept, dropped = {}, []
    for k, v in desired.items():
        if k in valid:
            kept[k] = v
        else:
            dropped.append(k)
    if dropped:
        print(f"[export] note: this Blender ignores {dropped}")
    return kept


def export_one(blend_path, out_path, kwargs):
    bpy.ops.wm.open_mainfile(filepath=blend_path)

    # Belt and braces: the validator rejects these, but never ship one if it slips through.
    for o in [o for o in bpy.data.objects if o.type in {"LIGHT", "CAMERA"}]:
        bpy.data.objects.remove(o, do_unlink=True)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out_path, **kwargs)


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    force = "--force" in args
    args = [a for a in args if a != "--force"]

    src = args[0] if len(args) > 0 else "assets/blend"
    dst = args[1] if len(args) > 1 else "assets/models"

    paths = sorted(glob.glob(os.path.join(src, "**", "*.blend"), recursive=True))
    if not paths:
        print(f"[export] no .blend files found under '{src}' — nothing to do.")
        return

    kwargs = supported_kwargs(DESIRED)

    exported = skipped = 0
    for p in paths:
        rel = os.path.relpath(p, src)
        out = os.path.join(dst, os.path.splitext(rel)[0] + ".glb")

        if not force and os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(p):
            skipped += 1
            continue

        print(f"[export] {rel} -> {os.path.relpath(out, dst)}")
        export_one(p, out, kwargs)
        exported += 1

    print(f"[export] done — {exported} exported, {skipped} up to date")


if __name__ == "__main__":
    # Blender exits 0 even when a Python script raises; a "successful" export that never ran
    # would go unnoticed until Godot showed nothing. Force a non-zero exit on failure.
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
