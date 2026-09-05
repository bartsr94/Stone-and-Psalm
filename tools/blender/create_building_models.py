"""Create one `bld_*.blend` per building type in `data/buildings.json`.

Run from the repository root with:

    blender --background --python tools/blender/create_building_models.py

These replace the greybox boxes `scripts/view/buildings_renderer.gd` drew for Phase 4. A box
with a flatter box on top is a fine stand-in for "a building exists here" and a poor one for
"this is a twelfth-century Yorkshire monastery", because the whole silhouette of the period is
in the parts a box has none of: a steep roof, a deep eaves overhang, a stone plinth under
timber walls, and studwork breaking up the wall face.

**Sizes are derived from `data/buildings.json`, not typed in twice.** Each model is built to its
own `footprint_cells` × the terrain cell size, so the mesh and the simulation's footprint can
never disagree. Change a footprint in the JSON, re-run this, and the model follows.

Three conventions the renderer depends on:

- **Origin at the footprint centre, on the ground.** `meshkit.finish` enforces it.
- **Authored long-axis-along-X, then swapped.** A ridge runs down a building's long axis, so the
  shape code always builds the long axis as X and `swap_xy()` turns it where the footprint is
  deeper than it is wide.
- **Walls are inset from the footprint edge so the eaves overhang lands back on it.** Without
  that inset the roof of one building overhangs the plot of the next.
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from meshkit import ROOT, MeshBuilder, build_all, finish, mix  # noqa: E402

CELL_M = 2.0          # world.terrain_cell_m; the one number this shares with the sim
WALL_INSET_M = 0.55   # walls stand back from the plot edge, so the eaves sit inside it
EAVES_M = 0.48        # the overhang that does most of the work of reading as medieval


def building_types():
    with open(os.path.join(ROOT, "data", "buildings.json"), "r", encoding="utf-8") as handle:
        parsed = json.load(handle)
    return {k: v for k, v in parsed.items() if not k.startswith("_")}


TYPES = building_types()


def precinct_buildings():
    """`data/precinct.json`'s greybox church and dormitory, keyed by id.

    These are not `Buildings` entries — they are the Phase 3 precinct the first monk walks
    between, placed by `Population` rather than by the player — but they are the largest things
    on screen, so they get authored models on the same terms as everything else. Their `size_m`
    is [width, height, length], with the ridge running down the length."""
    with open(os.path.join(ROOT, "data", "precinct.json"), "r", encoding="utf-8") as handle:
        parsed = json.load(handle)
    return {entry["id"]: entry for entry in parsed.get("buildings", [])}


PRECINCT = precinct_buildings()


def plot_size(type_id):
    """The building's footprint in metres, long axis first, plus whether it was swapped."""
    cells = TYPES[type_id]["footprint_cells"]
    x, y = cells[0] * CELL_M, cells[1] * CELL_M
    return (x, y, False) if x >= y else (y, x, True)


# --- shared shape vocabulary ---------------------------------------------------------------
#
# Everything below exists to solve one problem: with no textures anywhere in this project
# (Architecture Guide 4.1), a building's entire surface interest has to be geometry and vertex
# colour. A box with a roof on it reads as a placeholder no matter how well it is lit. So the
# vocabulary here is the real construction vocabulary of the period, at four to forty triangles
# a part: a rubble plinth in courses, a timber frame with limewashed infill between the studs,
# coursed stone for the buildings that are stone, and roofs laid in courses rather than as one
# flat plane.

FRAME = "oak_dark"          # the structural timber: posts, rails, studs, braces
FRAME_LIGHT = "oak_weathered"
FRAME_PROUD = 0.075         # how far a frame member stands off the infill behind it

# Two infills, and which one a building gets is a statement about the building. Limewash was
# bought and applied; a working shed in the outer court got bare daub and stayed brown. Using
# both stops nine buildings in a row reading as one repeated Tudor cottage, and it is the honest
# distinction: the granary and the wool store hold things worth protecting, the sawpit does not.
INFILL = "lime_render"
INFILL_DAUB = "mortar"


def plinth(b, width, depth, height, colour, courses=2):
    """The rubble footing every building of the period stands on, laid in courses.

    It also gives the wall a dark line at ground level, which is what stops a model looking like
    it is floating, and the courses stop the footing reading as a solid slab of one colour."""
    shades = (colour, mix(colour, "limestone_light", 0.30), mix(colour, "oak_dark", 0.22))
    for i in range(courses):
        z = height * i / courses
        # Each course steps in slightly, so the footing batters the way dry-laid rubble does.
        inset = 0.34 - 0.10 * i
        b.box((0.0, 0.0, z + height * 0.5 / courses),
              (width + inset, depth + inset, height / courses),
              shades[i % 3], top_colour=mix(colour, "limestone_light", 0.45))


