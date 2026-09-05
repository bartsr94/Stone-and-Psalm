"""Shared mesh authoring helpers for the generator scripts in this folder.

Every generated asset is built the same way: raw vertices and per-vertex palette colours pushed
into a `MeshBuilder`, then handed to `finish()`, which normalises the origin, writes the `Col`
attribute, attaches the one shared material and saves a `.blend`. Keeping that in one place is
what stops the three generator scripts drifting apart.

**The palette is read from `data/palette.json`, not hardcoded here.** Three copies of the same
colour table had already been pasted into the generator scripts, and a palette edit that reaches
the terrain shader but not the props is exactly the kind of divergence the single-palette rule
exists to prevent.

**Colours are converted to linear here, and stored linear.** This is the one subtle thing in the
pipeline and it is worth spelling out. A vertex colour is multiplied into albedo, which is
linear — unlike a material's `albedo_color`, which Godot treats as sRGB and converts for you.
Blender's glTF exporter passes a `BYTE_COLOR` attribute through to `COLOR_0` unchanged, and
neither `StandardMaterial3D` (whose `vertex_color_is_srgb` defaults to false) nor a custom
shader reading `COLOR` converts it either. So authoring the sRGB components straight into the
attribute renders every model roughly one gamma step too bright: it is what washed the valley
out to pale olive and read as a tonemapping problem rather than a colour-space one.

`scripts/view/palette.gd`'s `vertex()` already does this conversion for meshes built in code.
Doing it here too means a `.glb` from Blender and a mesh built in GDScript light identically,
which is the whole point of one shared material.

Import from a generator script with:

    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from meshkit import MeshBuilder, PALETTE, finish, reset_scene, shared_material
"""

import json
import math
import os

import bpy


ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
BLEND_DIR = os.path.join(ROOT, "assets", "blend")
PALETTE_PATH = os.path.join(ROOT, "data", "palette.json")

SHARED_MATERIAL = "M_StoneAndPsalm"
COLOR_ATTR = "Col"


def srgb_to_linear(component):
    """The exact sRGB transfer function, matching Color.srgb_to_linear() in Godot."""
    if component <= 0.04045:
        return component / 12.92
    return ((component + 0.055) / 1.055) ** 2.4


