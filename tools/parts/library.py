"""Every part made by the tool. Each part is a function that builds its shape
and says where its connectors are.

A connector is a spot where the part joins another, with a type and the way
it faces out. Studs face up out of the top and sockets face down out of the
bottom. Bars, axles and hinge pins are lines, given from one end with how
long they are, and a clip, wheel hub or hole joins anywhere along one. See
scripts/parts/connectors.gd for which types go together.
"""

import math

from kit import BRICK, EDGE, FINE, PLATE, STUD, STUD_HEIGHT, STUD_RADIUS, box, cut, cylinder, front, grid_cells, mirror_x, plan_y, profile_x, push_x, push_z, rounded, side, studs, union

# Colours, the classic brick ones.
RED = "#c4281c"
BLUE = "#0d69ab"
YELLOW = "#f2cd37"
WHITE = "#f2f3f2"
BLACK = "#1b2a34"
DARK_GREY = "#635f61"
LIGHT_GREY = "#a3a2a4"
GREEN = "#237841"
ORANGE = "#da8540"
LIME = "#a4bd46"
TYRE = "#202020"
METAL = "#9aa0a6"
TRANS_RED = "#c4281c"
TRANS_CLEAR = "#e8f4f8"
TRANS_AMBER = "#f5a623"
# Almost clear. The game draws window glass see-through, not blue.
GLASS = TRANS_CLEAR

# Mass for each cubic metre of a part's box, the same as the first parts.
DENSITY = 12.0


class Part:
    def __init__(self, id, name, kind, group, size, solid, connectors, color, **stats):
        self.id = id
        self.name = name
        self.kind = kind
        self.group = group
        # The box it fills, in metres (x across, y up, z along).
        self.size = size
        self.solid = solid
        self.connectors = connectors
        self.color = color
        # Optional racing_hull vertices are in metres from the part's corner.
        # They bound a convex body without changing the editor's solid boxes.
        self.stats = stats
        # A second piece in its own colour that isn't painted, like a tire or
        # a lens: (solid, colour, finish).
        self.trim = stats.pop("trim", None)
        # Clear lenses that shine when the lights are on, for a part whose
        # trim is something else: (solid, colour).
        self.lamp = stats.pop("lamp", None)
        self.finish = stats.pop("finish", "plastic")
        volume = size[0] * size[1] * size[2]
        self.stats.setdefault("mass", round(max(volume * DENSITY, 0.05), 2))
        self.stats.setdefault("strength", round(400 + volume * 2000, 0))


def c(type, at, axis, length=0.0):
    out = {"type": type, "at": list(at), "axis": list(axis)}
    if length:
        out["length"] = length
    return out


def top_studs(cells, top):
    return [c("stud", ((i + 0.5) * STUD, top, (k + 0.5) * STUD), (0, 1, 0)) for i, k in cells]


def sockets(cells, bottom=0.0):
    return [c("socket", ((i + 0.5) * STUD, bottom, (k + 0.5) * STUD), (0, -1, 0)) for i, k in cells]


PARTS = []


def part(fn):
    PARTS.append(fn)
    return fn


# Plates, bricks and tiles.

def _block(id, name, kind, group, across, along, plates, color, stud=True, aero=None):
    h = plates * PLATE
    cells = grid_cells(across, along)
    solid = box(0, 0, 0, across * STUD, h, along * STUD)
    connectors = sockets(cells)
    if stud:
        solid = union([solid, studs(cells, h)])
        connectors += top_studs(cells, h)
    stats = {}
    if aero:
        stats["aero"] = aero
    return Part(id, name, kind, group, (across * STUD, h, along * STUD), solid, connectors, color, **stats)


for _a, _b in [(1, 1), (1, 2), (1, 3), (1, 4), (1, 6), (1, 8), (2, 2), (2, 3), (2, 4), (2, 6), (2, 8), (2, 10), (4, 4), (4, 6), (4, 8), (6, 6), (6, 8), (6, 10), (6, 12)]:
    part((lambda a, b: lambda: _block("p_plate_%dx%d" % (a, b), "Plate %d×%d" % (a, b), "plate", "plates", a, b, 1, LIGHT_GREY if a >= 4 else RED))(_a, _b))

for _a, _b in [(1, 1), (1, 2), (1, 3), (1, 4), (1, 6), (2, 2), (2, 4)]:
    part((lambda a, b: lambda: _block("p_brick_%dx%d" % (a, b), "Brick %d×%d" % (a, b), "brick", "bricks", a, b, 3, RED))(_a, _b))

for _a, _b in [(1, 1), (1, 2), (1, 3), (1, 4), (1, 6), (2, 2), (2, 3), (2, 4), (2, 6), (1, 8), (2, 8)]:
    part((lambda a, b: lambda: _block("p_tile_%dx%d" % (a, b), "Tile %d×%d" % (a, b), "plate", "tiles", a, b, 1, BLACK, stud=False, aero={"front": 0.9, "back": 0.9}))(_a, _b))


@part
def round_plate_1x1():
    solid = union([cylinder(STUD * 0.5 - 0.004, PLATE - 0.002, "y", (STUD * 0.5, 0.001, STUD * 0.5)), studs([(0, 0)], PLATE)])
    return Part("p_round_plate_1x1", "Round plate 1×1", "plate", "plates", (STUD, PLATE, STUD), solid, sockets([(0, 0)]) + top_studs([(0, 0)], PLATE), YELLOW)


@part
def round_plate_2x2():
    solid = union([cylinder(STUD - 0.004, PLATE - 0.002, "y", (STUD, 0.001, STUD), 28), studs(grid_cells(2, 2), PLATE)])
    return Part("p_round_plate_2x2", "Round plate 2×2", "plate", "plates", (2 * STUD, PLATE, 2 * STUD), solid, sockets(grid_cells(2, 2)) + top_studs(grid_cells(2, 2), PLATE), WHITE)


@part
def round_tile_1x1():
    solid = cylinder(STUD * 0.5 - 0.004, PLATE - 0.002, "y", (STUD * 0.5, 0.001, STUD * 0.5))
    return Part("p_round_tile_1x1", "Round tile 1×1", "plate", "tiles", (STUD, PLATE, STUD), solid, sockets([(0, 0)]), BLACK)


@part
def round_tile_2x2():
    solid = cylinder(STUD - 0.004, PLATE - 0.002, "y", (STUD, 0.001, STUD), 28)
    return Part("p_round_tile_2x2", "Round tile 2×2", "plate", "tiles", (2 * STUD, PLATE, 2 * STUD), solid, sockets(grid_cells(2, 2)), BLACK)


@part
def round_brick_1x1():
    centre = STUD * 0.5
    body = cylinder(centre - 0.004, BRICK - 0.036, "y", (centre, 0.035, centre))
    collar = cylinder(0.1, 0.043, "y", (centre, 0.001, centre))
    stud = cylinder(STUD_RADIUS, STUD_HEIGHT, "y", (centre, BRICK - 0.001, centre))
    hole = cylinder(0.05, STUD_HEIGHT + 0.02, "y", (centre, BRICK - 0.015, centre))
    solid = cut(union([body, collar, stud]), hole)
    return Part("p_round_brick_1x1", "Round brick 1×1", "brick", "bricks", (STUD, BRICK, STUD), solid, sockets([(0, 0)]) + top_studs([(0, 0)], BRICK), BLACK)


@part
def round_brick_2x2():
    solid = union([cylinder(STUD - 0.004, BRICK - 0.002, "y", (STUD, 0.001, STUD), 28), studs(grid_cells(2, 2), BRICK)])
    return Part("p_round_brick_2x2", "Round brick 2×2", "brick", "bricks", (2 * STUD, BRICK, 2 * STUD), solid, sockets(grid_cells(2, 2)) + top_studs(grid_cells(2, 2), BRICK), DARK_GREY)


@part
def grille_tile_1x2():
    body = box(0, 0, 0, STUD, PLATE, 2 * STUD)
    slots = union([box(0.04, PLATE * 0.6, 0.06 + k * 0.08, STUD - 0.04, PLATE * 1.2, 0.09 + k * 0.08, edge=0) for k in range(5)])
    return Part("p_grille_1x2", "Grille tile 1×2", "plate", "tiles", (STUD, PLATE, 2 * STUD), cut(body, slots), sockets(grid_cells(1, 2)), DARK_GREY)


# Slopes and curves, all with their slope or curve at the front (-z).

def _slope(id, name, across, along, plates, flat, color, aero):
    """A slope that rises from a thin lip at the front to full height, with
    `flat` studs of flat top at the back."""
    h = plates * PLATE
    l = along * STUD
    lip = 0.04
    pts = [(0, 0), (0, lip), (l - flat * STUD, h), (l, h), (l, 0)]
    solid = profile_x(pts, 0.002, across * STUD - 0.002)
    cells_top = [(i, k) for i in range(across) for k in range(along - flat, along)]
    if flat:
        solid = union([solid, studs(cells_top, h)])
    return Part(id, name, "body", "slopes", (across * STUD, h, l), solid, sockets(grid_cells(across, along)) + top_studs(cells_top, h), color, aero=aero)


def _curve(id, name, across, along, plates, flat, color, aero):
    """A curved slope: a quarter of a smooth curve up from the front to full
    height, with `flat` studs of flat top at the back (or none)."""
    h = plates * PLATE
    l = along * STUD
    run = l - flat * STUD
    pts = [(0.0, 0.0)]
    for k in range(17):
        t = k / 16.0
        pts.append((run * t, 0.03 + (h - 0.03) * math.sin(t * math.pi * 0.5)))
    pts += [(l, h), (l, 0.0)]
    solid = profile_x(pts, 0.002, across * STUD - 0.002)
    cells_top = [(i, k) for i in range(across) for k in range(along - flat, along)]
    if flat:
        solid = union([solid, studs(cells_top, h)])
    return Part(id, name, "body", "curves", (across * STUD, h, l), solid, sockets(grid_cells(across, along)) + top_studs(cells_top, h), color, aero=aero)


part(lambda: _slope("p_cheese_1x1", "Cheese slope 1×1", 1, 1, 2, 0, YELLOW, {"front": 0.6, "back": 1.0}))
part(lambda: _slope("p_cheese_1x2", "Cheese slope 1×2", 1, 2, 2, 0, YELLOW, {"front": 0.5, "back": 1.0}))
part(lambda: _slope("p_slope_1x2", "Slope 1×2", 1, 2, 3, 1, RED, {"front": 0.55, "back": 1.0}))
part(lambda: _slope("p_slope_2x2", "Slope 2×2", 2, 2, 3, 1, RED, {"front": 0.55, "back": 1.0}))
part(lambda: _slope("p_slope_1x3", "Slope 1×3", 1, 3, 3, 1, RED, {"front": 0.45, "back": 1.0}))
part(lambda: _slope("p_slope_2x4", "Long slope 2×4", 2, 4, 3, 1, RED, {"front": 0.4, "back": 1.0}))
part(lambda: _curve("p_curve_1x2", "Curved slope 1×2", 1, 2, 2, 0, RED, {"front": 0.4, "back": 1.0}))
part(lambda: _curve("p_curve_1x3", "Curved slope 1×3", 1, 3, 2, 0, RED, {"front": 0.38, "back": 1.0}))
part(lambda: _curve("p_curve_1x4", "Curved slope 1×4", 1, 4, 2, 0, RED, {"front": 0.35, "back": 1.0}))
part(lambda: _curve("p_curve_2x2", "Curved slope 2×2", 2, 2, 2, 0, RED, {"front": 0.4, "back": 1.0}))
part(lambda: _curve("p_curve_2x4", "Curved slope 2×4", 2, 4, 3, 1, RED, {"front": 0.35, "back": 1.0}))
part(lambda: _curve("p_curve_2x6", "Curved slope 2×6", 2, 6, 3, 1, RED, {"front": 0.3, "back": 1.0}))
part(lambda: _curve("p_curve_2x8", "Long curved slope 2×8", 2, 8, 3, 2, RED, {"front": 0.28, "back": 1.0}))
part(lambda: _curve("p_curve_4x4", "Wide curved slope 4×4", 4, 4, 3, 1, RED, {"front": 0.33, "back": 1.0}))


@part
def inverted_curve_1x2():
    h = 2 * PLATE
    l = 2 * STUD
    pts = [(0.0, h), (0.0, h - 0.03)] + [(l * (k / 16.0), (h - 0.03) * (1 - math.sin((k / 16.0) * math.pi * 0.5))) for k in range(1, 17)] + [(l, h)]
    solid = union([profile_x(pts, 0.002, STUD - 0.002), studs(grid_cells(1, 2), h)])
    return Part("p_inverted_curve_1x2", "Inverted curve 1×2", "body", "curves", (STUD, h, l), solid, top_studs(grid_cells(1, 2), h) + sockets([(0, 1)]), RED, aero={"front": 0.7, "back": 1.0})


def _inverted_slope(along):
    h = BRICK
    l = along * STUD
    run = l - STUD
    lip = PLATE
    outline = [(0, h), (0, h - lip), (run, 0), (l, 0), (l, h)]
    solid = union([profile_x(outline, 0.002, STUD - 0.002), studs(grid_cells(1, along), h)])
    # Fine strips follow the underside, leaving room below the overhang.
    strips = round(run / FINE)
    solids = [[0, (h - lip) * (1 - (k + 1) / strips), k * FINE, STUD, h, (k + 1) * FINE] for k in range(strips)]
    solids.append([0, 0, run, STUD, h, l])
    return Part("p_inverted_slope_1x%d" % along, "Inverted slope 1×%d" % along, "body", "slopes", (STUD, h, l), solid,
                top_studs(grid_cells(1, along), h) + sockets([(0, along - 1)]), RED,
                aero={"front": 0.7, "back": 1.0}, solids=solids,
                racing_hull=[(x, y, z) for x in (0, STUD) for z, y in outline])


part(lambda: _inverted_slope(2))
part(lambda: _inverted_slope(3))


@part
def bow_1x4():
    """An arch-shaped curved brick, highest in the middle, for wheel arches
    and rounded noses."""
    h = 2 * PLATE
    l = 4 * STUD
    pts = [(0.0, 0.0)]
    for k in range(25):
        t = k / 24.0
        pts.append((l * t, 0.03 + (h - 0.03) * math.sin(t * math.pi)))
    pts.append((l, 0.0))
    solid = profile_x(pts, 0.002, STUD - 0.002)
    return Part("p_bow_1x4", "Bow 1×4", "body", "curves", (STUD, h, l), solid, sockets([(0, 0), (0, 3)]), RED, aero={"front": 0.45, "back": 0.45, "side": 0.8})


def _wedge(id, name, side, color):
    """A wedge plate, square at the back and cut away to a point at the front
    on one side."""
    w = 3 * STUD
    l = 2 * STUD
    if side == "left":
        pts = [(0.0, l), (w, l), (w, 0.0), (w - STUD, 0.0)]
    else:
        pts = [(0.0, l), (w, l), (STUD, 0.0), (0.0, 0.0)]
    solid = plan_y([(x, z) for x, z in pts], 0.001, PLATE - 0.001)
    cells = [(2, 0), (0, 1), (1, 1), (2, 1)] if side == "left" else [(0, 0), (0, 1), (1, 1), (2, 1)]
    solid = union([solid, studs(cells, PLATE)])
    return Part(id, name, "plate", "plates", (w, PLATE, l), solid, sockets(cells) + top_studs(cells, PLATE), color, mirror=("p_wedge_3x2_right" if side == "left" else "p_wedge_3x2_left"))


part(lambda: _wedge("p_wedge_3x2_left", "Wedge plate 3×2 left", "left", WHITE))
part(lambda: _wedge("p_wedge_3x2_right", "Wedge plate 3×2 right", "right", WHITE))


def _wedge_2x4(side):
    w, l = 2 * STUD, 4 * STUD
    outline = [(0, l), (w, l), (w, 0), (STUD, 0), (0, 3 * STUD)]
    cells = [(1, k) for k in range(4)] + [(0, 2), (0, 3)]
    solid = plan_y(outline, 0.001, PLATE - 0.001)
    # The boxes follow the diagonal so another part can use the cutaway.
    solids = [[max(0, STUD - (k + 1) * FINE / 3), 0, k * FINE, w, PLATE, (k + 1) * FINE] for k in range(round(l / FINE))]
    if side == "right":
        solid = mirror_x(solid).translate([w, 0, 0])
        outline = [(w - x, z) for x, z in outline]
        cells = [(1 - i, k) for i, k in cells]
        solids = [[w - x1, y0, z0, w - x0, y1, z1] for x0, y0, z0, x1, y1, z1 in solids]
    solid = union([solid, studs(cells, PLATE)])
    return Part("p_wedge_2x4_" + side, "Wedge plate 2×4 " + side, "plate", "plates", (w, PLATE, l), solid,
                sockets(cells) + top_studs(cells, PLATE), WHITE,
                mirror="p_wedge_2x4_" + ("right" if side == "left" else "left"), solids=solids,
                racing_hull=[(x, y, z) for y in (0, PLATE) for x, z in outline])


part(lambda: _wedge_2x4("left"))
part(lambda: _wedge_2x4("right"))


@part
def wheel_arch_1x4():
    """A mudguard arch over a wheel, two plates thick at the ends."""
    l = 4 * STUD
    h = 3 * PLATE
    outer = []
    for k in range(25):
        t = k / 24.0
        outer.append((l * 0.5 - math.cos(t * math.pi) * l * 0.5, h * math.sin(t * math.pi)))
    inner = [(l * 0.5 - math.cos(t * math.pi) * (l * 0.5 - 0.06), (h - 0.06) * math.sin(t * math.pi)) for t in [k / 24.0 for k in range(24, -1, -1)]]
    pts = outer + [(l - 0.06, 0.0)] + inner[1:-1] + [(0.06, 0.0)]
    solid = profile_x(pts, 0.002, STUD - 0.002)
    return Part("p_arch_1x4", "Wheel arch 1×4", "body", "arches", (STUD, h, l), solid, sockets([(0, 0), (0, 3)]), BLACK, aero={"front": 0.6, "back": 0.6, "side": 0.9})


# Bars and clips. A bar is a fifth of a stud across, the same as the round
# bit of a clip holds.

BAR = 0.05  # radius


def _bar(id, name, studs_long, color):
    l = studs_long * STUD
    solid = cylinder(BAR, l - 0.004, "z", (BAR, BAR, 0.002), 12)
    return Part(id, name, "body", "bars", (2 * BAR, 2 * BAR, l), solid, [c("bar", (BAR, BAR, 0.0), (0, 0, 1), l)], color)


for _n in (2, 3, 4, 6):
    part((lambda n: lambda: _bar("p_bar_%d" % n, "Bar %d long" % n, n, LIGHT_GREY))(_n))


@part
def plate_clip_1x1():
    """A plate 1×1 with a clip on its front edge that holds a bar across."""
    plate = union([box(0, 0, 0, STUD, PLATE, STUD), studs([(0, 0)], PLATE)])
    ring = cut(cylinder(BAR + 0.025, 0.12, "x", (0.065, PLATE * 0.5, -BAR - 0.01), 14), cylinder(BAR, 0.14, "x", (0.055, PLATE * 0.5, -BAR - 0.01), 14))
    solid = union([plate, ring, box(0.065, 0.0, -0.04, 0.185, PLATE, 0.01, edge=0.004)])
    con = sockets([(0, 0)]) + top_studs([(0, 0)], PLATE) + [c("clip", (STUD * 0.5, PLATE * 0.5, -BAR - 0.01), (1, 0, 0))]
    return Part("p_plate_clip_1x1", "Plate 1×1 with clip", "plate", "bars", (STUD, PLATE, STUD), solid, con, LIGHT_GREY, solids=[[0, 0, 0, STUD, PLATE, STUD]])


@part
def plate_handle_1x2():
    """A plate 1×2 with a bar handle along the top, for clips to hold."""
    plate = box(0, 0, 0, STUD, PLATE, 2 * STUD)
    handle = union([cylinder(BAR * 0.8, 0.08, "y", (STUD * 0.5, PLATE, 0.06), 10), cylinder(BAR * 0.8, 0.08, "y", (STUD * 0.5, PLATE, 2 * STUD - 0.06), 10),
                    cylinder(BAR, 2 * STUD - 0.08, "z", (STUD * 0.5, PLATE + 0.08, 0.04), 12)])
    con = sockets(grid_cells(1, 2)) + [c("bar", (STUD * 0.5, PLATE + 0.08, 0.06), (0, 0, 1), 2 * STUD - 0.12)]
    return Part("p_plate_handle_1x2", "Plate 1×2 with handle", "plate", "bars", (STUD, PLATE + 0.08 + BAR, 2 * STUD), union([plate, handle]), con, BLACK, solids=[[0, 0, 0, STUD, PLATE, 2 * STUD]])


@part
def bar_holder_clip():
    """A round 1×1 bar holder with a clip, to hang things off bars at any
    angle."""
    body = cylinder(STUD * 0.5 - 0.004, BRICK * 0.5, "y", (STUD * 0.5, 0.0, STUD * 0.5), 16)
    ring = cut(cylinder(BAR + 0.025, 0.12, "x", (0.065, BRICK * 0.25, -BAR - 0.01), 14), cylinder(BAR, 0.14, "x", (0.055, BRICK * 0.25, -BAR - 0.01), 14))
    con = sockets([(0, 0)]) + [c("clip", (STUD * 0.5, BRICK * 0.25, -BAR - 0.01), (1, 0, 0)), c("stud", (STUD * 0.5, BRICK * 0.5, STUD * 0.5), (0, 1, 0))]
    return Part("p_bar_holder", "Bar holder with clip", "body", "bars", (STUD, BRICK * 0.5, STUD), union([body, ring, studs([(0, 0)], BRICK * 0.5)]), con, DARK_GREY, solids=[[0, 0, 0, STUD, BRICK * 0.5, STUD]])


# Beams, pins and axles. Holes go across (x) through beams a stud
# apart, and pins and axles go through them.

HOLE = 0.06  # radius of a pin hole
BEAM_H = 0.225


def _beam(id, name, n, color):
    l = n * STUD
    pts = []
    r = BEAM_H * 0.5
    for k in range(13):
        a = math.pi * 0.5 + k * math.pi / 12.0
        pts.append((r + math.cos(a) * r, r + math.sin(a) * r))
    for k in range(13):
        a = -math.pi * 0.5 + k * math.pi / 12.0
        pts.append((l - r + math.cos(a) * r, r + math.sin(a) * r))
    solid = profile_x(pts, 0.004, STUD - 0.004)
    holes = [cylinder(HOLE, STUD + 0.02, "x", (-0.01, r, (k + 0.5) * STUD), 14) for k in range(n)]
    con = [c("hole", (0.0, r, (k + 0.5) * STUD), (1, 0, 0), STUD) for k in range(n)]
    return Part(id, name, "body", "technic", (STUD, BEAM_H, l), cut(solid, *holes), con, color)


for _n in (3, 5, 7, 9):
    part((lambda n: lambda: _beam("p_beam_%d" % n, "Beam %d long" % n, n, LIGHT_GREY))(_n))


@part
def technic_brick_1x4():
    solid = union([box(0, 0, 0, STUD, BRICK, 4 * STUD), studs(grid_cells(1, 4), BRICK)])
    holes = [cylinder(HOLE, STUD + 0.02, "x", (-0.01, 0.17, (k + 1) * STUD), 14) for k in range(3)]
    con = sockets(grid_cells(1, 4)) + top_studs(grid_cells(1, 4), BRICK) + [c("hole", (0.0, 0.17, (k + 1) * STUD), (1, 0, 0), STUD) for k in range(3)]
    return Part("p_technic_brick_1x4", "Brick 1×4 with holes", "brick", "technic", (STUD, BRICK, 4 * STUD), cut(solid, *holes), con, BLACK)



def _hole_walls(w, h, l, y, z, radius):
    """Four solid boxes leave clearance along a hole's axis."""
    return [[0, 0, 0, w, y - radius, l], [0, y + radius, 0, w, h, l],
            [0, y - radius, 0, w, y + radius, z - radius],
            [0, y - radius, z + radius, w, y + radius, l]]


@part
def technic_brick_1x2():
    cells = grid_cells(1, 2)
    solid = union([box(0, 0, 0, STUD, BRICK, 2 * STUD), studs(cells, BRICK)])
    hole = cylinder(HOLE, STUD + 0.02, "x", (-0.01, 0.17, STUD), 20)
    # Shallow rims clear the collar of a pin joining adjacent bricks.
    rims = [cylinder(HOLE + 0.012, 0.022, "x", (x, 0.17, STUD), 20) for x in (-0.01, STUD - 0.012)]
    con = sockets(cells) + top_studs(cells, BRICK) + [c("hole", (0, 0.17, STUD), (1, 0, 0), STUD)]
    return Part("p_technic_brick_1x2", "Brick 1×2 with pin hole", "brick", "technic", (STUD, BRICK, 2 * STUD), cut(solid, hole, *rims), con, BLACK,
                solids=_hole_walls(STUD, BRICK, 2 * STUD, 0.17, STUD, HOLE))


@part
def axle_hole_brick_1x1():
    y, z = BRICK * 0.5, STUD * 0.5
    # The cross clears the existing axle's 0.03 m arms and 0.055 m tips.
    arm, tip = 0.034, 0.059
    hole = union([box(-0.01, y - arm, z - tip, STUD + 0.01, y + arm, z + tip, edge=0),
                  box(-0.01, y - tip, z - arm, STUD + 0.01, y + tip, z + arm, edge=0)])
    solid = union([box(0, 0, 0, STUD, BRICK, STUD), studs([(0, 0)], BRICK)])
    walls = _hole_walls(STUD, BRICK, STUD, y, z, tip)
    for sy in (-1, 1):
        for sz in (-1, 1):
            ya, yb = sorted((y + sy * arm, y + sy * tip))
            za, zb = sorted((z + sz * arm, z + sz * tip))
            walls.append([0, ya, za, STUD, yb, zb])
    con = sockets([(0, 0)]) + top_studs([(0, 0)], BRICK) + [c("axle_hole", (0, y, z), (1, 0, 0), STUD)]
    return Part("p_axle_hole_brick_1x1", "Brick 1×1 with axle hole", "brick", "technic", (STUD, BRICK, STUD), cut(solid, hole), con, DARK_GREY, solids=walls)


@part
def pin():
    """A pin two studs long, half in one hole and half in the next."""
    solid = union([cylinder(HOLE - 0.006, 2 * STUD - 0.01, "x", (0.005, HOLE, HOLE), 14), cylinder(HOLE + 0.01, 0.02, "x", (STUD - 0.01, HOLE, HOLE), 14)])
    return Part("p_pin", "Pin", "body", "technic", (2 * STUD, 2 * HOLE, 2 * HOLE), solid, [c("pin", (0.0, HOLE, HOLE), (1, 0, 0), 2 * STUD)], BLACK, solids=[])


