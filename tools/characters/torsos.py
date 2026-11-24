"""The torsos: the standard torso, one function a style, each giving it in
colour regions in the upper body's space (see figure.py). Like a moulded toy
torso the shape stays the same and the style is printed on as flat colour
regions, with only a raised belt buckle here and there.

The front faces -z. Prints on the front reach a few centimetres in, so they
go round the soft edges, and bands go all the way round.
"""

import math

from manifold3d import CrossSection, JoinType, Manifold

import figure as F
from shapes import SEGMENTS, rbox, soft_slab

BOTTOM = F.HIPS_TOP
TOP = F.HIPS_TOP + F.TORSO_HEIGHT
CHEST = -F.TORSO_DEPTH * 0.5
BACK = F.TORSO_DEPTH * 0.5

COLOURS = {
    "denim": ["#1f4e8c", 0.0],
    "denim_dark": ["#173c6c", 0.0],
    "brown": ["#6b4430", 0.0],
}


def half_width(y):
    """Half the torso's width at a height, with its bowed sides."""
    t = (y - BOTTOM) / F.TORSO_HEIGHT
    return F.half_width(y) + 0.007 * math.sin(math.pi * t)


def section():
    """The torso from the front: wider at the bottom, the sides bowing out a
    little, rounded shoulders."""
    right = []
    steps = 5
    for k in range(steps + 1):
        y = BOTTOM + F.TORSO_HEIGHT * k / steps
        right.append((half_width(y), y))
    points = right + [(-x, y) for x, y in reversed(right)]
    s = CrossSection([points])
    shoulders = s.offset(-0.04, JoinType.Round, 2.0, 20).offset(0.04, JoinType.Round, 2.0, 20)
    lower = s.offset(-0.012, JoinType.Round, 2.0, 8).offset(0.012, JoinType.Round, 2.0, 8)
    cut = CrossSection.square([1.0, 1.0]).translate([-0.5, BOTTOM + F.TORSO_HEIGHT * 0.5])
    return (shoulders ^ cut) + (lower - cut)


def collar_ring(grow=0.0):
    """The round collar the neck sits in, moulded into the top."""
    c = CrossSection([[(0.046, -0.004), (0.068, -0.004), (0.068, 0.006), (0.046, 0.006)]])
    c = c.offset(-0.003, JoinType.Round, 2.0, 8).offset(0.003, JoinType.Round, 2.0, 8)
    if grow > 0.0:
        c = c.offset(grow, JoinType.Round, 2.0, 8)
    return c.revolve(24).rotate([-90.0, 0.0, 0.0]).translate([0.0, TOP, 0.0])


def base(grow=0.0):
    """The torso, or with `grow` the space around it pieces are kept out of."""
    s = section()
    if grow > 0.0:
        s = s.offset(grow, JoinType.Round, 2.0, 24)
    return soft_slab(s, F.TORSO_DEPTH + grow * 2.0, 0.03 + grow, 2, 12) + collar_ring(grow)


# Where prints go.

def poly(points):
    s = CrossSection([points])
    if s.area() <= 0.0:
        s = CrossSection([list(reversed(points))])
    return s


def front(points, depth=0.04):
    """A print on the front: the outline as (x, y) points, reaching `depth`
    in from the chest."""
    return poly(points).extrude(0.3 + depth).translate([0.0, 0.0, -0.3 + CHEST])


def back(points, depth=0.04):
    """A print on the back, the outline seen from the front."""
    return poly(points).extrude(0.3 + depth).translate([0.0, 0.0, BACK - depth])


def both(points, depth=0.04):
    return front(points, depth) + back(points, depth)


def band(y0, y1):
    """A band all the way round, from y0 up to y1."""
    return Manifold.cube([1.0, y1 - y0, 1.0]).translate([-0.5, y0, -0.5])


def strip(x0, x1, y0=-1.0, y1=2.0):
    """Everything between x0 and x1, front, back and top, from y0 to y1."""
    return Manifold.cube([x1 - x0, y1 - y0, 1.0]).translate([x0, y0, -0.5])


def rect(x0, y0, x1, y1):
    return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def circle(cx, cy, r, n=10):
    return [(cx + r * math.cos(2.0 * math.pi * k / n), cy + r * math.sin(2.0 * math.pi * k / n)) for k in range(n)]


