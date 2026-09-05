"""Create the small authored vegetation props used around the founding valley.

The output follows the same deliberately constrained contract as the hand-authored props:
one mesh object, one shared vertex-colour material, no UVs, and a ground-centred origin.
Run from the repository root with:

    blender --background --python tools/blender/create_vegetation_props.py

The generated .blend files are then exported by export_gltf.py.

Mesh building, the palette and the save conventions all live in `meshkit.py` — including
the sRGB-to-linear conversion every vertex colour needs, which is documented there.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from meshkit import MeshBuilder, build_all, finish  # noqa: E402


def make_stump():
    b = MeshBuilder()
    b.cylinder((0.0, 0.0, 0.0), 0.44, 0.78, 10, "oak_weathered", "oak_fresh")
    # Four low triangular root flares keep the silhouette grounded without becoming a building.
    for angle in (0.0, math.pi / 2.0, math.pi, math.pi * 1.5):
        direction = (math.cos(angle), math.sin(angle))
        side = (-direction[1], direction[0])
        base = (direction[0] * 0.34, direction[1] * 0.34, 0.02)
        left = (base[0] + side[0] * 0.16, base[1] + side[1] * 0.16, 0.02)
        right = (base[0] - side[0] * 0.16, base[1] - side[1] * 0.16, 0.02)
        tip = (direction[0] * 0.78, direction[1] * 0.78, 0.0)
        peak = (direction[0] * 0.30, direction[1] * 0.30, 0.44)
        b.triangle(left, right, peak, "oak_dark")
        b.triangle(right, tip, peak, "oak_weathered")
        b.triangle(tip, left, peak, "oak_fresh")
    finish("prop_stump", b)


def make_fallen_log():
    b = MeshBuilder()
    b.cylinder((-1.18, 0.0, 0.34), 0.32, 2.36, 10, "oak_weathered", "oak_fresh", "x")
    # A pair of short broken branches gives the log a readable profile at game distance.
    for x, y, z, radius, height in ((-0.55, 0.0, 0.54, 0.12, 0.48), (0.56, 0.02, 0.56, 0.10, 0.38)):
        b.cylinder((x, y, z), radius, height, 7, "oak_dark", "oak_fresh", "z")
    finish("prop_fallen_log", b)


def make_fern_clump():
    b = MeshBuilder()
    blade_count = 12
    for i in range(blade_count):
        angle = math.tau * i / blade_count
        lean = 0.30 + 0.10 * math.sin(i * 2.7)
        height = 0.62 + 0.25 * (0.5 + 0.5 * math.sin(i * 1.9))
        width = 0.11
        direction = (math.cos(angle), math.sin(angle))
        side = (-direction[1], direction[0])
        base = (0.0, 0.0, 0.02)
        shoulder = (direction[0] * lean * 0.45, direction[1] * lean * 0.45, height * 0.53)
        tip = (direction[0] * lean, direction[1] * lean, height)
        left = (shoulder[0] + side[0] * width, shoulder[1] + side[1] * width, shoulder[2])
        right = (shoulder[0] - side[0] * width, shoulder[1] - side[1] * width, shoulder[2])
        colour = "foliage_light" if i % 3 == 0 else "foliage_dark"
        b.triangle(base, left, tip, colour)
        b.triangle(base, tip, right, colour)
        b.triangle(left, right, tip, "foliage_light")
    b.cylinder((0.0, 0.0, 0.0), 0.16, 0.18, 7, "bracken", "foliage_dark")
    finish("prop_fern_clump", b)


def make_reeds():
    b = MeshBuilder()
    stems = ((-0.24, -0.08, 1.35), (-0.08, 0.04, 1.72), (0.10, -0.05, 1.48),
             (0.25, 0.05, 1.62), (-0.16, 0.16, 1.18), (0.05, 0.18, 1.28))
    for i, (x, y, height) in enumerate(stems):
        b.cylinder((x, y, 0.0), 0.035, height, 5, "bracken", "foliage_light")
        # One pair of flat, tapered leaves per stem keeps the silhouette legible and cheap.
        angle = math.tau * (i / len(stems) + 0.17)
        direction = (math.cos(angle), math.sin(angle))
        for side_sign in (-1.0, 1.0):
            z = height * (0.42 + 0.08 * (i % 2))
            root = (x, y, z)
            tip = (x + direction[0] * 0.25 * side_sign, y + direction[1] * 0.25 * side_sign, z + 0.30)
            side = (-direction[1] * 0.035, direction[0] * 0.035, 0.0)
            b.triangle((root[0] - side[0], root[1] - side[1], root[2]),
                       (root[0] + side[0], root[1] + side[1], root[2]), tip,
                       "foliage_light" if i % 2 else "bracken")
    finish("prop_river_reeds", b)


def main():
    build_all((make_stump, make_fallen_log, make_fern_clump, make_reeds), "props")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