def _axle(id, name, n, color):
    l = n * STUD
    w = 0.03
    cross = union([box(0.002, HOLE - w, HOLE - 0.055, l - 0.002, HOLE + w, HOLE + 0.055, edge=0.0), box(0.002, HOLE - 0.055, HOLE - w, l - 0.002, HOLE + 0.055, HOLE + w, edge=0.0)])
    return Part(id, name, "body", "technic", (l, 2 * HOLE, 2 * HOLE), cross, [c("axle", (0.0, HOLE, HOLE), (1, 0, 0), l)], color, solids=[])


for _n in (2, 3, 4, 6, 8):
    part((lambda n: lambda: _axle("p_axle_%d" % n, "Axle %d long" % n, n, DARK_GREY))(_n))


@part
def wheel_holder_2x2():
    """A plate 2×2 with a pin out of each side for a wheel to go on."""
    plate = union([box(STUD, 0, 0, 3 * STUD, PLATE, 2 * STUD), studs([(1, 0), (2, 0), (1, 1), (2, 1)], PLATE)])
    pins = cylinder(HOLE - 0.006, 4 * STUD, "x", (0.0, PLATE * 0.5, STUD), 14)
    cells = [(1, 0), (2, 0), (1, 1), (2, 1)]
    con = sockets(cells) + top_studs(cells, PLATE) + [c("pin", (0.0, PLATE * 0.5, STUD), (1, 0, 0), STUD), c("pin", (3 * STUD, PLATE * 0.5, STUD), (1, 0, 0), STUD)]
    return Part("p_wheel_holder_2x2", "Wheel holder 2×2", "plate", "technic", (4 * STUD, PLATE, 2 * STUD), union([plate, pins]), con, BLACK, solids=[[STUD, 0, 0, 3 * STUD, PLATE, 2 * STUD]])


@part
def axle_plate_2x6():
    """A long plate 2×6 with an axle across underneath at each end, for a
    kart's front and back wheels."""
    plate = union([box(STUD, 0.06, 0, 3 * STUD, 0.06 + PLATE, 6 * STUD), studs([(i, k) for i in (1, 2) for k in range(6)], 0.06 + PLATE)])
    axles = [box(0.0, 0.0, z - 0.04, 4 * STUD, 0.08, z + 0.04, edge=0.0) for z in (STUD * 0.5, 5.5 * STUD)]
    cells = [(i, k) for i in (1, 2) for k in range(6)]
    con = top_studs(cells, 0.06 + PLATE) + [c("axle", (0.0, 0.04, z), (1, 0, 0), STUD) for z in (STUD * 0.5, 5.5 * STUD)] + [c("axle", (3 * STUD, 0.04, z), (1, 0, 0), STUD) for z in (STUD * 0.5, 5.5 * STUD)]
    return Part("p_axle_plate_2x6", "Axle plate 2×6", "plate", "technic", (4 * STUD, 0.06 + PLATE, 6 * STUD), union([plate] + axles), con, DARK_GREY, solids=[[STUD, 0.0, 0, 3 * STUD, 0.06 + PLATE, 6 * STUD]])


# Hinges and joints.

@part
def hinge_base_1x2():
    """The bottom half of a hinge: a plate 1×2 with the knuckle at its front
    edge, turning about a line across."""
    plate = union([box(0, 0, 0, STUD, PLATE, 2 * STUD), studs([(0, 1)], PLATE)])
    knuckle = union([cylinder(PLATE * 0.5, 0.07, "x", (0.0, PLATE * 0.5, 0.0), 14), cylinder(PLATE * 0.5, 0.07, "x", (STUD - 0.07, PLATE * 0.5, 0.0), 14)])
    con = sockets(grid_cells(1, 2)) + top_studs([(0, 1)], PLATE) + [c("hinge_a", (0.0, PLATE * 0.5, 0.0), (1, 0, 0), STUD)]
    return Part("p_hinge_base", "Hinge base 1×2", "plate", "hinges", (STUD, PLATE, 2 * STUD), union([plate, knuckle]), con, LIGHT_GREY)


@part
def hinge_top_1x2():
    """The top half of a hinge, a plate 1×2 with the finger at its back edge."""
    plate = union([box(0, 0, 0, STUD, PLATE, 2 * STUD), studs(grid_cells(1, 2), PLATE)])
    finger = cylinder(PLATE * 0.5, STUD - 0.15, "x", (0.075, PLATE * 0.5, 2 * STUD), 14)
    con = sockets([(0, 0)]) + top_studs(grid_cells(1, 2), PLATE) + [c("hinge_b", (0.0, PLATE * 0.5, 2 * STUD), (1, 0, 0), STUD)]
    return Part("p_hinge_top", "Hinge top 1×2", "plate", "hinges", (STUD, PLATE, 2 * STUD), union([plate, finger]), con, LIGHT_GREY)


@part
def ball_plate_1x2():
    plate = union([box(0, 0, 0, STUD, PLATE, 2 * STUD), studs([(0, 1)], PLATE)])
    ball = union([cylinder(0.03, 0.06, "-z", (STUD * 0.5, PLATE * 0.5, 0.0), 10), Manifold_sphere(0.075, (STUD * 0.5, PLATE * 0.5, -0.1))])
    con = sockets(grid_cells(1, 2)) + top_studs([(0, 1)], PLATE) + [c("ball", (STUD * 0.5, PLATE * 0.5, -0.1), (0, 0, -1))]
    return Part("p_ball_plate", "Plate 1×2 with ball", "plate", "hinges", (STUD, PLATE, 2 * STUD), union([plate, ball]), con, LIGHT_GREY, solids=[[0, 0, 0, STUD, PLATE, 2 * STUD]])


@part
def cup_plate_1x2():
    plate = union([box(0, 0, 0, STUD, PLATE, 2 * STUD), studs([(0, 1)], PLATE)])
    cup = cut(Manifold_sphere(0.1, (STUD * 0.5, PLATE * 0.5, -0.1)), Manifold_sphere(0.076, (STUD * 0.5, PLATE * 0.5, -0.1)), box(0.0, -0.1, -0.25, STUD, 0.3, -0.13, edge=0))
    con = sockets(grid_cells(1, 2)) + top_studs([(0, 1)], PLATE) + [c("cup", (STUD * 0.5, PLATE * 0.5, -0.1), (0, 0, -1))]
    return Part("p_cup_plate", "Plate 1×2 with cup", "plate", "hinges", (STUD, PLATE, 2 * STUD), union([plate, cup]), con, LIGHT_GREY, solids=[[0, 0, 0, STUD, PLATE, 2 * STUD]])


def Manifold_sphere(r, at):
    from manifold3d import Manifold
    return Manifold.sphere(r, 16).translate(list(at))


# Brackets, for studs facing forward or to the side.

@part
def bracket_1x2():
    """A plate 1×2 with a plate standing up at its front, studs facing
    forward."""
    flat = box(0, 0, 0, 2 * STUD, PLATE, STUD)
    up = box(0, 0, -PLATE, 2 * STUD, 2 * STUD, 0.0)
    front_studs = union([cylinder(STUD_RADIUS, STUD_HEIGHT, "-z", ((i + 0.5) * STUD, STUD * 1.5, -PLATE + 0.001), 12) for i in range(2)])
    con = sockets([(0, 0), (1, 0)]) + top_studs([(0, 0), (1, 0)], PLATE) + [c("stud", ((i + 0.5) * STUD, STUD * 1.5, -PLATE), (0, 0, -1)) for i in range(2)]
    solid = union([flat, up, studs([(0, 0), (1, 0)], PLATE), front_studs])
    return Part("p_bracket_1x2", "Bracket 1×2", "plate", "brackets", (2 * STUD, 2 * STUD, STUD + PLATE), solid.translate([0, 0, PLATE]), [_shift(x, (0, 0, PLATE)) for x in con], WHITE)


@part
def inverted_bracket_1x2():
    """A top plate with a front mounting face hanging below it."""
    h = 2 * STUD
    flat = box(0, h - PLATE, PLATE, 2 * STUD, h, STUD + PLATE)
    down = box(0, 0, 0, 2 * STUD, h, PLATE)
    cells = [(0, 0), (1, 0)]
    face_studs = [cylinder(STUD_RADIUS, STUD_HEIGHT, "-z", ((i + 0.5) * STUD, STUD * 0.5, 0.001), 12) for i in range(2)]
    con = [_shift(co, (0, h - PLATE, PLATE)) for co in sockets(cells)]
    con += [_shift(co, (0, 0, PLATE)) for co in top_studs(cells, h)]
    con += [c("stud", ((i + 0.5) * STUD, STUD * 0.5, 0), (0, 0, -1)) for i in range(2)]
    solid = union([flat, down, studs(cells, h).translate([0, 0, PLATE])] + face_studs)
    return Part("p_inverted_bracket_1x2", "Inverted bracket 1×2", "plate", "brackets", (2 * STUD, h, STUD + PLATE), solid, con, WHITE,
                solids=[[0, h - PLATE, PLATE, 2 * STUD, h, STUD + PLATE], [0, 0, 0, 2 * STUD, h, PLATE]])


def _shift(conn, by):
    out = dict(conn)
    out["at"] = [conn["at"][0] + by[0], conn["at"][1] + by[1], conn["at"][2] + by[2]]
    return out


@part
def side_stud_brick_1x1():
    """A brick 1×1 with a stud on its front as well as its top."""
    solid = union([box(0, 0, 0, STUD, BRICK, STUD), studs([(0, 0)], BRICK), cylinder(STUD_RADIUS, STUD_HEIGHT, "-z", (STUD * 0.5, BRICK * 0.5, 0.001), 12)])
    con = sockets([(0, 0)]) + top_studs([(0, 0)], BRICK) + [c("stud", (STUD * 0.5, BRICK * 0.5, 0.0), (0, 0, -1))]
    return Part("p_side_stud_brick", "Brick 1×1 with side stud", "brick", "brackets", (STUD, BRICK, STUD), solid, con, WHITE)


@part
def opposite_stud_brick_1x1():
    solid = union([box(0, 0, 0, STUD, BRICK, STUD), studs([(0, 0)], BRICK),
                   cylinder(STUD_RADIUS, STUD_HEIGHT, "-z", (STUD * 0.5, BRICK * 0.5, 0.001), 12),
                   cylinder(STUD_RADIUS, STUD_HEIGHT, "z", (STUD * 0.5, BRICK * 0.5, STUD - 0.001), 12)])
    con = sockets([(0, 0)]) + top_studs([(0, 0)], BRICK)
    con += [c("stud", (STUD * 0.5, BRICK * 0.5, z), axis) for z, axis in [(0, (0, 0, -1)), (STUD, (0, 0, 1))]]
    return Part("p_opposite_stud_brick", "Brick 1×1 with opposite side studs", "brick", "brackets", (STUD, BRICK, STUD), solid, con, WHITE)


@part
def headlight_brick():
    """A brick 1×1 with a sunken stud on its front, the classic way to turn
    a light or grille sideways."""
    solid = cut(union([box(0, 0, 0, STUD, BRICK, STUD), studs([(0, 0)], BRICK)]), box(0.03, 0.06, -0.01, STUD - 0.03, BRICK - 0.04, 0.05, edge=0))
    solid = union([solid, cylinder(STUD_RADIUS, STUD_HEIGHT + 0.03, "-z", (STUD * 0.5, BRICK * 0.5, 0.05), 12)])
    con = sockets([(0, 0)]) + top_studs([(0, 0)], BRICK) + [c("stud", (STUD * 0.5, BRICK * 0.5, 0.0), (0, 0, -1))]
    return Part("p_headlight_brick", "Headlight brick", "brick", "brackets", (STUD, BRICK, STUD), solid, con, WHITE)


# Wheels. The rim is the part's own colour and the tire is black. A wheel
# goes onto a pin or an axle through the middle of its hub, which runs
# across (x).

def _revolve_x(points, at, sides=36):
    """Spins a side view round the x axis. Points are (along x, out from the
    axis)."""
    from manifold3d import CrossSection
    from kit import _anticlockwise
    section = CrossSection([_anticlockwise([(r, x) for x, r in points])])
    solid = section.revolve(sides)
    # Revolving goes round z with the section's x as the radius and y along
    # z, so turn z onto x.
    return solid.rotate([0, 90, 0]).translate(list(at))


def _wheel(id, name, radius, width, rim_radius, grip, rolling, offroad=0.0, lugs=0, color=LIGHT_GREY, about="", deep=None, finish="plastic", shoulder=None, **stats):
    """A wheel. `deep` is (lugs round, how tall, half their length) for a
    chunky tread whose tops reach `radius`, with the tire under them."""
    w = width
    body = radius - deep[1] if deep else radius
    shoulder = shoulder or min(0.06, w * 0.25)
    tire = [(0.0, rim_radius * 0.92), (0.0, body - shoulder), (shoulder * 0.4, body - shoulder * 0.2), (shoulder, body),
            (w - shoulder, body), (w - shoulder * 0.4, body - shoulder * 0.2), (w, body - shoulder), (w, rim_radius * 0.92)]
    tire_solid = _revolve_x(tire, (0.0, radius, radius))
    if lugs:
        tire_solid = union([tire_solid] + _lugs(lugs, radius, w))
    if deep:
        tire_solid = union([tire_solid] + _lugs(deep[0], body, w, deep[1] + 0.03, deep[2], 0.03, radius))
    hub = HOLE + 0.02
    rim = [(0.004, hub), (0.004, rim_radius * 0.6), (w * 0.3, rim_radius * 0.75), (w * 0.3, rim_radius), (w - 0.004, rim_radius), (w - 0.004, hub)]
    rim_solid = _revolve_x(rim, (0.0, radius, radius), 28)
    con = [c("hub", (0.0, radius, radius), (1, 0, 0), w)]
    stats.update({"radius": radius, "width": w, "grip": grip, "rolling": rolling, "trim": (tire_solid, TYRE, "plastic")})
    if offroad:
        stats["offroad"] = offroad
    if about:
        stats["about"] = about
    if finish != "plastic":
        stats["finish"] = finish
    return Part(id, name, "wheel", "wheels", (w, 2 * radius, 2 * radius), rim_solid, con, color, **stats)


def _lugs(n, radius, w, height=0.06, half=0.045, sink=0.035, centre=None):
    """Two staggered rings of tread blocks round a tire of this radius,
    `height` tall from `sink` under its surface, on a wheel whose middle is
    `centre` high and back (the radius if not given)."""
    centre = radius if centre is None else centre
    out = []
    for k in range(n):
        for side in (0, 1):
            a = (k + 0.5 * side) * 360.0 / n
            x0 = 0.01 + side * w * 0.5
            lug = box(x0, radius - sink, -half, x0 + w * 0.45, radius - sink + height, half, edge=0.006)
            out.append(lug.rotate([a, 0, 0]).translate([0, centre, centre]))
    return out


part(lambda: _wheel("w_kart", "Kart wheel", 0.3, 0.25, 0.2, 1.0, 0.015, color=LIGHT_GREY))
part(lambda: _wheel("w_kart_wide", "Wide kart wheel", 0.3, 0.45, 0.2, 1.2, 0.022, color=LIGHT_GREY))
part(lambda: _wheel("w_racing", "Racing tire", 0.35, 0.35, 0.27, 1.15, 0.018, color=WHITE))
part(lambda: _wheel("w_slick", "Big slick", 0.4, 0.5, 0.28, 1.35, 0.028, color=DARK_GREY))
part(lambda: _wheel("w_offroad", "Off-road wheel", 0.42, 0.4, 0.25, 1.05, 0.03, offroad=0.6, lugs=14, color=YELLOW))
# Motorbike tires are thin, so they don't hold a bend as well as a kart's.
part(lambda: _wheel("w_moto", "Motorbike wheel", 0.45, 0.2, 0.34, 0.95, 0.014, color=BLACK))
part(lambda: _wheel("w_moto_trail", "Trail bike wheel", 0.45, 0.22, 0.32, 0.88, 0.02, offroad=0.5, lugs=16, color=RED))
part(lambda: _wheel("w_scooter", "Scooter wheel", 0.3, 0.18, 0.2, 0.95, 0.016, color=WHITE))
# Wheels for the bigger stock vehicles. Their weight and strength go by
# their size, like the first wheels.
part(lambda: _wheel("w_drag_slick", "Dragster slick", 0.5, 0.6, 0.28, 1.5, 0.03, offroad=-0.35, color=METAL, finish="metal", mass=9.0, strength=1400.0,
                    about="A huge soft slick for the back of a dragster. It grips the road like nothing else, and is hopeless on grass."))
# The dragster front wheel is as small as a wheel can be on an axle plate
# and still leave two plates under the plate.
part(lambda: _wheel("w_drag_front", "Dragster front wheel", 0.26, 0.12, 0.2, 0.9, 0.01, color=METAL, finish="metal", mass=1.2, strength=900.0,
                    about="Tiny and thin, for the front of a dragster. It rolls easily but barely grips."))
part(lambda: _wheel("w_monster", "Monster truck wheel", 0.6, 0.7, 0.32, 1.2, 0.042, offroad=0.75, color=LIGHT_GREY, deep=(16, 0.07, 0.075), shoulder=0.09,
                    mass=16.0, strength=1700.0, about="Huge, with deep tread. It climbs over anything, but lifts the truck up high where it rolls in corners."))
part(lambda: _wheel("w_truck", "Truck tire", 0.45, 0.5, 0.26, 1.1, 0.032, offroad=0.65, color=WHITE, deep=(16, 0.045, 0.055), shoulder=0.07,
                    mass=8.0, strength=1450.0, about="A chunky knobbly tire for trucks. Good on dirt and grass, a little slow on the road."))
part(lambda: _wheel("w_quad", "Quad wheel", 0.28, 0.4, 0.17, 1.1, 0.03, offroad=0.6, color=WHITE, deep=(12, 0.04, 0.045), shoulder=0.09,
                    mass=4.5, strength=1250.0, about="Small, fat and knobbly, for quads. It grips well on dirt."))


@part
def mudguard_2x4():
    """A mudguard arch two studs wide that clips over a wheel, with a plate
    to fix it at each end."""
    l = 4 * STUD
    h = 3 * PLATE
    outer = [(l * 0.5 - math.cos(t * math.pi) * l * 0.5, h * math.sin(t * math.pi)) for t in [k / 24.0 for k in range(25)]]
    inner = [(l * 0.5 - math.cos(t * math.pi) * (l * 0.5 - 0.05), (h - 0.05) * math.sin(t * math.pi)) for t in [k / 24.0 for k in range(24, -1, -1)]]
    arch = profile_x(outer + [(l - 0.05, 0.0)] + inner[1:-1] + [(0.05, 0.0)], 0.002, 2 * STUD - 0.002)
    cells = [(0, 0), (1, 0), (0, 3), (1, 3)]
    return Part("p_mudguard_2x4", "Mudguard 2×4", "body", "arches", (2 * STUD, h, l), arch, sockets(cells), RED, aero={"front": 0.5, "back": 0.6, "side": 0.9})


# Bike parts.

@part
def front_fork():
    """A motorbike's front fork: a crown with studs on top and two legs down
    to an axle the wheel goes on. From the axle to the bottom of the crown is
    a brick more than on the swingarm, so with the same wheels a brick (or an
    engine as tall) on the swingarm brings it level with the crown. It turns
    with the wheel in it when that's a steered wheel."""
    top = 0.7
    crown = union([box(0, top, 0, 2 * STUD, top + PLATE, STUD), studs(grid_cells(2, 1), top + PLATE)])
    legs = [box(x, 0.0, 0.07, x + 0.08, top + 0.01, 0.18, edge=0.01) for x in (0.03, 2 * STUD - 0.11)]
    axle = cylinder(0.03, 2 * STUD - 0.06, "x", (0.03, 0.045, 0.125), 10)
    con = top_studs(grid_cells(2, 1), top + PLATE) + sockets(grid_cells(2, 1), top) + [c("axle", (0.11, 0.045, 0.125), (1, 0, 0), 2 * STUD - 0.22)]
    solids = [[0, top, 0, 2 * STUD, top + PLATE, STUD], [0.03, 0.0, 0.07, 0.11, top + 0.01, 0.18], [2 * STUD - 0.11, 0.0, 0.07, 2 * STUD - 0.03, top + 0.01, 0.18]]
    return Part("b_fork", "Front fork", "body", "bike", (2 * STUD, top + PLATE, STUD), union([crown, axle] + legs), con, METAL, finish="metal", solids=solids, steers=True)


@part
def swingarm():
    """The back fork of a motorbike that holds the back wheel, reaching back
    from a plate with studs on top."""
    base = union([box(0, 0.4, 0, 2 * STUD, 0.4 + PLATE, 2 * STUD), studs(grid_cells(2, 2), 0.4 + PLATE)])
    arms = [box(x, 0.02, 0.3, x + 0.07, 0.42, 1.0, edge=0.01) for x in (0.03, 2 * STUD - 0.1)]
    axle = cylinder(0.03, 2 * STUD - 0.06, "x", (0.03, 0.045, 0.875), 10)
    con = top_studs(grid_cells(2, 2), 0.4 + PLATE) + sockets(grid_cells(2, 2), 0.4) + [c("axle", (0.1, 0.045, 0.875), (1, 0, 0), 2 * STUD - 0.2)]
    solids = [[0, 0.4, 0, 2 * STUD, 0.4 + PLATE, 2 * STUD], [0.03, 0.02, 0.3, 0.1, 0.42, 1.0], [2 * STUD - 0.1, 0.02, 0.3, 2 * STUD - 0.03, 0.42, 1.0]]
    return Part("b_swingarm", "Swingarm", "body", "bike", (2 * STUD, 0.4 + PLATE, 1.0), union([base, axle] + arms), con, BLACK, solids=solids)


@part
def fuel_tank():
    """A rounded motorbike tank, 2×2, for under the bars."""
    l = 2 * STUD
    h = 2 * PLATE + 0.06
    pts = [(0.0, 0.0), (0.0, h * 0.5)] + [(l * 0.5 - math.cos(t * math.pi) * l * 0.5, h * 0.5 + h * 0.5 * math.sin(t * math.pi)) for t in [k / 16.0 for k in range(1, 16)]] + [(l, h * 0.5), (l, 0.0)]
    side = profile_x(pts, 0.03, 2 * STUD - 0.03)
    return Part("b_tank", "Fuel tank", "body", "bike", (2 * STUD, h, l), side, sockets(grid_cells(2, 2)), RED, aero={"front": 0.5, "back": 0.6, "side": 0.8})


@part
def saddle():
    """A motorbike saddle, 2×3. You sit astride it."""
    l = 3 * STUD
    h = 2 * PLATE
    pts = [(0.0, 0.0), (0.0, h * 0.7), (0.15, h), (l - 0.1, h * 0.95), (l, h * 0.6), (l, 0.0)]
    solid = profile_x(pts, 0.02, 2 * STUD - 0.02)
    return Part("b_saddle", "Saddle", "seat", "bike", (2 * STUD, h, l), solid, sockets(grid_cells(2, 3)), BLACK, control=1.05, driver_height=7, astride=True)


@part
def bike_bars():
    """Motorbike handlebars on a stem at the front, swept back over a tank
    toward the rider, with grips. They turn about the stem."""
    high = PLATE + 0.3
    back = 3 * STUD - 0.05
    stem = union([box(STUD * 1.5, 0, 0, STUD * 2.5, PLATE, STUD), cylinder(0.035, 0.3 + 0.025, "y", (2 * STUD, PLATE, STUD * 0.5), 10)])
    riser = cylinder(0.025, back - STUD * 0.5, "z", (2 * STUD, high, STUD * 0.5), 10)
    bar = cylinder(0.025, 0.7, "x", (2 * STUD - 0.35, high, back), 10)
    grips = [cylinder(0.04, 0.14, "x", (x, high, back), 10) for x in (2 * STUD - 0.42, 2 * STUD + 0.28)]
    con = sockets([(1, 0), (2, 0)])
    return Part("b_bars", "Bike bars", "steering", "bike", (4 * STUD, PLATE + 0.34, 3 * STUD), union([stem, riser, bar]), con, METAL, finish="metal", control=1.15, style="bikebars",
                trim=(union(grips), BLACK, "plastic"), solids=[[STUD * 1.5, 0, 0, STUD * 2.5, PLATE, STUD]])


@part
def footpegs():
    plate = union([box(STUD, 0, 0, 3 * STUD, PLATE, STUD), studs([(1, 0), (2, 0)], PLATE)])
    pegs = cylinder(0.03, 4 * STUD, "x", (0.0, PLATE * 0.5, STUD * 0.5), 10)
    return Part("b_footpegs", "Footpegs", "plate", "bike", (4 * STUD, PLATE, STUD), union([plate, pegs]), sockets([(1, 0), (2, 0)]) + top_studs([(1, 0), (2, 0)], PLATE), METAL,
                finish="metal", solids=[[STUD, 0, 0, 3 * STUD, PLATE, STUD]])


@part
def nose_fairing():
    """A rounded front fairing for a motorbike, with a headlight in it."""
    l = 2 * STUD
    h = 0.45
    pts = [(0.0, 0.05)] + [(l * 0.9 * (1 - math.sin(t * math.pi * 0.5)), 0.05 + (h - 0.05) * t) for t in [k / 12.0 for k in range(13)]] + [(l, h), (l, 0.0), (0.2, 0.0)]
    shell = profile_x(pts, 0.03, 2 * STUD - 0.03)
    lamp = cylinder(0.08, 0.04, "-z", (STUD, 0.22, 0.17), 16)
    return Part("b_nose", "Front fairing", "body", "bike", (2 * STUD, h, l), shell, sockets([(0, 1), (1, 1)]), WHITE, aero={"front": 0.35, "back": 1.0, "side": 0.8},
                trim=(lamp, TRANS_CLEAR, "glass"), light="head")


def _capsule(a, b, r):
    """A rod with round ends from a to b, like a frame tube."""
    from manifold3d import Manifold
    return Manifold.batch_hull([Manifold.sphere(r, 10).translate(list(a)), Manifold.sphere(r, 10).translate(list(b))])


# Bodywork made for karts.

@part
def nose_4x6():
    """A racing nose, 4 wide at the back and narrowing to 2 at the tip,
    curving up from a thin tip to 3 plates high."""
    w = 4 * STUD
    l = 6 * STUD
    h = 3 * PLATE
    plan = plan_y([(STUD, 0.0), (3 * STUD, 0.0), (w, 2.5 * STUD), (w, l), (0.0, l), (0.0, 2.5 * STUD)], 0.0, h + 0.01)
    side = [(0.0, 0.0)] + [(l * 0.8 * t, 0.04 + (h - 0.04) * math.sin(t * math.pi * 0.5)) for t in [k / 16.0 for k in range(17)]] + [(l, h), (l, 0.0)]
    body = profile_x(side, 0.002, w - 0.002) ^ plan
    cells = [(1, 0), (2, 0), (1, 1), (2, 1)] + [(i, k) for i in range(4) for k in range(3, 6)] + [(0, 2), (1, 2), (2, 2), (3, 2)]
    return Part("p_nose_4x6", "Racing nose 4×6", "body", "curves", (w, h, l), body, sockets(cells), RED, aero={"front": 0.25, "back": 1.0, "side": 0.7},
                solids=[[STUD, 0, 0, 3 * STUD, h, 2 * STUD], [0, 0, 2 * STUD, w, h, l]])