def slant(x0, y0, x1, y1, w):
    """A strip w wide from one point to another."""
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    nx, ny = -dy / length * w * 0.5, dx / length * w * 0.5
    return [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]


def collar(r=0.075):
    """The collar ring and the top just around it."""
    return Manifold.cylinder(0.05, r, r, 32).rotate([-90.0, 0.0, 0.0]).translate([0.0, TOP - 0.012, 0.0])


def mirror(points):
    return [(-x, y) for x, y in points]


# The ids of the meshes whose faces show, so the faces of the cuts between
# regions can be left out when saving (see keep).
SURFACE = set()
_base = []


def keep(solid):
    """Marks a solid's faces as ones that show."""
    solid = solid.as_original()
    SURFACE.add(solid.original_id())
    return solid


def shown_base():
    if not _base:
        _base.append(keep(base()))
    return _base[0]


class Paint:
    """A piece split into colour regions, main to start with: the torso, or
    a solid marked with keep."""

    def __init__(self, solid=None):
        self.regions = {"main": shown_base() if solid is None else solid}

    def paint(self, name, prism):
        # The rest is cut by the prism itself, not by what's inside it, which
        # leaves flat slivers on the surface that flicker against the print.
        for k in list(self.regions):
            if k == name:
                continue
            inside = self.regions[k] ^ prism
            if inside.is_empty():
                continue
            self.regions[k] = self.regions[k] - prism
            self.regions[name] = self.regions[name] + inside if name in self.regions else inside
        return self

    def add(self, name, solid):
        """A raised bit, in its own region."""
        solid = keep(solid)
        self.regions[name] = self.regions[name] + solid if name in self.regions else solid
        return self

    def done(self):
        return {k: v for k, v in self.regions.items() if not v.is_empty()}


def buckle(y):
    """A small raised buckle on the front of a belt."""
    return rbox(-0.022, y - 0.017, CHEST - 0.006, 0.022, y + 0.017, CHEST + 0.004, 0.003)


# The styles.

def tee():
    return Paint().done()


def racing_suit():
    p = Paint()
    for s in (-1.0, 1.0):
        lo, hi = sorted((0.132 * s, 0.4 * s))
        p.paint("white", strip(lo, hi, BOTTOM + 0.035, TOP - 0.05))
    p.paint("dark", band(BOTTOM + 0.012, BOTTOM + 0.035))
    p.paint("dark", collar(0.078))
    p.paint("silver", front(rect(-0.004, BOTTOM + 0.05, 0.004, TOP - 0.02), 0.03))
    return p.done()


def jacket():
    p = Paint()
    p.paint("white", front([(-0.045, TOP), (0.045, TOP), (0.04, BOTTOM), (-0.04, BOTTOM)]))
    for s in (-1.0, 1.0):
        lapel = [(0.045 * s, TOP), (0.09 * s, TOP), (0.06 * s, TOP - 0.1), (0.044 * s, TOP - 0.13)]
        p.paint("dark", front(lapel))
        p.paint("dark", front(slant(0.047 * s, TOP - 0.12, 0.042 * s, BOTTOM, 0.007)))
        p.paint("dark", front(rect(min(0.07 * s, 0.12 * s), 0.2, max(0.07 * s, 0.12 * s), 0.21)))
    p.paint("dark", collar(0.078))
    p.paint("dark", band(BOTTOM, BOTTOM + 0.018))
    return p.done()


def overalls():
    p = Paint()
    p.paint("denim", front(rect(-0.09, BOTTOM, 0.09, 0.3)))
    p.paint("denim", band(BOTTOM, BOTTOM + 0.07))
    p.paint("denim", back(rect(-0.12, BOTTOM, 0.12, 0.2)))
    for s in (-1.0, 1.0):
        lo, hi = sorted((0.068 * s, 0.1 * s))
        p.paint("denim", strip(lo, hi, 0.28, 1.0))
        p.paint("denim", back(rect(lo, 0.19, hi, TOP)))
        p.paint("gold", front(circle(0.084 * s, 0.288, 0.011, 8), 0.03))
    p.paint("denim_dark", front(rect(-0.045, 0.17, 0.045, 0.24)))
    p.paint("denim_dark", front(rect(-0.09, BOTTOM + 0.065, 0.09, BOTTOM + 0.072)))
    return p.done()