def stone_walls(b, width, depth, base_z, height, colour, courses=5, quoins=True,
                rubble_block_m=1.15):
    """Coursed rubble walling with dressed quoins at the corners.

    A stone building drawn as one box is four flat rectangles of identical colour, which at this
    camera reads as cardboard.

    The shade spread here is deliberately wide. Vertex colours are stored linear
    (`meshkit.py`), and a mix of 0.15 in linear space is a much smaller *perceived* step than the
    same number in sRGB — the first pass used gentle mixes and the coursing simply did not
    appear. Contrast that looks excessive in the numbers is about right on screen."""
    shades = (mix(colour, "limestone_shadow", 0.45),
              mix(colour, "limestone_light", 0.40),
              colour,
              mix(colour, "limestone_light", 0.20),
              mix(colour, "oak_dark", 0.22))
    for i in range(courses):
        z = base_z + height * i / courses
        # Alternate courses sit proud, so a low sun rakes across them and throws its own line.
        proud = 0.025 if i % 2 else 0.0
        top = mix(colour, "limestone_light", 0.5) if i == courses - 1 else None
        b.box((0.0, 0.0, z + height * 0.5 / courses),
              (width + proud, depth + proud, height / courses),
              shades[i % len(shades)], top_colour=top)

    # Individual rubble faces break the remaining broad courses into hand-sized stones. They sit
    # only a finger proud of the structural wall: enough for raking light and AO, without making
    # the wall look assembled from toy bricks.
    for face in ("-y", "+y", "-x", "+x"):
        along_y = face.endswith("y")
        span = width if along_y else depth
        plane = (depth if along_y else width) * 0.5
        sign = -1.0 if face.startswith("-") else 1.0
        for row in range(courses):
            course_h = height / courses
            blocks = max(3, int(span / rubble_block_m))
            block_w = span / blocks
            stagger = block_w * 0.5 if row % 2 else 0.0
            for column in range(blocks + 1):
                left = -span * 0.5 + column * block_w - stagger
                right = left + block_w
                clipped_left, clipped_right = max(-span * 0.5, left), min(span * 0.5, right)
                if clipped_right - clipped_left < 0.22:
                    continue
                variation = ((row * 7 + column * 11) % 5) / 4.0
                shade = mix(colour, "limestone_light", 0.06 + variation * 0.24)
                along = (clipped_left + clipped_right) * 0.5
                z = base_z + (row + 0.5) * course_h
                centre = ((along, plane * sign, z) if along_y
                          else (plane * sign, along, z))
                b.panel(face, centre,
                        (clipped_right - clipped_left - 0.055, course_h * 0.78),
                        shade, offset=0.045 + variation * 0.012)

    if quoins:
        # Dressed corner stones, alternating long-and-short up each angle. Quoins are the single
        # most legible thing about a stone building at distance: they draw the corner as a line.
        blocks = max(3, courses + 1)
        for sx in (-1.0, 1.0):
            for sy in (-1.0, 1.0):
                for i in range(blocks):
                    z = base_z + height * (i + 0.5) / blocks
                    long_side = i % 2 == 0
                    size_x, size_y = (0.78, 0.42) if long_side else (0.42, 0.78)
                    b.box(((width * 0.5 - size_x * 0.5 + 0.12) * sx,
                           (depth * 0.5 - size_y * 0.5 + 0.12) * sy, z),
                          (size_x, size_y, height / blocks * 0.78),
                          mix(colour, "limestone_light", 0.55 if long_side else 0.34),
                          top_colour=mix(colour, "limestone_light", 0.7))


def buttress(b, x, y, base_z, height, width_m, depth_m, colour):
    """A stepped buttress with a weathered set-off at the top, rather than a plain slab.

    The set-off is what makes it read as masonry doing a job: a vertical box against a vertical
    wall just looks like a dark stripe."""
    b.box((x, y, base_z + height * 0.42), (width_m, depth_m, height * 0.84),
          mix(colour, "limestone_light", 0.18),
          top_colour=mix(colour, "limestone_light", 0.55))
    b.box((x, y * 0.86, base_z + height * 0.84 + height * 0.06),
          (width_m * 0.88, depth_m * 0.7, height * 0.12),
          mix(colour, "limestone_light", 0.34),
          top_colour=mix(colour, "limestone_light", 0.62))


def timber_walls(b, width, depth, base_z, height, brace=True, infill=INFILL):
    """A timber frame with limewashed infill: the outer-court building of a Yorkshire house.

    The infill is the wall box itself, in `lime_render`; every frame member is a panel standing
    proud of it, plus real boxes at the corners so the posts read in silhouette as well as in
    shading. Dark frame against pale panel is the single most recognisable thing about an English
    timber-framed building, and it costs about eighty triangles."""
    b.box((0.0, 0.0, base_z + height * 0.5), (width, depth, height),
          infill, top_colour=mix(infill, FRAME, 0.5))

    post = 0.24
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            b.box(((width * 0.5 - post * 0.35) * sx, (depth * 0.5 - post * 0.35) * sy,
                   base_z + height * 0.5),
                  (post, post, height), FRAME, top_colour=FRAME_LIGHT)

    for face in ("-y", "+y", "-x", "+x"):
        along_y = face.endswith("y")
        span = width if along_y else depth
        sign = -1.0 if face.startswith("-") else 1.0

        def rail(z, thick):
            if along_y:
                b.panel(face, (0.0, depth * 0.5 * sign, z), (span, thick), FRAME, FRAME_PROUD)
            else:
                b.panel(face, (width * 0.5 * sign, 0.0, z), (span, thick), FRAME, FRAME_PROUD)

        # The daub was mixed and repaired bay by bay, never a perfectly uniform rendered slab.
        # Keep the variation restrained so the frame remains the read at game distance.
        bays = max(1, int(span / 1.9))
        bay_w = span / bays
        rows = ((base_z + height * 0.31, height * 0.38),
                (base_z + height * 0.76, height * 0.38))
        for bay in range(bays):
            along = -span * 0.5 + (bay + 0.5) * bay_w
            for row, (z, panel_h) in enumerate(rows):
                ageing = 0.025 + ((bay * 3 + row * 5) % 4) * 0.018
                shade = mix(infill, "oak_weathered", ageing)
                centre = ((along, depth * 0.5 * sign, z) if along_y
                          else (width * 0.5 * sign, along, z))
                b.panel(face, centre, (max(0.18, bay_w - 0.18), panel_h),
                        shade, FRAME_PROUD * 0.28)

        rail(base_z + 0.14, 0.26)               # sill beam
        rail(base_z + height * 0.54, 0.18)      # mid rail
        rail(base_z + height - 0.15, 0.28)      # wall plate

        # Studs between the rails, in both the lower and the upper panel.
        studs = max(1, int(span / 1.9))
        for i in range(1, studs):
            offset = -span * 0.5 + span * i / studs
            for z, tall in ((base_z + height * 0.34, height * 0.30),
                            (base_z + height * 0.77, height * 0.36)):
                if along_y:
                    b.panel(face, (offset, depth * 0.5 * sign, z), (0.14, tall), FRAME,
                            FRAME_PROUD)
                else:
                    b.panel(face, (width * 0.5 * sign, offset, z), (0.14, tall), FRAME,
                            FRAME_PROUD)

    if brace:
        # True curved-growth corner braces. A continuous diagonal reads as joined carpentry in a
        # close camera view; the former staircase of horizontal bars read as a UI stripe.
        for sy in (-1.0, 1.0):
            face = "+y" if sy > 0 else "-y"
            for sx in (-1.0, 1.0):
                b.diagonal_panel(
                    face, depth * 0.5 * sy,
                    ((width * 0.5 - 1.45) * sx, base_z + height * 0.56),
                    ((width * 0.5 - 0.18) * sx, base_z + height - 0.22),
                    0.18, FRAME, FRAME_PROUD + 0.01)


