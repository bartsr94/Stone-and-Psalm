"""Create the ground-cover props: the grass clump and the moor tuft.

Run from the repository root with:

    blender --background --python tools/blender/create_ground_cover_props.py

**Why this exists.** Every reference image this project is chasing (the In-The-Nature look,
2026-09-07) is dense with ground cover at the camera's own scale, and a meadow drawn as one
green plane — however well its colour is broken up — is the first thing that says "game" rather
than "place". These two props are instanced in the tens of thousands by
`scripts/view/vegetation_renderer.gd`, so they are built to be almost free: a clump is a fan of
single-sided blade quads (the grass shader is `cull_disabled`, so a quad reads from both sides)
at two triangles a blade, and nothing here casts a shadow.

The blades are coloured dark at the root and pale at the tip. That gradient is what the wind
sway in `assets/materials/grass.gdshader` bends along, and what makes ten thousand identical
clumps read as grass rather than as a carpet of green triangles. The season's ground tint and a
per-instance colour are multiplied in by the shader, so there is no need for autumn or winter
variants of the mesh.

Same contract as every other prop: one mesh, one shared vertex-colour material, no UVs, origin at
the ground centre. `meshkit.py` does the palette lookup and the sRGB-to-linear conversion.
"""

import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from meshkit import MeshBuilder, build_all, finish, mix  # noqa: E402


def _blade(b, base, direction, height, width, lean, root_colour, tip_colour, bend=0.55):
    """One blade: two stacked quads, bending over toward `direction` as they rise.

    The lower quad leans a little and the upper quad leans more, so the blade curves rather than
    sticking out straight like a spike; the split also gives the wind shader a mid-point to
    hinge on."""
    bx, by, bz = base
    dx, dy = direction
    sx, sy = -dy * width * 0.5, dx * width * 0.5
    # Root, knee, tip along the blade's own curve.
    knee = (bx + dx * lean * bend * height, by + dy * lean * bend * height, bz + height * 0.55)
    tip = (bx + dx * lean * height, by + dy * lean * height, bz + height)
    mid_colour = mix(root_colour, tip_colour, 0.5)
    b.quad((bx - sx, by - sy, bz), (bx + sx, by + sy, bz),
           (knee[0] + sx * 0.7, knee[1] + sy * 0.7, knee[2]),
           (knee[0] - sx * 0.7, knee[1] - sy * 0.7, knee[2]), mid_colour)
    b.triangle((knee[0] - sx * 0.7, knee[1] - sy * 0.7, knee[2]),
               (knee[0] + sx * 0.7, knee[1] + sy * 0.7, knee[2]), tip, tip_colour)
    # Root shading: paint the bottom quad's lower edge darker by adding a thin dark collar.
    b.quad((bx - sx, by - sy, bz), (bx + sx, by + sy, bz),
           (bx + sx * 0.95, by + sy * 0.95, bz + height * 0.14),
           (bx - sx * 0.95, by - sy * 0.95, bz + height * 0.14), root_colour)


def make_grass_clump():
    """A meadow clump: ten blades in a loose ring, leaning outward, 0.45–0.75 m tall.

    Real meadow grass at hay height, not lawn; the valley is unmown pasture and the point of the
    clump is that it stands up into the low sun."""
    rng = random.Random(0x6A55)
    b = MeshBuilder()
    # Kept close to the meadow's own colour: a clump a shade darker than the ground read as a
    # dark spike on the first pass. Only the root sits in shade; the tips go toward straw.
    root = mix("grass_summer", "soil", 0.28)
    tip = mix("grass_summer", "crop_ripe", 0.45)
    blades = 10
    for i in range(blades):
        angle = math.tau * i / blades + rng.uniform(-0.25, 0.25)
        direction = (math.cos(angle), math.sin(angle))
        radius = rng.uniform(0.03, 0.14)
        base = (direction[0] * radius, direction[1] * radius, 0.0)
        height = rng.uniform(0.45, 0.78)
        lean = rng.uniform(0.28, 0.62)
        width = rng.uniform(0.06, 0.10)
        shade = rng.uniform(0.0, 0.35)
        _blade(b, base, direction, height, width, lean,
               mix(root, "foliage_dark", shade), mix(tip, "grass_spring", shade))
    finish("prop_grass_clump", b)


def make_moor_tuft():
    """A moor tuft: shorter, tighter, browner — cotton-grass and heather rather than pasture.

    The moor tops read as a different country from the dale floor, and that difference is most
    of what says "Yorkshire" from a distance. The tint is baked in dark and warm so the seasonal
    ground tint still lands on it but it never reads as lush."""
    rng = random.Random(0x3B21)
    b = MeshBuilder()
    root = mix("moor_heather", "soil", 0.5)
    tip = mix("bracken", "grass_autumn", 0.45)
    blades = 9
    for i in range(blades):
        angle = math.tau * i / blades + rng.uniform(-0.3, 0.3)
        direction = (math.cos(angle), math.sin(angle))
        radius = rng.uniform(0.02, 0.10)
        base = (direction[0] * radius, direction[1] * radius, 0.0)
        height = rng.uniform(0.22, 0.42)
        lean = rng.uniform(0.35, 0.75)
        width = rng.uniform(0.05, 0.08)
        shade = rng.uniform(0.0, 0.4)
        _blade(b, base, direction, height, width, lean,
               mix(root, "charcoal", shade * 0.5), mix(tip, "moor_heather", shade), bend=0.5)
    finish("prop_moor_tuft", b)


def main():
    build_all((make_grass_clump, make_moor_tuft), "ground cover")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
