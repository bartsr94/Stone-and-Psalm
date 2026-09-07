"""Create the woodland trees, at the size a real tree in a Yorkshire dale actually is.

Run from the repository root with:

    blender --background --python tools/blender/create_tree_props.py

**Why this script exists.** The first pass authored the broadleaf at 2.95 m and the pine at
4.10 m tall. Standing on 2 m terrain cells beside a 3.2 m building, that is shrub height, and it
was the single largest reason the valley did not read like a wooded dale: the woodland band
rendered as a dark stripe of ground with specks on it, because the trees were shorter than the
huts. A mature oak is 12-18 m and a Scots pine 16-22 m, so the canopy has to be the tallest
thing in the frame until the church rises. Everything else in the graphics pass is downstream of
getting this one number right.

**The second pass (In-The-Nature look, 2026-09-07) is about silhouette.** Six big faceted balls
read as a cluster of balls, and eight stacked cones read as a traffic bollard; neither reads as
a tree against the sky, which is the one view a tree on a hillside is always seen in. So:

- The **oak** is built from many smaller, heavily jittered canopy masses in three irregular
  tiers, with visible limbs between them. Gaps in the crown are the point — sky shows through a
  real oak.
- The **Scots pine** is the native conifer, and a native conifer has a tall *bare* trunk with
  the foliage held in flat, layered plates near the top, not a Christmas-tree skirt to the
  ground. Its upper bark is orange-red, which is the one colour note that separates a pine
  stand from a dark green smear.
- A **birch** joins them: slender, pale-trunked, with a light and open crown. A wood of one
  species reads as a plantation; a third silhouette and a third green break that up more than
  any amount of scale jitter.

The shapes stay cheap — a faceted trunk and `blob` canopy masses — because these are MultiMesh-
instanced in the thousands and the prop triangle budget is 400 (`tools/blender/validate_assets.py`).

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


def _limb(b, base, tip, root_radius, tip_radius, colour):
    """A limb as a twisted quad pair: two crossed quads read as a round branch from any angle
    at a quarter of a cylinder's cost."""
    bx, by, bz = base
    tx, ty, tz = tip
    for sx, sy in ((1.0, 0.0), (0.0, 1.0)):
        b.quad((bx - sx * root_radius, by - sy * root_radius, bz),
               (bx + sx * root_radius, by + sy * root_radius, bz),
               (tx + sx * tip_radius, ty + sy * tip_radius, tz),
               (tx - sx * tip_radius, ty - sy * tip_radius, tz), colour)


def make_tree_broadleaf():
    """An oak, ~14 m to the crown. Ten canopy masses in three loose tiers, each a different
    size and a slightly different green, with limbs reaching out to the lower ones."""
    rng = random.Random(0x0A4B12)
    b = MeshBuilder()

    # Trunk: two tapered segments, so the bole swells at the base the way a standard oak does.
    b.cylinder((0.0, 0.0, 0.0), 0.66, 2.40, 7, "oak_dark", "oak_weathered", top_radius=0.44)
    b.cylinder((0.0, 0.0, 2.40), 0.44, 3.90, 7, "oak_weathered", "oak_weathered", top_radius=0.24)

    # Limbs leaving the bole where the canopy starts, each carrying a mass out with it.
    limbs = ((0.45, 5.6, 3.4), (2.20, 5.3, 3.0), (3.90, 5.9, 3.6), (5.30, 6.3, 2.6))
    for angle, base_z, reach in limbs:
        direction = (math.cos(angle), math.sin(angle))
        tip = (direction[0] * reach, direction[1] * reach, base_z + reach * 0.85)
        _limb(b, (0.0, 0.0, base_z), tip, 0.20, 0.08, "oak_dark")

    # Canopy tiers: a wide low ring, a broad middle, a narrow crown. Radii are small and the
    # jitter is high so no two masses match and the outline is ragged rather than round.
    masses = []
    for i, (angle, base_z, reach) in enumerate(limbs):
        direction = (math.cos(angle), math.sin(angle))
        masses.append(((direction[0] * reach * 1.05, direction[1] * reach * 1.05,
                        base_z + reach * 0.85 + 0.9), 2.05 + 0.15 * (i % 2)))
    masses += [
        ((-1.10, 1.60, 9.60), 2.30),
        ((1.55, -1.10, 9.90), 2.20),
        ((0.10, 2.30, 10.90), 1.95),
        ((-1.70, -1.50, 10.40), 2.05),
        ((0.90, 0.70, 12.10), 2.10),
        ((-0.40, -0.30, 13.10), 1.65),
    ]
    for i, (centre, radius) in enumerate(masses):
        # Lower masses sit in their own shade; the crown catches the light.
        lift = min(1.0, max(0.0, (centre[2] - 7.0) / 6.0))
        dark = mix("foliage_dark", "oak_dark", 0.18 * (1.0 - lift))
        light = mix("foliage_light", "grass_spring", 0.35 * lift + 0.15 * (i % 3) / 2.0)
        b.blob(centre, radius, dark, squash=0.72 + 0.06 * (i % 3), jitter=0.26, rng=rng,
               alt_colour=light)

    finish("prop_tree_broadleaf", b)