def shingle_surface(b, span_x, span_y, eaves_z, height, colour, courses):
    """Overlapping, staggered oak shingles laid over the structural roof planes."""
    hx, hy = span_x * 0.5, span_y * 0.5
    rows = max(5, courses)
    columns = max(4, min(18, int(span_x / 1.15)))
    tile_w = span_x / columns
    slope_length = math.hypot(hy, height)
    normal_y = height / slope_length
    normal_z = hy / slope_length
    lift = 0.035
    for slope in (-1.0, 1.0):
        for row in range(rows):
            t0, t1 = row / rows, (row + 1) / rows
            y0 = slope * hy * (1.0 - t0) + slope * lift * normal_y
            y1 = slope * hy * (1.0 - t1) + slope * lift * normal_y
            z0 = eaves_z + height * t0 + lift * normal_z
            z1 = eaves_z + height * t1 + lift * normal_z
            start = -hx - (tile_w * 0.5 if row % 2 else 0.0)
            for column in range(columns + 1):
                left = max(-hx, start + column * tile_w) + 0.025
                right = min(hx, start + (column + 1) * tile_w) - 0.025
                if right - left < 0.12:
                    continue
                weathering = ((row * 5 + column * 3 + (1 if slope > 0 else 0)) % 6) / 5.0
                shade = mix(colour, "oak_dark", 0.04 + weathering * 0.24)
                if slope < 0:
                    b.quad((left, y0, z0), (right, y0, z0),
                           (right, y1, z1), (left, y1, z1), shade)
                else:
                    b.quad((right, y0, z0), (left, y0, z0),
                           (left, y1, z1), (right, y1, z1), shade)


def lead_sheet_surface(b, span_x, span_y, eaves_z, height, colour):
    """Broad lead sheets with staggered rolls, replacing an undifferentiated grey plane."""
    hx, hy = span_x * 0.5, span_y * 0.5
    rows = 3
    columns = max(4, min(10, int(span_x / 1.8)))
    sheet_w = span_x / columns
    slope_length = math.hypot(hy, height)
    lift_y = height / slope_length * 0.025
    lift_z = hy / slope_length * 0.025
    for slope in (-1.0, 1.0):
        for row in range(rows):
            t0, t1 = row / rows, (row + 1) / rows
            y0 = slope * (hy * (1.0 - t0) + lift_y)
            y1 = slope * (hy * (1.0 - t1) + lift_y)
            z0 = eaves_z + height * t0 + lift_z
            z1 = eaves_z + height * t1 + lift_z
            offset = sheet_w * 0.5 if row % 2 else 0.0
            for column in range(columns + 1):
                left = max(-hx, -hx + column * sheet_w - offset) + 0.018
                right = min(hx, -hx + (column + 1) * sheet_w - offset) - 0.018
                if right - left < 0.12:
                    continue
                shade = mix(colour, "slate", 0.04 + ((row + column) % 4) * 0.035)
                if slope < 0:
                    b.quad((left, y0, z0), (right, y0, z0),
                           (right, y1, z1), (left, y1, z1), shade)
                else:
                    b.quad((right, y0, z0), (left, y0, z0),
                           (left, y1, z1), (right, y1, z1), shade)


def thatch_fringe(b, span_x, span_y, eaves_z, colour):
    """Uneven hanging bundles that keep a thatched eave from ending as a ruler-straight box."""
    hx, hy = span_x * 0.5, span_y * 0.5
    bundles = max(8, min(22, int(span_x / 0.7)))
    bundle_w = span_x / bundles
    for slope in (-1.0, 1.0):
        y = slope * (hy + 0.235)
        for i in range(bundles):
            left = -hx + i * bundle_w
            right = left + bundle_w + 0.025
            drop = 0.15 + (i * 7 % 5) * 0.035
            shade = mix(colour, "thatch_old", 0.18 + (i * 3 % 4) * 0.09)
            corners = ((left, y, eaves_z + 0.08), (right, y, eaves_z + 0.08),
                       (right - 0.035, y, eaves_z - drop),
                       (left + 0.02, y, eaves_z - drop * 0.82))
            if slope < 0:
                corners = tuple(reversed(corners))
            b.quad(*corners, shade)


def thatch_weathering(b, span_x, span_y, eaves_z, height, colour):
    """Sparse, broad repairs and damp patches on an otherwise continuous thatched slope."""
    hx, hy = span_x * 0.5, span_y * 0.5
    rows = 5
    columns = max(5, min(14, int(span_x / 1.45)))
    patch_w = span_x / columns
    slope_length = math.hypot(hy, height)
    lift_y = height / slope_length * 0.025
    lift_z = hy / slope_length * 0.025
    for slope in (-1.0, 1.0):
        for row in range(rows):
            t0, t1 = row / rows, (row + 1) / rows
            y0 = slope * (hy * (1.0 - t0) + lift_y)
            y1 = slope * (hy * (1.0 - t1) + lift_y)
            z0 = eaves_z + height * t0 + lift_z
            z1 = eaves_z + height * t1 + lift_z
            for column in range(columns):
                if (row * 5 + column * 7 + (1 if slope > 0 else 0)) % 4:
                    continue
                left = -hx + column * patch_w + patch_w * 0.10
                right = min(hx, left + patch_w * 1.35)
                shade = mix(colour, "thatch_old", 0.08 + ((row + column) % 3) * 0.05)
                if slope < 0:
                    b.quad((left, y0, z0), (right, y0, z0),
                           (right, y1, z1), (left, y1, z1), shade)
                else:
                    b.quad((right, y0, z0), (left, y0, z0),
                           (left, y1, z1), (right, y1, z1), shade)


