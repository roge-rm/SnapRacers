"""Every part made by the tool. Each part is a function that builds its shape
and says where its connectors are.

A connector is a spot where the part joins another, with a type and the way
it faces out. Studs face up out of the top and sockets face down out of the
bottom. Bars, axles and hinge pins are lines, given from one end with how
long they are, and a clip, wheel hub or hole joins anywhere along one. See
scripts/parts/connectors.gd for which types go together.
"""

import math

from kit import BRICK, EDGE, FINE, PLATE, STUD, STUD_HEIGHT, STUD_RADIUS, box, cut, cylinder, grid_cells, plan_y, profile_x, studs, union

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
TYRE = "#202020"
METAL = "#9aa0a6"
GLASS = "#8fd3f4"
TRANS_RED = "#c4281c"
TRANS_CLEAR = "#e8f4f8"

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
        self.stats = stats
        # A second piece in its own colour that isn't painted, like a tire or
        # a lens: (solid, colour, finish).
        self.trim = stats.pop("trim", None)
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

for _a, _b in [(1, 1), (1, 2), (1, 4), (1, 6), (2, 2), (2, 4)]:
    part((lambda a, b: lambda: _block("p_brick_%dx%d" % (a, b), "Brick %d×%d" % (a, b), "brick", "bricks", a, b, 3, RED))(_a, _b))

for _a, _b in [(1, 1), (1, 2), (1, 4), (1, 6), (2, 2), (2, 4), (2, 6)]:
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
def round_tile_2x2():
    solid = cylinder(STUD - 0.004, PLATE - 0.002, "y", (STUD, 0.001, STUD), 28)
    return Part("p_round_tile_2x2", "Round tile 2×2", "plate", "tiles", (2 * STUD, PLATE, 2 * STUD), solid, sockets(grid_cells(2, 2)), BLACK)


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


# Technic beams, pins and axles. Holes go across (x) through beams a stud
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


def _wheel(id, name, radius, width, rim_radius, grip, rolling, offroad=0.0, lugs=0, color=LIGHT_GREY, about=""):
    w = width
    cx = (w * 0.5, radius, radius)
    shoulder = min(0.06, w * 0.25)
    tire = [(0.0, rim_radius * 0.92), (0.0, radius - shoulder), (shoulder * 0.4, radius - shoulder * 0.2), (shoulder, radius),
            (w - shoulder, radius), (w - shoulder * 0.4, radius - shoulder * 0.2), (w, radius - shoulder), (w, rim_radius * 0.92)]
    tire_solid = _revolve_x(tire, (0.0, radius, radius))
    if lugs:
        tire_solid = union([tire_solid] + _lugs(lugs, radius, w))
    hub = HOLE + 0.02
    rim = [(0.004, hub), (0.004, rim_radius * 0.6), (w * 0.3, rim_radius * 0.75), (w * 0.3, rim_radius), (w - 0.004, rim_radius), (w - 0.004, hub)]
    rim_solid = _revolve_x(rim, (0.0, radius, radius), 28)
    con = [c("hub", (0.0, radius, radius), (1, 0, 0), w)]
    stats = {"radius": radius, "width": w, "grip": grip, "rolling": rolling, "trim": (tire_solid, TYRE, "plastic")}
    if offroad:
        stats["offroad"] = offroad
    if about:
        stats["about"] = about
    return Part(id, name, "wheel", "wheels", (w, 2 * radius, 2 * radius), rim_solid, con, color, **stats)


def _lugs(n, radius, w):
    out = []
    for k in range(n):
        for side in (0, 1):
            a = (k + 0.5 * side) * 360.0 / n
            x0 = 0.01 + side * w * 0.5
            lug = box(x0, radius - 0.035, -0.045, x0 + w * 0.45, radius + 0.025, 0.045, edge=0.006)
            out.append(lug.rotate([a, 0, 0]).translate([0, radius, radius]))
    return out


