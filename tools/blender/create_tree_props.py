"""Create the two woodland trees, at the size a real tree in a Yorkshire dale actually is.

Run from the repository root with:

    blender --background --python tools/blender/create_tree_props.py

**Why this script exists.** The first pass authored the broadleaf at 2.95 m and the pine at
4.10 m tall. Standing on 2 m terrain cells beside a 3.2 m building, that is shrub height, and it
was the single largest reason the valley did not read like a wooded dale: the woodland band
rendered as a dark stripe of ground with specks on it, because the trees were shorter than the
huts. A mature oak is 12-18 m and a Scots pine 16-22 m, so the canopy has to be the tallest
thing in the frame until the church rises. Everything else in the graphics pass is downstream of
getting this one number right.

The shapes stay deliberately cheap — a faceted trunk and a handful of `blob` canopy masses for
the broadleaf, stacked cones for the pine — because these are MultiMesh-instanced in the
thousands and the prop triangle budget is 400 (`tools/blender/validate_assets.py`).

Canopy colours must stay green-dominant: `assets/materials/veg_foliage.gdshader` decides what is
a leaf and what is a trunk by how far the green channel sits above red and blue, and recolours
only the leaves through the seasons. A canopy authored in a brown-green would go bare in summer.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from meshkit import MeshBuilder, build_all, finish, mix  # noqa: E402


def make_tree_broadleaf():
    """An oak, ~14 m to the crown. Three canopy tiers of overlapping blobs, so the silhouette
    breaks up against the sky instead of reading as one ball on a stick."""
    rng = random.Random(0x0A4B12)
    b = MeshBuilder()

    # Trunk: two tapered segments, so the bole swells at the base the way a standard oak does.
    b.cylinder((0.0, 0.0, 0.0), 0.62, 2.30, 7, "oak_dark", "oak_weathered", top_radius=0.42)
    b.cylinder((0.0, 0.0, 2.30), 0.42, 3.60, 7, "oak_weathered", "oak_weathered", top_radius=0.26)

    # Three limbs leaving the bole where the canopy starts, each carrying a blob out with it.
    limbs = ((0.55, 5.30, 3.10), (2.60, 5.05, 2.85), (4.35, 5.55, 3.35))
    for angle, base_z, reach in limbs:
        direction = (math.cos(angle), math.sin(angle))
        rise = reach * 0.72
        tip = (direction[0] * reach, direction[1] * reach, base_z + rise)
        # A limb is one thin tapered cylinder aimed by hand: cheap, and only ever seen in
        # silhouette through the canopy.
        b.quad(
            (-0.16, -0.16, base_z), (0.16, 0.16, base_z),
            (tip[0] + 0.07, tip[1] + 0.07, tip[2]), (tip[0] - 0.07, tip[1] - 0.07, tip[2]),
            "oak_dark",
        )

    # Canopy: a wide low tier, a broad middle, and a narrower crown.
    tiers = (
        ((-2.55, -0.85, 7.40), 2.70),
        ((2.35, 1.15, 7.90), 2.55),
        ((0.35, -2.45, 8.40), 2.40),
        ((-1.15, 1.95, 9.70), 2.75),
        ((1.55, -0.55, 10.30), 2.85),
        ((-0.25, 0.45, 12.00), 2.30),
    )
    for centre, radius in tiers:
        b.blob(centre, radius, "foliage_dark", squash=0.82, jitter=0.16, rng=rng,
               alt_colour="foliage_light")

    finish("prop_tree_broadleaf", b)


def make_tree_pine():
    """A Scots pine, ~17 m. Overlapping skirts rather than one cone: a single cone reads as a
    traffic bollard, and the gaps between skirts are what make a stand of them look like wood."""
    b = MeshBuilder()

    b.cylinder((0.0, 0.0, 0.0), 0.46, 3.20, 6, "oak_dark", "oak_weathered", top_radius=0.30)
    b.cylinder((0.0, 0.0, 3.20), 0.30, 13.40, 6, "oak_weathered", "oak_weathered", top_radius=0.10)

    # Base radius shrinks up the tree; each skirt is tall enough to overlap the one above it.
    skirts = (
        (2.60, 2.75, 3.10),
        (4.30, 2.55, 3.00),
        (6.00, 2.30, 2.85),
        (7.70, 2.00, 2.70),
        (9.40, 1.65, 2.55),
        (11.10, 1.28, 2.40),
        (12.80, 0.90, 2.30),
        (14.50, 0.52, 2.20),
    )
    for i, (z, radius, height) in enumerate(skirts):
        # Alternate the tint so the stacked skirts separate under a flat sky.
        colour = "foliage_dark" if i % 2 == 0 else mix("foliage_dark", "foliage_light", 0.45)
        b.cone((0.0, 0.0, z), radius, height, 9, colour, base_colour="foliage_dark")

    finish("prop_tree_pine", b)


def main():
    build_all((make_tree_broadleaf, make_tree_pine), "trees")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