def roof(b, width, depth, eaves_z, colour, pitch=0.52, ridge_colour="oak_dark",
         gable_colour=None, courses=6, thatched=False):
    """A pitched roof with a deep overhang, laid in courses, with a ridge timber along the top.

    `pitch` is the roof's height as a fraction of its full span, so 0.5 is a 45 degree roof:
    steep enough to shed a Yorkshire winter and shallow enough that the walls below it still read
    from the game's camera."""
    span_x = width + EAVES_M * 2.0
    span_y = depth + EAVES_M * 2.0
    height = span_y * pitch
    b.gable_roof((0.0, 0.0, eaves_z), (span_x, span_y), height, colour,
                 ridge_colour=mix(colour, "oak_dark", 0.22),
                 gable_colour=gable_colour or mix(colour, "oak_dark", 0.10),
                 courses=courses,
                 course_contrast=0.09 if thatched else 0.16,
                 eaves_thickness=0.46 if thatched else 0.18)
    if thatched:
        thatch_fringe(b, span_x, span_y, eaves_z, colour)
        thatch_weathering(b, span_x, span_y, eaves_z, height, colour)
        # A thatched ridge is a rolled, pegged cap sitting proud of both pitches, not a timber.
        b.cylinder((-span_x * 0.495, 0.0, eaves_z + height + 0.02), 0.31,
                   span_x * 0.99, 8, mix(colour, "thatch_old", 0.12), colour, direction="x")
        # Hazel spars pegging the ridge down. They have to stay small: at 1.1 m they spanned both
        # pitches and read from the game camera as a ladder painted down the middle of the roof,
        # which was the loudest thing on the building.
        spars = max(2, int(span_x / 2.2))
        for i in range(spars):
            x = -span_x * 0.42 + span_x * 0.84 * i / max(1, spars - 1)
            b.box((x, 0.0, eaves_z + height + 0.20), (0.08, 0.62, 0.07),
                  mix(colour, "oak_dark", 0.35))
    else:
        if colour == "shingle":
            shingle_surface(b, span_x, span_y, eaves_z, height, colour, courses + 1)
        elif colour == "lead_roof":
            lead_sheet_surface(b, span_x, span_y, eaves_z, height, colour)
        b.box((0.0, 0.0, eaves_z + height + 0.04), (span_x + 0.16, 0.30, 0.26), ridge_colour)
    return height


def door(b, width, depth, base_z, height=2.1, span=1.5, face="-y", colour="oak_weathered"):
    """A boarded door in a timber frame, set into the wall rather than painted onto it."""
    sign = 1.0 if face == "+y" else -1.0
    at = depth * 0.5 * sign
    b.panel(face, (0.0, at, base_z + height * 0.5), (span + 0.28, height + 0.14), FRAME, 0.05)
    b.panel(face, (0.0, at, base_z + height * 0.5), (span, height), colour, 0.10)
    # Vertical board lines, and the two ledges that hold them together.
    for i in range(3):
        x = -span * 0.28 + span * 0.28 * i
        b.panel(face, (x, at, base_z + height * 0.5), (0.05, height - 0.1), FRAME, 0.13)
    for z in (base_z + height * 0.24, base_z + height * 0.78):
        b.panel(face, (0.0, at, z), (span - 0.1, 0.13), FRAME, 0.13)
    # Forged strap hinges and a latch: small dark asymmetry makes this read as an operable door.
    hinge_x = -span * 0.36
    for z in (base_z + height * 0.24, base_z + height * 0.76):
        b.panel(face, (hinge_x, at, z), (span * 0.42, 0.07), "iron", 0.15)
    b.panel(face, (span * 0.28, at, base_z + height * 0.50), (0.16, 0.10), "iron", 0.16)


def windows(b, width, depth, base_z, height, count=2):
    """Small unglazed openings with a shutter beside each - glass is for the church."""
    for i in range(count):
        x = -width * 0.35 + width * 0.7 * (i / max(1, count - 1)) if count > 1 else 0.0
        for face in ("-y", "+y"):
            sign = 1.0 if face == "+y" else -1.0
            b.panel(face, (x, depth * 0.5 * sign, base_z + height), (0.72, 0.76), FRAME, 0.09)
            b.panel(face, (x, depth * 0.5 * sign, base_z + height), (0.52, 0.56), "charcoal",
                    0.12)
            # Slender timber mullion and projecting sill instead of a flat dark rectangle.
            b.panel(face, (x, depth * 0.5 * sign, base_z + height), (0.08, 0.56),
                    FRAME_LIGHT, 0.14)
            b.panel(face, (x, depth * 0.5 * sign, base_z + height - 0.32), (0.78, 0.10),
                    FRAME_LIGHT, 0.14)


def gable_infill(b, width, depth, eaves_z, roof_h, colour=INFILL):
    """Frame the gable ends: a tie beam, a king post and raking struts on the roof's gable face.

    This has to be drawn on the *roof's* gable plane, not the wall's. The roof overhangs the wall
    by `EAVES_M` on every side, so a panel placed on the wall line sits behind the roof's own
    gable triangle and never shows — which is how the first pass ended up with a blank cream
    triangle where the most-photographed face of the building should be. A gable is a large flat
    area pointed straight at the camera in two of the cardinal views, so it is worth the
    twenty triangles."""
    span_x = width + EAVES_M * 2.0
    span_y = depth + EAVES_M * 2.0

    for sx in (-1.0, 1.0):
        x = span_x * 0.5 * sx
        face = "+x" if sx > 0 else "-x"
        proud = 0.04

        # Tie beam across the foot of the gable, and a wall plate just under it.
        b.panel(face, (x, 0.0, eaves_z + 0.30), (span_y * 0.94, 0.34), FRAME, proud)
        # King post from the tie beam up to the ridge.
        b.panel(face, (x, 0.0, eaves_z + roof_h * 0.52), (0.28, roof_h * 0.86), FRAME, proud)
        # A collar beam across the middle of the truss.
        b.panel(face, (x, 0.0, eaves_z + roof_h * 0.55), (span_y * 0.42, 0.24), FRAME, proud)
        # Raking struts each side of the king post expose the actual roof truss construction.
        for sy in (-1.0, 1.0):
            b.diagonal_panel(face, x,
                             (0.02 * sy, eaves_z + roof_h * 0.62),
                             (span_y * 0.30 * sy, eaves_z + 0.42),
                             0.18, FRAME, proud)