def hoodie():
    p = Paint()
    p.paint("dark", front([(-0.09, 0.2), (0.09, 0.2), (0.125, 0.11), (-0.125, 0.11)]))
    p.paint("dark", band(BOTTOM, BOTTOM + 0.02))
    # The hood lying on the back, and its rim round the neck.
    p.paint("dark", back([(-0.11, TOP + 0.05), (0.11, TOP + 0.05), (0.1, 0.33), (0.05, 0.29), (-0.05, 0.29), (-0.1, 0.33)], 0.06))
    p.paint("dark", collar(0.082))
    for s in (-1.0, 1.0):
        p.paint("white", front(rect(0.024 * s - 0.004, 0.31, 0.024 * s + 0.004, TOP - 0.015), 0.03))
        p.paint("white", front(circle(0.024 * s, 0.305, 0.008, 8), 0.03))
    return p.done()


def armour():
    p = Paint()
    p.paint("dark", both(rect(-0.004, BOTTOM + 0.07, 0.004, TOP - 0.03)))
    p.paint("dark", band(BOTTOM + 0.066, BOTTOM + 0.074))
    p.paint("dark", band(BOTTOM + 0.03, BOTTOM + 0.036))
    p.paint("dark", front([(-0.15, 0.34), (0.15, 0.34), (0.15, 0.348), (0.0, 0.31), (-0.15, 0.348)]))
    for x, y in ((-0.1, 0.32), (0.1, 0.32), (-0.13, 0.17), (0.13, 0.17), (-0.06, BOTTOM + 0.05), (0.06, BOTTOM + 0.05)):
        p.paint("silver", front(circle(x, y, 0.008, 8), 0.03))
    return p.done()


def tuxedo():
    p = Paint()
    p.paint("white", front([(-0.05, TOP + 0.01), (0.05, TOP + 0.01), (0.0, 0.2)]))
    for s in (-1.0, 1.0):
        p.paint("dark", front([(0.05 * s, TOP + 0.01), (0.085 * s, TOP + 0.01), (0.075 * s, 0.33), (0.004 * s, 0.205), (0.0 * s, 0.2)]))
    for y in (0.3, 0.26):
        p.paint("ink", front(circle(0.0, y, 0.006, 8), 0.03))
    p.paint("ink", front(circle(0.0, 0.16, 0.009, 8), 0.03))
    p.paint("white", front([(-0.13, 0.31), (-0.09, 0.31), (-0.095, 0.325), (-0.11, 0.318), (-0.125, 0.325)], 0.03))
    return p.done()


def gown():
    p = Paint()
    p.paint("light", front([(-0.06, 0.37), (0.06, 0.37), (0.035, BOTTOM), (-0.035, BOTTOM)]))
    p.paint("gold", front([(-0.14, 0.37), (0.14, 0.37), (0.14, 0.382), (0.0, 0.36), (-0.14, 0.382)], 0.035))
    for s in (-1.0, 1.0):
        p.paint("gold", front(slant(0.06 * s, 0.37, 0.035 * s, BOTTOM, 0.009)))
    for k in range(3):
        y = 0.16 + k * 0.06
        p.paint("gold", back(slant(-0.03, y, 0.03, y + 0.04, 0.006)))
        p.paint("gold", back(slant(0.03, y, -0.03, y + 0.04, 0.006)))
    return p.done()


def vest():
    p = Paint()
    p.paint("white", front([(-0.05, TOP + 0.01), (0.05, TOP + 0.01), (0.05, BOTTOM), (-0.05, BOTTOM)]))
    p.paint("white", collar(0.078))
    for s in (-1.0, 1.0):
        p.paint("dark", front(slant(0.052 * s, TOP - 0.005, 0.052 * s, BOTTOM, 0.008)))
        for k in range(3):
            p.paint("gold", front(circle(0.072 * s, 0.3 - k * 0.07, 0.008, 8), 0.03))
    p.paint("dark", back(rect(-0.05, 0.19, 0.05, 0.205)))
    return p.done()


def tank_top():
    p = Paint()
    skin = band(0.36, 1.0)
    for s in (-1.0, 1.0):
        lo, hi = sorted((0.066 * s, 0.104 * s))
        skin = skin - strip(lo, hi)
    p.paint("skin", skin)
    p.paint("skin", front(circle(0.0, TOP, 0.09, 16)))
    p.paint("skin", back(circle(0.0, TOP, 0.075, 16)))
    return p.done()


