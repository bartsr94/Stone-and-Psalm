"""
Create or repair the single shared vertex-colour material, and load the project palette.

Every mesh in Stone and Psalm uses one material, M_StoneAndPsalm, whose Base Color is driven
by the 'Col' colour attribute. That is what lets us skip UV unwrapping and texturing entirely
(docs/ARCHITECTURE_GUIDE.md section 4.1) and what makes everything look like one game by
construction rather than by discipline.

Run on an open file from Blender's scripting tab, or headless on one file:
    blender assets/blend/bld_lime_kiln.blend --background --python tools/blender/setup_material.py -- --save

With no --save it only reports what it would change.
"""

import sys
import os
import json

import bpy

MATERIAL_NAME = "M_StoneAndPsalm"
COLOR_ATTR = "Col"
PALETTE_PATH = "data/palette.json"


def build_material():
    """Create M_StoneAndPsalm, or rewire it if it exists but is wrong."""
    mat = bpy.data.materials.get(MATERIAL_NAME)
    if mat is None:
        mat = bpy.data.materials.new(MATERIAL_NAME)
        print(f"[material] created {MATERIAL_NAME}")
    else:
        print(f"[material] found existing {MATERIAL_NAME} — rewiring")

    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    nodes.clear()

    out = nodes.new("ShaderNodeOutputMaterial")
    out.location = (400, 0)

    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.location = (100, 0)
    # Matte, non-metallic. The look comes from lighting, not from material trickery.
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 0.85

    attr = nodes.new("ShaderNodeVertexColor")
    attr.layer_name = COLOR_ATTR
    attr.location = (-200, 0)

    links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])

    return mat


def ensure_color_attribute(obj):
    attrs = obj.data.color_attributes
    if COLOR_ATTR in attrs:
        return False
    attrs.new(name=COLOR_ATTR, type="BYTE_COLOR", domain="CORNER")
    attrs.active_color = attrs[COLOR_ATTR]
    print(f"[material] {obj.name}: added '{COLOR_ATTR}' colour attribute")
    return True


def apply_to_all(mat):
    changed = 0
    for obj in [o for o in bpy.data.objects if o.type == "MESH"]:
        if ensure_color_attribute(obj):
            changed += 1
        mats = obj.data.materials
        if len(mats) == 0:
            mats.append(mat)
            print(f"[material] {obj.name}: assigned {MATERIAL_NAME}")
            changed += 1
        elif len(mats) > 1 or mats[0] != mat:
            mats.clear()
            mats.append(mat)
            print(f"[material] {obj.name}: replaced material(s) with {MATERIAL_NAME}")
            changed += 1
    return changed


def find_palette():
    """Locate data/palette.json relative to this script, not the caller's working directory."""
    here = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.abspath(os.path.join(here, "..", ".."))
    candidates = [os.path.join(repo_root, PALETTE_PATH), PALETTE_PATH]
    for p in candidates:
        if os.path.exists(p):
            return p
    return None


def report_palette():
    """Print the palette so it is visible in the scripting console while modelling."""
    p = find_palette()
    if p is None:
        print(f"[palette] {PALETTE_PATH} not found — skipping palette report")
        return

    with open(p, encoding="utf-8") as f:
        palette = json.load(f)

    # Keys beginning with "_" are documentation, not colours.
    entries = {k: v for k, v in palette.items() if not k.startswith("_")}
    print(f"[palette] {len(entries)} entries from {p}:")
    for key, entry in entries.items():
        print(f"    {key:<20} {entry['hex']:<9} {entry.get('note', '')}")


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else []
    save = "--save" in args

    mat = build_material()
    changed = apply_to_all(mat)

    # Save before reporting: the file is the point, the palette print is a convenience.
    print(f"[material] {changed} change(s)")
    if save and bpy.data.filepath:
        bpy.ops.wm.save_mainfile()
        print(f"[material] saved {bpy.data.filepath}")
    elif changed:
        print("[material] not saved (pass -- --save to write the file)")

    report_palette()


if __name__ == "__main__":
    # Blender exits 0 even when a Python script raises, which would silently defeat any
    # build gate built on these scripts. Force a non-zero exit on failure.
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