@part
def nose_4x6_lights():
    """The racing nose with a pair of round headlights set into its front,
    either side of the tip."""
    base = nose_4x6()
    lenses = union([cylinder(0.045, 0.22, "-z", (x, 0.11, 0.4), 18) for x in (0.24, 0.76)])
    return Part("p_nose_4x6_lights", "Racing nose 4×6 with lights", "body", "curves", base.size, base.solid, base.connectors, RED,
                aero={"front": 0.25, "back": 1.0, "side": 0.7}, solids=base.stats["solids"], trim=(lenses, TRANS_CLEAR, "glass"), light="head")


@part
def cowl_2x6():
    """An engine cowl, rounded over the top and sloping down at the back."""
    w = 2 * STUD
    l = 6 * STUD
    h = 3 * PLATE
    from manifold3d import CrossSection
    arch = [(w * 0.5 + w * 0.5 * math.cos(t * math.pi), h * 0.35 + h * 0.65 * math.sin(t * math.pi)) for t in [k / 16.0 for k in range(17)]]
    across = CrossSection([[(0.002, 0.0), (w - 0.002, 0.0)] + [(x, y) for x, y in arch]]).extrude(l)
    side = [(0.0, 0.0), (0.0, h), (l * 0.45, h)] + [(l * 0.45 + l * 0.55 * t, h * (1.0 - 0.75 * t * t)) for t in [k / 12.0 for k in range(1, 13)]] + [(l, 0.0)]
    body = across ^ profile_x(side, 0.0, w)
    return Part("p_cowl_2x6", "Engine cowl 2×6", "body", "curves", (w, h, l), body, sockets(grid_cells(2, 6)), RED, aero={"front": 1.0, "back": 0.4, "side": 0.8})


# Car and truck bodywork: a few big smooth pieces, the way small racing sets
# build a car. Hollow pieces (cabs, the engine cover) have a sill down each
# side to fix them by, and solid boxes only where they're solid, so a seat,
# steering or engine fits inside.

def _d_section(hw, h, r, cx, bottom=0.0, n=6):
    """A cross-section with a flat bottom and its top corners rounded by r,
    hw either side of cx."""
    r = max(0.002, min(r, hw - 0.001, h - bottom - 0.001))
    pts = [(cx - hw, bottom), (cx + hw, bottom)]
    for k in range(n + 1):
        a = k / n * math.pi * 0.5
        pts.append((cx + hw - r + r * math.cos(a), h - r + r * math.sin(a)))
    for k in range(n + 1):
        a = math.pi * 0.5 + k / n * math.pi * 0.5
        pts.append((cx - hw + r + r * math.cos(a), h - r + r * math.sin(a)))
    return pts


def _loft(stations, bottom=0.0):
    """A smooth body through cross-sections along z. Each station is
    (z, middle x, half width, height, corner radius); neighbours are joined
    by their hull, so each step has to be convex."""
    from manifold3d import Manifold
    slices = []
    for k, (z, cx, hw, h, r) in enumerate(stations):
        sl = front(_d_section(hw, h, r, cx, bottom)).extrude(0.0005)
        slices.append(sl.translate([0, 0, z - (0.0005 if k == len(stations) - 1 else 0.0)]))
    return union([Manifold.batch_hull([slices[k], slices[k + 1]]) for k in range(len(slices) - 1)])


def _skin(body, boxes):
    """A thin layer over the top of a body inside the boxes, for stripes."""
    over = body.translate([0, 0.003, 0]) - body
    return over ^ union(boxes)


def _bonnet(id, name, along, plates, stripes=False, stripe_colour=WHITE, lanes=None, across=6, top=True):
    """A bonnet `across` studs wide, curving up from a thin lip at the
    front, rounded along both sides, with a row of studs along the flat back
    edge unless `top` is off. With `stripes` it has two racing stripes down
    the middle, or stripes in `lanes`, each (where it starts across, how
    wide), in studs."""
    w = across * STUD
    l = along * STUD
    h = plates * PLATE
    lip = 0.05
    run = l - STUD
    stations = []
    for k in range(17):
        t = k / 16.0
        y = lip + (h - lip) * math.sin(t * math.pi * 0.5)
        stations.append((0.002 + (run - 0.002) * t, w * 0.5, w * 0.5 - 0.002, y, min(0.07, y * 0.6)))
    stations.append((l - 0.002, w * 0.5, w * 0.5 - 0.002, h, 0.07))
    body = _loft(stations)
    cells = [(i, along - 1) for i in range(across)]
    stats = {}
    if stripes:
        if lanes:
            cuts = [box(x0 * STUD, 0.0, -0.1, (x0 + n) * STUD, h + 0.1, l + 0.1, edge=0) for x0, n in lanes]
        else:
            cuts = [box(x0, 0.0, -0.1, x0 + 0.2, h + 0.1, l + 0.1, edge=0) for x0 in (w * 0.5 - 0.28, w * 0.5 + 0.08)]
        stats["trim"] = (_skin(body, cuts), stripe_colour, "plastic")
    if not top:
        cells = []
    solid = union([body] + ([studs(cells, h)] if cells else []))
    return Part(id, name, "body", "curves", (w, h, l), solid, sockets(grid_cells(across, along)) + top_studs(cells, h), RED,
                aero={"front": 0.3, "back": 1.0, "side": 0.8}, **stats)


part(lambda: _bonnet("p_bonnet_6x4", "Curved bonnet 6×4", 4, 2))
part(lambda: _bonnet("p_bonnet_6x6", "Curved bonnet 6×6", 6, 3))
part(lambda: _bonnet("p_bonnet_6x6_stripes", "Striped bonnet 6×6", 6, 3, stripes=True))
part(lambda: _bonnet("p_bonnet_4x4_lime_stripe", "Smooth bonnet 4×4 with a lime stripe", 4, 3, stripes=True, stripe_colour=LIME, lanes=((1.8, 0.4),), across=4, top=False))
part(lambda: _bonnet("p_bonnet_4x6_black_stripes", "Bonnet 4×6 with black stripes", 6, 3, stripes=True, stripe_colour=BLACK, lanes=((0, 1), (3, 1)), across=4))


def _shell(side_pts, front_pts, w, l, t, r_side, r_front):
    """A hollow body open underneath: the side view pushed across, cut to the
    front view pushed back, with walls t thick. Returns the outside, the
    shell and the middle of its walls (for glass)."""
    sv = rounded(side(side_pts), r_side)
    fv = rounded(front(front_pts), r_front)
    floor = box(-1, -1, -1, 3, 0.0, 3, edge=0)

    def solid(d):
        return (push_x(sv.offset(-d), -0.5, w + 0.5) ^ push_z(fv.offset(-d), -0.5, l + 0.5)) - floor

    outer = solid(0.0)
    inner = solid(t)
    return outer, outer - inner, solid(t * 0.35) - inner


def _sills(outer, w, l, across):
    """A plate high strip down each side to fix a hollow body by."""
    return outer ^ union([box(0, 0, 0, STUD, PLATE, l, edge=0), box(w - STUD, 0, 0, w, PLATE, l, edge=0)])


@part
def car_cab():
    """A car's cab 4×6 with a sloping windscreen and back window and two
    windows down each side. The driver sits inside."""
    w, l, h = 4 * STUD, 6 * STUD, 0.6
    sv = [(0.0, -0.3), (0.0, 0.08), (0.55, h), (1.12, h), (l, 0.12), (l, -0.3)]
    fv = [(0.002, -0.3), (w - 0.002, -0.3), (w - 0.002, 0.12), (w - 0.09, h), (0.09, h), (0.002, 0.12)]
    outer, shell, glass_layer = _shell(sv, fv, w, l, 0.04, 0.05, 0.08)
    side_view = (rounded(side(sv), 0.05).offset(-0.08) - side([(-1, -1), (-1, 0.16), (3, 0.16), (3, -1)])) - side([(0.74, -1), (0.74, 2), (0.82, 2), (0.82, -1)])
    cutters = union([
        push_x(side_view, -0.1, 0.3), push_x(side_view, w - 0.3, w + 0.1),
        box(0.13, 0.14, -0.2, w - 0.13, h - 0.07, 0.5, edge=0),
        box(0.15, 0.18, 1.18, w - 0.15, h - 0.08, l + 0.2, edge=0),
    ])
    roof = [(1, 2), (2, 2), (1, 3), (2, 3)]
    body = union([shell - cutters, _sills(outer, w, l, 4), studs(roof, h)])
    cells = [(i, k) for i in (0, 3) for k in range(6)]
    return Part("p_cab_4x6", "Car cab 4×6", "body", "curves", (w, h, l), body, sockets(cells) + top_studs(roof, h), WHITE,
                trim=(glass_layer ^ cutters, GLASS, "glass"), aero={"front": 0.45, "back": 0.6, "side": 0.8}, mass=4.0, strength=900.0,
                solids=[[0, 0, 0, STUD, PLATE, l], [w - STUD, 0, 0, w, PLATE, l], [0, h - PLATE, 0.55, w, h, 1.12]])


@part
def truck_cab():
    """A tall boxy truck cab 6×4 with a big windscreen, side windows and a
    small back window, and studs on the roof for lights."""
    w, l, h = 6 * STUD, 4 * STUD, 0.8
    sv = [(0.0, -0.3), (0.0, 0.32), (0.12, h), (l, h), (l, -0.3)]
    fv = [(0.002, -0.3), (w - 0.002, -0.3), (w - 0.002, 0.3), (w - 0.04, h), (0.04, h), (0.002, 0.3)]
    outer, shell, glass_layer = _shell(sv, fv, w, l, 0.04, 0.04, 0.06)
    cutters = union([
        box(0.13, 0.38, -0.2, w - 0.13, h - 0.08, 0.2, edge=0),
        box(-0.1, 0.38, 0.26, 0.3, h - 0.08, l - 0.1, edge=0), box(w - 0.3, 0.38, 0.26, w + 0.1, h - 0.08, l - 0.1, edge=0),
        box(0.42, 0.46, l - 0.2, w - 0.42, h - 0.12, l + 0.2, edge=0),
    ])
    roof = [(i, k) for i in range(1, 5) for k in range(1, 4)]
    body = union([shell - cutters, _sills(outer, w, l, 6), studs(roof, h)])
    cells = [(i, k) for i in (0, 5) for k in range(4)]
    return Part("p_truck_cab_6x4", "Truck cab 6×4", "body", "curves", (w, h, l), body, sockets(cells) + top_studs(roof, h), WHITE,
                trim=(glass_layer ^ cutters, GLASS, "glass"), aero={"front": 0.8, "back": 1.0, "side": 0.9}, mass=6.0, strength=1100.0,
                solids=[[0, 0, 0, STUD, PLATE, l], [w - STUD, 0, 0, w, PLATE, l], [0, h - PLATE, 0.12, w, h, l]])


def _big_arch(id, name, across, smooth=False, stripe=None):
    """A big wheel arch 6 long with flat ends 4 plates high and studs on
    them, humped over the opening. The opening clears a wheel up to 0.45 m
    across with its middle a plate or two under the arch's bottom. A
    `smooth` one has no studs on its ends, so it reads as one smooth side;
    `stripe` runs a stripe that colour down the middle of its top."""
    w = across * STUD
    l = 6 * STUD
    base = 4 * PLATE
    hump = 0.08
    a, b = 0.5, 0.36
    top = []
    for k in range(33):
        z = l * k / 32.0
        u = min(1.0, max(0.0, (z - STUD) / (l - 2 * STUD)))
        top.append((z, base + hump * math.sin(u * math.pi)))
    sv = side([(0.0, 0.0)] + top + [(l, 0.0)])
    hole = side([(l * 0.5 + a * math.cos(k / 24.0 * math.pi), b * math.sin(k / 24.0 * math.pi)) for k in range(25)] + [(l * 0.5 - a, -0.1), (l * 0.5 + a, -0.1)])
    fv = rounded(front([(0.002, -0.1), (w - 0.002, -0.1), (w - 0.002, base + hump), (0.002, base + hump)]), 0.05)
    body = push_x(sv - hole, 0.0, w) ^ push_z(fv, 0.002, l - 0.002)
    ends = [(i, k) for i in range(across) for k in (0, 5)]
    stats = {}
    if stripe:
        lane = box(w * 0.5 - 0.05, 0.0, -0.1, w * 0.5 + 0.05, 1.0, l + 0.1, edge=0)
        stats["trim"] = (_skin(body, [lane]), stripe, "plastic")
    top = [] if smooth else ends
    solid = union([body, studs(top, base)]) if top else body
    return Part(id, name, "body", "arches", (w, base + hump, l), solid, sockets(ends) + top_studs(top, base), RED, **stats,
                aero={"front": 0.5, "back": 0.6, "side": 0.9}, mass=round(0.7 * across, 1), strength=500.0 + 100.0 * across,
                solids=[[0, 0, 0, w, base, STUD], [0, 0, l - STUD, w, base, l], [0, b, STUD, w, base + hump, l - STUD]])


part(lambda: _big_arch("p_arch_2x6", "Big wheel arch 2×6", 2))
part(lambda: _big_arch("p_arch_3x6", "Big wheel arch 3×6", 3))
part(lambda: _big_arch("p_arch_2x6_smooth", "Smooth wheel arch 2×6", 2, smooth=True))
part(lambda: _big_arch("p_arch_2x6_yellow_stripe", "Smooth wheel arch 2×6 with a yellow stripe", 2, smooth=True, stripe=YELLOW))


@part
def mud_flap():
    """A mud flap 2 wide hanging under a plate, to go behind a wheel. It
    clips on by two studs along its top edge."""
    w, h = 2 * STUD, 0.15
    sheet = box(0.0, 0.0, 0.03, w, h, 0.07)
    strip = box(0.0, h - 0.03, 0.0, w, h, STUD)
    cells = [(0, 0), (1, 0)]
    return Part("d_mud_flap", "Mud flap", "body", "details", (w, h, STUD), union([sheet, strip, studs(cells, h)]), top_studs(cells, h), RED,
                aero={"front": 0.9, "back": 0.9}, mass=0.2, strength=300.0, solids=[[0, h - 0.03, 0, w, h, STUD], [0, 0, 0.03, w, h, 0.07]])


@part
def nose_cone_2x6():
    """A long formula nose, 2 wide at the back, tapering and dropping to a
    low rounded tip."""
    w, l, h = 2 * STUD, 6 * STUD, 3 * PLATE
    stations = []
    for k in range(17):
        t = k / 16.0
        z = 0.002 + (l - 0.004) * t
        u = min(1.0, z / (4.5 * STUD))
        hw = 0.08 + (w * 0.5 - 0.082) * math.sin(u * math.pi * 0.5)
        y = 0.09 + (h - 0.09) * math.sin(u * math.pi * 0.5)
        if k == 0:
            hw, y = 0.05, 0.06
        stations.append((z, w * 0.5, hw, y, min(hw, y) * 0.9))
    return Part("p_nose_cone_2x6", "Formula nose 2×6", "body", "curves", (w, h, l), _loft(stations), sockets(grid_cells(2, 6)), RED,
                aero={"front": 0.2, "back": 1.0, "side": 0.6})


@part
def front_wing_8x2():
    """A front wing 8×2 with a flap and an endplate at each end, on a plate
    2×2 in the middle with studs for a nose."""
    w, l = 8 * STUD, 2 * STUD
    main = profile_x([(0.0, 0.01), (0.02, 0.0), (0.32, 0.0), (0.33, 0.04), (0.06, 0.05), (0.0, 0.035)], 0.04, w - 0.04)
    flap = profile_x([(0.3, 0.045), (0.32, 0.03), (0.49, 0.11), (0.5, 0.14), (0.47, 0.145)], 0.04, w - 0.04)
    plate = [(0.0, 0.0), (0.0, 0.1), (0.1, 0.2), (l, 0.2), (l, 0.0)]
    ends = [profile_x(plate, x, x + 0.04) for x in (0.002, w - 0.042)]
    middle = [(3, 0), (4, 0), (3, 1), (4, 1)]
    mount = union([box(3 * STUD, 0, 0, 5 * STUD, PLATE, l), studs(middle, PLATE)])
    return Part("d_front_wing_8x2", "Front wing with endplates 8×2", "wing", "details", (w, 0.2, l), union([main, flap, mount] + ends),
                sockets(middle) + top_studs(middle, PLATE), RED, lift_area=0.35, aero={"front": 0.8, "back": 0.8}, mass=1.3, strength=300.0,
                solids=[[3 * STUD, 0, 0, 5 * STUD, PLATE, l], [0, 0, 0, w, 0.05, l], [0, 0, 0, 0.04, 0.2, l], [w - 0.04, 0, 0, w, 0.2, l]])


@part
def rear_wing_8():
    """A big rear wing 8 wide with a flap and tall black endplates, up on
    two struts from a plate 2×2 in the middle."""
    w, l = 8 * STUD, 2 * STUD
    lift = 0.42
    main = profile_x([(0.0, 0.02), (0.03, 0.0), (0.34, 0.01), (0.35, 0.05), (0.08, 0.07), (0.0, 0.05)], 0.04, w - 0.04).translate([0, lift, 0])
    flap = profile_x([(0.3, 0.07), (0.33, 0.05), (0.49, 0.15), (0.5, 0.19), (0.47, 0.19)], 0.04, w - 0.04).translate([0, lift, 0])
    plate = rounded(side([(0.0, 0.3), (0.0, 0.66), (l, 0.7), (l, 0.3)]), 0.03)
    ends = [push_x(plate, x, x + 0.04) for x in (0.002, w - 0.042)]
    struts = [push_x(rounded(side([(0.14, PLATE - 0.01), (0.2, lift + 0.03), (0.34, lift + 0.03), (0.34, PLATE - 0.01)]), 0.01), x, x + 0.04) for x in (0.8, 1.16)]
    middle = [(3, 0), (4, 0), (3, 1), (4, 1)]
    foot = box(3 * STUD, 0, 0, 5 * STUD, PLATE, l)
    return Part("d_rear_wing_8", "Big rear wing 8 wide", "wing", "details", (w, 0.7, l), union([main, flap, foot] + struts),
                sockets(middle), RED, trim=(union(ends), BLACK, "plastic"), lift_area=0.7, aero={"front": 0.9, "back": 0.9}, mass=2.0, strength=350.0,
                solids=[[3 * STUD, 0, 0, 5 * STUD, PLATE, l], [0.04, lift, 0, w - 0.04, lift + 0.2, l], [0, 0.3, 0, 0.04, 0.7, l], [w - 0.04, 0.3, 0, w, 0.7, l]])


@part
def bonnet_scoop():
    """An air scoop 2×3 for a bonnet, tall at the front with a dark intake,
    sloping down to the back."""
    w, l, h = 2 * STUD, 3 * STUD, 0.24
    stations = []
    for k in range(9):
        t = k / 8.0
        stations.append((0.002 + (l - 0.004) * t, w * 0.5, w * 0.5 - 0.02, h - (h - 0.08) * t * t, 0.05))
    intake = box(0.07, 0.04, -0.1, w - 0.07, h - 0.06, 0.12, edge=0)
    inside = box(0.075, 0.045, 0.03, w - 0.075, h - 0.065, 0.13, edge=0)
    return Part("p_scoop_2x3", "Bonnet scoop 2×3", "body", "curves", (w, h, l), _loft(stations) - intake, sockets(grid_cells(2, 3)), RED,
                trim=(inside, BLACK, "plastic"), aero={"front": 0.9, "back": 0.5, "side": 0.8})


@part
def fin_cover_4x6():
    """A long engine cover 4×6 with a fin along the top, like an endurance
    racer's. It's hollow, so an engine 2 wide and 3 plates high fits under
    its front, between the sills."""
    w, l, h, low = 4 * STUD, 6 * STUD, 0.4, 0.18

    def height(z):
        u = min(1.0, max(0.0, (z - 1.0) / (l - 1.0)))
        return low + (h - low) * (1 + math.cos(u * math.pi)) * 0.5

    def stations(d):
        out = []
        for k in range(21):
            z = d + 0.002 + (l - 2 * d - 0.004) * k / 20.0
            y = height(z) - d
            if k == 0:
                y -= 0.04
            out.append((z, w * 0.5, w * 0.5 - 0.002 - d, y, 0.12 - d))
        return out

    outer = _loft(stations(0.0))
    inner = _loft(stations(0.04), bottom=-0.1)
    fin = profile_x([(0.35, h - 0.03), (1.0, h - 0.03), (l, low - 0.03), (l, 0.68), (l - 0.12, 0.7)], w * 0.5 - 0.02, w * 0.5 + 0.02)
    body = union([outer - inner, _sills(outer, w, l, 4), fin])
    cells = [(i, k) for i in (0, 3) for k in range(6)]
    return Part("p_fin_cover_4x6", "Engine cover with fin 4×6", "body", "curves", (w, 0.7, l), body, sockets(cells), RED,
                aero={"front": 1.0, "back": 0.4, "side": 0.8}, mass=4.0, strength=800.0,
                solids=[[0, 0, 0, STUD, PLATE, l], [w - STUD, 0, 0, w, PLATE, l], [0, h - PLATE, 0, w, h, 1.0], [w * 0.5 - 0.02, h, 0.35, w * 0.5 + 0.02, 0.7, l]])


def _pinstripe(id, name, along):
    """A smooth tile 2 wide with two thin white stripes down it."""
    w, l = 2 * STUD, along * STUD
    tile = box(0, 0, 0, w, PLATE, l)
    lines = union([box(x, PLATE - 0.006, 0.01, x + 0.035, PLATE + 0.004, l - 0.01, edge=0) for x in (0.07, w - 0.105)])
    return Part(id, name, "plate", "tiles", (w, PLATE, l), tile, sockets(grid_cells(2, along)), BLUE, trim=(lines, WHITE, "plastic"),
                aero={"front": 0.9, "back": 0.9})


part(lambda: _pinstripe("p_pinstripe_2x4", "Pinstripe tile 2×4", 4))
part(lambda: _pinstripe("p_pinstripe_2x6", "Pinstripe tile 2×6", 6))


# Motorbikes, the way toy motorbikes come: a frame in one piece with the
# engine, tank, seat and swingarm in it, a front fork with its bars on top
# that turns as one, and a fairing that clips on the front. Everything is in
# the fine unit, measured from the ground with the wheels on, from the front
# of the fork (where the front axle is, 10 back) and across the frame.


def _f(*v):
    return [x * FINE for x in v]


def _tube(a, b, r):
    """A tube from a to b, r across, all in the fine unit."""
    return _capsule(_f(*a), _f(*b), r * FINE)


def _moto_frame(id, name, style, color, twin, power, push, about):
    """A motorbike's frame. `style` is "sport", "dirt", "cruiser",
    "scooter" or "trike". The front wheel's middle is at R and its top at
    2R, with the fork crown just over it and the frame's head on that. The
    back axle is at `back`."""
    R = 24 if style == "scooter" else 36
    top = 2 * R
    back = {"sport": 170, "dirt": 170, "cruiser": 190, "scooter": 140, "trike": 150}[style]
    seat = {"sport": top + 10, "dirt": top + 16, "cruiser": top + 4, "scooter": top + 10, "trike": top + 10}[style]
    low = max(R - 4, 16)
    head = (top + 10, top + 30)
    wide = 80 if style == "trike" else 0
    x0, x1 = -wide, 40 + wide
    parts = []
    trim = []
    solids = []
    # The head over the fork crown, and the spine back to the seat.
    parts.append(box(*_f(2, head[0], 0, 38, head[1], 20), edge=0.02))
    solids.append([2, head[0], 0, 38, head[1], 20])
    trim.append(_tube((20, head[0] + 4, 14), (20, low + 8, 60), 2.6))
    trim.append(_tube((20, head[1] - 4, 16), (20, seat - 6, 84), 2.6))
    if style == "scooter":
        # An apron in front of the legs and a floor to put the feet on.
        parts.append(box(*_f(2, R + 26, 20, 38, head[1], 28), edge=0.015))
        parts.append(box(*_f(2, R + 12, 36, 38, R + 20, 84), edge=0.015))
        solids += [[2, R + 26, 20, 38, head[1], 28], [2, R + 12, 36, 38, R + 20, 84]]
    else:
        # The tank, sloping down from the head to the seat.
        tl = 44
        th = {"sport": 24, "dirt": 18, "cruiser": 22, "trike": 24}[style]
        pts = [(0.0, 0.0)] + [(tl * t, th * (1.0 - 0.45 * t * t) * (0.55 + 0.45 * math.sin(math.pi * min(1.0, t * 1.6)))) for t in [k / 16.0 for k in range(17)]] + [(tl, 0.0)]
        tank = profile_x([(z * FINE, y * FINE) for z, y in pts], 4 * FINE, 36 * FINE).translate(_f(0, top + 4, 21))
        parts.append(tank)
        solids.append([4, top + 4, 21, 36, top + 4 + th, 21 + tl])
    # The engine, low between the wheels, with its cylinders and fins.
    if style == "scooter":
        parts.append(box(*_f(6, low, 84, 34, seat - 8, 112), edge=0.03))
        solids.append([6, low, 84, 34, seat - 8, 112])
    else:
        e0, e1 = 48, 96
        parts.append(box(*_f(5, low, e0, 35, top - 12, e1), edge=0.03))
        solids.append([5, low, e0, 35, top - 12, e1])
        cylinders = {"sport": 2, "dirt": 1, "cruiser": 2, "trike": 2}[style]
        for k in range(cylinders):
            z = e0 + 12 + k * 22 if cylinders > 1 else e0 + 20
            lean = -10 if (style == "cruiser" and k == 0) else 6
            trim.append(_tube((20, low + 14, z), (20, top - 6, z + lean), 4.0))
            for fin in range(4):
                y = low + 18 + fin * 7
                trim.append(box(*_f(7, y, z - 7 + lean * fin / 6.0, 33, y + 1.6, z + 7 + lean * fin / 6.0), edge=0.004))
        # Footpegs out each side.
        trim.append(_tube((-8, low + 12, 64), (48, low + 12, 64), 1.8))
    # The seat, and the tail behind it.
    s0 = 76
    parts.append(box(*_f(4, seat - 8, s0, 36, seat, 122), edge=0.03))
    solids.append([4, seat - 8, s0, 36, seat, 122])
    under = box(*_f(6, top - 12, 84, 34, seat - 8, 122), edge=0.02)
    parts.append(under)
    tail_end = back - 10 if style != "trike" else back + 30
    # It rises clear of the back wheel.
    under_tail = max(seat - 14, top + 4)
    tail = profile_x([(z * FINE, y * FINE) for z, y in [(122, under_tail), (tail_end, seat + 2), (tail_end, seat + 8), (122, seat)]], 8 * FINE, 32 * FINE)
    parts.append(tail)
    solids.append([8, under_tail, 122, 32, seat + 2, tail_end])
    trim.append(box(*_f(10, seat + 1, tail_end - 4, 30, seat + 7, tail_end), edge=0.008))
    # The swingarm back to the axle, or for a trike an axle across.
    if style == "trike":
        housing = box(*_f(-20, R - 6, back - 8, 60, R + 6, back + 8), edge=0.02)
        parts.append(housing)
        solids.append([-20, R - 6, back - 8, 60, R + 6, back + 8])
        trim.append(_tube((20, low + 10, 96), (20, R, back - 8), 3.0))
        for side in (-1, 1):
            x = 20 + side * 70
            fender = cut(cylinder((R + 10) * FINE, 22 * FINE, "x", (0, 0, 0), 24).translate(_f(x - 11, R, back)),
                         cylinder((R + 6) * FINE, 30 * FINE, "x", (0, 0, 0), 24).translate(_f(x - 15, R, back)),
                         box(*_f(x - 20, -10, back - 60, x + 20, R + 4, back + 60), edge=0))
            parts.append(fender)
        axle = c("axle", _f(-wide, R, back), (1, 0, 0), (40 + 2 * wide) * FINE)
    else:
        for x in (2, 32):
            arm = box(*_f(x, R - 5, 96, x + 6, R + 5, back + 6), edge=0.01)
            parts.append(arm)
            solids.append([x, R - 5, 96, x + 6, R + 5, back + 6])
        axle = c("axle", _f(8.8, R, back), (1, 0, 0), 22.4 * FINE)
        # A mudguard over the back wheel, and the exhaust along the right.
        guard = cut(cylinder((R + 7) * FINE, 20 * FINE, "x", (0, 0, 0), 24).translate(_f(10, R, back)),
                    cylinder((R + 3) * FINE, 30 * FINE, "x", (0, 0, 0), 24).translate(_f(5, R, back)),
                    box(*_f(0, -10, back - 60, 40, R + 6, back + 60), edge=0), box(*_f(0, -10, back - 60, 40, R + 60, back - 10), edge=0))
        parts.append(guard)
        if style == "scooter":
            trim.append(_tube((34, low + 6, 110), (34, R + 6, back + 10), 2.6))
        else:
            trim.append(_tube((36, low + 6, 90), (36, R + 6, back + 14), 2.6))
            trim.append(cylinder(0.04, 16 * FINE, "z", tuple(_f(36, R + 6, back + 6)), 12))
    con = [c("socket", _f(x, head[0], 10), (0, -1, 0)) for x in (10, 30)]
    con += [c("side", _f(x, head[0] + 10, 0), (0, 0, -1)) for x in (10, 30)]
    con.append(axle)
    zmax = max(back + 30, tail_end)
    hi = max(head[1], seat + 8, top + 4 + 24)
    shift = [-x0 * FINE, -low * FINE, 0]
    body = union(parts + trim[:0]).translate(shift)
    trimmed = union(trim).translate(shift)
    for co in con:
        co["at"] = [co["at"][0] + shift[0], co["at"][1] + shift[1], co["at"][2]]
    solids = [[(a - x0) * FINE, (b - low) * FINE, cc * FINE, (d - x0) * FINE, (e - low) * FINE, g * FINE] for a, b, cc, d, e, g in solids]
    seat_box = [(4 - x0) * FINE, (seat - 8 - low) * FINE, s0 * FINE, (36 - x0) * FINE, (seat - low) * FINE, 122 * FINE]
    return Part(id, name, "seat", "bike", ((x1 - x0) * FINE, (hi - low) * FINE, zmax * FINE), body, con, color, about=about,
                trim=(trimmed, METAL, "metal"), solids=solids, seat_box=seat_box, engine_twin=twin, aero={"front": 0.6, "back": 0.7, "side": 0.8}, power=power, max_force=push, astride=True, driver_height=7,
                control=1.05, recline=0)