def flower(cx, cy, r):
    pts = []
    for k in range(15):
        a = 2.0 * math.pi * k / 15
        rr = r * (0.62 + 0.38 * abs(math.cos(a * 2.5)))
        pts.append((cx + rr * math.sin(a), cy + rr * math.cos(a)))
    return pts


def flowery():
    p = Paint()
    spots = [(-0.09, 0.33, "white"), (0.07, 0.3, "yellow"), (-0.03, 0.2, "pink"), (0.11, 0.17, "white"), (-0.12, 0.12, "yellow")]
    for x, y, colour in spots:
        p.paint(colour, front(flower(x, y, 0.038), 0.03))
        p.paint("orange", front(circle(x, y, 0.011, 6), 0.03))
    for x, y, colour in ((-0.07, 0.3, "pink"), (0.08, 0.18, "white")):
        p.paint(colour, back(flower(x, y, 0.038), 0.03))
        p.paint("orange", back(circle(x, y, 0.011, 6), 0.03))
    return p.done()


def stripes():
    p = Paint()
    for k in range(5):
        y = BOTTOM + 0.03 + k * 0.064
        p.paint("white", band(y, y + 0.024))
    return p.done()


def plaid():
    p = Paint()
    for x in (-0.09, 0.0, 0.09):
        p.paint("dark", strip(x - 0.008, x + 0.008, BOTTOM, TOP - 0.03))
    for y in (0.13, 0.22, 0.31):
        p.paint("dark", band(y - 0.008, y + 0.008))
    p.paint("light", front(rect(0.042, BOTTOM, 0.048, TOP - 0.02), 0.03))
    return p.done()


def lab_coat():
    p = Paint()
    for s in (-1.0, 1.0):
        p.paint("dark", front([(0.045 * s, TOP + 0.01), (0.07 * s, TOP + 0.01), (0.03 * s, 0.27), (0.02 * s, 0.28)]))
    p.paint("dark", front(rect(-0.003, BOTTOM, 0.003, 0.28), 0.03))
    for y in (0.24, 0.18, 0.12):
        p.paint("ink", front(circle(0.0, y, 0.006, 8), 0.03))
    p.paint("dark", front(rect(-0.13, 0.25, -0.07, 0.257), 0.03))
    p.paint("blue", front(rect(-0.118, 0.257, -0.11, 0.3), 0.03))
    p.paint("red", front(rect(-0.102, 0.257, -0.094, 0.29), 0.03))
    p.paint("dark", back(rect(-0.006, BOTTOM, 0.006, 0.22)))
    return p.done()


def tunic():
    p = Paint()
    p.paint("white", front(rect(-0.024, 0.15, 0.024, 0.37)))
    p.paint("white", front(rect(-0.09, 0.27, 0.09, 0.315)))
    p.paint("brown", band(BOTTOM + 0.056, BOTTOM + 0.088))
    p.add("gold", buckle(BOTTOM + 0.072))
    return p.done()


def pirate_coat():
    p = Paint()
    p.paint("white", front([(-0.045, TOP + 0.01), (0.045, TOP + 0.01), (0.0, 0.22)]))
    for s in (-1.0, 1.0):
        p.paint("dark", front([(0.045 * s, TOP + 0.01), (0.08 * s, TOP + 0.01), (0.03 * s, 0.24), (0.0, 0.22)]))
        for k in range(3):
            p.paint("gold", front(circle(0.1 * s, 0.3 - k * 0.06, 0.009, 8), 0.03))
    p.paint("brown", band(BOTTOM + 0.056, BOTTOM + 0.088))
    p.add("gold", buckle(BOTTOM + 0.072))
    return p.done()


def leather():
    p = Paint()
    p.paint("silver", front(rect(-0.024, BOTTOM, -0.017, TOP - 0.03), 0.03))
    for s in (-1.0, 1.0):
        p.paint("dark", front([(0.04 * s, TOP + 0.01), (0.11 * s, TOP + 0.01), (0.12 * s, 0.36), (0.07 * s, 0.33)]))
    p.paint("silver", front(slant(0.05, 0.24, 0.1, 0.27, 0.006), 0.03))
    p.paint("dark", band(BOTTOM, BOTTOM + 0.025))
    p.paint("dark", back(rect(-0.14, 0.33, 0.14, 0.338)))
    return p.done()


