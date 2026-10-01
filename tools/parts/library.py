"""Every part made by the tool. Each part is a function that builds its shape
and says where its connectors are.

A connector is a spot where the part joins another, with a type and the way
it faces out. Studs face up out of the top and sockets face down out of the
bottom. Bars, axles and hinge pins are lines, given from one end with how
long they are, and a clip, wheel hub or hole joins anywhere along one. See
scripts/parts/connectors.gd for which types go together.
"""

import math

from kit import BRICK, EDGE, PLATE, STUD, STUD_HEIGHT, STUD_RADIUS, box, cut, cylinder, grid_cells, plan_y, profile_x, studs, union

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
part(lambda: _wheel("w_moto", "Motorbike wheel", 0.45, 0.2, 0.34, 1.1, 0.014, color=BLACK))
part(lambda: _wheel("w_moto_trail", "Trail bike wheel", 0.45, 0.22, 0.32, 1.0, 0.02, offroad=0.5, lugs=16, color=RED))
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
    four plates more than on the swingarm, so with the same wheels a brick and
    a plate on the swingarm bring it level with the crown. It turns with the
    wheel in it when that's a steered wheel."""
    top = 0.8
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
    """A rounded motorbike tank, 2×3."""
    l = 3 * STUD
    h = 2 * PLATE + 0.06
    pts = [(0.0, 0.0), (0.0, h * 0.5)] + [(l * 0.5 - math.cos(t * math.pi) * l * 0.5, h * 0.5 + h * 0.5 * math.sin(t * math.pi)) for t in [k / 16.0 for k in range(1, 16)]] + [(l, h * 0.5), (l, 0.0)]
    side = profile_x(pts, 0.03, 2 * STUD - 0.03)
    return Part("b_tank", "Fuel tank", "body", "bike", (2 * STUD, h, l), side, sockets(grid_cells(2, 3)), RED, aero={"front": 0.5, "back": 0.6, "side": 0.8})


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
    """Motorbike handlebars on a stem at the front, swept back toward the
    rider, with grips. They turn about the stem."""
    high = PLATE + 0.2
    back = 2 * STUD - 0.05
    stem = union([box(STUD * 1.5, 0, 0, STUD * 2.5, PLATE, STUD), cylinder(0.035, 0.2 + 0.025, "y", (2 * STUD, PLATE, STUD * 0.5), 10)])
    riser = cylinder(0.025, back - STUD * 0.5, "z", (2 * STUD, high, STUD * 0.5), 10)
    bar = cylinder(0.025, 0.7, "x", (2 * STUD - 0.35, high, back), 10)
    grips = [cylinder(0.04, 0.14, "x", (x, high, back), 10) for x in (2 * STUD - 0.42, 2 * STUD + 0.28)]
    con = sockets([(1, 0), (2, 0)])
    return Part("b_bars", "Bike bars", "steering", "bike", (4 * STUD, PLATE + 0.24, 2 * STUD), union([stem, riser, bar]), con, METAL, finish="metal", control=1.15, style="bikebars",
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
                aero={"front": 0.35, "back": 0.6, "side": 0.6}, solids=[[0, 0, 0, w, PLATE * 0.5, l]])