# A bike's narrow, so its engine is smaller than a kart's for the same speed,
# and it's light, so it still pulls away quickly.
part(lambda: _moto_frame("b_frame_sport", "Sports bike frame", "sport", RED, "engine_twin", 6500.0, 1300.0,
                         "A sports bike frame with a twin in it, and the seat and swingarm. Put a fork on the front, a fairing too if you like, and wheels on both ends."))
part(lambda: _moto_frame("b_frame_dirt", "Dirt bike frame", "dirt", YELLOW, "engine_micro", 6200.0, 1300.0,
                         "A dirt bike frame, light, with a little single and a tall seat. Put a fork on the front and wheels on both ends."))
part(lambda: _moto_frame("b_frame_cruiser", "Cruiser frame", "cruiser", BLACK, "engine_big", 6500.0, 1400.0,
                         "A long, low cruiser frame with a big twin. Put a fork on the front and wheels on both ends."))
part(lambda: _moto_frame("b_frame_scooter", "Scooter frame", "scooter", WHITE, "electric_motor", 4500.0, 1600.0,
                         "A scooter with an electric motor under the seat and a floor for your feet. Put the scooter fork on the front and small wheels on both ends."))
part(lambda: _moto_frame("b_frame_trike", "Trike frame", "trike", BLUE, "engine_big", 9000.0, 1600.0,
                         "A trike frame with an axle across the back for two wheels. Put a fork on the front and wheels on all three."))


def _moto_fork(id, name, style, about):
    """A front fork with the bars on top, which turns as one about the front
    axle. Its crown sits just over the wheel, under the frame's head, and the
    bars sweep back over the tank to the rider's hands."""
    R = 24 if style == "scooter" else 36
    top = 2 * R
    crown = (top + 2, top + 10)
    bar = top + 40 if style != "dirt" else top + 46
    reach = 66
    parts = [box(*_f(20, crown[0], 0, 60, crown[1], 20), edge=0.015)]
    for x in (22.4, 51.2):
        parts.append(box(*_f(x, R - 3.6, 5, x + 6.4, crown[0] + 1, 15), edge=0.01))
    parts.append(cylinder(0.03, 22.4 * FINE, "x", tuple(_f(28.8, R, 10)), 10))
    # The steerer up through the head, then the bars.
    parts.append(cylinder(0.035, (bar - crown[1]) * FINE, "y", tuple(_f(40, crown[1], 10)), 12))
    parts.append(_tube((40, bar, 10), (40, bar, reach - 10), 2.2))
    parts.append(_tube((16, bar, reach), (64, bar, reach), 2.2))
    for x in (16, 64):
        parts.append(_tube((40 + (x - 40) * 0.5, bar, reach - 10), (x, bar, reach), 2.0))
    grips = [_tube((x, bar, reach), (x + d * 9, bar, reach), 3.2) for x, d in ((22, -1), (58, 1))]
    if style == "dirt":
        guard = cut(cylinder((R + 6) * FINE, 18 * FINE, "x", (0, 0, 0), 24).translate(_f(31, R, 10)),
                    cylinder((R + 2) * FINE, 30 * FINE, "x", (0, 0, 0), 24).translate(_f(25, R, 10)),
                    box(*_f(20, -10, -60, 60, R + 8, 80), edge=0))
        parts.append(guard)
    # A round headlamp in a black shell, out in front of the frame's head.
    lamp_y = bar - 6 if style == "scooter" else crown[1] + 12
    lamp_r = 0.05 if style == "scooter" else 0.065
    grips.append(cylinder(lamp_r + 0.01, 0.06, "-z", tuple(_f(40, lamp_y, 1)), 16))
    lamp = cylinder(lamp_r, 0.012, "-z", tuple(_f(40, lamp_y, 1 - 0.06 / FINE)), 16)
    low = R - 3.6
    hi = bar + 4
    shift = [0, -low * FINE, 0]
    con = [c("stud", _f(x, crown[1], 10), (0, 1, 0)) for x in (30, 50)] + [c("axle", _f(28.8, R, 10), (1, 0, 0), 22.4 * FINE)]
    for co in con:
        co["at"] = [co["at"][0], co["at"][1] + shift[1], co["at"][2]]
    solids = [[20, crown[0], 0, 60, crown[1], 20], [22.4, R - 3.6, 5, 28.8, crown[0], 15], [51.2, R - 3.6, 5, 57.6, crown[0], 15]]
    solids = [[a * FINE, (b - low) * FINE, cc * FINE, d * FINE, (e - low) * FINE, g * FINE] for a, b, cc, d, e, g in solids]
    return Part(id, name, "steering", "bike", (80 * FINE, (hi - low) * FINE, (reach + 4) * FINE), union(parts).translate(shift), con, METAL, finish="metal",
                about=about, style="bikebars", control=1.15, grip_reach=0.3, mass=2.5, strength=900.0, trim=(union(grips).translate(shift), BLACK, "plastic"), solids=solids,
                lamp=(lamp.translate(shift), TRANS_CLEAR), light="head")


part(lambda: _moto_fork("b_moto_fork", "Motorbike fork", "road",
                        "A front fork with the bars on top, for a motorbike frame. The bars and the front wheel turn together."))
part(lambda: _moto_fork("b_moto_fork_dirt", "Dirt bike fork", "dirt",
                        "A dirt bike's fork with high bars and a mudguard up high over the wheel."))
part(lambda: _moto_fork("b_moto_fork_scooter", "Scooter fork", "scooter",
                        "A short fork with bars and a lamp, for the scooter frame and small wheels."))


@part
def moto_fairing():
    """A sports bike's fairing, with a headlight and a screen, that clips
    onto the front of the frame's head and stays put while the bars turn."""
    top = 72
    l = 30
    h0, h1 = top + 2, top + 40
    h = h1 - h0
    tip = 12.0
    pts = [(l, 0.0), (l, h)] + [(l * (1 - t), tip + (h - tip) * math.cos(t * math.pi * 0.5)) for t in [k / 12.0 for k in range(1, 13)]] + [(6.0, 0.0)]
    shell = profile_x([(z * FINE, y * FINE) for z, y in pts], 2 * FINE, 38 * FINE)
    lamp = cylinder(0.06, 0.06, "-z", tuple(_f(20, 18, 7)), 16)
    screen = profile_x([(z * FINE, y * FINE) for z, y in [(14, h1 - h0 - 2), (l, h1 - h0 + 12), (l + 2, h1 - h0 + 12), (18, h1 - h0 - 2)]], 6 * FINE, 34 * FINE)
    con = [c("clip", _f(x, 18, l), (0, 0, 1)) for x in (10, 30)]
    return Part("b_moto_fairing", "Sports fairing", "body", "bike", (40 * FINE, (h1 - h0 + 12) * FINE, (l + 2) * FINE), shell, con, WHITE,
                aero={"front": 0.3, "back": 1.0, "side": 0.8}, trim=(screen, TRANS_CLEAR, "glass"), lamp=(lamp, TRANS_CLEAR), light="head", solids=[[2 * FINE, 0, 0, 38 * FINE, (h1 - h0) * FINE, l * FINE]])


# Kart chassis and seats.

@part
def kart_axle_plate():
    """A plate 6×2 with a pin out of each side for a wheel, for the front or
    back of a kart. Any wheel goes on the pins right up against the plate."""
    cells = [(i, k) for i in range(1, 7) for k in range(2)]
    plate = union([box(STUD, 0, 0, 7 * STUD, PLATE, 2 * STUD), studs(cells, PLATE)])
    pins = [cylinder(HOLE - 0.006, STUD, "x", (x, PLATE * 0.5, STUD), 14) for x in (0.0, 7 * STUD)]
    con = sockets(cells) + top_studs(cells, PLATE) + [c("pin", (x, PLATE * 0.5, STUD), (1, 0, 0), STUD) for x in (0.0, 7 * STUD)]
    return Part("p_kart_axle_plate", "Kart axle plate 6×2", "plate", "technic", (8 * STUD, PLATE, 2 * STUD), union([plate] + pins), con, BLACK,
                solids=[[STUD, 0, 0, 7 * STUD, PLATE, 2 * STUD]], mass=2.0, strength=2500.0)


@part
def kart_axle_plate_4():
    """A narrow kart axle plate 4×2, pins out of each side like the 6×2, so
    the wheels sit in close to a slim formula body."""
    cells = [(i, k) for i in range(1, 5) for k in range(2)]
    plate = union([box(STUD, 0, 0, 5 * STUD, PLATE, 2 * STUD), studs(cells, PLATE)])
    pins = [cylinder(HOLE - 0.006, STUD, "x", (x, PLATE * 0.5, STUD), 14) for x in (0.0, 5 * STUD)]
    con = sockets(cells) + top_studs(cells, PLATE) + [c("pin", (x, PLATE * 0.5, STUD), (1, 0, 0), STUD) for x in (0.0, 5 * STUD)]
    return Part("p_kart_axle_plate_4", "Kart axle plate 4×2", "plate", "technic", (6 * STUD, PLATE, 2 * STUD), union([plate] + pins), con, BLACK,
                solids=[[STUD, 0, 0, 5 * STUD, PLATE, 2 * STUD]], mass=1.4, strength=2500.0)


def _seat(id, twin, across, plates, along, recline, back, color, bolsters=True):
    """A seat with a cushion filling its box, which the driver sits on top
    of, and a backrest rising behind them leaning back by `recline` degrees.
    It weighs the same and works the same as `twin`, one of the first seats."""
    w = across * STUD
    h = plates * PLATE
    l = along * STUD
    cushion = box(0.01, 0, 0.01, w - 0.01, h, l - 0.01, edge=0.025)
    rest = box(0.02, 0.0, -0.06, w - 0.02, back, 0.0, edge=0.025).rotate([recline, 0, 0]).translate([0, h - 0.02, l - 0.01])
    parts = [cushion, rest]
    if bolsters:
        for x in (0.0, w - 0.06):
            parts.append(box(x, h - 0.02, 0.06, x + 0.06, h + 0.07, l - 0.02, edge=0.02))
    return Part(id, "", "seat", "seats", (w, h, l), union(parts), sockets(grid_cells(across, along)), color, twin=twin)


part(lambda: _seat("s_seat", "seat", 2, 3, 2, 8, 0.3, BLACK, bolsters=False))
part(lambda: _seat("s_bucket_seat", "bucket_seat", 2, 2, 2, 25, 0.3, BLACK))
part(lambda: _seat("s_racing_seat", "racing_seat", 2, 2, 2, 15, 0.34, RED))
part(lambda: _seat("s_lay_down_seat", "lay_down_seat", 2, 1, 4, 62, 0.3, BLACK))


# Details.

@part
def headlight_1x1():
    lens = cylinder(STUD * 0.5 - 0.02, PLATE - 0.002, "y", (STUD * 0.5, 0.001, STUD * 0.5), 18)
    return Part("d_light_1x1", "Round light 1×1", "plate", "details", (STUD, PLATE, STUD), lens, sockets([(0, 0)]), TRANS_CLEAR, finish="glass", light="head")


@part
def taillight_1x2():
    lens = box(0, 0, 0, STUD, PLATE, 2 * STUD, edge=0.015)
    return Part("d_taillight_1x2", "Tail light 1×2", "plate", "details", (STUD, PLATE, 2 * STUD), lens, sockets(grid_cells(1, 2)), TRANS_RED, finish="glass", light="tail")


@part
def amber_1x1():
    """A round amber light, like a beacon or an indicator."""
    lens = cylinder(STUD * 0.5 - 0.02, PLATE - 0.002, "y", (STUD * 0.5, 0.001, STUD * 0.5), 18)
    return Part("d_amber_1x1", "Amber light 1×1", "plate", "details", (STUD, PLATE, STUD), lens, sockets([(0, 0)]), TRANS_AMBER, finish="glass", light="amber")


@part
def light_bar():
    """A bar of four round lamps along its front, for a roll cage or a bumper."""
    bar = union([box(0, 0, 0.02, 4 * STUD, BRICK, STUD, edge=0.02)])
    lenses = union([cylinder(0.09, 0.04, "-z", ((i + 0.5) * STUD, BRICK * 0.5, 0.025), 16) for i in range(4)])
    return Part("d_light_bar", "Light bar", "brick", "details", (4 * STUD, BRICK, STUD), bar, sockets(grid_cells(4, 1)) + top_studs(grid_cells(4, 1), BRICK), BLACK,
                light="head", trim=(lenses, TRANS_CLEAR, "glass"))


@part
def spotlights():
    """Two big round spotlights on a brick, facing forward."""
    body = union([box(0, 0, 0.04, 2 * STUD, BRICK, STUD, edge=0.02)] + [cylinder(0.11, 0.06, "-z", ((i + 0.5) * STUD, BRICK * 0.5, 0.05), 18) for i in range(2)])
    lenses = union([cylinder(0.1, 0.03, "-z", ((i + 0.5) * STUD, BRICK * 0.5, 0.0), 18) for i in range(2)])
    return Part("d_spotlights", "Spotlights", "brick", "details", (2 * STUD, BRICK, STUD), body, sockets(grid_cells(2, 1)), DARK_GREY,
                light="head", trim=(lenses, TRANS_CLEAR, "glass"))


@part
def round_lamp_2x2():
    """A big round headlamp in its own housing, facing forward."""
    housing = union([box(0, 0, 0.1, 2 * STUD, 0.08, 2 * STUD, edge=0.01), cylinder(0.22, 0.2, "-z", (STUD, 0.27, 0.32), 24)])
    lens = cylinder(0.2, 0.03, "-z", (STUD, 0.27, 0.12), 24)
    return Part("d_round_lamp_2x2", "Round lamp 2×2", "plate", "details", (2 * STUD, 0.5, 2 * STUD), housing, sockets(grid_cells(2, 2)), METAL,
                finish="metal", light="head", trim=(lens, TRANS_CLEAR, "glass"))


@part
def exhaust():
    """A chrome exhaust pipe on a plate, sticking out behind."""
    plate = union([box(0, 0, 0, STUD, PLATE, 2 * STUD), studs([(0, 0)], PLATE)])
    pipe = cut(cylinder(0.06, 0.6, "z", (STUD * 0.5, PLATE + 0.06, 0.1), 16), cylinder(0.045, 0.2, "z", (STUD * 0.5, PLATE + 0.06, 0.55), 16))
    return Part("d_exhaust", "Exhaust", "body", "details", (STUD, PLATE + 0.12, 0.7), union([plate, pipe]), sockets(grid_cells(1, 2)), METAL, finish="metal",
                solids=[[0, 0, 0, STUD, PLATE, 2 * STUD]])


@part
def mirror():
    """A wing mirror on a stalk."""
    base = box(0, 0, 0, STUD, PLATE, STUD)
    stalk = cylinder(0.02, 0.18, "y", (STUD * 0.5, PLATE, STUD * 0.5), 8)
    head = box(STUD * 0.5 - 0.1, PLATE + 0.14, STUD * 0.5 - 0.03, STUD * 0.5 + 0.1, PLATE + 0.26, STUD * 0.5 + 0.03, edge=0.015)
    return Part("d_mirror", "Mirror", "body", "details", (STUD, PLATE + 0.26, STUD), union([base, stalk, head]), sockets([(0, 0)]), BLACK, solids=[[0, 0, 0, STUD, PLATE, STUD]])


@part
def spoiler_4():
    """A rear wing 4 studs wide on two stands."""
    w = 4 * STUD
    blade_pts = [(0.0, 0.0), (0.03, 0.03), (STUD * 1.4, 0.05), (STUD * 1.5, 0.02), (STUD * 1.5, 0.0)]
    blade = profile_x(blade_pts, 0.002, w - 0.002).translate([0, 0.3, 0])
    stands = [box(x, 0, 0.1, x + 0.06, 0.32, 0.25, edge=0.008) for x in (STUD * 0.5, w - STUD * 0.5 - 0.06)]
    feet = [box(x - 0.09, 0, 0, x + 0.15, PLATE, STUD, edge=0.008) for x in (STUD * 0.5, w - STUD * 0.5 - 0.06)]
    return Part("d_spoiler", "Spoiler", "wing", "details", (w, 0.36, STUD * 1.5), union([blade] + stands + feet), sockets([(0, 0), (3, 0)]), BLACK, lift_area=0.25, aero={"front": 0.7, "back": 0.8},
                solids=[[0, 0.28, 0, w, 0.36, STUD * 1.5], [0, 0, 0, STUD, PLATE, STUD], [w - STUD, 0, 0, w, PLATE, STUD]])


def _screen(id, name, across, h, color=GLASS):
    """A windscreen leaning back from its bottom front edge."""
    l = 2 * STUD
    shell = profile_x([(0.0, 0.0), (0.04, 0.0), (l - 0.02, h - 0.02), (l - 0.06, h)], 0.004, across * STUD - 0.004)
    return Part(id, name, "screen", "details", (across * STUD, h, l), shell, sockets([(i, 0) for i in range(across)]), color, finish="glass", aero={"front": 0.5, "back": 1.0})


part(lambda: _screen("d_screen_2", "Windscreen 2 wide", 2, 0.35))
part(lambda: _screen("d_screen_4", "Windscreen 4 wide", 4, 0.4))


@part
def canopy():
    """A bubble canopy 4×6 that closes right over the driver."""
    l = 6 * STUD
    w = 4 * STUD
    h = 0.55
    from manifold3d import Manifold
    dome = Manifold.sphere(1.0, 36).scale([w * 0.5 - 0.01, h, l * 0.5 - 0.01]).translate([w * 0.5, 0.0, l * 0.5])
    dome = dome - box(-1, -2, -1, 2, 0.0, 2, edge=0)
    hollow = Manifold.sphere(1.0, 36).scale([w * 0.5 - 0.04, h - 0.03, l * 0.5 - 0.04]).translate([w * 0.5, 0.0, l * 0.5])
    shell = (dome - hollow) - box(-1, -2, -1, 2, 0.0, 2, edge=0)
    rim = cut(box(0, 0, 0, w, PLATE * 0.5, l, edge=0.01), box(0.06, -0.1, 0.06, w - 0.06, 0.2, l - 0.06, edge=0))
    cells = [(0, 0), (3, 0), (0, 5), (3, 5)]
    return Part("d_canopy", "Canopy", "screen", "details", (w, h, l), union([shell.translate([0, PLATE * 0.5, 0]), rim]), sockets(cells), GLASS, finish="glass",
                aero={"front": 0.35, "back": 0.6, "side": 0.6},
                solids=[[0, 0, 0, w, PLATE * 0.5, 0.06], [0, 0, l - 0.06, w, PLATE * 0.5, l], [0, 0, 0, 0.06, PLATE * 0.5, l], [w - 0.06, 0, 0, w, PLATE * 0.5, l]])



@part
def canopy_high_back():
    """A bubble canopy 4×6 that's highest three quarters of the way back, over a
    lay-down driver's helmet, and drops steeply behind it."""
    l = 6 * STUD
    w = 4 * STUD
    h = 0.6
    peak = 4.5 * STUD
    from manifold3d import Manifold

    def bubble(inset, top):
        # Two half egg shapes meeting at the peak: long in front, short behind.
        front = Manifold.sphere(1.0, 36).scale([w * 0.5 - inset, top, peak - inset]).translate([w * 0.5, 0.0, peak])
        back = Manifold.sphere(1.0, 36).scale([w * 0.5 - inset, top, l - peak - inset]).translate([w * 0.5, 0.0, peak])
        return union([front - box(-1, -2, peak, 2, 2, 3, edge=0), back - box(-1, -2, -2, 2, 2, peak, edge=0)])

    shell = (bubble(0.01, h) - bubble(0.04, h - 0.03)) - box(-1, -2, -1, 2, 0.0, 2, edge=0)
    rim = cut(box(0, 0, 0, w, PLATE * 0.5, l, edge=0.01), box(0.06, -0.1, 0.06, w - 0.06, 0.2, l - 0.06, edge=0))
    cells = [(0, 0), (3, 0), (0, 5), (3, 5)]
    return Part("d_canopy_high_back", "Canopy high at the back", "screen", "details", (w, h, l), union([shell.translate([0, PLATE * 0.5, 0]), rim]), sockets(cells), GLASS, finish="glass",
                aero={"front": 0.35, "back": 0.6, "side": 0.6},
                solids=[[0, 0, 0, w, PLATE * 0.5, 0.06], [0, 0, l - 0.06, w, PLATE * 0.5, l], [0, 0, 0, 0.06, PLATE * 0.5, l], [w - 0.06, 0, 0, w, PLATE * 0.5, l]])

# Engines and mechanical parts for the bigger stock vehicles.

def _rods(points, r):
    """Tubes joining the points one after another, like a bent pipe."""
    return union([_capsule(points[k], points[k + 1], r) for k in range(len(points) - 1)])


@part
def blower_v8():
    """A V8 with a supercharger and an air scoop on top, for hot rods and
    muscle cars. The block is painted and the rocker covers, blower, scoop
    and pulleys are chrome."""
    w, l, h = 3 * STUD, 4 * STUD, 0.7
    from manifold3d import Manifold
    mid = w * 0.5
    base = box(0.02, 0.0, 0.03, w - 0.02, 0.08, l - 0.03, edge=0.01)
    block = box(0.13, 0.06, 0.06, w - 0.13, 0.3, l - 0.06, edge=0.03)
    manifold = box(mid - 0.12, 0.26, 0.12, mid + 0.12, 0.4, l - 0.12, edge=0.02)

    def cover(sign):
        c = box(-0.08, -0.045, 0.08, 0.08, 0.045, l - 0.08, edge=0.03).rotate([0, 0, -35 * sign])
        return c.translate([mid + sign * 0.2, 0.31, 0])

    blower = box(mid - 0.16, 0.38, 0.1, mid + 0.16, 0.56, l - 0.14, edge=0.035)
    ribs = union([box(mid - 0.165, y, 0.14, mid + 0.165, y + 0.015, l - 0.18, edge=0.004) for y in (0.42, 0.46, 0.5)])
    hat = box(mid - 0.12, 0.55, 0.22, mid + 0.12, 0.58, l - 0.26, edge=0.01)
    scoop = profile_x([(0.2, 0.57), (0.22, h), (0.3, h), (l - 0.25, 0.6), (l - 0.25, 0.57)], mid - 0.1, mid + 0.1)
    mouth = box(mid - 0.075, 0.6, 0.15, mid + 0.075, h - 0.025, 0.36, edge=0)
    pulleys = union([cylinder(0.075, 0.05, "-z", (mid, 0.47, 0.1), 20), cylinder(0.09, 0.04, "-z", (mid, 0.17, 0.06), 20),
                     box(mid - 0.04, 0.17, 0.035, mid + 0.04, 0.47, 0.055, edge=0.01)])
    painted = union([base, block, manifold])
    chrome = union([cover(1), cover(-1), blower, ribs, hat, scoop - mouth, pulleys])
    return Part("e_blower_v8", "Blower V8", "engine", "engines", (w, h, l), painted, sockets(grid_cells(3, 4)), RED,
                trim=(chrome, METAL, "metal"), sound="engine_v8", power=18000.0, max_force=2300.0, mass=52.0, strength=1500.0,
                about="A V8 with a blower on top. A huge shove off the line and lots of power, but it's heavy.",
                solids=[[0, 0, 0, w, 0.4, l], [mid - 0.16, 0.4, 0.04, mid + 0.16, h, l - 0.14]])


@part
def open_exhausts():
    """Four short chrome pipes on a plate 1×4, sweeping up and back, to go
    beside an engine. Use one each side."""
    w, l, h = STUD, 4 * STUD, 0.36
    plate = box(0, 0, 0, w, PLATE, l)
    pipes = []
    for k in range(4):
        z = 0.08 + k * 0.21
        pipe = _capsule((w * 0.5, PLATE, z), (w * 0.5, h - 0.04, z + 0.16), 0.035)
        end = cylinder(0.024, 0.2, "y", (0, 0, 0), 12).rotate([45, 0, 0]).translate([w * 0.5, h - 0.04, z + 0.16])
        pipes.append(pipe - end)
    return Part("d_open_exhausts", "Open exhaust pipes", "body", "details", (w, h, l), union([plate] + pipes), sockets(grid_cells(1, 4)), METAL, finish="metal",
                aero={"front": 0.6, "back": 0.8}, mass=1.2, strength=500.0)