part(lambda: _wheel("w_kart", "Kart wheel", 0.3, 0.25, 0.2, 1.0, 0.015, color=LIGHT_GREY))
part(lambda: _wheel("w_kart_wide", "Wide kart wheel", 0.3, 0.45, 0.2, 1.2, 0.022, color=LIGHT_GREY))
part(lambda: _wheel("w_racing", "Racing wheel", 0.35, 0.35, 0.27, 1.15, 0.018, color=WHITE))
part(lambda: _wheel("w_slick", "Big slick", 0.4, 0.5, 0.28, 1.35, 0.028, color=DARK_GREY))
part(lambda: _wheel("w_offroad", "Off-road wheel", 0.42, 0.4, 0.25, 1.05, 0.03, offroad=0.6, lugs=14, color=YELLOW))
# Motorbike tires are thin, so they don't hold a bend as well as a kart's.
part(lambda: _wheel("w_moto", "Motorbike wheel", 0.45, 0.2, 0.34, 0.95, 0.014, color=BLACK))
part(lambda: _wheel("w_moto_trail", "Trail bike wheel", 0.45, 0.22, 0.32, 0.88, 0.02, offroad=0.5, lugs=16, color=RED))
part(lambda: _wheel("w_scooter", "Scooter wheel", 0.3, 0.18, 0.2, 0.95, 0.016, color=WHITE))


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
                trim=(lamp, TRANS_CLEAR, "glass"))


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
    if style == "scooter":
        # A little headlamp on the bars.
        grips.append(cylinder(0.05, 0.04, "-z", tuple(_f(40, bar - 6, 8)), 14))
    low = R - 3.6
    hi = bar + 4
    shift = [0, -low * FINE, 0]
    con = [c("stud", _f(x, crown[1], 10), (0, 1, 0)) for x in (30, 50)] + [c("axle", _f(28.8, R, 10), (1, 0, 0), 22.4 * FINE)]
    for co in con:
        co["at"] = [co["at"][0], co["at"][1] + shift[1], co["at"][2]]
    solids = [[20, crown[0], 0, 60, crown[1], 20], [22.4, R - 3.6, 5, 28.8, crown[0], 15], [51.2, R - 3.6, 5, 57.6, crown[0], 15]]
    solids = [[a * FINE, (b - low) * FINE, cc * FINE, d * FINE, (e - low) * FINE, g * FINE] for a, b, cc, d, e, g in solids]
    return Part(id, name, "steering", "bike", (80 * FINE, (hi - low) * FINE, (reach + 4) * FINE), union(parts).translate(shift), con, METAL, finish="metal",
                about=about, style="bikebars", control=1.15, grip_reach=0.3, mass=2.5, strength=900.0, trim=(union(grips).translate(shift), BLACK, "plastic"), solids=solids)


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
    lamp = cylinder(0.06, 0.03, "-z", tuple(_f(20, 18, 7)), 16)
    screen = profile_x([(z * FINE, y * FINE) for z, y in [(14, h1 - h0 - 2), (l, h1 - h0 + 12), (l + 2, h1 - h0 + 12), (18, h1 - h0 - 2)]], 6 * FINE, 34 * FINE)
    con = [c("clip", _f(x, 18, l), (0, 0, 1)) for x in (10, 30)]
    return Part("b_moto_fairing", "Sports fairing", "body", "bike", (40 * FINE, (h1 - h0 + 12) * FINE, (l + 2) * FINE), union([shell, lamp]), con, WHITE,
                aero={"front": 0.3, "back": 1.0, "side": 0.8}, trim=(union([screen, lamp]), TRANS_CLEAR, "glass"), solids=[[2 * FINE, 0, 0, 38 * FINE, (h1 - h0) * FINE, l * FINE]])


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
    return Part("d_light_1x1", "Round light 1×1", "plate", "details", (STUD, PLATE, STUD), lens, sockets([(0, 0)]), TRANS_CLEAR, finish="glass")


@part
def taillight_1x2():
    lens = box(0, 0, 0, STUD, PLATE, 2 * STUD, edge=0.015)
    return Part("d_taillight_1x2", "Tail light 1×2", "plate", "details", (STUD, PLATE, 2 * STUD), lens, sockets(grid_cells(1, 2)), TRANS_RED, finish="glass")


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