def _load_palette():
    """`data/palette.json` as name -> (r, g, b, 1.0), converted to linear. See the module note."""
    with open(PALETTE_PATH, "r", encoding="utf-8") as handle:
        parsed = json.load(handle)
    colours = {}
    for key, entry in parsed.items():
        if not isinstance(entry, dict) or "hex" not in entry:
            continue  # the file carries `_comment` strings alongside the colour entries
        text = entry["hex"].lstrip("#")
        srgb = tuple(int(text[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        colours[key] = tuple(srgb_to_linear(c) for c in srgb) + (1.0,)
    return colours


PALETTE = _load_palette()


def rgba(colour):
    """A palette name, or an explicit (r, g, b, a) tuple, as a colour."""
    return PALETTE[colour] if isinstance(colour, str) else colour


def mix(a, b, t):
    """Blend two palette colours, for shading a face family without adding palette entries."""
    ca, cb = rgba(a), rgba(b)
    return tuple(ca[i] + (cb[i] - ca[i]) * t for i in range(4))


class MeshBuilder:
    """Accumulates faces with a colour each. Every face owns its vertices, so nothing is shared
    between faces and the whole mesh shades flat — which is the look, not an oversight."""

    def __init__(self):
        self.vertices = []
        self.faces = []
        self.colours = []

    # --- primitives ---------------------------------------------------------------------

    def vertex(self, position, colour):
        self.vertices.append(position)
        self.colours.append(rgba(colour))
        return len(self.vertices) - 1

    def face(self, positions, colour):
        self.faces.append(tuple(self.vertex(p, colour) for p in positions))

    def triangle(self, a, b, c, colour):
        self.face((a, b, c), colour)

    def quad(self, a, b, c, d, colour):
        self.face((a, b, c, d), colour)

    def box(self, centre, size, colour, top_colour=None):
        """An axis-aligned box centred on `centre`, z up."""
        cx, cy, cz = centre
        sx, sy, sz = (value * 0.5 for value in size)
        bottom = ((cx - sx, cy - sy, cz - sz), (cx + sx, cy - sy, cz - sz),
                  (cx + sx, cy + sy, cz - sz), (cx - sx, cy + sy, cz - sz))
        top = ((cx - sx, cy - sy, cz + sz), (cx + sx, cy - sy, cz + sz),
               (cx + sx, cy + sy, cz + sz), (cx - sx, cy + sy, cz + sz))
        self.quad(bottom[0], bottom[1], bottom[2], bottom[3], colour)
        self.quad(bottom[1], top[1], top[2], bottom[2], colour)
        self.quad(bottom[2], top[2], top[3], bottom[3], colour)
        self.quad(bottom[3], top[3], top[0], bottom[0], colour)
        self.quad(bottom[0], top[0], top[1], bottom[1], colour)
        self.quad(top[0], top[3], top[2], top[1], top_colour or colour)

    def cylinder(self, centre, radius, height, sides, side_colour, top_colour=None,
                 direction="z", top_radius=None):
        """A capped low-poly cylinder with its base at `centre`, growing along `direction`.

        `top_radius` tapers it into a truncated cone — a tree trunk that does not taper reads as
        a fence post at any distance."""
        top_colour = top_colour or side_colour
        top_radius = radius if top_radius is None else top_radius
        cx, cy, cz = centre
        bottom = []
        top = []
        for i in range(sides):
            angle = math.tau * i / sides
            cos_a, sin_a = math.cos(angle), math.sin(angle)
            if direction == "x":
                bottom.append((cx, cy + cos_a * radius, cz + sin_a * radius))
                top.append((cx + height, cy + cos_a * top_radius, cz + sin_a * top_radius))
            elif direction == "y":
                bottom.append((cx + cos_a * radius, cy, cz + sin_a * radius))
                top.append((cx + cos_a * top_radius, cy + height, cz + sin_a * top_radius))
            else:
                bottom.append((cx + cos_a * radius, cy + sin_a * radius, cz))
                top.append((cx + cos_a * top_radius, cy + sin_a * top_radius, cz + height))
        for i in range(sides):
            nxt = (i + 1) % sides
            self.quad(bottom[i], bottom[nxt], top[nxt], top[i], side_colour)
        self.face(tuple(reversed(bottom)), side_colour)
        self.face(top, top_colour)

    def cone(self, centre, radius, height, sides, side_colour, base_colour=None):
        """A cone with its base ring at `centre` and its apex directly above — one skirt of a
        conifer, and the cheapest shape that still reads as needled foliage."""
        cx, cy, cz = centre
        ring = []
        for i in range(sides):
            angle = math.tau * i / sides
            ring.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius, cz))
        apex = (cx, cy, cz + height)
        for i in range(sides):
            self.triangle(ring[i], ring[(i + 1) % sides], apex, side_colour)
        self.face(tuple(reversed(ring)), base_colour or side_colour)

    def blob(self, centre, radius, colour, squash=1.0, jitter=0.0, rng=None, alt_colour=None):
        """A once-subdivided octahedron, normalised into a faceted sphere: 32 triangles of
        deliberately visible facets. This is the canopy mass of every broadleaf in the valley.

        `jitter` pushes each vertex in or out by up to that fraction of the radius so no two
        blobs read as the same ball; `alt_colour` shades the upward-facing facets, which is what
        gives a canopy a lit top and a shaded underside with no extra geometry."""
        top = (0.0, 0.0, 1.0)
        bottom = (0.0, 0.0, -1.0)
        equator = [(1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (-1.0, 0.0, 0.0), (0.0, -1.0, 0.0)]
        octahedron = []
        for i in range(4):
            a, b = equator[i], equator[(i + 1) % 4]
            octahedron.append((a, b, top))
            octahedron.append((b, a, bottom))

        def normalise(v):
            length = math.sqrt(sum(component * component for component in v)) or 1.0
            return tuple(component / length for component in v)

        def midpoint(a, b):
            return normalise(tuple((a[i] + b[i]) * 0.5 for i in range(3)))

        cx, cy, cz = centre
        for a, b, c in octahedron:
            ab, bc, ca = midpoint(a, b), midpoint(b, c), midpoint(c, a)
            for face in ((a, ab, ca), (ab, b, bc), (ca, bc, c), (ab, bc, ca)):
                placed = []
                for direction in face:
                    scale = radius
                    if jitter and rng is not None:
                        scale *= 1.0 + rng.uniform(-jitter, jitter)
                    placed.append((cx + direction[0] * scale,
                                   cy + direction[1] * scale,
                                   cz + direction[2] * scale * squash))
                lift = sum(direction[2] for direction in face) / 3.0
                shade = colour if alt_colour is None else mix(colour, alt_colour,
                                                              max(0.0, min(1.0, lift * 0.5 + 0.5)))
                self.face(tuple(placed), shade)

    def gable_roof(self, centre, size, height, colour, ridge_colour=None, gable_colour=None,
                   courses=6, course_contrast=0.40, eaves_thickness=0.20):
        """A pitched roof ridged along X, sitting with its eaves at `centre`'s z.

        `size` is the full eaves footprint (x, y) — pass it wider than the walls, because the
        overhang is most of what makes a roof read as medieval rather than as a lid.

        **Each slope is split into `courses` bands of alternating shade.** From the game's camera
        a pitched building is mostly roof, so a roof drawn as one flat quad is the single largest
        untextured surface on screen and the thing that most makes a model look unfinished. With
        no textures anywhere in this project (Architecture Guide §4.1), courses of thatch or
        shingle have to be geometry — and at four triangles a course they are cheap enough to put
        on every building."""
        cx, cy, cz = centre
        hx, hy = size[0] * 0.5, size[1] * 0.5
        courses = max(1, courses)
        dark = mix(colour, "oak_dark", course_contrast)

        for slope in (-1.0, 1.0):
            for i in range(courses):
                t0, t1 = i / courses, (i + 1) / courses
                y0, y1 = hy * slope * (1.0 - t0), hy * slope * (1.0 - t1)
                z0, z1 = cz + height * t0, cz + height * t1
                band = colour if i % 2 == 0 else dark
                if slope < 0.0:
                    self.quad((cx - hx, cy + y0, z0), (cx + hx, cy + y0, z0),
                              (cx + hx, cy + y1, z1), (cx - hx, cy + y1, z1), band)
                else:
                    # The far slope carries a little of the ridge tone, so the two pitches
                    # separate even when the sun is behind the camera and lights them equally.
                    self.quad((cx + hx, cy + y0, z0), (cx - hx, cy + y0, z0),
                              (cx - hx, cy + y1, z1), (cx + hx, cy + y1, z1),
                              band if ridge_colour is None else mix(band, ridge_colour, 0.12))

        near_l = (cx - hx, cy - hy, cz)
        near_r = (cx + hx, cy - hy, cz)
        far_l = (cx - hx, cy + hy, cz)
        far_r = (cx + hx, cy + hy, cz)
        ridge_l = (cx - hx, cy, cz + height)
        ridge_r = (cx + hx, cy, cz + height)
        self.triangle(near_l, ridge_l, far_l, gable_colour or colour)
        self.triangle(far_r, ridge_r, near_r, gable_colour or colour)
        # Underside of the eaves, so the overhang has a shaded soffit rather than a hole.
        self.quad(near_r, near_l, far_l, far_r, mix(colour, "oak_dark", 0.65))
        # A barge board along each eave. It catches the light differently from the slope above
        # it, which is what stops the roof and the wall reading as one continuous mass. Thatch
        # gets a thick one, because a thatched eaves really is half a metre of packed straw and
        # that heavy bottom edge is most of what distinguishes it from a shingled roof.
        for slope in (-1.0, 1.0):
            self.box((cx, cy + hy * slope, cz + eaves_thickness * 0.1),
                     (size[0] + 0.12, eaves_thickness * 0.9, eaves_thickness),
                     mix(colour, "oak_dark", 0.42))

    def pyramid(self, centre, size, height, colour, apex_shift=(0.0, 0.0)):
        """A square pyramid with its base at `centre`'s z — a tower spire, or a spoil heap."""
        cx, cy, cz = centre
        hx, hy = size[0] * 0.5, size[1] * 0.5
        base = ((cx - hx, cy - hy, cz), (cx + hx, cy - hy, cz),
                (cx + hx, cy + hy, cz), (cx - hx, cy + hy, cz))
        apex = (cx + apex_shift[0], cy + apex_shift[1], cz + height)
        for i in range(4):
            self.triangle(base[i], base[(i + 1) % 4], apex, colour)
        self.face(tuple(reversed(base)), colour)

    def panel(self, face, centre, size, colour, offset=0.02):
        """A flat quad laid just proud of a wall, for a door, a shutter or a timber stud.

        Detail like this is what separates a medieval building from a crate, and a quad costs two
        triangles where a box costs twelve — at these footprints that is the difference between a
        fully framed barn and blowing the `bld_` budget on studwork. `face` is one of
        `-x +x -y +y`, `centre` is the point on the wall plane, `size` is (along, up)."""
        cx, cy, cz = centre
        half, up = size[0] * 0.5, size[1] * 0.5
        if face in ("-y", "+y"):
            y = cy - offset if face == "-y" else cy + offset
            corners = ((cx - half, y, cz - up), (cx + half, y, cz - up),
                       (cx + half, y, cz + up), (cx - half, y, cz + up))
            if face == "-y":
                corners = tuple(reversed(corners))
        else:
            x = cx - offset if face == "-x" else cx + offset
            corners = ((x, cy - half, cz - up), (x, cy + half, cz - up),
                       (x, cy + half, cz + up), (x, cy - half, cz + up))
            if face == "+x":
                corners = tuple(reversed(corners))
        self.quad(*corners, colour)

    def swap_xy(self):
        """Mirror the whole mesh across the x=y diagonal, turning a hall authored ridge-along-X
        into the same hall ridge-along-Y. Buildings are authored long-axis-first and swapped when
        their footprint is deeper than it is wide, which keeps one body of shape code for both."""
        self.vertices = [(y, x, z) for x, y, z in self.vertices]
        # Mirroring flips handedness, so every face must be rewound or the mesh renders inside out.
        self.faces = [tuple(reversed(face)) for face in self.faces]

    # --- output -------------------------------------------------------------------------

    def bounds(self):
        xs = [v[0] for v in self.vertices]
        ys = [v[1] for v in self.vertices]
        zs = [v[2] for v in self.vertices]
        return (min(xs), max(xs)), (min(ys), max(ys)), (min(zs), max(zs))

    def to_object(self, name):
        mesh = bpy.data.meshes.new(name + "_mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)

        colours = mesh.color_attributes.new(name=COLOR_ATTR, type="BYTE_COLOR", domain="CORNER")
        mesh.color_attributes.active_color = colours
        for polygon in mesh.polygons:
            for loop_index in polygon.loop_indices:
                colours.data[loop_index].color = self.colours[mesh.loops[loop_index].vertex_index]

        obj.data.materials.append(shared_material())
        return obj


def shared_material():
    """The one material every asset in the game uses. Vertex colour straight into base colour —
    no textures, no UVs, nothing per-model (Architecture Guide §4.1)."""
    material = bpy.data.materials.get(SHARED_MATERIAL)
    if material is None:
        material = bpy.data.materials.new(SHARED_MATERIAL)
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Roughness"].default_value = 0.85
    colour = nodes.new("ShaderNodeVertexColor")
    colour.layer_name = COLOR_ATTR
    links.new(colour.outputs["Color"], shader.inputs["Base Color"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def finish(name, builder, centre_xy=True):
    """Normalise the origin, build the object, and save `assets/blend/<name>.blend`.

    Geometry is authored directly in final coordinates so the object transform stays identity and
    `validate_assets.py` can enforce the origin/scale contract with no exceptions. The origin
    lands on the footprint centre at ground level, which is the contract every renderer assumes.
    """
    (min_x, max_x), (min_y, max_y), (min_z, _) = builder.bounds()
    shift_x = (min_x + max_x) * 0.5 if centre_xy else 0.0
    shift_y = (min_y + max_y) * 0.5 if centre_xy else 0.0
    builder.vertices = [(x - shift_x, y - shift_y, z - min_z) for x, y, z in builder.vertices]

    obj = builder.to_object(name)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    os.makedirs(BLEND_DIR, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    bpy.ops.object.select_all(action="DESELECT")
    return obj


def build_all(makers, label):
    """Run each maker in a clean scene. Every generator script's `main()` is this loop."""
    os.makedirs(BLEND_DIR, exist_ok=True)
    for maker in makers:
        reset_scene()
        maker()
    print("[%s] created %d asset(s)" % (label, len(makers)))