@part
def exhaust_stack():
    """A tall chrome exhaust stack for a big rig, on a plate 1×2, with a
    pipe in along the bottom and a slanted top."""
    w, l, h = STUD, 2 * STUD, 1.3
    plate = box(0, 0, 0, w, PLATE, l)
    stack = cylinder(0.07, h - PLATE, "y", (w * 0.5, PLATE, 0.375), 20)
    stack = stack - box(-1, 0, -1, 1, 1, 1, edge=0).rotate([-25, 0, 0]).translate([0, h - 0.05, 0.375])
    stack = stack - cylinder(0.05, 0.5, "y", (w * 0.5, h - 0.4, 0.375), 16)
    elbow = _rods([(w * 0.5, 0.17, 0.06), (w * 0.5, 0.17, 0.32), (w * 0.5, 0.25, 0.375)], 0.055)
    shield = cylinder(0.085, 0.36, "y", (w * 0.5, 0.45, 0.375), 20)
    clamps = union([cylinder(0.09, 0.03, "y", (w * 0.5, y, 0.375), 20) for y in (0.42, 0.82)])
    return Part("d_exhaust_stack", "Exhaust stack", "body", "details", (w, h, l), union([plate, stack, elbow, shield, clamps]), sockets(grid_cells(1, 2)), METAL,
                finish="metal", aero={"front": 0.6, "back": 0.8}, mass=1.5, strength=600.0,
                solids=[[0, 0, 0, w, PLATE, l], [0, PLATE, STUD, w, h, l], [0, PLATE, 0, w, 0.26, STUD]])


TUBE = 0.035  # radius of a cage or bar tube


@part
def roll_hoop():
    """A roll hoop 4 wide to go behind the driver, with braces back down to
    its feet."""
    w, l, h = 4 * STUD, 2 * STUD, 0.86
    feet = [box(x, 0, 0, x + STUD, PLATE, l) for x in (0.0, w - STUD)]
    top = h - TUBE
    hoop = _rods([(STUD * 0.5, PLATE, 0.14), (STUD * 0.5, top - 0.12, 0.14), (STUD * 0.5 + 0.1, top, 0.14),
                  (w - STUD * 0.5 - 0.1, top, 0.14), (w - STUD * 0.5, top - 0.12, 0.14), (w - STUD * 0.5, PLATE, 0.14)], TUBE)
    braces = [_capsule((x, top - 0.14, 0.14), (x, PLATE, l - 0.1), TUBE) for x in (STUD * 0.5, w - STUD * 0.5)]
    cells = [(i, k) for i in (0, 3) for k in range(2)]
    return Part("d_roll_hoop", "Roll hoop", "body", "details", (w, h, l), union(feet + [hoop] + braces), sockets(cells), BLACK,
                aero={"front": 0.5, "back": 0.8}, mass=1.5, strength=1200.0,
                solids=[[0, 0, 0, STUD, PLATE, l], [w - STUD, 0, 0, w, PLATE, l], [0, PLATE, 0.08, STUD, h, l], [w - STUD, PLATE, 0.08, w, h, l], [0, h - 0.1, 0.08, w, h, 0.22]])


@part
def roll_cage():
    """A dune buggy's roll cage 6×7, open all round, over the seat and
    steering. Pillars lean back from the front feet to the roof, and down to
    the back feet, with a cross brace behind. A plate across the front of
    the roof takes lights."""
    roof = 1.08
    w, l, h = 6 * STUD, 7 * STUD, roof + PLATE
    zf, za, zb, zr = STUD * 0.5, 0.75, 1.25, l - STUD * 0.5
    sides = []
    for x in (STUD * 0.5, w - STUD * 0.5):
        sides.append(_rods([(x, PLATE, zf), (x, roof - 0.06, za - 0.04), (x, roof, za + 0.06), (x, roof, zb - 0.06), (x, roof - 0.06, zb + 0.04), (x, PLATE, zr)], TUBE))
    x0, x1 = STUD * 0.5, w - STUD * 0.5
    bars = [_capsule((x0, roof, za + 0.06), (x1, roof, za + 0.06), TUBE), _capsule((x0, roof, zb - 0.06), (x1, roof, zb - 0.06), TUBE),
            _capsule((x0, roof - 0.06, zb + 0.04), (x1, PLATE + 0.1, zr), TUBE), _capsule((x1, roof - 0.06, zb + 0.04), (x0, PLATE + 0.1, zr), TUBE)]
    feet = [box(x, 0, z, x + STUD, PLATE, z + STUD) for x in (0.0, w - STUD) for z in (0.0, l - STUD)]
    lights = [(i, 3) for i in range(1, 5)]
    plate = union([box(STUD, roof, 3 * STUD, 5 * STUD, roof + PLATE, 4 * STUD), studs(lights, roof + PLATE)])
    cells = [(i, k) for i in (0, 5) for k in (0, 6)]
    tube = [[0, PLATE, 0, STUD, roof + TUBE, l], [w - STUD, PLATE, 0, w, roof + TUBE, l]]
    return Part("d_roll_cage", "Roll cage", "body", "details", (w, h, l), union(sides + bars + feet + [plate]), sockets(cells) + top_studs(lights, roof + PLATE), BLACK,
                aero={"front": 0.5, "back": 0.8}, mass=4.0, strength=1800.0,
                solids=[[x, 0, z, x + STUD, PLATE, z + STUD] for x in (0.0, w - STUD) for z in (0.0, l - STUD)]
                + tube + [[STUD, roof - TUBE, za, w - STUD, h, zb], [STUD, PLATE + 0.05, zb + 0.1, w - STUD, roof, zr]])


@part
def bull_bar():
    """A tubular bull bar 6 wide for the front of a truck. Its two tabs
    press onto the front row of studs and the bars hang down in front."""
    w, l, h = 6 * STUD, 2 * STUD, 0.6
    tab_y = 0.2
    tabs = [union([box(x, tab_y, STUD, x + STUD, tab_y + PLATE, l), _capsule((x + STUD * 0.5, tab_y + 0.05, STUD + 0.05), (x + STUD * 0.5, tab_y + 0.05, STUD * 0.5), TUBE)])
            for x in (STUD, 4 * STUD)]
    z = STUD * 0.5
    ups = [_capsule((x, 0.04, z), (x, h - 0.05, z), TUBE + 0.005) for x in (1.5 * STUD, 4.5 * STUD)]
    hoop = _rods([(0.06, 0.18, z), (0.08, 0.42, z), (0.22, h - TUBE - 0.01, z), (w - 0.22, h - TUBE - 0.01, z), (w - 0.08, 0.42, z), (w - 0.06, 0.18, z)], TUBE)
    bars = [_capsule((0.06, 0.18, z), (w - 0.06, 0.18, z), TUBE), _capsule((1.5 * STUD, 0.36, z), (4.5 * STUD, 0.36, z), TUBE)]
    cells = [(1, 1), (4, 1)]
    return Part("d_bull_bar", "Bull bar", "body", "details", (w, h, l), union(tabs + ups + [hoop] + bars), sockets(cells, tab_y), METAL, finish="metal",
                aero={"front": 0.5, "back": 0.8}, mass=2.5, strength=2200.0,
                solids=[[STUD, tab_y, STUD, 2 * STUD, tab_y + PLATE, l], [4 * STUD, tab_y, STUD, 5 * STUD, tab_y + PLATE, l], [0, 0, 0, w, h, STUD]])


@part
def wheelie_bar():
    """A dragster's wheelie bar: a plate 2×1 that sits on the back of the
    chassis, with two rails sloping back and down to a pair of little
    rollers that stop it flipping over."""
    w, l, h = 2 * STUD, 7 * STUD, 0.3
    top = 0.2
    plate = box(0, top, 0, w, top + PLATE, STUD)
    zr = l - 0.08
    rails = [_capsule((x, top + 0.03, 0.15), (x, 0.08, zr), 0.025) for x in (0.12, w - 0.12)]
    braces = [_capsule((0.12, 0.08 + (top - 0.05) * t, 0.15 + (zr - 0.15) * (1 - t)), (w - 0.12, 0.08 + (top - 0.05) * t, 0.15 + (zr - 0.15) * (1 - t)), 0.018) for t in (0.3, 0.65)]
    axle = cylinder(0.02, w - 0.02, "x", (0.01, 0.07, zr), 10)
    rollers = union([cylinder(0.07, 0.07, "x", (x, 0.07, zr), 18) for x in (0.002, w - 0.072)])
    return Part("d_wheelie_bar", "Wheelie bar", "body", "details", (w, h, l), union([plate, axle] + rails + braces) - rollers, sockets(grid_cells(2, 1), top), METAL,
                finish="metal", trim=(rollers, TYRE, "plastic"), aero={"front": 0.5, "back": 0.8}, mass=1.5, strength=700.0,
                solids=[[0, top, 0, w, h, STUD], [0, 0, STUD, w, top + 0.05, l]])


# Quads, choppers and trikes.

def _shifted(con, solids, seat_box, dy):
    """Moves connectors, solid boxes and a seat box (all in the fine unit,
    from the ground) down by dy, onto a part whose box starts at dy."""
    for co in con:
        co["at"] = [co["at"][0], co["at"][1] - dy * FINE, co["at"][2]]
    solids = [[a * FINE, (b - dy) * FINE, cc * FINE, d * FINE, (e - dy) * FINE, g * FINE] for a, b, cc, d, e, g in solids]
    if seat_box:
        a, b, cc, d, e, g = seat_box
        seat_box = [a * FINE, (b - dy) * FINE, cc * FINE, d * FINE, (e - dy) * FINE, g * FINE]
    return con, solids, seat_box


# A quad's layout in the fine unit, from the ground, for quad wheels: a front
# axle at Q_FRONT and a back one at Q_BACK, the wheels 32 wide on the axle
# ends, 7 studs across in all, with decks for the fenders at y Q_DECK.
Q_R = 22.4
Q_FRONT, Q_BACK = 30, 160
Q_W, Q_L = 140, 190
Q_DECK = 44


@part
def quad_frame():
    """A quad's frame in one piece, with the engine, tank and saddle in it
    and an axle across each end for four wheels. Fenders go on the decks at
    each end and quad bars on the post just in front of the saddle."""
    low = 16
    parts, trim, solids = [], [], []

    def block(*b, edge=0.012):
        parts.append(box(*_f(*b), edge=edge))
        solids.append(list(b))

    block(44, low, 0, 96, 26, Q_L)                  # the pan along the bottom
    block(40, 26, 0, 100, Q_DECK, 40)               # front deck
    block(50, 26, 40, 90, Q_DECK, 64)               # under the tank
    block(50, 26, 80, 90, 60, 100)                  # post for the bars
    block(40, 26, 150, 100, Q_DECK, Q_L)            # back deck
    parts.append(box(*_f(48, Q_DECK - 2, 44, 92, 58, 84), edge=0.03))  # tank
    solids.append([48, Q_DECK, 44, 92, 58, 80])
    seat = 64
    parts.append(profile_x([(z * FINE, y * FINE) for z, y in [(96, Q_DECK - 2), (96, 56), (104, seat), (144, seat), (150, 58), (150, Q_DECK - 2)]], 50 * FINE, 90 * FINE))
    solids.append([50, Q_DECK, 100, 90, seat, 150])
    front_studs = [(x, z) for x in (50, 70, 90) for z in (10, 30)]
    back_studs = [(x, z) for x in (50, 70, 90) for z in (160, 180)]
    bar_studs = [(60, 90), (80, 90)]
    for x, z in front_studs + back_studs:
        parts.append(cylinder(STUD_RADIUS, STUD_HEIGHT, "y", tuple(_f(x, Q_DECK - 0.08, z)), 12))
    for x, z in bar_studs:
        parts.append(cylinder(STUD_RADIUS, STUD_HEIGHT, "y", tuple(_f(x, 59.92, z)), 12))
    # The engine under the saddle, with fins, and the exhaust back along the
    # right to a silencer.
    trim.append(box(*_f(52, 26, 64, 88, Q_DECK - 1, 124), edge=0.02))
    for k in range(4):
        y = 30 + k * 3.4
        trim.append(box(*_f(50, y, 70, 90, y + 1.4, 92), edge=0.004))
    trim.append(_tube((90, 34, 110), (102, 36, 130), 2.4))
    trim.append(_tube((102, 36, 130), (102, 38, 170), 2.4))
    trim.append(cylinder(4.2 * FINE, 24 * FINE, "z", tuple(_f(102, 38, 168)), 14))
    # The axles across, and a footboard each side between the wheels.
    for z in (Q_FRONT, Q_BACK):
        trim.append(cylinder(5 * FINE, 80 * FINE, "x", tuple(_f(30, Q_R, z)), 14))
    for x in (32, 94):
        trim.append(box(*_f(x, 20, 62, x + 14, 24, 122), edge=0.006))
    hi = 60 + 4
    con = [c("stud", _f(x, Q_DECK, z), (0, 1, 0)) for x, z in front_studs + back_studs]
    con += [c("stud", _f(x, 60, z), (0, 1, 0)) for x, z in bar_studs]
    con += [c("axle", _f(0, Q_R, z), (1, 0, 0), Q_W * FINE) for z in (Q_FRONT, Q_BACK)]
    # The rider sits on the middle of the saddle, a little forward.
    seat_box = [52, seat - 8, 106, 88, seat, 150]
    con, solids, seat_box = _shifted(con, solids, seat_box, low)
    shift = [0, -low * FINE, 0]
    return Part("b_quad_frame", "Quad frame", "seat", "bike", (Q_W * FINE, (hi - low) * FINE, Q_L * FINE), union(parts).translate(shift), con, BLACK,
                about="A quad's frame with the engine and saddle in it and an axle across each end. Put quad wheels on the ends of the axles, quad bars on the post and fenders over the wheels.",
                trim=(union(trim).translate(shift), METAL, "metal"), solids=solids, seat_box=seat_box, engine_twin="engine_twin",
                aero={"front": 0.7, "back": 0.8, "side": 0.8}, power=7000.0, max_force=1500.0, astride=True, driver_height=7, control=1.05, recline=0)

@part
def quad_bars():
    """A quad's bars: a short riser straight up from the post in front of the
    saddle to a bar with a grip at each end, where a seated rider's hands
    land. They turn about the riser."""
    bar = 24
    parts = [box(*_f(4, 0, 0, 36, 8, 20), edge=0.012)]
    parts.append(_tube((20, 6, 10), (20, bar, 15), 2.6))
    parts.append(_tube((13, bar, 15), (27, bar, 15), 2.2))
    grips = [_tube((20 + d * 6, bar, 15), (20 + d * 17, bar, 15), 3.2) for d in (-1, 1)]
    con = sockets([(0, 0), (1, 0)])
    return Part("b_quad_bars", "Quad bars", "steering", "bike", (40 * FINE, (bar + 4) * FINE, 20 * FINE), union(parts), con, METAL, finish="metal",
                about="Short bars for a quad, on the post in front of its saddle.", style="bikebars", control=1.15, grip_reach=11.2 * FINE,
                trim=(union(grips), BLACK, "plastic"), solids=[[4 * FINE, 0, 0, 36 * FINE, 8 * FINE, 20 * FINE]])


def _quad_fender(id, name, style):
    """Fenders across one end of a quad: an arch over each wheel and a bridge
    between them that sits on the frame's deck. `style` is "front" (a lamp
    on top), "back" (studs on the arches and a tail light, made to face
    back) or "rack" (a tube rack all over, for either end)."""
    l = 60
    top = 56
    bottom = 32
    ax = 30                                          # the axle, along
    lip = [(0, bottom), (0, 48), (2, 54), (5, top), (55, top), (58, 54), (60, 48), (60, bottom)]
    well = cylinder(27 * FINE, Q_W * FINE + 0.02, "x", tuple(_f(-1, Q_R, ax)), 40)
    arches = [push_x(side([(z * FINE, y * FINE) for z, y in lip]), x0 * FINE, x1 * FINE) - well for x0, x1 in ((0, 40), (100, 140))]
    back = style == "back"
    b0, b1 = (20, 60) if back else (0, 40)
    bridge = box(*_f(40, Q_DECK, b0, 100, 52, b1), edge=0.012)
    parts = arches + [bridge]
    trim = []
    lamp = None
    cells = [(x, z) for x in (50, 70, 90) for z in ((30, 50) if back else (10, 30))]
    con = [c("socket", _f(x, Q_DECK, z), (0, -1, 0)) for x, z in cells]
    solids = [[0, 50, 2, 40, top, 58], [100, 50, 2, 140, top, 58], [40, Q_DECK, b0, 100, 52, b1]]
    hi = top
    if style == "front":
        parts.append(box(*_f(58, 50, 0, 82, 60, 12), edge=0.015))
        lamp = cylinder(4 * FINE, 1.2 * FINE, "-z", tuple(_f(70, 55, 0.6)), 18)
        hi = 60
    elif back:
        tops = [(x, z) for x in (10, 30, 110, 130) for z in (10, 30, 50)]
        parts += [cylinder(STUD_RADIUS, STUD_HEIGHT, "y", tuple(_f(x, top - 0.08, z)), 12) for x, z in tops]
        con += [c("stud", _f(x, top, z), (0, 1, 0)) for x, z in tops]
        trim.append(box(*_f(62, 46, 59, 78, 50, 61), edge=0.003))
        hi = top + STUD_HEIGHT / FINE
    else:
        rail = 63
        pts = [(4, 4), (136, 4), (136, 56), (4, 56)]
        trim.append(_rods([(_f(x, rail, z)) for x, z in pts + [pts[0]]], 1.6 * FINE))
        for x in (20, 120):
            trim.append(_tube((x, rail, 4), (x, rail, 56), 1.4))
        for z in (20, 40):
            trim.append(_tube((4, rail, z), (136, rail, z), 1.4))
        for x, z in [(6, 8), (134, 8), (6, 52), (134, 52)]:
            trim.append(_tube((x, top - 1, z), (x, rail, z), 1.6))
        for x, z in [(46, 8), (94, 8), (46, 36), (94, 36)]:
            trim.append(_tube((x, 51, z), (x, rail, z), 1.6))
        hi = rail + 1.6
    shift = [0, -bottom * FINE, 0]
    con, solids, _ = _shifted(con, solids, None, bottom)
    stats = dict(aero={"front": 0.5, "back": 0.6, "side": 0.9}, mass=1.6, strength=700.0, solids=solids)
    if lamp is not None:
        stats.update(lamp=(lamp.translate(shift), TRANS_CLEAR), light="head")
    if back:
        stats.update(trim=(union(trim).translate(shift), TRANS_RED, "glass"), light="tail")
    elif trim:
        stats["trim"] = (union(trim).translate(shift), BLACK, "plastic")
    return Part(id, name, "body", "arches", (Q_W * FINE, (hi - bottom) * FINE, l * FINE), union(parts).translate(shift), con, BLUE, **stats)


part(lambda: _quad_fender("b_quad_fender_front", "Quad front fenders", "front"))
part(lambda: _quad_fender("b_quad_fender_back", "Quad back fenders", "back"))
part(lambda: _quad_fender("b_quad_fender_rack", "Quad fenders with rack", "rack"))


@part
def chopper_fork():
    """A chopper's long raked fork with tall bars, for a cruiser or trike
    frame. Its crown fits under the frame's head like the motorbike fork,
    with the front axle RAKE further forward, and it turns as one about the
    axle like the other forks."""
    R = 36
    top = 2 * R
    rake = 32
    crown = (top + 2, top + 10)
    cz = 10 + rake + 10                              # middle of the crown, under the head

    def along(y):
        """Where the fork legs are, along, at this height."""
        return 10 + (y - R) * (cz - 10) / (crown[0] + 4 - R)

    leg_top = top + 34
    clamp = top + 30
    bar = top + 52
    reach = 96
    parts = [box(*_f(8, crown[0], cz - 14, 72, crown[1], cz + 10), edge=0.015)]
    zc = along(clamp + 3)
    parts.append(box(*_f(8, clamp, zc - 8, 72, clamp + 6, zc + 8), edge=0.015))
    legs = [_tube((x, R, 10), (x, leg_top, along(leg_top)), 3.0) for x in (17, 63)]
    sliders = [_tube((x, R, 10), (x, R + 24, along(R + 24)), 4.0) for x in (17, 63)]
    parts.append(cylinder(0.03, 46 * FINE, "x", tuple(_f(17, R, 10)), 10))
    # Risers up from the top clamp to a tall bar, swept back to the grips.
    zr = zc + 2
    risers = [_tube((40 + d * 8, clamp + 6, zc), (40 + d * 10, bar, zr + 4), 2.2) for d in (-1, 1)]
    cross = _tube((30, bar, zr + 4), (50, bar, zr + 4), 2.2)
    sweep = [_tube((40 + d * 10, bar, zr + 4), (40 + d * 24, bar, reach), 2.2) for d in (-1, 1)]
    grips = [_tube((x, bar, reach), (x + d * 9, bar, reach), 3.2) for x, d in ((16, -1), (64, 1))]
    # A round lamp on the front of the crown, in front of the frame's head.
    grips.append(cylinder(0.075, 0.05, "-z", tuple(_f(40, crown[1] + 6, cz - 14)), 18))
    lamp = cylinder(0.065, 0.012, "-z", tuple(_f(40, crown[1] + 6, cz - 14 - 0.05 / FINE)), 18)
    low = R - 4
    hi = bar + 4
    shift = [0, -low * FINE, 0]
    con = [c("stud", _f(x, crown[1], cz), (0, 1, 0)) for x in (30, 50)] + [c("axle", _f(24, R, 10), (1, 0, 0), 32 * FINE)]
    solids = [[8, crown[0], cz - 14, 72, crown[1], cz + 10], [8, clamp, zc - 8, 72, clamp + 6, zc + 8]]
    con, solids, _ = _shifted(con, solids, None, low)
    metal = union(parts + legs + risers + [cross] + sweep)
    return Part("b_chopper_fork", "Chopper fork", "steering", "bike", (80 * FINE, (hi - low) * FINE, (reach + 4) * FINE), union([metal] + sliders).translate(shift), con, METAL,
                finish="metal", about="A long raked fork with tall bars, for a cruiser or trike frame. The frame goes on further back than on the motorbike fork.",
                style="bikebars", control=1.1, grip_reach=0.3, mass=3.0, strength=900.0, trim=(union(grips).translate(shift), BLACK, "plastic"), solids=solids,
                lamp=(lamp.translate(shift), TRANS_CLEAR), light="head")


@part
def sissy_bar():
    """A tall chrome backrest hoop with a pad, on a plate 2×1, for behind a
    chopper's seat."""
    w, l = 2 * STUD, STUD
    h = 0.66
    plate = box(0, 0, 0, w, PLATE, l)
    back = 0.08                                      # how far it leans back at the top
    x0, x1 = 0.05, w - 0.05
    hoop = _rods([(x0, PLATE, l * 0.5), (x0, h - 0.1, l * 0.5 + back * 0.8), (x0 + 0.06, h - 0.03, l * 0.5 + back),
                  (x1 - 0.06, h - 0.03, l * 0.5 + back), (x1, h - 0.1, l * 0.5 + back * 0.8), (x1, PLATE, l * 0.5)], 0.022)
    pad = box(x0 - 0.02, 0.22, 0.0, x1 + 0.02, 0.4, 0.06, edge=0.025).rotate([-6, 0, 0]).translate([0, 0, l * 0.5 + 0.02])
    return Part("b_sissy_bar", "Sissy bar", "body", "bike", (w, h, l + back + 0.06), union([plate, hoop]), sockets(grid_cells(2, 1)), METAL, finish="metal",
                trim=(pad, BLACK, "plastic"), aero={"front": 0.6, "back": 0.8}, mass=0.8, strength=500.0,
                solids=[[0, 0, 0, w, PLATE, l]])


def _cycle_wing(id, name, side_):
    """A cycle wing over a front wheel that sits on the end studs of a kart
    axle plate, with a stalk out to an arc over the wheel. It turns with the
    wheel. Made for wheels up to 0.35 m tall and 0.35 m wide. This is the
    left one; the right is its mirror image."""
    w, l = 60, 80
    zc = 40                                          # the axle, along
    yc = -4                                          # the axle, under the plate
    r0, r1 = 31, 35
    xs = (4, 44)                                     # the arc, across
    arc_pts = []
    for k in range(25):
        a = math.radians(-70 + 140 * k / 24.0)
        arc_pts.append((zc + r1 * math.sin(a), yc + r1 * math.cos(a)))
    for k in range(24, -1, -1):
        a = math.radians(-70 + 140 * k / 24.0)
        arc_pts.append((zc + r0 * math.sin(a), yc + r0 * math.cos(a)))
    arc = push_x(side([(z * FINE, y * FINE) for z, y in arc_pts]), xs[0] * FINE, xs[1] * FINE)
    base = box(*_f(40, 0, 20, 60, 8, 60), edge=0.01)
    stalk = box(*_f(42, 6, 34, 52, yc + r0 + 2, 46), edge=0.01)
    body = union([arc, base, stalk])
    cells = [(2, 1), (2, 2)]
    solids = [[40, 0, 20, 60, 8, 60], [xs[0], yc + r0 - 1, zc - 14, xs[1], yc + r1, zc + 14], [42, 8, 34, 52, yc + r0, 46]]
    con = sockets(cells)
    if side_ == "right":
        body = mirror_x(body).translate([w * FINE, 0, 0])
        cells = [(0, 1), (0, 2)]
        con = sockets(cells)
        solids = [[w - b[3], b[1], b[2], w - b[0], b[4], b[5]] for b in solids]
    hi = yc + r1
    solids = [[v * FINE for v in b] for b in solids]
    twin = "b_cycle_wing_right" if side_ == "left" else "b_cycle_wing_left"
    return Part(id, name, "body", "arches", (w * FINE, hi * FINE, l * FINE), body, con, RED, aero={"front": 0.5, "back": 0.6, "side": 0.9},
                mass=0.6, strength=500.0, solids=solids, steers=True, mirror=twin)


part(lambda: _cycle_wing("b_cycle_wing_left", "Cycle wing left", "left"))
part(lambda: _cycle_wing("b_cycle_wing_right", "Cycle wing right", "right"))