def make_tree_pine():
    """A Scots pine, ~18 m: a tall bare trunk going orange toward the top, two thin lower
    skirts where old branches persist, and a crown of flat plates."""
    rng = random.Random(0x51C0)
    b = MeshBuilder()

    upper_bark = mix("russet", "oak_fresh", 0.45)
    b.cylinder((0.0, 0.0, 0.0), 0.50, 4.00, 6, "oak_dark", "oak_weathered", top_radius=0.36)
    b.cylinder((0.0, 0.0, 4.00), 0.36, 7.20, 6, mix("oak_weathered", upper_bark, 0.5), upper_bark,
               top_radius=0.24)
    b.cylinder((0.0, 0.0, 11.20), 0.24, 5.60, 6, upper_bark, upper_bark, top_radius=0.09)

    # Two sparse skirts low on the crown: the branches a pine keeps below its living plates.
    dark = "foliage_dark"
    mid = mix("foliage_dark", "foliage_light", 0.35)
    b.cone((0.0, 0.0, 8.20), 2.10, 1.90, 8, dark, base_colour=mix(dark, "oak_dark", 0.3))
    b.cone((0.0, 0.0, 10.10), 1.75, 1.70, 8, mid, base_colour=mix(dark, "oak_dark", 0.3))

    # The crown: flattened plates of foliage, stepped and offset, narrowing to a tip.
    plates = (
        ((0.60, -0.30, 11.90), 2.60, 0.42),
        ((-0.70, 0.55, 12.90), 2.35, 0.40),
        ((0.35, 0.65, 13.95), 2.05, 0.42),
        ((-0.30, -0.60, 14.95), 1.75, 0.44),
        ((0.15, 0.10, 15.95), 1.35, 0.50),
        ((0.00, 0.00, 16.85), 0.85, 0.75),
    )
    for i, (centre, radius, squash) in enumerate(plates):
        colour = dark if i % 2 == 0 else mid
        b.blob(centre, radius, colour, squash=squash, jitter=0.20, rng=rng,
               alt_colour=mix(colour, "foliage_light", 0.5))

    finish("prop_tree_pine", b)


def make_tree_birch():
    """A birch, ~11 m: a slender pale trunk that forks, and a light, open crown of small
    masses in a fresh green. The tree that lets sky into a wood."""
    rng = random.Random(0x7B1E)
    b = MeshBuilder()

    bark = mix("linen", "limestone_mid", 0.35)
    bark_dark = mix(bark, "charcoal", 0.35)
    b.cylinder((0.0, 0.0, 0.0), 0.26, 3.60, 6, bark_dark, bark, top_radius=0.19)
    b.cylinder((0.0, 0.0, 3.60), 0.19, 4.40, 6, bark, bark, top_radius=0.11)
    # The fork: two leaders leaning apart from ~5 m.
    for angle, lean in ((0.9, 1.30), (3.9, 1.05)):
        direction = (math.cos(angle), math.sin(angle))
        _limb(b, (0.0, 0.0, 5.20),
              (direction[0] * lean, direction[1] * lean, 9.60), 0.12, 0.05, bark)

    leaf = mix("foliage_light", "grass_spring", 0.55)
    leaf_dark = mix("foliage_light", "foliage_dark", 0.4)
    masses = (
        ((0.95, 0.70, 7.60), 1.45),
        ((-0.85, -0.55, 7.20), 1.35),
        ((0.35, -1.10, 8.70), 1.40),
        ((-0.55, 0.95, 9.10), 1.30),
        ((0.75, 0.15, 10.10), 1.25),
        ((-0.20, -0.25, 11.00), 1.05),
    )
    for i, (centre, radius) in enumerate(masses):
        b.blob(centre, radius, leaf_dark if i % 2 else mix(leaf_dark, leaf, 0.4), squash=1.15,
               jitter=0.30, rng=rng, alt_colour=leaf)

    finish("prop_tree_birch", b)


def main():
    build_all((make_tree_broadleaf, make_tree_pine, make_tree_birch), "trees")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