def gable_vent(b, width, depth, eaves_z, roof_h, sx=-1.0):
    """An owl hole in one gable: a dark opening under the apex. Every barn and granary had one,
    and a single dark note high on a pale gable is what gives the face a focal point."""
    span_x = width + EAVES_M * 2.0
    span_y = depth + EAVES_M * 2.0
    x = span_x * 0.5 * sx
    face = "+x" if sx > 0 else "-x"
    b.panel(face, (x, 0.0, eaves_z + roof_h * 0.80), (0.72, 0.62), FRAME, 0.05)
    b.panel(face, (x, 0.0, eaves_z + roof_h * 0.80), (0.50, 0.44), "charcoal", 0.08)
    _ = span_y


def smoke_louvre(b, x, roof_top_z, colour="shingle"):
    """A vented cap on the ridge. A building with a hearth needs one, and it breaks the ridge
    line, which is the other reason to have it."""
    b.box((x, 0.0, roof_top_z - 0.18), (1.15, 0.95, 0.55), FRAME, top_colour=FRAME_LIGHT)
    b.pyramid((x, 0.0, roof_top_z + 0.08), (1.45, 1.25), 0.55, colour)


def timber_walls_tower(b, x, width, depth, base_z, height):
    """`timber_walls` for a body that is not centred on the origin - the church's west tower."""
    b.box((x, 0.0, base_z + height * 0.5), (width, depth, height), INFILL,
          top_colour=mix(INFILL, FRAME, 0.5))
    post = 0.28
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            b.box((x + (width * 0.5 - post * 0.35) * sx, (depth * 0.5 - post * 0.35) * sy,
                   base_z + height * 0.5), (post, post, height), FRAME, top_colour=FRAME_LIGHT)
    for level in range(3):
        z = base_z + 0.2 + (height - 0.6) * level / 2.0
        for face, sign in (("-y", -1.0), ("+y", 1.0)):
            b.panel(face, (x, depth * 0.5 * sign, z), (width, 0.3), FRAME, FRAME_PROUD)
        for face, sign in (("-x", -1.0), ("+x", 1.0)):
            b.panel(face, (x + width * 0.5 * sign, 0.0, z), (depth, 0.3), FRAME, FRAME_PROUD)


def timber_hall(b, type_id, wall_h, wall_colour, roof_colour,
                plinth_colour="gritstone", plinth_h=0.5, with_windows=2, pitch=0.52,
                infill=INFILL, thatched=None):
    """The common building of the outer court: rubble footing, framed timber walls, courses of
    thatch or shingle above. `wall_colour` is unused now that walls are frame-and-infill; it is
    kept so `data/buildings.json`'s `colour` stays the record of a type's material family."""
    long_m, short_m, swapped = plot_size(type_id)
    width = long_m - WALL_INSET_M * 2.0
    depth = short_m - WALL_INSET_M * 2.0

    if thatched is None:
        thatched = roof_colour.startswith("thatch")

    plinth(b, width, depth, plinth_h, plinth_colour)
    timber_walls(b, width, depth, plinth_h, wall_h, infill=infill)
    door(b, width, depth, plinth_h)
    if with_windows:
        windows(b, width, depth, plinth_h, wall_h * 0.60, with_windows)
    roof_h = roof(b, width, depth, plinth_h + wall_h, roof_colour, pitch=pitch,
                  gable_colour=mix(infill, "oak_dark", 0.18), thatched=thatched)
    gable_infill(b, width, depth, plinth_h + wall_h, roof_h, colour=infill)
    return width, depth, plinth_h, wall_h, roof_h, swapped


# How far a model may reach past its plot edge. An eaves overhang that breaks the plot line by a
# hand's width is what a real roof does; a porch that reaches into the next plot is a bug, and it
# shows up in game as a building hanging over unclaimed ground or clipping its neighbour.
PLOT_TOLERANCE_M = 0.35

_overruns = []


def emit(type_id, b, swapped):
    if swapped:
        b.swap_xy()
    cells = TYPES[type_id]["footprint_cells"]
    plot = (cells[0] * CELL_M, cells[1] * CELL_M)
    (min_x, max_x), (min_y, max_y), _ = b.bounds()
    # `finish` re-centres on the bounding box, so measure the extent, not the raw coordinates.
    for axis, span, limit in (("x", max_x - min_x, plot[0]), ("y", max_y - min_y, plot[1])):
        if span > limit + PLOT_TOLERANCE_M * 2.0:
            _overruns.append("%s: %s extent %.2f m exceeds its %.1f m plot"
                             % (type_id, axis, span, limit))
    finish("bld_" + type_id, b)


def emit_free(name, b, swapped):
    """Emit a model whose size comes from somewhere other than `footprint_cells`, so there is no
    plot to check it against."""
    if swapped:
        b.swap_xy()
    finish("bld_" + name, b)


# --- the building types --------------------------------------------------------------------

def make_woodcutters_hut():
    b = MeshBuilder()
    width, depth, plinth_h, wall_h, _, swapped = timber_hall(
        b, "woodcutters_hut", 2.6, "oak_weathered", "shingle", with_windows=1,
        infill=INFILL_DAUB)
    # A stack of cordwood against the gable end: this is a woodcutter's, and the pile says so.
    for row in range(3):
        for log in range(4):
            b.cylinder((width * 0.5 - 1.20, -depth * 0.30 + log * 0.32, plinth_h + row * 0.30),
                       0.15, 1.10, 6, "oak_fresh", "oak_weathered", direction="x")
    emit("woodcutters_hut", b, swapped)


def make_sawpit():
    """No walls: a sawpit is a trestle over a hole with a frame roof to keep the rain off."""
    b = MeshBuilder()
    long_m, short_m, swapped = plot_size("sawpit")
    width = long_m - WALL_INSET_M * 2.0
    depth = short_m - WALL_INSET_M * 2.0

    # The pit itself, and the boards either side of it.
    b.box((0.0, 0.0, -0.05), (width * 0.55, depth * 0.42, 0.5), "soil")
    for sign in (-1.0, 1.0):
        b.box((0.0, depth * 0.32 * sign, 0.14), (width * 0.9, depth * 0.22, 0.16), "oak_fresh")

    posts_z = 2.5
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            b.box((width * 0.46 * sx, depth * 0.46 * sy, posts_z * 0.5),
                  (0.24, 0.24, posts_z), "oak_weathered")
    # The log on its trestles, mid-cut, with the saw kerf running into it.
    b.cylinder((-width * 0.42, 0.0, 0.78), 0.36, width * 0.84, 8, "oak_fresh",
               "oak_weathered", direction="x")
    for sx in (-0.55, 0.55):
        b.box((width * sx * 0.6, 0.0, 0.32), (0.22, depth * 0.5, 0.64), "oak_weathered")
    roof(b, width * 0.92, depth * 0.92, posts_z, "shingle", pitch=0.40, courses=5)
    emit("sawpit", b, swapped)