def space_suit():
    p = Paint()
    p.paint("grey", front(rect(-0.07, 0.21, 0.07, 0.3), 0.03))
    for k, colour in enumerate(("red", "green", "yellow", "blue")):
        p.paint(colour, front(circle(-0.045 + k * 0.03, 0.275, 0.009, 8), 0.03))
    p.paint("ink", front(rect(-0.05, 0.23, 0.05, 0.24), 0.03))
    p.paint("white", band(BOTTOM, BOTTOM + 0.03))
    p.paint("white", collar(0.085))
    p.paint("grey", back(rect(-0.1, 0.15, 0.1, 0.36)))
    return p.done()


def gi():
    p = Paint()
    p.paint("dark", front(slant(-0.075, TOP + 0.01, 0.05, BOTTOM + 0.05, 0.03)))
    p.paint("dark", front(slant(0.075, TOP + 0.01, 0.01, 0.27, 0.03)))
    p.paint("ink", band(BOTTOM + 0.018, BOTTOM + 0.05))
    p.paint("ink", front([(-0.01, BOTTOM + 0.02), (-0.03, BOTTOM - 0.01), (-0.016, BOTTOM - 0.01), (0.0, BOTTOM + 0.02)]))
    p.paint("ink", front([(0.01, BOTTOM + 0.02), (0.03, BOTTOM - 0.01), (0.016, BOTTOM - 0.01), (0.0, BOTTOM + 0.02)]))
    return p.done()


def robot():
    p = Paint()
    p.paint("dark", front(rect(-0.09, 0.19, 0.09, 0.34), 0.03))
    for k, colour in enumerate(("red", "green", "blue")):
        p.paint(colour, front(circle(-0.04 + k * 0.04, 0.305, 0.011, 8), 0.03))
    for y in (0.265, 0.24, 0.215):
        p.paint("ink", front(rect(-0.06, y - 0.005, 0.06, y + 0.005), 0.03))
    p.paint("dark", back(rect(-0.08, 0.2, 0.08, 0.32)))
    p.paint("dark", band(BOTTOM, BOTTOM + 0.025))
    return p.done()


def jersey():
    p = Paint()
    for s in (-1.0, 1.0):
        lo, hi = sorted((0.085 * s, 0.125 * s))
        p.paint("white", strip(lo, hi, 0.37, 1.0))
    # A white trim round a V neck.
    p.paint("white", front([(-0.065, TOP + 0.01), (0.065, TOP + 0.01), (0.0, 0.325)]))
    p.paint("main", front([(-0.048, TOP + 0.02), (0.048, TOP + 0.02), (0.0, 0.345)]))
    p.paint("white", band(BOTTOM, BOTTOM + 0.02))
    # A big number one on the back.
    p.paint("white", back([(-0.005, 0.32), (0.025, 0.32), (0.025, 0.16), (-0.005, 0.16), (-0.005, 0.28), (-0.03, 0.27), (-0.03, 0.295)]))
    return p.done()


def dino_belly():
    p = Paint()
    belly = [(0.105 * math.sin(2.0 * math.pi * k / 16), 0.22 + 0.13 * math.cos(2.0 * math.pi * k / 16)) for k in range(16)]
    p.paint("light", front(belly))
    for k in range(4):
        y = 0.15 + k * 0.05
        p.paint("main", front(rect(-0.1, y - 0.004, 0.1, y + 0.004)))
    for k in range(4):
        y = 0.16 + k * 0.06
        p.paint("dark", back([(-0.03, y), (0.03, y), (0.0, y + 0.045)]))
    return p.done()


STYLES = {
    "racing_suit": racing_suit,
    "jacket": jacket,
    "overalls": overalls,
    "hoodie": hoodie,
    "armour": armour,
    "tee": tee,
    "tuxedo": tuxedo,
    "gown": gown,
    "vest": vest,
    "tank_top": tank_top,
    "flowery": flowery,
    "stripes": stripes,
    "plaid": plaid,
    "lab_coat": lab_coat,
    "tunic": tunic,
    "pirate_coat": pirate_coat,
    "leather": leather,
    "space_suit": space_suit,
    "gi": gi,
    "robot": robot,
    "jersey": jersey,
    "dino_belly": dino_belly,
}
# Styles whose own colour is shiny.
METAL = {"armour": 0.45, "robot": 0.35}