@part
def chopper_trike_body():
    """A chopper trike's wide rear body, over the back of the trike frame
    and between its back wheels, with studs all over the top. It hangs on
    the frame's back axle and is open underneath for the frame's tail. Put
    it at the frame's sides, its front 118 (5.9 studs) behind the frame's."""
    # In the trike frame's own fine units: across from its left edge, up
    # from the ground with 0.45 m wheels, along from its front.
    R = 36
    back = 150
    z0, z1 = 118, 198
    top = 98
    bottom = 44
    w = 200
    mid0, mid1 = 84, 116                             # the channel for the frame's tail
    fv = rounded(front([(16 * FINE, bottom * FINE), (184 * FINE, bottom * FINE), (184 * FINE, top * FINE), (16 * FINE, top * FINE)]), 0.03)
    tub = push_z(fv, z0 * FINE, (z1 - 1) * FINE)
    channel = box(*_f(mid0, bottom - 2, z0 - 2, mid1, 90, z1 + 2), edge=0)
    tub = tub - channel
    # Flares out over the wheels.
    flares = []
    for x0, x1 in ((0, 18), (182, 200)):
        f = cut(cylinder(46 * FINE, (x1 - x0) * FINE, "x", tuple(_f(x0, R, back)), 36),
                cylinder(40 * FINE, (x1 - x0 + 2) * FINE, "x", tuple(_f(x0 - 1, R, back)), 36),
                box(*_f(x0 - 2, -20, back - 60, x1 + 2, bottom + 6, back + 60), edge=0))
        flares.append(f)
    # Brackets down to the axle.
    brackets = [box(*_f(x, 30, back - 8, x + 10, bottom + 2, back + 8), edge=0.006) for x in (46, 144)]
    cells = [(i, k) for i in range(1, 9) for k in range(4)]
    tops = [(x, z) for x in (30, 50, 70, 90, 110, 130, 150, 170) for z in (128, 148, 168, 188)]
    nubs = [cylinder(STUD_RADIUS, STUD_HEIGHT, "y", tuple(_f(x, top - 0.08, z)), 12) for x, z in tops]
    lights = [box(*_f(x, 80, z1 - 2, x + 18, 88, z1), edge=0.003) for x in (24, 158)]
    ylow = 30
    body = union([tub] + flares + brackets + nubs)
    con = [c("stud", _f(x, top, z), (0, 1, 0)) for x, z in tops]
    con += [c("hole", _f(x, R, back), (1, 0, 0), 10 * FINE) for x in (46, 144)]
    solids = [[16, bottom, z0, mid0, top, z1], [mid1, bottom, z0, 184, top, z1], [mid0, 90, z0, mid1, top, z1],
              [0, 78, back - 24, 18, 82, back + 24], [182, 78, back - 24, 200, 82, back + 24],
              [46, 30, back - 8, 56, bottom, back + 8], [144, 30, back - 8, 154, bottom, back + 8]]
    shift = [0, -ylow * FINE, -z0 * FINE]
    for co in con:
        co["at"] = [co["at"][0], co["at"][1] - ylow * FINE, co["at"][2] - z0 * FINE]
    solids = [[a * FINE, (b - ylow) * FINE, (cc - z0) * FINE, d * FINE, (e - ylow) * FINE, (g - z0) * FINE] for a, b, cc, d, e, g in solids]
    return Part("b_trike_body", "Chopper trike body", "body", "bike", (w * FINE, (top + STUD_HEIGHT / FINE - ylow) * FINE, (z1 - z0) * FINE), body.translate(shift), con, YELLOW,
                trim=(union(lights).translate(shift), TRANS_RED, "glass"), light="tail", aero={"front": 0.7, "back": 0.9, "side": 0.9}, mass=5.0, strength=1400.0, solids=solids,
                about="A wide body for the back of the trike frame, over the frame's tail and between the back wheels, with studs on top. It hangs on the back axle.")


# Racer bodies and fittings for the dragster, hot rod, buggy and electric racer.

@part
def jumper_1x2():
    """A plate 2×1 with one stud in the middle, so a part an odd number of
    studs wide can sit centred on a body an even number wide."""
    w, l = 2 * STUD, STUD
    solid = union([box(0, 0, 0, w, PLATE, l), cylinder(STUD_RADIUS, STUD_HEIGHT, "y", (STUD, PLATE - 0.001, STUD * 0.5), 12)])
    con = sockets(grid_cells(2, 1)) + [c("stud", (STUD, PLATE, STUD * 0.5), (0, 1, 0))]
    return Part("p_jumper_1x2", "Jumper plate 1×2", "plate", "plates", (w, PLATE, l), solid, con, LIGHT_GREY)


@part
def jumper_2x2():
    solid = union([box(0, 0, 0, 2 * STUD, PLATE, 2 * STUD),
                   cylinder(STUD_RADIUS, STUD_HEIGHT, "y", (STUD, PLATE - 0.001, STUD), 12)])
    con = sockets(grid_cells(2, 2)) + [c("stud", (STUD, PLATE, STUD), (0, 1, 0))]
    return Part("p_jumper_2x2", "Jumper plate 2×2", "plate", "plates", (2 * STUD, PLATE, 2 * STUD), solid, con, LIGHT_GREY)


@part
def drag_body_2x10_flames():
    """A dragster's long body 2×10, narrowing and dropping to a thin nose at
    the front, with orange flames licking forward along its top."""
    w, l, h = 2 * STUD, 10 * STUD, 3 * PLATE
    stations = []
    for k in range(21):
        t = k / 20.0
        z = 0.002 + (l - STUD - 0.002) * t
        hw = 0.07 + (w * 0.5 - 0.072) * t ** 0.8
        y = 0.07 + (h - 0.07) * t ** 1.2
        stations.append((z, w * 0.5, hw, y, min(hw, y) * 0.8))
    stations.append((l - 0.002, w * 0.5, w * 0.5 - 0.002, h, (w * 0.5 - 0.002) * 0.8))
    body = _loft(stations)
    # A thin base the full width, so the studs it sits on don't show beside
    # the narrow nose.
    base = plan_y([(0.002, 0.1), (0.1, 0.002), (w - 0.1, 0.002), (w - 0.002, 0.1), (w - 0.002, l - 0.002), (0.002, l - 0.002)], 0.0, STUD_HEIGHT + 0.012)
    body = union([body, base])

    def flame(side):
        # A tongue from the back reaching forward, with a notch, on one side
        # of the middle.
        x = lambda u: w * 0.5 + side * u
        pts = [(x(0.025), l - 1.6 * STUD), (x(0.2), l - 1.6 * STUD), (x(0.05), 3.2 * STUD), (x(0.1), 4.4 * STUD), (x(0.03), 1.6 * STUD)]
        return plan_y(pts if side > 0 else pts[::-1], -0.1, 1.0)

    return Part("p_drag_body_2x10_flames", "Dragster body 2×10 with flames", "body", "curves", (w, h, l), body,
                sockets(grid_cells(2, 10)), RED, trim=(_skin(body, [flame(1), flame(-1)]), ORANGE, "plastic"),
                aero={"front": 0.2, "back": 1.0, "side": 0.6})


@part
def roll_cage_4x4():
    """A dune buggy's roll cage 4×4, over the seat of a small buggy, with a
    plate across the roof for lights. The front pillars lean back to the
    roof and the back ones drop nearly straight, with one bar across the back
    up high, so an engine fits under it behind the seat. Three studs across
    the roof take lamps."""
    roof = 1.08
    w, l, h = 4 * STUD, 4 * STUD, roof + PLATE
    zf, za, zb, zr = STUD * 0.5, 0.36, 0.78, l - STUD * 0.5
    sides = []
    for x in (STUD * 0.5, w - STUD * 0.5):
        sides.append(_rods([(x, PLATE, zf), (x, roof - 0.06, za - 0.04), (x, roof, za + 0.06), (x, roof, zb - 0.06), (x, roof - 0.06, zb + 0.02), (x, PLATE, zr)], TUBE))
    x0, x1 = STUD * 0.5, w - STUD * 0.5
    bars = [_capsule((x0, roof, za + 0.06), (x1, roof, za + 0.06), TUBE), _capsule((x0, roof, zb - 0.06), (x1, roof, zb - 0.06), TUBE),
            _capsule((x0, 0.62, zb + 0.06), (x1, 0.62, zb + 0.06), TUBE)]
    feet = [box(x, 0, z, x + STUD, PLATE, z + STUD) for x in (0.0, w - STUD) for z in (0.0, l - STUD)]
    # Three studs for lamps, half a stud off the grid so they sit centred.
    lights = [((i + 0.5) * STUD, roof + PLATE, 2.5 * STUD) for i in (0.5, 1.5, 2.5)]
    plate = union([box(0.5 * STUD, roof, 2 * STUD, 3.5 * STUD, roof + PLATE, 3 * STUD)]
                  + [cylinder(STUD_RADIUS, STUD_HEIGHT, "y", (x, y - 0.001, z), 12) for x, y, z in lights])
    cells = [(i, k) for i in (0, 3) for k in (0, 3)]
    tube = [[0, PLATE, 0, STUD, roof + TUBE, l], [w - STUD, PLATE, 0, w, roof + TUBE, l]]
    return Part("d_roll_cage_4x4", "Small roll cage 4×4", "body", "details", (w, h, l), union(sides + bars + feet + [plate]),
                sockets(cells) + [c("stud", at, (0, 1, 0)) for at in lights], BLACK,
                aero={"front": 0.5, "back": 0.8}, mass=3.0, strength=1500.0,
                solids=[[x, 0, z, x + STUD, PLATE, z + STUD] for x in (0.0, w - STUD) for z in (0.0, l - STUD)]
                + tube + [[STUD, roof - TUBE, za, w - STUD, h, zb]])


TEAL = "#36aebf"
part(lambda: _bonnet("p_bonnet_4x4", "Smooth bonnet 4×4", 4, 3, across=4, top=False))
part(lambda: _big_arch("p_arch_2x6_teal_stripe", "Smooth wheel arch 2×6 with a teal stripe", 2, smooth=True, stripe=TEAL))


@part
def hot_rod_grille():
    """A hot rod's radiator grille 2 wide standing up at the front, a chrome
    surround round dark bars, on a foot that reaches back a stud and clips
    onto the studs behind it a plate up."""
    w, l, h = 2 * STUD, 2 * STUD, 0.5
    shell = push_z(rounded(front([(0.02, 0.0), (w - 0.02, 0.0), (w - 0.02, h), (0.02, h)]), 0.06), 0.02, 0.17)
    opening = box(0.08, 0.06, -0.1, w - 0.08, h - 0.06, 0.09, edge=0)
    cap = cylinder(0.035, 0.05, "y", (w * 0.5, h - 0.01, 0.1), 16)
    foot = box(0, PLATE, STUD, w, 2 * PLATE, l)
    brace = box(0.12, PLATE, 0.15, w - 0.12, 2 * PLATE, STUD + 0.01, edge=0.005)
    bars = union([box(0.08, 0.06, 0.07, w - 0.08, h - 0.06, 0.1, edge=0)]
                  + [box(x - 0.012, 0.06, 0.04, x + 0.012, h - 0.06, 0.08, edge=0.004) for x in [0.11 + k * 0.035 for k in range(9)]])
    cells = [(0, 1), (1, 1)]
    return Part("d_hot_rod_grille", "Hot rod grille", "body", "details", (w, h + 0.04, l), union([shell - opening, cap, foot, brace]),
                sockets(cells, PLATE), METAL, finish="metal", trim=(bars, BLACK, "plastic"), aero={"front": 0.9, "back": 0.8}, mass=1.0, strength=600.0,
                solids=[[0, 0, 0, w, h, 0.17], [0, PLATE, 0.17, w, 2 * PLATE, l]])


@part
def tub_side_flames():
    """A smooth side for a hot rod's tub, 1×6 and a brick high, rounded along
    the top, with orange flames licking forward down both faces."""
    w, l, h = STUD, 6 * STUD, 3 * PLATE
    body = push_x(rounded(side([(0.0, 0.0), (0.0, h), (l, h), (l, 0.0)]), 0.02), 0.0, w) ^ push_z(rounded(front([(0.0, -0.1), (w, -0.1), (w, h), (0.0, h)]), 0.04), 0.0, l)
    flame = side([(l - 0.03, 0.07), (0.2, 0.12), (0.7, 0.15), (0.45, 0.2), (1.0, 0.22), (l - 0.03, 0.24)])
    trim = union([push_x(flame, -0.004, 0.003), push_x(flame, w - 0.003, w + 0.004)])
    return Part("p_tub_side_1x6_flames", "Tub side 1×6 with flames", "body", "curves", (w, h, l), body, sockets(grid_cells(1, 6)), RED,
                trim=(trim, ORANGE, "plastic"), aero={"front": 0.8, "back": 0.9, "side": 0.9})


# Truck fittings.

@part
def truck_fender():
    """A truck's mudguard curved over the top of a tire 2 wide, on a plate
    1×2 along its inside that sits on a brick beside the tire and has studs
    on top. With the plate level with the top of a tire 0.45 m round (or a
    brick and a plate above a big slick's axle), the inside clears the tire
    by 5 cm (10 cm for the slick)."""
    w, l = 3 * STUD, 4 * STUD
    ri, ro, low = 0.5, 0.55, 0.3
    tab = 0.45 - low
    h = ro - low
    zc = l * 0.5

    def arc(r, a0, a1, n=24):
        return [(zc + r * math.sin(a0 + (a1 - a0) * k / n), r * math.cos(a0 + (a1 - a0) * k / n) - low) for k in range(n + 1)]

    o = math.acos(low / ro)
    i = math.acos(low / ri)
    sheet = push_x(side(arc(ro, -o, o) + arc(ri, i, -i)), 0.002, 2 * STUD)
    plate = box(2 * STUD, tab, STUD, w, tab + PLATE, 3 * STUD)
    web = box(2 * STUD - 0.01, tab, STUD, 2 * STUD + 0.02, h, 3 * STUD, edge=0.004)
    cells = [(2, 1), (2, 2)]
    return Part("d_truck_fender", "Truck mudguard", "body", "arches", (w, h, l), union([sheet, plate, web, studs(cells, tab + PLATE)]),
                sockets(cells, tab) + top_studs(cells, tab + PLATE), BLACK, aero={"front": 0.5, "back": 0.6, "side": 0.9}, mass=0.8, strength=600.0,
                solids=[[2 * STUD, tab, STUD, w, tab + PLATE, 3 * STUD], [0, 0.45 - low, zc - 0.25, 2 * STUD, h, zc + 0.25]])


part(lambda: _bonnet("p_bonnet_4x4_red_stripe", "Low bonnet 4×4 with a red stripe", 4, 2, stripes=True, stripe_colour=RED, lanes=((1.5, 1),), across=4, top=False))


@part
def car_cab_4x4():
    """A short car cab 4×4 with a steep windscreen, a window down each side
    and two studs on the roof for lamps. The driver sits inside."""
    w, l, h = 4 * STUD, 4 * STUD, 0.6
    sv = [(0.0, -0.3), (0.0, 0.08), (0.34, h), (0.84, h), (l, 0.2), (l, -0.3)]
    fv = [(0.002, -0.3), (w - 0.002, -0.3), (w - 0.002, 0.12), (w - 0.09, h), (0.09, h), (0.002, 0.12)]
    outer, shell, glass_layer = _shell(sv, fv, w, l, 0.04, 0.05, 0.08)
    side_view = rounded(side(sv), 0.05).offset(-0.08) - side([(-1, -1), (-1, 0.16), (3, 0.16), (3, -1)])
    cutters = union([
        push_x(side_view, -0.1, 0.3), push_x(side_view, w - 0.3, w + 0.1),
        box(0.13, 0.14, -0.2, w - 0.13, h - 0.07, 0.3, edge=0),
        box(0.15, 0.22, 0.9, w - 0.15, h - 0.08, l + 0.2, edge=0),
    ])
    roof = [(1, 2), (2, 2)]
    body = union([shell - cutters, _sills(outer, w, l, 4), studs(roof, h)])
    cells = [(i, k) for i in (0, 3) for k in range(4)]
    return Part("p_cab_4x4", "Car cab 4×4", "body", "curves", (w, h, l), body, sockets(cells) + top_studs(roof, h), WHITE,
                trim=(glass_layer ^ cutters, GLASS, "glass"), aero={"front": 0.5, "back": 0.65, "side": 0.8}, mass=3.0, strength=900.0,
                solids=[[0, 0, 0, STUD, PLATE, l], [w - STUD, 0, 0, w, PLATE, l], [0, h - PLATE, 0.34, w, h, 0.84]])


@part
def truck_cab_4x4():
    """A tall truck cab 4×4 with a big upright windscreen, side windows, a
    small back window and a smooth roof. The driver sits inside."""
    w, l, h = 4 * STUD, 4 * STUD, 0.65
    sv = [(0.0, -0.3), (0.0, 0.28), (0.1, h), (l, h), (l, -0.3)]
    fv = [(0.002, -0.3), (w - 0.002, -0.3), (w - 0.002, 0.26), (w - 0.04, h), (0.04, h), (0.002, 0.26)]
    outer, shell, glass_layer = _shell(sv, fv, w, l, 0.04, 0.04, 0.06)
    cutters = union([
        box(0.12, 0.32, -0.2, w - 0.12, h - 0.07, 0.2, edge=0),
        box(-0.1, 0.32, 0.22, 0.3, h - 0.07, l - 0.12, edge=0), box(w - 0.3, 0.32, 0.22, w + 0.1, h - 0.07, l - 0.12, edge=0),
        box(0.3, 0.38, l - 0.2, w - 0.3, h - 0.1, l + 0.2, edge=0),
    ])
    body = union([shell - cutters, _sills(outer, w, l, 4)])
    cells = [(i, k) for i in (0, 3) for k in range(4)]
    return Part("p_truck_cab_4x4", "Truck cab 4×4", "body", "curves", (w, h, l), body, sockets(cells), WHITE,
                trim=(glass_layer ^ cutters, GLASS, "glass"), aero={"front": 0.85, "back": 1.0, "side": 0.9}, mass=4.5, strength=1100.0,
                solids=[[0, 0, 0, STUD, PLATE, l], [w - STUD, 0, 0, w, PLATE, l], [0, h - PLATE, 0.1, w, h, l]])


@part
def number_brick():
    """A brick 1×1 with a race number roundel on its left side, 47 printed
    in black inside a black ring. Turned round it faces right."""
    disc_r, cy, cz = 0.11, BRICK * 0.5, STUD * 0.5
    disc = cylinder(disc_r, 0.01, "x", (-0.008, cy, cz), 32)
    ring = cylinder(disc_r - 0.004, 0.006, "x", (-0.013, cy, cz), 32) - cylinder(disc_r - 0.018, 0.01, "x", (-0.015, cy, cz), 32)
    s, dw, dh = 0.014, 0.05, 0.09

    def seg(z0, y0, z1, y1):
        return box(-0.013, y0, z0, -0.006, y1, z1, edge=0)

    lo, hi = cy - dh / 2, cy + dh / 2
    four_z, seven_z = cz - 0.06, cz + 0.01
    four = [seg(four_z, cy - s / 2, four_z + s, hi), seg(four_z, cy - s / 2, four_z + dw, cy + s / 2), seg(four_z + dw - s, lo, four_z + dw, hi)]
    seven = [seg(seven_z, hi - s, seven_z + dw, hi), seg(seven_z + dw - s, lo, seven_z + dw, hi)]
    body = union([box(0, 0, 0, STUD, BRICK, STUD), studs([(0, 0)], BRICK), disc])
    return Part("d_number_brick", "Brick 1×1 with a race number", "brick", "bricks", (STUD, BRICK, STUD), body,
                sockets([(0, 0)]) + top_studs([(0, 0)], BRICK), WHITE, trim=(union([ring] + four + seven), BLACK, "plastic"),
                solids=[[0, 0, 0, STUD, BRICK, STUD]])


@part
def roll_bar():
    """A plain roll bar 4 wide and 1 long to stand behind the driver."""
    w, l, h = 4 * STUD, STUD, 0.7
    feet = [box(x, 0, 0, x + STUD, PLATE, l) for x in (0.0, w - STUD)]
    top = h - TUBE
    hoop = _rods([(STUD * 0.5, PLATE, l * 0.5), (STUD * 0.5, top - 0.12, l * 0.5), (STUD * 0.5 + 0.1, top, l * 0.5),
                  (w - STUD * 0.5 - 0.1, top, l * 0.5), (w - STUD * 0.5, top - 0.12, l * 0.5), (w - STUD * 0.5, PLATE, l * 0.5)], TUBE)
    cells = [(0, 0), (3, 0)]
    return Part("d_roll_bar", "Roll bar", "body", "details", (w, h, l), union(feet + [hoop]), sockets(cells), BLACK,
                aero={"front": 0.5, "back": 0.8}, mass=1.0, strength=1000.0,
                solids=[[0, 0, 0, STUD, PLATE, l], [w - STUD, 0, 0, w, PLATE, l], [0, PLATE, 0.08, STUD, h, 0.17], [w - STUD, PLATE, 0.08, w, h, 0.17], [0, h - 0.1, 0.08, w, h, 0.17]])


# The stock bikes and trikes. Each is modelled in its own space in the fine
# unit: x across from the middle, y up from the ground and z back from the
# front axle. A part is given the corner of its box in that space, `at`, and
# make_karts.py puts the part's corner at the same spot. The rider sits with
# their hips on the middle of the seat box's top, legs forward and down 25
# degrees and leaning forward 30, and reaches about 34 forward and 16 up to
# the grips.

CREAM = "#f3e3b0"


def _sec(hw, yb, yt, rt, rb=None, n=5):
    """A cross-section across, hw either side of the middle from yb up to
    yt, its top corners rounded by rt and the bottom ones by rb."""
    rb = rt if rb is None else rb
    h = yt - yb
    rt = max(0.3, min(rt, hw - 0.1, h * 0.5 - 0.05))
    rb = max(0.3, min(rb, hw - 0.1, h * 0.5 - 0.05))
    pts = []
    for cx, cy, r, a0 in ((hw - rb, yb + rb, rb, -90), (hw - rt, yt - rt, rt, 0), (-hw + rt, yt - rt, rt, 90), (-hw + rb, yb + rb, rb, 180)):
        for k in range(n + 1):
            a = math.radians(a0 + 90.0 * k / n)
            pts.append(((cx + r * math.cos(a)) * FINE, (cy + r * math.sin(a)) * FINE))
    return pts


def _lofted(stations):
    """A smooth body through cross-sections along z, each station (z, half
    width, bottom, top, top corner radius[, bottom corner radius]) in the
    fine unit. Neighbours are joined by their hull."""
    from manifold3d import Manifold
    slices = [front(_sec(*s[1:])).extrude(0.0005).translate([0, 0, s[0] * FINE]) for s in stations]
    return union([Manifold.batch_hull([slices[k], slices[k + 1]]) for k in range(len(slices) - 1)])


def _vbox(x0, y0, z0, x1, y1, z1, edge=0.01):
    """A box in the fine unit."""
    return box(*_f(x0, y0, z0, x1, y1, z1), edge=edge)


def _arc(r0, r1, axle, x0, x1, a0, a1, n=24):
    """A curved band round an axle at (z, y), from radius r0 to r1, swept
    from angle a0 to a1 (degrees, 0 straight up, going back), across from
    x0 to x1. For mudguards."""
    zc, yc = axle
    pts = []
    for k in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        pts.append((zc + r1 * math.sin(a), yc + r1 * math.cos(a)))
    for k in range(n, -1, -1):
        a = math.radians(a0 + (a1 - a0) * k / n)
        pts.append((zc + r0 * math.sin(a), yc + r0 * math.cos(a)))
    return push_x(side([(z * FINE, y * FINE) for z, y in pts]), x0 * FINE, x1 * FINE)


# Seven segment digits, for race numbers: the segments each lights.
_DIGITS = {"7": "abc", "9": "abcdfg", "3": "abcdg", "1": "bc", "2": "abged", "5": "afgcd"}


def _number(text, at, h, side_):
    """Race number segments standing proud on a side of a bike at (z, y)
    (their middle), h tall, as boxes across from x to the outside. `side_`
    is -1 for the left side, read from the left, or 1 for the right."""
    zc, yc = at
    w = h * 0.55
    s = h * 0.16
    out = []
    n = len(text)
    for i, ch in enumerate(text):
        # Along the side, reading direction is +z on the left, -z on the right.
        u0 = (i - n * 0.5) * (w + s) + s * 0.5
        segs = {"a": (u0, h * 0.5 - s, u0 + w, h * 0.5), "d": (u0, -h * 0.5, u0 + w, -h * 0.5 + s),
                "g": (u0, -s * 0.5, u0 + w, s * 0.5), "f": (u0, 0, u0 + s, h * 0.5), "e": (u0, -h * 0.5, u0 + s, 0),
                "b": (u0 + w - s, 0, u0 + w, h * 0.5), "c": (u0 + w - s, -h * 0.5, u0 + w, 0)}
        for key in _DIGITS[ch]:
            a0, b0, a1, b1 = segs[key]
            za, zb = (zc + a0, zc + a1) if side_ < 0 else (zc - a1, zc - a0)
            out.append((za, yc + b0, zb, yc + b1))
    return out


def _vpart(id, name, kind, at, solid, color, con=(), solids=(), seat_box=None, trim=None, lamp=None, size=None, loose=False, group="bike", **stats):
    """A part modelled in a bike's own space with the corner of its box at
    `at`. Connectors are (type, point, axis[, length]), and they, the solid
    boxes and the seat box are in that space too. The box reaches as far as
    the model does, or is `size`. With `loose` the model can reach out
    past the box, like a fork's mudguard."""
    pieces = [solid] + [t[0] for t in (trim, lamp) if t]
    b = union(pieces).bounding_box()
    lo = [v / FINE for v in b[:3]]
    hi = [v / FINE for v in b[3:]]
    if not loose:
        assert all(l >= a - 0.6 for l, a in zip(lo, at)), "%s reaches past its corner (%s against %s)" % (id, lo, at)
    if size is None:
        size = [math.ceil(h - a - 0.3) for h, a in zip(hi, at)]
    shift = [-a * FINE for a in at]
    cons = [c(co[0], _f(*[p - a for p, a in zip(co[1], at)]), co[2], co[3] * FINE if len(co) > 3 else 0.0) for co in con]
    stats["solids"] = [[(v - at[i % 3]) * FINE for i, v in enumerate(s)] for s in solids]
    if seat_box:
        stats["seat_box"] = [(v - at[i % 3]) * FINE for i, v in enumerate(seat_box)]
    if trim:
        stats["trim"] = (trim[0].translate(shift), trim[1], trim[2])
    if lamp:
        stats["lamp"] = (lamp[0].translate(shift), lamp[1])
    return Part(id, name, kind, group, tuple(v * FINE for v in size), solid.translate(shift), cons, color, **stats)


# Small wheels for the stock bikes and trikes.
part(lambda: _wheel("w_scrambler", "Scrambler wheel", 0.375, 0.2, 0.24, 0.9, 0.02, offroad=0.65, color=LIGHT_GREY, deep=(16, 0.035, 0.03), shoulder=0.05,
                    about="A knobbly wheel for a dirt bike, smaller than a motorbike wheel. Good on grass and gravel."))
part(lambda: _wheel("w_scooter_small", "Little scooter wheel", 0.25, 0.15, 0.17, 0.95, 0.018, color=WHITE,
                    about="A little fat wheel for scooters and little trikes."))