def make_quarry():
    """A worked face and a spoil heap, not a building — the silhouette is a hole in the ground
    with a winch over it, which is what tells the player at a glance that nothing lives here."""
    b = MeshBuilder()
    long_m, short_m, swapped = plot_size("quarry")
    width = long_m - 0.8
    depth = short_m - 0.8

    # Stepped benches cut down into the ground, deepest at one end.
    for i, (inset, z) in enumerate(((0.0, -0.35), (0.14, -0.95), (0.28, -1.55))):
        shade = ("gritstone", "limestone_shadow", "limestone_mid")[i]
        b.box((width * inset * 0.5, 0.0, z),
              (width * (1.0 - inset), depth * (1.0 - inset * 0.7), 0.62), shade)
    # Dressed blocks stacked at the lip, and rubble spoil behind them.
    for i in range(4):
        b.box((-width * 0.42 + i * 0.05, -depth * 0.38 + i * 0.62, 0.30 + (i % 2) * 0.34),
              (1.05, 0.58, 0.58), "limestone_mid", top_colour="limestone_light")
    for i in range(5):
        angle = math.tau * i / 5.0
        b.cone((width * 0.36 + math.cos(angle) * 0.5, depth * 0.30 + math.sin(angle) * 0.7, 0.0),
               0.75, 0.85, 7, "gritstone")
    # A shear-legs winch over the face: the tallest thing here, and the read at wide zoom.
    for sy in (-1.0, 1.0):
        b.quad((-width * 0.16, depth * 0.30 * sy, 0.0), (width * 0.16, depth * 0.30 * sy, 0.0),
               (0.14, 0.0, 3.6), (-0.14, 0.0, 3.6), "oak_weathered")
    b.cylinder((-1.0, 0.0, 3.5), 0.13, 2.0, 6, "oak_dark", "oak_fresh", direction="x")
    emit("quarry", b, swapped)


def make_masons_lodge():
    """Open-sided: a masons' lodge is a roof over the banker benches, not an enclosed shed."""
    b = MeshBuilder()
    long_m, short_m, swapped = plot_size("masons_lodge")
    width = long_m - WALL_INSET_M * 2.0
    depth = short_m - WALL_INSET_M * 2.0

    plinth(b, width, depth, 0.30, "gritstone")
    posts_z = 2.7
    for i in range(4):
        x = -width * 0.5 + width * i / 3.0
        for sy in (-1.0, 1.0):
            b.box((x, depth * 0.5 * sy, 0.30 + posts_z * 0.5), (0.26, 0.26, posts_z),
                  "oak_weathered")
    # A closed back wall, so the lodge has one solid side to work against.
    b.box((0.0, depth * 0.5, 0.30 + posts_z * 0.5), (width, 0.3, posts_z), "oak_weathered")
    # Banker benches with part-dressed blocks on them.
    for sx in (-0.28, 0.28):
        b.box((width * sx, -depth * 0.12, 0.30 + 0.42), (1.5, 0.9, 0.84), "oak_dark")
        b.box((width * sx, -depth * 0.12, 0.30 + 1.14), (0.9, 0.7, 0.6),
              "limestone_mid", top_colour="limestone_light")
    roof(b, width, depth, 0.30 + posts_z, "shingle", pitch=0.46, courses=6)
    emit("masons_lodge", b, swapped)


def make_granary():
    """Raised on staddle stones — the mushroom-shaped feet that keep rats out of the grain. It is
    the most recognisable English farm silhouette there is, and it costs eight cylinders."""
    b = MeshBuilder()
    long_m, short_m, swapped = plot_size("granary")
    width = long_m - WALL_INSET_M * 2.0
    depth = short_m - WALL_INSET_M * 2.0
    floor_z = 0.95

    for i in range(4):
        for j in range(2):
            x = -width * 0.4 + width * 0.8 * i / 3.0
            y = -depth * 0.35 + depth * 0.7 * j
            b.cylinder((x, y, 0.0), 0.24, 0.60, 7, "limestone_shadow", top_radius=0.20)
            b.cylinder((x, y, 0.60), 0.46, 0.30, 8, "limestone_mid", "limestone_light",
                       top_radius=0.40)
    b.box((0.0, 0.0, floor_z - 0.14), (width + 0.3, depth + 0.3, 0.28), "oak_dark")

    wall_h = 3.0
    timber_walls(b, width, depth, floor_z, wall_h)
    door(b, width, depth, floor_z, height=2.0, span=1.6)
    # The steps up to the raised door.
    for i in range(3):
        b.box((0.0, -depth * 0.5 - 0.16 - i * 0.20, floor_z - 0.22 - i * 0.30),
              (1.9, 0.40, 0.26), "limestone_shadow", top_colour="limestone_mid")
    roof_h = roof(b, width, depth, floor_z + wall_h, "thatch", pitch=0.56, thatched=True,
                  gable_colour=mix(INFILL, "oak_dark", 0.18))
    gable_infill(b, width, depth, floor_z + wall_h, roof_h)
    gable_vent(b, width, depth, floor_z + wall_h, roof_h)
    # Ventilation slits down the long walls: a granary has to breathe or the grain heats.
    for i in range(5):
        x = -width * 0.36 + width * 0.72 * i / 4.0
        for face, sign in (("-y", -1.0), ("+y", 1.0)):
            b.panel(face, (x, depth * 0.5 * sign, floor_z + wall_h * 0.72), (0.18, 0.9),
                    "charcoal", 0.11)
    emit("granary", b, swapped)


