"""Create the low-poly props that mark the first monastic foundation.

These are deliberately presentation-scale placeholders for the Phase 1 valley. They follow the
same contract as the vegetation assets: one mesh, one vertex-colour material, no UVs, and a
ground-centred origin. The final church and buildings remain hero assets to be modelled by hand.

Run from the repository root with:

    blender --background --python tools/blender/create_foundation_props.py

The generated .blend files are then exported by export_gltf.py.

Mesh building, the palette and the save conventions all live in `meshkit.py` — including
the sRGB-to-linear conversion every vertex colour needs, which is documented there.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from meshkit import MeshBuilder, build_all, finish  # noqa: E402


def make_founders_cross():
    b = MeshBuilder()
    b.cylinder((0.0, 0.0, 0.0), 0.58, 0.28, 8, "limestone_shadow", "limestone_mid")
    b.cylinder((0.0, 0.0, 0.28), 0.25, 2.20, 8, "limestone_mid", "limestone_light")
    b.box((0.0, 0.0, 1.63), (1.24, 0.34, 0.34), "limestone_mid", "limestone_light")
    b.box((0.0, 0.0, 2.20), (0.44, 0.30, 0.40), "limestone_shadow", "limestone_mid")
    finish("prop_founders_cross", b)


def make_timber_shelter():
    b = MeshBuilder()
    # Four squat posts and two ridge rails make a readable temporary shelter at wide zoom.
    for x in (-1.35, 1.35):
        for y in (-0.90, 0.90):
            b.box((x, y, 0.95), (0.22, 0.22, 1.90), "oak_weathered", "oak_fresh")
    b.box((0.0, -0.90, 1.82), (3.0, 0.22, 0.22), "oak_dark", "oak_fresh")
    b.box((0.0, 0.90, 1.82), (3.0, 0.22, 0.22), "oak_dark", "oak_fresh")
    # A simple pitched roof, with the open gable facing the approach.
    front = ((-1.62, -1.12, 1.72), (1.62, -1.12, 1.72), (0.0, -1.12, 2.90))
    back = ((-1.62, 1.12, 1.72), (1.62, 1.12, 1.72), (0.0, 1.12, 2.90))
    b.quad(front[0], front[1], back[1], back[0], "oak_weathered")
    b.quad(front[1], front[2], back[2], back[1], "oak_fresh")
    b.quad(front[2], front[0], back[0], back[2], "oak_dark")
    b.triangle(front[0], front[2], front[1], "oak_dark")
    b.triangle(back[1], back[2], back[0], "oak_weathered")
    finish("prop_timber_shelter", b)


def make_campfire():
    b = MeshBuilder()
    for i in range(8):
        angle = math.tau * i / 8.0
        b.cylinder((math.cos(angle) * 0.72, math.sin(angle) * 0.72, 0.0),
                   0.22, 0.28, 7, "stone_weathered", "limestone_light")
    b.cylinder((-0.48, 0.0, 0.23), 0.15, 1.05, 7, "oak_dark", "oak_fresh", "x")
    b.cylinder((0.0, -0.48, 0.31), 0.15, 1.05, 7, "oak_weathered", "oak_fresh", "x")
    b.cylinder((0.0, 0.0, 0.28), 0.25, 0.48, 7, "charcoal", "fire")
    finish("prop_campfire", b)


def main():
    build_all((make_founders_cross, make_timber_shelter, make_campfire), "foundation")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