def _bike_fork(id, name, R, crown, grip, style, about, color=METAL):
    """A front fork with its bars, turning as one about the front axle at
    (0, R) like the motorbike fork. `crown` is (z, y) of the middle of the
    crown and its bottom, with the frame's head on top of it, and `grip`
    is (z, y, x) where the right hand holds. `style` is "sport" (low
    clip-ons), "dirt" (tall bars with a mudguard up high and a number
    plate), "scooter" (a mudguard round the wheel and a headset with the
    lamp) or "chopper" (a long raked fork with high bars)."""
    cz, cy = crown
    gz, gy, gx = grip
    top = cy + 8
    parts, metal, black = [], [], []
    lamp = None
    lean = cz / (cy + 4 - R)                         # along per up, along the legs
    crown_box = _vbox(-18, cy, cz - 9, 18, top, cz + 9, edge=0.02)
    legs = lambda y0, y1, r, x=12: [_tube((s * x, y0, lean * (y0 - R)), (s * x, y1, lean * (y1 - R)), r) for s in (-1, 1)]
    axle = cylinder(2.2 * FINE, 28 * FINE, "x", tuple(_f(-14, R, 0)), 12)
    grips = [_tube((s * (gx - 4.5), gy, gz), (s * (gx + 4.5), gy, gz), 3.2) for s in (-1, 1)]
    solids = [[-18, cy, cz - 9, 18, top, cz + 9]]
    if style == "sport":
        clamp = top + 6
        metal += [crown_box, axle] + legs(R, clamp + 2, 2.6) + legs(R, R + 14, 3.4)
        metal.append(_vbox(-15, clamp, cz + lean * (clamp - cy) - 6, 15, clamp + 4, cz + lean * (clamp - cy) + 6))
        zc = cz + lean * (clamp + 2 - cy)
        metal += [_tube((s * 12, clamp + 2, zc), (s * (gx - 4.5), gy, gz), 2.2) for s in (-1, 1)]
        black += grips
        parts = metal
        body, trim_ = union(parts), (union(black), BLACK, "plastic")
        finish = "metal"
    elif style == "dirt":
        clamp = top + 10
        zc = cz + lean * (clamp - cy)
        silver = [axle] + legs(R, clamp + 2, 2.8) + legs(R, R + 20, 3.6)
        silver += [_tube((s * 7, clamp + 3, zc), (s * 9, gy, gz), 2.2) for s in (-1, 1)]
        silver.append(_tube((-(gx - 4.5), gy, gz), (gx - 4.5, gy, gz), 2.2))
        silver.append(_tube((-9, gy - 6, gz - 1.5), (9, gy - 6, gz - 1.5), 1.8))
        silver += grips
        own = [crown_box, _vbox(-15, clamp, zc - 6, 15, clamp + 4, zc + 6, edge=0.015)]
        # A mudguard up high under the crown, reaching well out in front.
        g = 2 * R + 3
        own.append(_lofted([(-R - 6, 5, g - 5, g - 1, 1.5), (-R + 2, 8, g - 1, g + 4, 2), (-8, 9, g, g + 5, 2), (cz - 4, 8, g, g + 5, 2)]))
        # The number plate in front of the fork legs and the frame's head.
        pz = cz - 12
        plate = _lofted([(pz - 1.5, 11, clamp - 12, clamp + 4, 4), (pz + 1.5, 11, clamp - 12, clamp + 4, 4)])
        own.append(plate)
        body, trim_ = union(own), (union(silver), METAL, "metal")
        finish = "plastic"
        solids.append([-15, clamp, zc - 6, 15, clamp + 4, zc + 6])
        lamp = cylinder(3.4 * FINE, 1.0 * FINE, "-z", tuple(_f(0, clamp - 6, pz - 1.4)), 16)
    elif style == "scooter":
        # The mudguard over the front of the wheel, the fork short under it,
        # and a stem up to the headset with the lamp and bars.
        own = [_arc(R + 3, R + 7, (0, R), -9, 9, -70, 55)]
        own.append(crown_box)
        hz = cz + 2
        own.append(_lofted([(hz - 9, 13, gy - 6, gy + 3, 5), (hz - 4, 15, gy - 7, gy + 3, 5), (hz + 7, 13, gy - 6, gy + 2, 5)]))
        stem = [cylinder(3.2 * FINE, (gy - 6 - top) * FINE, "y", tuple(_f(0, top, cz)), 14)]
        own += stem + legs(R, cy, 2.6, 10)
        bars = [axle] + [_tube((s * 12, gy, hz + 4), (s * (gx - 4.5), gy, gz), 2.2) for s in (-1, 1)] + grips
        body, trim_ = union(own), (union(bars), CREAM, "plastic")
        finish = "plastic"
        lamp = cylinder(4.0 * FINE, 1.0 * FINE, "-z", tuple(_f(0, gy - 2, hz - 9.3)), 18)
        black = []
    else:
        clamp = top + 6
        zc = cz + lean * (clamp - cy)
        metal += [crown_box, axle] + legs(R, clamp + 3, 2.8) + legs(R, R + 18, 3.6)
        metal.append(_vbox(-16, clamp, zc - 6, 16, clamp + 5, zc + 6, edge=0.015))
        # Risers up from the top clamp, then the bars swept back and down a
        # little to the grips.
        rz, ry = zc + 3, gy + 6
        metal += [_tube((s * 7, clamp + 4, zc), (s * 9, ry, rz), 2.2) for s in (-1, 1)]
        metal.append(_tube((-9, ry, rz), (9, ry, rz), 2.2))
        metal += [_tube((s * 9, ry, rz), (s * (gx - 4.5), gy, gz), 2.2) for s in (-1, 1)]
        black += grips
        black.append(cylinder(5.4 * FINE, 4 * FINE, "-z", tuple(_f(0, top + 5, cz - 10)), 18))
        lamp = cylinder(4.6 * FINE, 1.0 * FINE, "-z", tuple(_f(0, top + 5, cz - 13.6)), 18)
        body, trim_ = union(metal), (union(black), BLACK, "plastic")
        finish = "metal"
        solids.append([-16, clamp, zc - 6, 16, clamp + 5, zc + 6])
    con = [("stud", (x, top, cz), (0, 1, 0)) for x in (-10, 10)] + [("axle", (-14, R, 0), (1, 0, 0), 28)]
    low = R - 3.6
    size = [2 * (gx + 5), gy + 3.2 - low, gz + 4 + 10]
    stats = dict(about=about, style="bikebars", control=1.15 if style != "chopper" else 1.1, grip_reach=gx * FINE, mass=2.5, strength=900.0,
                 trim=trim_, finish=finish)
    if lamp is not None:
        stats.update(lamp=(lamp, TRANS_CLEAR), light="head")
    return _vpart(id, name, "steering", (-(gx + 5), low, -10), body, color, con=con, solids=solids, size=size, loose=True, **stats)


def _coat(body, boxes, d=0.003):
    """A thin layer over the outside of a body inside the boxes, for
    stripes and roundels, on its top and both sides."""
    over = union([body.translate([d, 0, 0]), body.translate([-d, 0, 0]), body.translate([0, d, 0])]) - body
    return over ^ union(boxes)


def _roundel(body, at, r, number, x_out=60):
    """A white roundel on each side of a body at (z, y), with the number
    cut out of it so the body shows through."""
    zc, yc = at
    disc = cylinder(r * FINE, 2 * x_out * FINE, "x", tuple(_f(-x_out, yc, zc)), 28)
    ring = _coat(body, [disc], 0.004)
    cuts = []
    for s in (-1, 1):
        for z0, y0, z1, y1 in _number(number, at, r * 1.1, s):
            cuts.append(_vbox(0 if s > 0 else -x_out, y0, z0, x_out if s > 0 else 0, y1, z1, edge=0))
    return ring - union(cuts)


# Streak, a superbike: low clip-ons, a fairing all round with a screen, a
# tail up high, on small wheels 24 in radius, 140 apart.

part(lambda: _bike_fork("b_fork_sport", "Sports fork", 24, (26, 50), (52, 76, 20), "sport",
                        "A short sports fork with low bars, for small wheels on the superbike frame."))
part(lambda: _bike_fork("b_fork_dirt_small", "Scrambler fork", 30, (20, 68), (44, 96, 22), "dirt",
                        "A dirt bike fork with tall bars, a mudguard up high and a number plate, for the scrambler frame.", color=ORANGE))
part(lambda: _bike_fork("b_fork_scooter_small", "Little scooter fork", 20, (18, 48), (40, 70, 20), "scooter",
                        "A scooter's front end: a mudguard round the wheel, the headset with its lamp and the bars, for little wheels.", color=BLUE))
part(lambda: _bike_fork("b_fork_chopper_long", "Long chopper fork", 24, (44, 70), (104, 88, 22), "chopper",
                        "A long raked fork with high bars for a chopper or chopper trike frame, on a small front wheel."))


@part
def frame_superbike():
    R, back = 24, 140
    black = [_vbox(-8, 58, 18, 8, 64, 34, edge=0.015), _tube((0, 62, 30), (0, 54, 76), 4.0)]
    black.append(_vbox(-13, 20, 36, 13, 44, 80, edge=0.03))
    black.append(_lofted([(64, 13, 50, 57, 4, 2), (72, 15, 50, 60, 5, 2), (98, 14, 50, 60, 5, 2), (104, 12, 52, 60, 4, 2)]))
    metal = [_tube((s * 9.5, 30, 82), (s * 9.5, R, back), 2.4) for s in (-1, 1)]
    metal.append(_tube((-9.5, 30, 82), (9.5, 30, 82), 2.4))
    metal.append(cylinder(2.0 * FINE, 24 * FINE, "x", tuple(_f(-12, R, back)), 12))
    metal += [_tube((10, 22, 76), (13, 32, 104), 2.2), _tube((13, 33, 102), (14, 40, 132), 4.2)]
    con = [("socket", (x, 58, 26), (0, -1, 0)) for x in (-10, 10)]
    con += [("stud", (x, 44, z), (0, 1, 0)) for x in (-6, 6) for z in (44, 70)]
    con += [("side", (x, 62, 18), (0, 0, -1)) for x in (-6, 6)]
    con.append(("axle", (-12, R, back), (1, 0, 0), 24))
    solids = [[-8, 58, 18, 8, 64, 34], [-13, 20, 36, 13, 44, 80], [-15, 50, 64, 15, 60, 104], [-12, 20, 82, 12, 32, 114]]
    return _vpart("b_frame_superbike", "Superbike frame", "seat", (-20, 16, 16), union(black), BLACK, con=con, solids=solids,
                  seat_box=[-14, 52, 62, 14, 60, 106], trim=(union(metal), METAL, "metal"),
                  about="A low superbike frame with a twin in it, the seat and swingarm. Put the sports fork and small wheels on it and the fairings over it.",
                  engine_twin="engine_twin", aero={"front": 0.6, "back": 0.7, "side": 0.8}, power=7600.0, max_force=1300.0,
                  astride=True, driver_height=7, control=1.05, recline=0)


@part
def body_superbike():
    belly = _lofted([(28, 16, 22, 64, 7, 5), (36, 19, 19, 65, 8, 6), (46, 20, 18, 61, 8, 6), (56, 19, 18, 55, 7, 6), (64, 17, 19, 50, 6, 6),
                     (74, 15, 21, 49, 5, 6), (84, 13, 24, 48, 5, 6)])
    tail = _lofted([(96, 12, 50, 58, 5), (106, 14, 51, 61, 5), (130, 12, 53, 64, 5), (152, 9, 55, 67, 4), (162, 6, 57, 68, 3)])
    body = union([belly, tail])
    stripes = _coat(body, [_vbox(-2.5, 0, 0, 2.5, 100, 200, edge=0), _vbox(-40, 22, 30, 40, 25.5, 90, edge=0)])
    trim = union([stripes, _roundel(belly, (52, 36), 7.5, "9")])
    con = [("socket", (x, 44, z), (0, -1, 0)) for x in (-6, 6) for z in (44, 70)]
    solids = [[-16, 44.5, 38, 16, 60, 58], [13.5, 20, 38, 19.5, 44, 78], [-19.5, 20, 38, -13.5, 44, 78], [-12, 52, 105, 12, 66, 160]]
    return _vpart("b_body_superbike", "Superbike bodywork", "body", (-21, 17, 27), body, GREEN, con=con, solids=solids, trim=(trim, WHITE, "plastic"),
                  about="The superbike's tank, belly pan and tail in one, with a stripe and a number.", aero={"front": 0.35, "back": 0.6, "side": 0.8}, mass=2.5, strength=800.0)


@part
def nose_superbike():
    shell = _lofted([(-24, 5, 40, 45, 2.5), (-18, 12, 43, 54, 5), (-8, 17, 49, 62, 7, 4), (4, 20, 50, 68, 8, 4), (18, 20, 50, 70, 8, 4), (22, 19, 52, 70, 8, 4)])
    screen = profile_x([(z * FINE, y * FINE) for z, y in [(6, 68), (18, 78), (20, 78), (10, 68)]], -9 * FINE, 9 * FINE)
    lamp = cylinder(3.2 * FINE, 1.0 * FINE, "-z", tuple(_f(0, 43, -24)), 16)
    con = [("clip", (x, 62, 18), (0, 0, 1)) for x in (-6, 6)]
    solids = [[-20, 60, -4, 20, 70, 17.5], [-14, 49, -20, 14, 58, 14]]
    return _vpart("b_nose_superbike", "Superbike fairing", "body", (-21, 39, -26), shell, GREEN, con=con, solids=solids, trim=(screen, GLASS, "glass"),
                  lamp=(lamp, TRANS_CLEAR), light="head", about="A pointed front fairing with a screen and a headlight, for the superbike frame.",
                  aero={"front": 0.3, "back": 1.0, "side": 0.8}, mass=1.2, strength=700.0)


# Scrambler, a dirt bike: tall, with knobbly wheels 30 in radius 144 apart,
# a long flat seat, a tank between the knees and a high front mudguard.

@part
def frame_scrambler():
    R, back = 30, 144
    black = [_vbox(-8, 76, 14, 8, 88, 28, edge=0.015), _tube((0, 84, 26), (0, 74, 72), 3.5), _tube((0, 80, 22), (0, 40, 40), 3.5)]
    black.append(_lofted([(50, 9, 70, 78, 4, 2), (60, 11, 70, 80, 5, 2), (110, 11, 72, 80, 5, 2), (120, 9, 73, 80, 4, 2)]))
    metal = [_vbox(-11, 22, 38, 11, 50, 78, edge=0.03)]
    metal += [_vbox(-12, 30 + 5 * k, 46, 12, 31.5 + 5 * k, 70, edge=0.004) for k in range(4)]
    metal += [_tube((s * 11.5, 36, 80), (s * 11.5, R, back), 2.6) for s in (-1, 1)]
    metal.append(_tube((-11.5, 36, 80), (11.5, 36, 80), 2.6))
    metal.append(cylinder(2.0 * FINE, 26 * FINE, "x", tuple(_f(-13, R, back)), 12))
    metal += [_tube((s * 8, 50, 76), (s * 8, 72, 122), 2.0) for s in (-1, 1)]
    metal += [_tube((11, 34, 40), (13, 52, 70), 2.2), _tube((13, 52, 70), (14, 62, 104), 2.2), _tube((14, 62, 102), (14, 68, 136), 4.2)]
    con = [("socket", (x, 76, 20), (0, -1, 0)) for x in (-10, 10)]
    con += [("stud", (x, 68, z), (0, 1, 0)) for x in (-5, 5) for z in (36, 44)]
    con.append(("axle", (-13, R, back), (1, 0, 0), 26))
    solids = [[-8, 76, 14, 8, 85.5, 22], [-11, 22, 38, 11, 50, 78], [-11, 70, 50, 11, 80, 120], [-13, 26, 80, 13, 40, 112]]
    return _vpart("b_frame_scrambler", "Scrambler frame", "seat", (-19, 20, 12), union(black), BLACK, con=con, solids=solids,
                  seat_box=[-11, 72, 56, 11, 80, 100], trim=(union(metal), METAL, "metal"),
                  about="A tall dirt bike frame with a single in it, a long flat seat and the swingarm. Put the scrambler fork and knobbly wheels on it.",
                  engine_twin="engine_micro", aero={"front": 0.6, "back": 0.7, "side": 0.8}, power=6200.0, max_force=1300.0,
                  astride=True, driver_height=7, control=1.05, recline=0)


@part
def body_scrambler():
    tank = _lofted([(24, 9, 70, 84, 5), (32, 11, 68, 84, 5), (44, 11, 68, 79, 5), (50, 9, 69, 75, 4)])
    shrouds = [profile_x([(z * FINE, y * FINE) for z, y in [(22, 52), (22, 80), (46, 76), (40, 54)]], x0 * FINE, x1 * FINE) for x0, x1 in ((-13.5, -10.5), (10.5, 13.5))]
    panels = [profile_x([(z * FINE, y * FINE) for z, y in [(84, 60), (84, 76), (114, 76), (106, 60)]], x0 * FINE, x1 * FINE) for x0, x1 in ((-13.5, -11.5), (11.5, 13.5))]
    fender = _lofted([(100, 10, 71, 75, 1.5), (140, 9, 74, 78.5, 2), (176, 7, 80, 83, 1.5)])
    body = union([tank, fender] + shrouds + panels)
    trim = union([_coat(tank, [_vbox(-2.5, 0, 0, 2.5, 100, 200, edge=0)]), _roundel(union(panels), (98, 68), 6, "7")])
    con = [("socket", (x, 68, z), (0, -1, 0)) for x in (-5, 5) for z in (36, 44)]
    solids = [[-11, 68, 29, 11, 84, 50], [10.5, 51, 29.5, 13.5, 80, 46], [-13.5, 51, 29.5, -10.5, 80, 46], [11.5, 60, 84, 13.5, 76, 112],
              [-13.5, 60, 84, -11.5, 76, 112], [-10, 72, 121, 10, 83, 176]]
    return _vpart("b_body_scrambler", "Scrambler bodywork", "body", (-14, 51, 21), body, ORANGE, con=con, solids=solids, trim=(trim, WHITE, "plastic"),
                  about="The scrambler's tank, radiator scoops, number boards and back mudguard in one.", aero={"front": 0.6, "back": 0.7, "side": 0.8}, mass=1.6, strength=700.0)


# Zippy, a scooter, and Tiddler, a little delta trike with a scooter's front
# end: little wheels 20 in radius 104 apart, the rider's feet on a floor
# behind an apron.

def _scooter_frame(id, name, trike, about):
    R, back = 20, 104
    # The floor is thick so the rider's feet rest on the bodywork's floor on top.
    black = [_vbox(-8, 56, 12, 8, 62, 24, edge=0.015), _tube((0, 58, 22), (0, 26, 36), 3.5), _vbox(-10, 16, 30, 10, 26.5, 66, edge=0.012)]
    metal = []
    con = [("socket", (x, 56, 18), (0, -1, 0)) for x in (-10, 10)]
    con += [("stud", (x, 26.5, z), (0, 1, 0)) for x in (-6, 6) for z in (40, 60)]
    solids = [[-8, 56, 12, 8, 62, 24], [-10, 16, 30, 10, 26.5, 66]]
    if trike:
        # An axle across the back for a little wheel each end, a deck over
        # it for a box, and the saddle up on a post.
        black += [_vbox(-6, 18, 66, 6, 24, 96, edge=0.01), _tube((0, 22, 70), (0, 38, 74), 3.5)]
        black.append(_lofted([(67, 11, 36, 45, 4, 2), (72, 13, 37, 48, 5, 2), (78, 13, 38, 48, 5, 2), (88, 13, 38, 48, 5, 2), (94, 11, 40, 48, 4, 2)]))
        black.append(_vbox(-22, 38, 96, 22, 42, 132, edge=0.01))
        black += [_tube((s * 14, 22, 104), (s * 14, 39, 112), 2.6) for s in (-1, 1)]
        metal += [cylinder(4.0 * FINE, 88 * FINE, "x", tuple(_f(-44, R, back)), 14), _vbox(-12, 16.5, 92, 12, 28, 114, edge=0.02)]
        con.append(("axle", (-44, R, back), (1, 0, 0), 88))
        con += [("stud", (x, 42, z), (0, 1, 0)) for x in (-10, 10) for z in (104, 124)]
        solids += [[-13, 38, 67, 13, 48, 94], [-22, 38, 96, 22, 42, 132], [-12, 16.5, 92, 12, 28, 114]]
        stats = dict(engine_twin="electric_motor", power=3600.0, max_force=1600.0)
        at = (-45, 16, 11)
    else:
        # The motor and swingarm in one down the left of the back wheel.
        metal += [_vbox(-14, 18, 74, -6.5, 30, 112, edge=0.02), cylinder(2.0 * FINE, 20 * FINE, "x", tuple(_f(-10, R, back)), 12)]
        metal.append(_tube((-14, 24, 70), (-9, 21, 40), 2.6))
        con.append(("axle", (-10, R, back), (1, 0, 0), 20))
        solids.append([-14, 18, 82, -6.5, 30, 112])
        stats = dict(engine_twin="electric_motor", power=4500.0, max_force=1600.0)
        at = (-17, 16, 11)
    return _vpart(id, name, "seat", at, union(black), BLACK, con=con, solids=solids, seat_box=[-12, 40, 52, 12, 48, 96],
                  trim=(union(metal), METAL, "metal") if metal else None, about=about, aero={"front": 0.7, "back": 0.7, "side": 0.8},
                  astride=True, feet_forward=True, driver_height=7, control=1.05, recline=0, **stats)


part(lambda: _scooter_frame("b_frame_scooter_small", "Little scooter frame", False,
                            "A scooter's frame, the floor and an electric motor driving the back wheel. Put the little scooter fork on the front, the scooter bodywork over it and little wheels on both ends."))
part(lambda: _scooter_frame("b_frame_delta_trike", "Little trike frame", True,
                            "A little trike's frame with a scooter's front, a saddle on a post, a deck for a box and an axle across the back for two little wheels."))


def _apron(hw0, hw1):
    """A scooter's apron, from the floor up to just under the headset, in
    front of the rider's feet, leaning forward at the top."""
    return _lofted([(23, hw1, 40, 62, 6, 3), (28, hw0 * 0.5 + hw1 * 0.5, 22, 62, 8, 3), (34, hw0, 18.5, 60, 8, 3), (42, hw0, 18.5, 38, 6, 3)])


@part
def body_scooter():
    apron = _apron(17, 13)
    floor = _vbox(-15, 18.5, 30, 15, 31, 66, edge=0.012)
    cowl = _lofted([(58, 13, 23, 31, 6, 4), (66, 18, 23, 34, 8, 5), (76, 19, 23, 39, 10, 6), (84, 19, 23, 42, 11, 6), (100, 20, 23, 47, 12, 6), (120, 18, 25, 45, 10, 6),
                    (132, 11, 31, 41, 6, 4)])
    well = cylinder(26 * FINE, 20 * FINE, "x", tuple(_f(-10, 20, 104)), 32)
    cowl = cowl - union([well, _vbox(-10, 0, 104, 10, 40, 140, edge=0)])
    # Low where the rider sits, stepping up over the back wheel.
    seat = _lofted([(67, 12, 36, 45, 4, 2), (72, 14, 37, 48, 5, 2), (78, 14, 38, 48, 5, 2), (86, 14, 39, 48, 5, 2), (96, 14, 44, 54, 5, 2), (104, 12, 46, 52, 4, 2)])
    rack = _vbox(-9, 44, 108, 9, 46.5, 128, edge=0.006)
    mat = _vbox(-12, 30.5, 34, 12, 31.6, 62, edge=0.004)
    body = union([apron, floor, cowl])
    con = [("socket", (x, 26.5, z), (0, -1, 0)) for x in (-6, 6) for z in (40, 60)]
    solids = [[-15, 26.5, 30, 15, 31, 66], [-16, 31, 27.5, 16, 47.5, 40], [-20, 23.5, 66, 20, 41, 82], [-20, 31, 82, -10.5, 46, 128], [10.5, 31, 82, 20, 46, 128]]
    return _vpart("b_body_scooter", "Scooter bodywork", "body", (-21, 18, 23), body, BLUE, con=con, solids=solids,
                  trim=(union([seat, rack, mat]), CREAM, "plastic"), about="A scooter's apron, floor and rounded back with the seat on top, for the little scooter frame.",
                  aero={"front": 0.5, "back": 0.6, "side": 0.8}, mass=2.4, strength=800.0)


@part
def body_delta_trike():
    apron = _apron(15, 12)
    floor = _vbox(-14, 18.5, 30, 14, 31, 62, edge=0.012)
    stand = _lofted([(58, 10, 22, 31, 5, 3), (66, 12, 22, 34, 6, 3), (76, 12, 23, 38, 6, 3), (90, 12, 24, 38, 6, 3), (96, 10, 24, 36, 5, 3)])
    guards = [_arc(23, 27, (104, 20), x0, x1, -75, 80) for x0, x1 in ((-46, -30), (30, 46))]
    stays = [_vbox(x0, 36, 100, x1, 39, 110, edge=0.004) for x0, x1 in ((-31, -21), (21, 31))]
    mat = _vbox(-11, 30.5, 34, 11, 31.6, 58, edge=0.004)
    body = union([apron, floor, stand] + guards + stays)
    con = [("socket", (x, 26.5, z), (0, -1, 0)) for x in (-6, 6) for z in (40, 60)]
    solids = [[-14, 26.5, 30, 14, 31, 62], [-15, 31, 27.5, 15, 47.5, 40], [-12, 26.5, 66, 12, 37.5, 92], [-46, 40, 94, -30, 47, 120], [30, 40, 94, 46, 47, 120]]
    return _vpart("b_body_delta_trike", "Little trike bodywork", "body", (-47, 18, 23), body, "#e86a9a", con=con, solids=solids,
                  trim=(mat, BLACK, "plastic"), about="A little trike's apron, floor, a stand for its saddle and mudguards over the back wheels.",
                  aero={"front": 0.5, "back": 0.6, "side": 0.8}, mass=2.0, strength=800.0)


@part
def box_delta_trike():
    # The size, weight and strength of a 2×2 brick, so it drives the same as one.
    box_ = _lofted([(94.5, 18, 42, 65.5, 6, 2), (98, 19.5, 42, 66, 7, 2), (130, 19.5, 42, 66, 7, 2), (133.5, 18, 42, 65.5, 6, 2)])
    d = 0.003
    over = union([box_.translate(v) for v in ([d, 0, 0], [-d, 0, 0], [0, d, 0], [0, 0, d], [0, 0, -d])]) - box_
    lid = over ^ _vbox(-30, 61, 80, 30, 80, 150, edge=0)
    con = [("socket", (x, 42, z), (0, -1, 0)) for x in (-10, 10) for z in (104, 124)]
    return _vpart("b_box_delta_trike", "Little trike box", "body", (-20, 42, 94), box_, "#7fd8be", con=con, solids=[[-20, 42, 94, 20, 66, 134]],
                  trim=(lid, WHITE, "plastic"), size=(40, 24, 40), about="A rounded box with a lid, for the deck on the back of the little trike.",
                  mass=1.0, strength=600.0)


# Long Fork, a chopper, and Sunday Trike, a chopper trike: the long fork out
# in front on a small wheel, the rider low, 200 back to the back axle.