def make_tithe_barn():
    """The largest thing in the outer court and, until the church rises, the largest thing in the
    valley. Stone walls with buttresses, an enormous thatched roof, and a cart porch."""
    b = MeshBuilder()
    long_m, short_m, swapped = plot_size("tithe_barn")
    # A deeper inset than the standard hall: the barn is the only building with a projecting cart
    # porch, and a porch worth having needs the metre and a half of plot that buys it.
    width = long_m - WALL_INSET_M * 2.0
    depth = short_m - 2.6
    plinth_h, wall_h = 0.55, 4.6

    plinth(b, width, depth, plinth_h, "gritstone")
    stone_walls(b, width, depth, plinth_h, wall_h, "limestone_mid", courses=6,
                rubble_block_m=2.2)
    # Buttresses down both long walls: the detail that makes stone read as stone at this size.
    count = max(3, int(width / 3.4))
    for i in range(count + 1):
        x = -width * 0.5 + width * i / count
        for sy in (-1.0, 1.0):
            buttress(b, x, (depth * 0.5 + 0.16) * sy, plinth_h, wall_h, 0.8, 0.56,
                     "limestone_mid")
    for i in range(4):
        x = -width * 0.34 + width * 0.68 * i / 3.0
        for sy in (-1.0, 1.0):
            b.panel("+y" if sy > 0 else "-y", (x, depth * 0.5 * sy, plinth_h + wall_h * 0.72),
                    (0.42, 1.5), "limestone_shadow", offset=0.04)

    roof_h = roof(b, width, depth, plinth_h + wall_h, "thatch", pitch=0.50, courses=9,
                  thatched=True)
    # The cart porch: a gabled projection over the great doors on the long side.
    porch_d = 1.6
    b.box((0.0, -depth * 0.5 - porch_d * 0.5, plinth_h + wall_h * 0.42),
          (5.4, porch_d, wall_h * 0.84), "limestone_mid")
    b.gable_roof((0.0, -depth * 0.5 - porch_d * 0.5, plinth_h + wall_h * 0.84),
                 (5.9, porch_d + 0.7), 2.1, "thatch", courses=4,
                 gable_colour=mix("thatch", "oak_dark", 0.12))
    _great_doors(b, 0.0, -depth * 0.5 - porch_d, "-y", plinth_h, 3.4, 3.3)
    _great_doors(b, 0.0, depth * 0.5, "+y", plinth_h, 3.4, 3.3)
    _ = roof_h
    emit("tithe_barn", b, swapped)


def _great_doors(b, x, y, face, base_z, span, height):
    """A pair of boarded cart doors with a stone surround, on the scale a loaded wain needs."""
    centre_z = base_z + height * 0.5
    b.panel(face, (x, y, centre_z), (span + 0.5, height + 0.3), "limestone_light", 0.04)
    b.panel(face, (x, y, centre_z), (span, height), "oak_weathered", 0.09)
    b.panel(face, (x, y, centre_z), (0.18, height), "oak_dark", 0.13)          # the meeting stile
    for i in range(4):
        offset = -span * 0.32 + span * 0.64 * i / 3.0
        b.panel(face, (x + offset, y, centre_z), (0.07, height - 0.2), "oak_dark", 0.12)
    for z in (base_z + height * 0.22, base_z + height * 0.76):
        b.panel(face, (x, y, z), (span - 0.15, 0.16), "oak_dark", 0.12)


def make_cellarers_undercroft():
    """Low, heavy and vaulted, with a lead roof — the one building here that is all stone."""
    b = MeshBuilder()
    long_m, short_m, swapped = plot_size("cellarers_undercroft")
    width = long_m - WALL_INSET_M * 2.0
    depth = short_m - WALL_INSET_M * 2.0
    plinth_h, wall_h = 0.5, 3.2

    plinth(b, width, depth, plinth_h, "gritstone")
    stone_walls(b, width, depth, plinth_h, wall_h, "limestone_shadow", courses=5)
    for i in range(4):
        x = -width * 0.5 + width * i / 3.0
        for sy in (-1.0, 1.0):
            buttress(b, x, (depth * 0.5 + 0.14) * sy, plinth_h, wall_h, 0.7, 0.5,
                     "limestone_mid")
    # Round-headed openings, approximated by a tall slot with a squarer head above it.
    for i in range(3):
        x = -width * 0.30 + width * 0.60 * i / 2.0
        for sy in (-1.0, 1.0):
            face = "+y" if sy > 0 else "-y"
            b.panel(face, (x, depth * 0.5 * sy, plinth_h + 1.5), (0.66, 1.7), "oak_dark",
                    offset=0.04)
            b.panel(face, (x, depth * 0.5 * sy, plinth_h + 2.44), (0.46, 0.42), "oak_dark",
                    offset=0.04)
    door(b, width, depth, plinth_h, height=2.3, span=1.8, colour="oak_weathered")
    # A shallow lead pitch, not a steep thatch: lead cannot be laid steep and should not look it.
    roof(b, width, depth, plinth_h + wall_h, "lead_roof", pitch=0.26, ridge_colour="slate",
         courses=4)
    emit("cellarers_undercroft", b, swapped)


def make_wool_store():
    b = MeshBuilder()
    width, depth, plinth_h, wall_h, _, swapped = timber_hall(
        b, "wool_store", 3.5, "oak_fresh", "thatch", with_windows=3)
    # A loading hatch and hoist beam under the gable, for getting fleeces up to the loft.
    b.panel("-y", (0.0, -depth * 0.5, plinth_h + wall_h - 0.9), (1.3, 1.3), "oak_dark",
            offset=0.04)
    b.box((0.0, -depth * 0.5 - 0.34, plinth_h + wall_h + 0.35), (0.2, 0.95, 0.2), "oak_dark")
    emit("wool_store", b, swapped)


def make_open_stockpile():
    """Not a building at all: hurdles round a patch of hardstanding, with goods stacked on it."""
    b = MeshBuilder()
    long_m, short_m, swapped = plot_size("open_stockpile")
    width = long_m - 0.7
    depth = short_m - 0.7

    b.box((0.0, 0.0, 0.06), (width, depth, 0.12), "mud", top_colour=mix("mud", "soil", 0.4))
    # Corner posts with hurdle panels on three sides, the fourth left open for access.
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            b.box((width * 0.5 * sx, depth * 0.5 * sy, 0.55), (0.18, 0.18, 1.1), "oak_weathered")
    for face, sign in (("+y", 1.0), ("-x", -1.0), ("+x", 1.0)):
        along = width if face == "+y" else depth
        centre = (0.0, depth * 0.5 * sign, 0.5) if face == "+y" else (width * 0.5 * sign, 0.0, 0.5)
        for rail in range(3):
            b.panel(face, (centre[0], centre[1], 0.24 + rail * 0.34), (along, 0.2), "oak_dark")
    # Stacked timber and a couple of stone blocks, so an empty stockpile still reads as a store.
    for i in range(3):
        b.cylinder((-width * 0.36, -depth * 0.2 + i * 0.34, 0.12 + (i % 2) * 0.3),
                   0.17, width * 0.6, 6, "oak_fresh", "oak_weathered", direction="x")
    b.box((width * 0.28, depth * 0.15, 0.52), (1.0, 0.8, 0.8), "limestone_mid",
          top_colour="limestone_light")
    emit("open_stockpile", b, swapped)


# --- the precinct (data/precinct.json, placed by Population rather than by the player) --------

def _precinct_size(building_id):
    """(width, length, wall height) in metres for a precinct building."""
    size = PRECINCT[building_id]["size_m"]
    return float(size[0]), float(size[2]), float(size[1])


def make_precinct_church():
    """The first timber church: a long nave under a steep shingle roof, with a west tower.

    This is the tallest thing in the valley and will be for fifty years — the stone church is a
    Phase 8 concern — so it carries the detail that sets the scale for everything else: a tower
    with a broach spire, a cross on the east gable, and round-headed windows down the nave."""
    b = MeshBuilder()
    width, length, wall_h = _precinct_size("church")
    plinth_h = 0.5

    # Authored ridge-along-X, so the nave's length is X here and swapped at the end.
    nave_w, nave_d = length, width
    plinth(b, nave_w, nave_d, plinth_h, "gritstone")
    timber_walls(b, nave_w, nave_d, plinth_h, wall_h)
    # Round-headed nave windows: a tall slot with a squarer head, same trick as the undercroft.
    for i in range(4):
        x = -nave_w * 0.28 + nave_w * 0.56 * i / 3.0
        for face, sign in (("-y", -1.0), ("+y", 1.0)):
            b.panel(face, (x, nave_d * 0.5 * sign, plinth_h + wall_h * 0.62),
                    (0.52, 1.4), "oak_dark", offset=0.04)
            b.panel(face, (x, nave_d * 0.5 * sign, plinth_h + wall_h * 0.62 + 0.84),
                    (0.36, 0.34), "oak_dark", offset=0.04)
    roof_h = roof(b, nave_w, nave_d, plinth_h + wall_h, "shingle", pitch=0.60, courses=8,
                  gable_colour=mix(INFILL, "oak_dark", 0.18))
    gable_infill(b, nave_w, nave_d, plinth_h + wall_h, roof_h)

    # The cross on the east gable — the mark of a house, and the thing the founding site is for.
    east = nave_w * 0.5 + EAVES_M
    b.box((east, 0.0, plinth_h + wall_h + roof_h + 0.55), (0.16, 0.18, 1.10), "oak_dark")
    b.box((east, 0.0, plinth_h + wall_h + roof_h + 0.82), (0.16, 0.72, 0.18), "oak_dark")

    # West tower with a broach spire.
    tower = PRECINCT["church"].get("tower_m")
    if tower:
        t_w, t_h, t_d = float(tower[0]), float(tower[1]), float(tower[2])
        t_x = -nave_w * 0.5 + t_d * 0.5
        timber_walls_tower(b, t_x, t_d, t_w, plinth_h, t_h)
        # Belfry openings just under the spire, on all four faces.
        for face, sign in (("-y", -1.0), ("+y", 1.0)):
            b.panel(face, (t_x, t_w * 0.5 * sign, plinth_h + t_h - 1.15), (0.5, 1.2),
                    "oak_dark", offset=0.04)
        for face, sign in (("-x", -1.0), ("+x", 1.0)):
            b.panel(face, (t_x + t_d * 0.5 * sign, 0.0, plinth_h + t_h - 1.15), (0.5, 1.2),
                    "oak_dark", offset=0.04)
        b.pyramid((t_x, 0.0, plinth_h + t_h), (t_d + 0.5, t_w + 0.5), t_h * 0.62, "shingle")
    emit_free("precinct_church", b, swapped=True)


def make_precinct_dormitory():
    """The dormitory range: plainer than the church by design — a long thatched hall."""
    b = MeshBuilder()
    width, length, wall_h = _precinct_size("dormitory")
    plinth_h = 0.42
    hall_w, hall_d = length, width

    plinth(b, hall_w, hall_d, plinth_h, "gritstone")
    timber_walls(b, hall_w, hall_d, plinth_h, wall_h)
    door(b, hall_w, hall_d, plinth_h, height=2.0, span=1.4)
    windows(b, hall_w, hall_d, plinth_h, wall_h * 0.66, count=4)
    roof_h = roof(b, hall_w, hall_d, plinth_h + wall_h, "thatch", pitch=0.56, courses=7,
                  thatched=True, gable_colour=mix(INFILL, "oak_dark", 0.18))
    gable_infill(b, hall_w, hall_d, plinth_h + wall_h, roof_h)
    smoke_louvre(b, hall_w * 0.24, plinth_h + wall_h + roof_h)
    emit_free("precinct_dormitory", b, swapped=True)


MAKERS = (
    make_precinct_church,
    make_precinct_dormitory,
    make_woodcutters_hut,
    make_quarry,
    make_sawpit,
    make_masons_lodge,
    make_granary,
    make_tithe_barn,
    make_cellarers_undercroft,
    make_wool_store,
    make_open_stockpile,
)


def main():
    missing = set(TYPES) - {maker.__name__[len("make_"):] for maker in MAKERS}
    if missing:
        # A building type with no model falls back to the greybox box in the renderer, so this is
        # a warning and not a failure — but it should never pass unnoticed.
        print("[buildings] WARNING: no model for %s" % ", ".join(sorted(missing)))
    build_all(MAKERS, "buildings")
    if _overruns:
        for line in _overruns:
            print("[buildings] ERROR: " + line)
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