def _chopper_frame(id, name, trike, about):
    back = 200
    rb = 28                                          # the back wheels' radius
    black = [_vbox(-8, 78, 38, 8, 90, 50, edge=0.015), _tube((0, 86, 48), (0, 68, 118), 3.5)]
    black += [_tube((s * 5, 80, 44), (s * 6, 24, 90), 3.0) for s in (-1, 1)]
    black.append(_lofted([(116, 11, 54, 60, 4, 2), (124, 13, 54, 62, 5, 2), (152, 13, 54, 62, 5, 2), (158, 12, 55, 64, 4, 2)]))
    metal = [_vbox(-10, 26, 104, 10, 46, 140, edge=0.03), _tube((0, 44, 114), (0, 64, 101), 6.0), _tube((0, 44, 130), (0, 53, 135), 6.0)]
    metal += [_tube((0, 46 + 4 * k, 114 - 2.6 * k), (0, 46 + 4 * k, 114 - 2.6 * k), 7.5) for k in range(3)]
    # Pegs out in front for the rider's feet, on posts up off the engine.
    for s in (-1, 1):
        metal += [_tube((s * 8, 52, 117), (s * 19.5, 52, 117), 2.0), _tube((s * 9, 44, 117), (s * 9, 52, 117), 1.8)]
    con = [("socket", (x, 78, 44), (0, -1, 0)) for x in (-10, 10)]
    con += [("stud", (0, 72, z), (0, 1, 0)) for z in (80, 96)]
    solids = [[-8, 78, 38, 8, 90, 50], [-10, 26, 104, 10, 46, 140], [-13, 54, 116, 13, 64, 156.5], [-14, 58, 160, 14, 62, 174]]
    # A pad behind the saddle for a sissy bar.
    black.append(_vbox(-14, 58, 160, 14, 62, 174, edge=0.01))
    con += [("stud", (x, 62, 167), (0, 1, 0)) for x in (-10, 10)]
    if trike:
        # An axle across the back and a deck over it for the body.
        black += [_tube((s * 6, 24, 90), (s * 10, 26, 150), 3.0) for s in (-1, 1)]
        black += [_tube((s * 10, 26, 150), (s * 12, 30, 196), 3.0) for s in (-1, 1)]
        black += [_tube((s * 12, 56, 162), (s * 22, 34, 186), 2.6) for s in (-1, 1)]
        black.append(_vbox(-28, 30, 174, 28, 36, 250, edge=0.01))
        metal += [cylinder(5.0 * FINE, 122 * FINE, "x", tuple(_f(-61, rb, back)), 16), _vbox(-14, 21, 190, 14, 35, 210, edge=0.02)]
        metal += [_tube((s * 8, 30, 132), (s * 30, 26, 170), 2.4) for s in (-1, 1)]
        con.append(("axle", (-61, rb, back), (1, 0, 0), 122))
        con += [("stud", (x, 36, z), (0, 1, 0)) for x in (-20, 0, 20) for z in (180, 220)]
        solids += [[-28, 30, 174, 28, 36, 250], [-14, 21, 190, 14, 30, 210]]
        stats = dict(engine_twin="engine_big", power=9000.0, max_force=1600.0)
        at = (-62, 20, 36)
    else:
        # Rails back round the wide back wheel, struts up to the pad, and
        # pipes down both sides.
        for s in (-1, 1):
            black += [_tube((s * 6, 24, 90), (s * 8, 23, 140), 3.0), _tube((s * 8, 23, 140), (s * 17, 26, 166), 3.0), _tube((s * 17, 26, 166), (s * 17, rb, back), 3.0)]
            black.append(_tube((s * 17, rb, back), (s * 14, 59, 168), 2.6))
            metal += [_tube((s * 10, 36, 112), (s * 19, 27, 150), 2.4), _tube((s * 19, 27, 150), (s * 19, 30, 236), 2.4)]
        metal.append(cylinder(2.0 * FINE, 40 * FINE, "x", tuple(_f(-20, rb, back)), 12))
        con.append(("axle", (-16, rb, back), (1, 0, 0), 32))
        con += [("stud", (x, 56, 190), (0, 1, 0)) for x in (-10, 10)]
        stats = dict(engine_twin="engine_big", power=6500.0, max_force=1400.0)
        at = (-22, 20, 36)
    return _vpart(id, name, "seat", at, union(black), BLACK, con=con, solids=solids, seat_box=[-13, 54, 116, 13, 62, 162],
                  trim=(union(metal), METAL, "metal"), about=about, aero={"front": 0.6, "back": 0.7, "side": 0.8},
                  astride=True, feet_forward=True, driver_height=7, control=1.0, recline=0, **stats)


part(lambda: _chopper_frame("b_frame_chopper_long", "Long chopper frame", False,
                            "A long, low chopper frame with a big V twin, the seat low down and a pad behind it for a sissy bar. Put the long chopper fork on the front and a fat wheel at the back."))
part(lambda: _chopper_frame("b_frame_chopper_trike", "Chopper trike frame", True,
                            "A chopper trike's frame with a big V twin, the seat low down, a pad for a sissy bar and a deck over an axle across the back for two wheels."))


@part
def tank_chopper():
    tank = _lofted([(60, 6, 80, 85, 2.5), (66, 11, 74, 88, 6, 4), (84, 13, 72, 88, 7, 4), (100, 11, 72, 84, 6, 4), (112, 7, 73, 79, 4, 3)])
    stripe = _coat(tank, [_vbox(-3.5, 0, 0, 3.5, 100, 200, edge=0)])
    con = [("socket", (0, 72, z), (0, -1, 0)) for z in (80, 96)]
    return _vpart("b_tank_chopper", "Chopper tank", "body", (-14, 71, 59), tank, BLUE, con=con, solids=[[-12, 74, 64, 12, 88, 108]],
                  trim=(stripe, "#2a9d6e", "plastic"), about="A teardrop tank with a stripe down the top, for a chopper frame.",
                  aero={"front": 0.5, "back": 0.6, "side": 0.8}, mass=1.0, strength=600.0)


@part
def fender_chopper():
    rb, back = 28, 200
    guard = _arc(rb + 3, rb + 9, (back, rb), -16, 16, -45, 105, 30)
    struts = [_tube((s * 17, rb, back), (s * 17, rb + 30, back + 8), 2.0) for s in (-1, 1)]
    con = [("socket", (x, 56, 190), (0, -1, 0)) for x in (-10, 10)]
    return _vpart("b_fender_chopper", "Chopper mudguard", "body", (-20, 18, 173), guard, "#2a9d6e", con=con,
                  solids=[[-16, 58, 186, 16, 64, 214]], trim=(union(struts), METAL, "metal"),
                  about="A long rounded mudguard over a chopper's fat back wheel, on chrome stays.", aero={"front": 0.5, "back": 0.6, "side": 0.8}, mass=0.8, strength=600.0)


@part
def body_chopper_trike():
    # A smooth tub with rounded ends and top edges. The size is kept from
    # when it had studs on top, so it drives the same.
    shell = _lofted([(174, 27, 36, 59, 6, 2), (179, 30, 36, 62, 9, 2), (245, 30, 36, 62, 9, 2), (250, 27, 36, 59, 6, 2)])
    lights = [_vbox(x - 5, 50, 249.2, x + 5, 55, 250.4, edge=0.003) for x in (-15, 15)]
    con = [("socket", (x, 36, z), (0, -1, 0)) for x in (-20, 0, 20) for z in (180, 220)]
    return _vpart("b_body_chopper_trike", "Smooth chopper trike body", "body", (-31, 36, 173), shell, YELLOW, con=con, solids=[[-30, 36, 174, 30, 62, 250]],
                  trim=(union(lights), TRANS_RED, "glass"), light="tail", size=(61, 30, 78),
                  about="A chopper trike's smooth rounded body 3×4 over the back axle.",
                  aero={"front": 0.7, "back": 0.9, "side": 0.9}, mass=3.0, strength=1200.0)


# Twin Nose, a reverse trike: two wheels in front on a kart axle plate with
# cycle wings, a wide nose between them, the rider astride with quad bars, and
# one fat wheel at the back under a tail.

@part
def frame_reverse_trike():
    R, back = 24, 140
    # A beam across the front with an axle through it for a wheel each side,
    # and a clip each end for the wings.
    black = [_vbox(-32, 20, -10, 32, 28, 10, edge=0.012), _vbox(-20, 28, -20, 20, 36, 20, edge=0.012)]
    black += [_vbox(-8, 24, 18, 8, 32, 96, edge=0.012), _vbox(-10, 32, 52, 10, 52, 72, edge=0.015)]
    black.append(_lofted([(74, 11, 50, 56, 4, 2), (80, 13, 50, 60, 5, 2), (116, 13, 50, 60, 5, 2), (124, 11, 52, 60, 4, 2)]))
    metal = [cylinder(2.0 * FINE, 108 * FINE, "x", tuple(_f(-54, R, 0)), 12), _vbox(-12, 20, 80, 12, 46, 114, edge=0.03)]
    metal += [_vbox(-13, 26 + 5 * k, 84, 13, 27.5 + 5 * k, 110, edge=0.004) for k in range(4)]
    metal += [_tube((s * 12, 30, 106), (s * 13, R, back), 2.6) for s in (-1, 1)]
    metal.append(cylinder(2.0 * FINE, 28 * FINE, "x", tuple(_f(-14, R, back)), 12))
    metal += [_tube((10, 26, 96), (19, 30, 122), 2.2), _tube((19, 30, 122), (19, 32, 146), 2.2), _tube((19, 32, 142), (19, 34, 164), 4.0)]
    con = [("stud", (x, 36, z), (0, 1, 0)) for x in (-6, 6) for z in (-8, 8)]
    con += [("stud", (x, 52, 62), (0, 1, 0)) for x in (-10, 10)]
    con += [("stud", (x, 54, 128), (0, 1, 0)) for x in (-6, 6)]
    con += [("side", (s * 32, 24, 0), (s, 0, 0)) for s in (-1, 1)]
    con += [("axle", (-54, R, 0), (1, 0, 0), 108), ("axle", (-14, R, back), (1, 0, 0), 28)]
    solids = [[-32, 20, -10, 32, 28, 10], [-20, 28, -20, 20, 36, 20], [-8, 24, 20, 8, 32, 84], [-10, 32, 52, 10, 52, 72], [-13, 50, 74, 13, 60, 124], [-12, 20, 80, 12, 46, 114]]
    return _vpart("b_frame_reverse_trike", "Reverse trike frame", "seat", (-55, 19, -21), union(black), BLACK, con=con, solids=solids,
                  seat_box=[-12, 52, 78, 12, 60, 122], trim=(union(metal), METAL, "metal"),
                  about="A reverse trike's frame with a twin under the saddle, an axle across the front for two wheels with clips for wings, a swingarm for one back wheel and a post for quad bars.",
                  engine_twin="engine_twin", aero={"front": 0.6, "back": 0.7, "side": 0.8}, power=8000.0, max_force=1500.0,
                  astride=True, driver_height=7, control=1.05, recline=0)


def _trike_wing(id, twin, side_):
    """A small wing over a front wheel of the reverse trike, on an upright
    that clips to the end of the frame's beam. It turns with the wheel."""
    R = 24
    # Made on the other side and mirrored across.
    k = -1 if side_ == "right" else 1
    band = cylinder((R + 7) * FINE, 24 * FINE, "x", tuple(_f(33 if k > 0 else -57, R, 0)), 64)
    band = band - cylinder((R + 4) * FINE, 30 * FINE, "x", tuple(_f(30 if k > 0 else -60, R, 0)), 64)
    arc = band ^ _vbox(min(32 * k, 58 * k), R + 14, -40, max(32 * k, 58 * k), R + 40, 40, edge=0)
    post = _vbox(min(32 * k, 33.8 * k), 22, -4, max(32 * k, 33.8 * k), R + 26, 4, edge=0.004)
    body = mirror_x(union([arc, post]))
    solids = [[-57 * k, R + 24.5, -20, -34 * k, R + 31, 20]]
    solids = [[min(b[0], b[3]), b[1], b[2], max(b[0], b[3]), b[4], b[5]] for b in solids]
    con = [("clip", (-32 * k, 24, 0), (k, 0, 0))]
    at = (-57 if k > 0 else 32, 20, -28)
    return _vpart(id, "Trike wing " + side_, "body", at, body, ORANGE, con=con, solids=solids, steers=True, mirror=twin,
                  about="A small wing over a front wheel of the reverse trike, on an upright that turns with the wheel.",
                  aero={"front": 0.5, "back": 0.6, "side": 0.9}, mass=0.4, strength=500.0)


part(lambda: _trike_wing("b_wing_trike_left", "b_wing_trike_right", "left"))
part(lambda: _trike_wing("b_wing_trike_right", "b_wing_trike_left", "right"))


@part
def nose_reverse_trike():
    shell = _lofted([(-42, 10, 30, 36, 3), (-34, 18, 30, 42, 5, 3), (-16, 24, 30, 50, 8, 3), (8, 26, 30, 54, 9, 3), (30, 24, 32, 56, 8, 3), (44, 17, 34, 58, 6, 3)])
    stripe = _coat(shell, [_vbox(-3, 0, -60, 3, 100, 60, edge=0)])
    lamps = union([cylinder(3.2 * FINE, 1.0 * FINE, "-z", tuple(_f(x, 33.5, -37.6)), 16) for x in (-8, 8)])
    con = [("socket", (x, 36, z), (0, -1, 0)) for x in (-6, 6) for z in (-8, 8)]
    return _vpart("b_nose_reverse_trike", "Reverse trike nose", "body", (-27, 29, -43), shell, ORANGE, con=con,
                  solids=[[-26, 36.5, -34, 26, 54, 44]], trim=(stripe, DARK_GREY, "plastic"), lamp=(lamps, TRANS_CLEAR), light="head",
                  about="A wide rounded nose with a stripe and two headlights, between the front wheels of the reverse trike.",
                  aero={"front": 0.3, "back": 0.8, "side": 0.8}, mass=1.8, strength=800.0)


@part
def tail_reverse_trike():
    R, back = 24, 140
    shell = _lofted([(118, 15, 44, 56, 4), (128, 22, 42, 58, 5, 3), (158, 21, 42, 60, 5, 3), (166, 16, 46, 58, 4)])
    shell = shell - union([cylinder((R + 5) * FINE, 40 * FINE, "x", tuple(_f(-20, R, back)), 36)])
    lights = _vbox(-10, 52, 165.2, 10, 56, 166.6, edge=0.003)
    con = [("socket", (x, 54, 128), (0, -1, 0)) for x in (-6, 6)]
    return _vpart("b_tail_reverse_trike", "Reverse trike tail", "body", (-23, 41, 117), shell, ORANGE, con=con,
                  solids=[[-22, 54, 124, 22, 60, 164]], trim=(lights, TRANS_RED, "glass"), light="tail",
                  about="A tail over the reverse trike's back wheel, with a tail light.", aero={"front": 0.6, "back": 0.8, "side": 0.8}, mass=1.2, strength=700.0)


# The stock quads: Zipper, Mudlark and Flat Track. Each has a black frame
# with the saddle on it, a body over the front wheels with the tank and a
# body over the back wheels. In each quad's own space like the bikes, the
# front axle at z 0. A quad is (wheel radius, wheel width, wheelbase, the
# wheels' outside face across, half width of the bodies, top of the bodies,
# top of the saddle). The rider's hips are QUAD_HIPS in front of the back
# wheel's arch.

_QUADS = {"zipper": (22.4, 32, 120, 68, 50, 56, 64),
          "mudlark": (33.6, 32, 140, 74, 52, 75, 84),
          "flat_track": (24, 36, 120, 72, 54, 56, 66)}
QUAD_HIPS = 28


def _quad_hips(q):
    R, ww, wb, xo, hw, yt, ys = q
    return wb - R - QUAD_HIPS


def _quad_frame_v(key, name, about, **stats):
    """A quad's frame: a spine joining the axles, the engine under the
    saddle, footboards each side and an exhaust down the right."""
    q = _QUADS[key]
    R, ww, wb, xo, hw, yt, ys = q
    zs = _quad_hips(q)
    sy = R + 6                                       # top of the spine, where the bodies sit
    spine = _lofted([(-14, 8, R - 6, sy, 3), (-10, 10, R - 6, sy, 4), (wb + 10, 10, R - 6, sy, 4), (wb + 14, 8, R - 6, sy, 3)])
    # The saddle narrows in front so the rider's thighs clear it.
    saddle = _lofted([(zs - 26, 5, ys - 14, ys - 4, 2), (zs - 20, 6, ys - 14, ys - 1, 3, 2), (zs - 4, 6, ys - 14, ys, 3, 2), (zs + 6, 12, ys - 14, ys, 5, 2),
                      (zs + 18, 12, ys - 14, ys, 5, 2), (zs + 26, 10, ys - 12, ys - 3, 4, 2)])
    black = [spine, saddle]
    inner = 22                                       # footboards out to here
    metal = [_vbox(-13, sy - 1, zs - 22, 13, ys - 13, zs + 18, edge=0.02)]
    fins = max(1, int((ys - 14 - sy) // 5))
    metal += [_vbox(-14, sy + 2 + 5 * k, zs - 18, 14, sy + 3.4 + 5 * k, zs + 8, edge=0.004) for k in range(fins)]
    metal += [cylinder(3 * FINE, 2 * xo * FINE, "x", tuple(_f(-xo, R, z)), 14) for z in (0, wb)]
    metal += [_vbox(s * 9 if s > 0 else -inner, R - 4, R + 4, inner if s > 0 else -9, R - 1.5, wb - R - 4, edge=0.006) for s in (-1, 1)]
    metal += [_tube((13, sy + 4, zs + 6), (16, R + 2, zs + 22), 2.2), _tube((16, R + 2, zs + 22), (16, R + 2, wb - R - 6), 2.2)]
    metal.append(cylinder(4 * FINE, (R + 2) * FINE, "z", tuple(_f(16, R + 2, wb - R - 8)), 14))
    con = [("stud", (x, sy, z), (0, 1, 0)) for x in (-6, 6) for z in (-6, 6, wb - 6, wb + 6)]
    con += [("axle", (-xo, R, z), (1, 0, 0), 2 * xo) for z in (0, wb)]
    # The saddle's back end rests on the back body.
    solids = [[-10, R - 6, -14, 10, sy, wb + 14], [-12, ys - 14, zs - 26, 12, ys, zs + 23], [-12, yt, zs + 23, 12, ys, zs + 26],
              [-13, sy, zs - 22, 13, ys - 14, zs + 18]]
    return _vpart("b_frame_quad_" + key, name + " frame", "seat", (-xo, R - 6, -14), union(black), BLACK, con=con, solids=solids,
                  seat_box=[-12, ys - 8, zs - 22, 12, ys, zs + 22], trim=(union(metal), METAL, "metal"), about=about,
                  engine_twin="engine_twin", aero={"front": 0.7, "back": 0.8, "side": 0.8}, astride=True, driver_height=7, recline=0, **stats)


def _quad_shell(q, z0, z1, axle):
    """A smooth body across the quad from z0 to z1: a mudguard over each
    wheel that drops down at both ends, and a rounded block between the
    wheels under it."""
    R, ww, wb, xo, hw, yt, ys = q
    yb = R + 6
    xi = xo - ww
    lo = yt - 7                                      # underside of the top over the wheels
    guard = _lofted([(z0, hw - 5, R + 12, yt - 5, 4), (z0 + 4, hw, R + 9, yt - 1, 5, 2), (z0 + 14, hw, lo, yt, 6, 2),
                     (z1 - 14, hw, lo, yt, 6, 2), (z1 - 4, hw, R + 9, yt - 1, 5, 2), (z1, hw - 5, R + 12, yt - 5, 4)])
    m0, m1 = axle - R + 4, axle + R - 4               # hidden behind the wheels from the side
    middle = _lofted([(m0, xi - 4, yb, yt - 2, 4, 2), (m1, xi - 4, yb, yt - 2, 4, 2)])
    wells = [cylinder((R + 4) * FINE, (ww + 6) * FINE, "x", tuple(_f(x, R, axle)), 48) for x in (-xo - 3, xo - ww - 3)]
    under = _vbox(-xo - 4, R - 20, z0 - 4, xo + 4, yb, z1 + 4, edge=0)
    return union([guard, middle]) - union(wells) - under


def _quad_solids(q, z0, z1, axle):
    """Solid boxes for a quad body from z0 to z1: the top, and the block
    between the wheels down to the frame."""
    R, ww, wb, xo, hw, yt, ys = q
    xi = xo - ww
    return [[-hw, max(2 * R, yt - 9), z0, hw, yt, z1], [-xi + 4, R + 6, axle - R + 4, xi - 4, max(2 * R, yt - 9), axle + R - 4]]


def _quad_rack(q, z0, z1):
    """A tube rack over a quad body from z0 to z1."""
    R, ww, wb, xo, hw, yt, ys = q
    y = yt + 5
    x = hw - 4
    a, b = z0 + 4, z1 - 4
    rods = [_rods([_f(-x, y, a), _f(x, y, a), _f(x, y, b), _f(-x, y, b), _f(-x, y, a)], 1.6 * FINE)]
    rods += [_tube((-x, y, z), (x, y, z), 1.3) for z in (a + (b - a) / 3, a + 2 * (b - a) / 3)]
    rods += [_tube((s * x, yt - 1, z), (s * x, y, z), 1.5) for s in (-1, 1) for z in (a + 2, b - 2)]
    return union(rods)


def _quad_front_v(key, name, colour, trim_colour, number, about, rack=False):
    """The body over a quad's front wheels with two lamps and the tank back
    to the bars. Quad bars go on the studs on the back of the tank."""
    q = _QUADS[key]
    R, ww, wb, xo, hw, yt, ys = q
    zs = _quad_hips(q)
    yb = R + 6
    z0, z1 = -R - 8, R + 8
    shell = _quad_shell(q, z0, z1, 0)
    tank = _lofted([(R - 6, 14, yb, yt - 1, 5, 2), (zs - 36, 13, yb, ys - 8, 5, 2), (zs - 28, 11, yb, ys - 8, 4, 2)])
    body = union([shell, tank])
    ym = (yb + 5 + yt - 3) / 2
    lamps = union([cylinder(3.4 * FINE, 1.0 * FINE, "-z", tuple(_f(x, ym, z0 + 0.5)), 18) for x in (-hw + 16, hw - 16)])
    if rack:
        trim = _quad_rack(q, z0 + 3, min(z1 - 3, zs - 50))
    else:
        trim = union([_coat(body, [_vbox(-3, 0, -100, 3, 200, 300, edge=0)]), _roundel(tank, ((R - 6 + zs - 28) / 2, (yb + ys - 8) / 2), 6.5, number)])
    con = [("socket", (x, yb, z), (0, -1, 0)) for x in (-6, 6) for z in (-6, 6)]
    con += [("stud", (x, ys - 8, zs - 38), (0, 1, 0)) for x in (-10, 10)]
    solids = _quad_solids(q, z0 + 3, z1 - 3, 0) + [[-12, yb, z1 - 3, 12, ys - 8, zs - 28]]
    return _vpart("b_quad_front_" + key, name + " front", "body", (-hw, yb, z0), body, colour, con=con, solids=solids,
                  trim=(trim, trim_colour, "plastic"), lamp=(lamps, TRANS_CLEAR), light="head", about=about,
                  aero={"front": 0.4, "back": 0.8, "side": 0.8}, mass=1.8, strength=800.0)


def _quad_back_v(key, name, colour, about, style):
    """The body over a quad's back wheels: studs on top and tail lights
    ("studs"), or a rack and a tow hitch ("rack")."""
    q = _QUADS[key]
    R, ww, wb, xo, hw, yt, ys = q
    yb = R + 6
    z0, z1 = wb - R - 8, wb + R + 8
    body = _quad_shell(q, z0, z1, wb)
    con = [("socket", (x, yb, z), (0, -1, 0)) for x in (-6, 6) for z in (wb - 6, wb + 6)]
    solids = _quad_solids(q, z0 + 3, z1 - 3, wb)
    stats = {}
    if style == "studs":
        tops = [(x, z) for x in (-30, -10, 10, 30) for z in (wb - 10, wb + 10)]
        body = union([body] + [cylinder(STUD_RADIUS, STUD_HEIGHT, "y", tuple(_f(x, yt - 0.08, z)), 12) for x, z in tops])
        con += [("stud", (x, yt, z), (0, 1, 0)) for x, z in tops]
        ym = (yb + 5 + yt - 3) / 2
        lights = union([_vbox(s * (hw - 18) - 6, ym - 2.5, z1 - 0.6, s * (hw - 18) + 6, ym + 2.5, z1 + 0.6, edge=0.003) for s in (-1, 1)])
        stats.update(trim=(lights, TRANS_RED, "glass"), light="tail")
    else:
        hitch = union([_vbox(-4, yb, z1 - 2, 4, yb + 4, z1 + 6, edge=0.004), cylinder(2.5 * FINE, 4 * FINE, "y", tuple(_f(0, yb + 4, z1 + 3)), 12)])
        stats["trim"] = (union([_quad_rack(q, z0 + 3, z1 - 3), hitch]), BLACK, "plastic")
    return _vpart("b_quad_back_" + key, name + " back", "body", (-hw, yb, z0), body, colour, con=con, solids=solids, about=about,
                  aero={"front": 0.6, "back": 0.8, "side": 0.8}, mass=1.8, strength=800.0, **stats)


part(lambda: _quad_frame_v("zipper", "Sport quad", "A sport quad's frame with the engine and saddle on it and an axle across each end for quad wheels. Put its bodies over the wheels.",
                           power=7400.0, max_force=1500.0, control=1.1))
part(lambda: _quad_front_v("zipper", "Sport quad", BLUE, WHITE, "2", "A sport quad's front body over both front wheels, with lamps, a stripe and the tank."))
part(lambda: _quad_back_v("zipper", "Sport quad", BLUE, "A sport quad's back body over both back wheels, with studs on top and tail lights.", "studs"))
part(lambda: _quad_frame_v("mudlark", "Mud quad", "A tall mud quad's frame with the engine and saddle on it and an axle across each end for big knobbly wheels. Put its bodies over the wheels.",
                           power=7000.0, max_force=1700.0, control=1.0))
part(lambda: _quad_front_v("mudlark", "Mud quad", GREEN, BLACK, "", "A mud quad's front body over both front wheels, with lamps, a rack and the tank.", rack=True))
part(lambda: _quad_back_v("mudlark", "Mud quad", GREEN, "A mud quad's back body over both back wheels, with a rack and a tow hitch.", "rack"))
part(lambda: _quad_frame_v("flat_track", "Racing quad", "A low racing quad's frame with the engine and saddle on it and an axle across each end. Put its bodies over the wheels.",
                           power=7800.0, max_force=1400.0, control=1.15))
part(lambda: _quad_front_v("flat_track", "Racing quad", YELLOW, BLACK, "5", "A racing quad's low front body over both front wheels, with lamps, a stripe and the tank."))
part(lambda: _quad_back_v("flat_track", "Racing quad", YELLOW, "A racing quad's low back body over both back wheels, with studs on top and tail lights.", "studs"))
