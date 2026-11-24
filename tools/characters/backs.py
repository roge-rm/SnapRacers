"""What's worn on the back: shells, capes, packs, wings, tails and gear, one
function a style. Each gives its solids by colour region in the upper body's
space (see figure.py), before they're cut back from the torso, the neck and
the neck pieces.

Each piece is made standing, seated and reclined (lying back in a lay-down
seat), and astride on a bike. Seated, the seat's back is about 9 cm behind
the torso, so most pieces are squashed flatter against the back to fit
(`squash`), capes stop at the hips with their hem rolled up, and tails curl
out to the side over the edge of the seat. Lying back the seat's cushion
comes up under the bottom of the back, so pieces sit higher up it.

Anything above the shoulders behind the head stays clear of the hair and
headgear as the head turns, as the ponytail reaches 30 cm back.
"""

import math

import numpy as np
from manifold3d import CrossSection, Manifold

import figure as F
import torsos
from shapes import GAP, ball, blob, chain, rbox, soft_slab, tube
from torsos import keep

TOP = F.HIPS_TOP + F.TORSO_HEIGHT
BACK = F.TORSO_DEPTH * 0.5
ON = BACK + GAP
MIDDLE = F.HIPS_TOP + F.TORSO_HEIGHT * 0.5

# Colours that don't follow the piece's own: (colour, metallic). "clear" is
# the piece's own colour, see through.
COLOURS = {
    "white": ["#f2f2f2", 0.0],
    "gold": ["#c9a227", 0.6],
    "silver": ["#c8ccd0", 0.6],
    "ink": ["#3c3f44", 0.0],
    "brown": ["#6b4430", 0.0],
}

POSES = ("standing", "seated", "reclined", "astride")
# How far back a piece can reach (z) and how low it can go (y), seated in an
# upright seat and lying back in a lay-down one.
ROOM = {"seated": (0.184, 0.09), "reclined": (0.172, 0.2)}


# Shapes.

def _add():
    from manifold3d import OpType
    return OpType.Add


def union(parts):
    parts = [p for p in parts if p is not None and not p.is_empty()]
    return Manifold.batch_boolean(parts, _add()) if parts else Manifold()


def poly(points):
    s = CrossSection([points])
    if s.area() <= 0.0:
        s = CrossSection([list(reversed(points))])
    return s


def slab(points, depth, r=None, segments=16):
    """A flat piece from a convex outline (x, y), `depth` thick along z,
    centred on z = 0, its edges rounded."""
    r = depth * 0.4 if r is None else r
    return soft_slab(poly(points), depth, r, 2, segments)


def disc(radius, depth, r=None, sides=24):
    r = depth * 0.4 if r is None else r
    return soft_slab(CrossSection.circle(radius, sides), depth, r, 2, sides)


def turned(solid, degrees_z=0.0, degrees_y=0.0, at=(0.0, 0.0, 0.0)):
    return solid.rotate([0.0, 0.0, degrees_z]).rotate([0.0, degrees_y, 0.0]).translate(list(at))


def block(x0, y0, z0, x1, y1, z1, r, segments=8):
    """A small rounded box, kept light."""
    r = min(r, (x1 - x0) * 0.49, (y1 - y0) * 0.49, (z1 - z0) * 0.49)
    b = Manifold.sphere(r, segments)
    return Manifold.batch_hull([b.translate([x, y, z]) for x in (x0 + r, x1 - r) for y in (y0 + r, y1 - r) for z in (z0 + r, z1 - r)])


def xband(x0, x1):
    return Manifold.cube([x1 - x0, 4.0, 4.0]).translate([x0, -2.0, -2.0])


def yband(y0, y1):
    return Manifold.cube([4.0, y1 - y0, 4.0]).translate([-2.0, y0, -2.0])


def zband(z0, z1):
    return Manifold.cube([4.0, 4.0, z1 - z0]).translate([-2.0, -2.0, z0])


def straps():
    """A strap over each shoulder, from the top of the back over the
    shoulder and a little way down the front, lying on the torso."""
    shell = torsos.base(GAP + 0.005) - torsos.base(GAP)
    out = []
    for s in (-1.0, 1.0):
        band = xband(*sorted((0.127 * s, 0.155 * s)))
        zone = (yband(0.3, 1.0) ^ zband(-0.02, 1.0)) + (yband(0.385, 1.0) ^ zband(-1.0, 0.0))
        out.append(shell ^ band ^ zone)
    return union(out).simplify(0.0006)


class Piece:
    """A piece in colour regions, main to start with. Raised bits go in
    their own region; prints repaint what's inside a zone."""

    def __init__(self, solid=None):
        self.regions = {}
        if solid is not None:
            self.regions["main"] = keep(solid)

    def add(self, name, solid):
        solid = keep(solid)
        # Cut with a copy whose faces don't show, as they're under the bit.
        hidden = solid.as_original()
        for k in list(self.regions):
            if k != name:
                self.regions[k] = self.regions[k] - hidden
        self.regions[name] = self.regions[name] + solid if name in self.regions else solid
        return self

    def under(self, name, solid):
        """A raised bit that goes under what's there already."""
        solid = keep(solid)
        for k in list(self.regions):
            solid = solid - self.regions[k].as_original()
        self.regions[name] = self.regions[name] + solid if name in self.regions else solid
        return self

    def paint(self, name, zone, only=None):
        for k in list(self.regions):
            if k == name or (only is not None and k not in only):
                continue
            inside = self.regions[k] ^ zone
            if inside.is_empty():
                continue
            self.regions[k] = self.regions[k] - zone
            self.regions[name] = self.regions[name] + inside if name in self.regions else inside
        return self

    def done(self):
        return {k: v for k, v in self.regions.items() if not v.is_empty() and v.volume() > 1e-9}


def squash(regions, pose):
    """Flattens a piece against the back so it fits in front of the seat's
    back, and lifts its bottom clear of the cushion, the same for every
    region so they still meet."""
    zmax, ylow = ROOM[pose]
    box = union(list(regions.values())).bounding_box()
    k = min(1.0, (zmax - BACK) / max(box[5] - BACK, 1e-6))
    top = box[4]
    s = (top - ylow) / (top - box[1]) if box[1] < ylow else 1.0
    m = np.array([[1.0, 0.0, 0.0, 0.0], [0.0, s, 0.0, top * (1.0 - s)], [0.0, 0.0, k, BACK * (1.0 - k)]])
    return {name: v.transform(m) for name, v in regions.items()}


# The styles. Each takes the pose and gives its regions.

def _shell(pose, spiky):
    dome = blob((0.0, MIDDLE + 0.01, ON), (0.17, 0.17, 0.115), 24) ^ zband(ON, 1.0)
    p = Piece(dome)
    p.paint("light", zband(-1.0, ON + 0.028))
    # The plates on the back of the shell, as lines.
    for x in (-0.055, 0.055):
        p.paint("dark", xband(x - 0.004, x + 0.004) ^ zband(ON + 0.07, 1.0), ["main"])
    for y in (MIDDLE - 0.05, MIDDLE + 0.07):
        p.paint("dark", yband(y - 0.004, y + 0.004) ^ zband(ON + 0.07, 1.0), ["main"])
    if spiky:
        middle = np.array([0.0, MIDDLE + 0.01, ON])
        spikes = []
        for k in range(7):
            if k == 0:
                d = np.array([0.0, 0.0, 1.0])
            else:
                a = 2.0 * math.pi * (k - 1) / 6.0 + math.pi / 6.0
                d = np.array([math.cos(a) * 0.6, math.sin(a) * 0.6, 0.62])
            d /= np.linalg.norm(d)
            # Where that way meets the dome.
            q = d / np.array([0.17, 0.17, 0.115])
            at = middle + d / np.linalg.norm(q)
            spikes.append(tube(at - d * 0.012, at + d * 0.05, 0.026, 0.002, 14))
        p.add("white", union(spikes))
    return p.done()


def shell(pose):
    return _shell(pose, False)


def spiky_shell(pose):
    return _shell(pose, True)


def _cape(pose, long):
    """A cape hanging from a roll across the top of the back, held by a
    strap over each shoulder. Seated it stops at the hips with its hem
    rolled up; standing the long one reaches the calves."""
    top = TOP - 0.008
    sitting = pose in ("seated", "reclined", "astride")
    if sitting:
        bottom = 0.11 if pose != "reclined" else 0.21
    else:
        bottom = -0.2 if long else 0.18
    # Wider at the hem than the shoulders.
    hw_top, hw_bottom = 0.17, (0.25 if long and not sitting else 0.2)
    if sitting:
        hw_bottom = hw_top + (hw_bottom - hw_top) * (top - bottom) / (top - (-0.2 if long else 0.18))
    outline = [(-hw_top, top), (hw_top, top), (hw_bottom, bottom + 0.02), (hw_bottom - 0.02, bottom), (-hw_bottom + 0.02, bottom), (-hw_bottom, bottom + 0.02)]
    thick = 0.012
    sheet = poly(outline).extrude(thick).refine_to_length(0.05)
    inner = 0.128
    droop_from = 0.12

    def drape(pts):
        pts = np.array(pts, copy=True)
        x, y = pts[:, 0], pts[:, 1]
        t = np.clip((droop_from - y) / 0.32, 0.0, 1.0)
        pts[:, 2] = pts[:, 2] + inner + 0.055 * t + 0.4 * x * x * (0.25 + t)
        return pts

    sheet = sheet.warp_batch(drape)
    p = Piece(sheet)
    # A clasp strap over each shoulder.
    shell = torsos.base(GAP + 0.005) - torsos.base(GAP)
    for s in (-1.0, 1.0):
        band = xband(*sorted((0.127 * s, 0.158 * s)))
        p.add("main", shell ^ band ^ yband(TOP - 0.03, 1.0) ^ zband(-0.06, 0.13))
        p.add("gold", ball((0.142 * s, TOP - 0.012, 0.085), 0.011, 12))
    if sitting:
        # The hem rolled up where it meets the seat.
        z = inner + thick * 0.5
        roll = tube((-hw_bottom + 0.01, bottom + 0.01, z + 0.006), (hw_bottom - 0.01, bottom + 0.01, z + 0.006), 0.016, 0.016, 16)
        p.add("main", roll)
    # A darker lining shows round the edges.
    p.paint("dark", zband(-1.0, inner + 0.003), ["main"])
    # The gathered top, all in the cape's colour: the lining's edge across
    # its round ends left slivers of both colours there.
    p.add("main", tube((-0.165, top - 0.004, 0.12), (0.165, top - 0.004, 0.12), 0.014, 0.014, 16)
          + ball((-0.165, top - 0.004, 0.12), 0.014, 16) + ball((0.165, top - 0.004, 0.12), 0.014, 16))
    return p.done()


def cape(pose):
    return _cape(pose, True)


def short_cape(pose):
    return _cape(pose, False)


def backpack(pose):
    p = Piece(rbox(-0.12, 0.13, ON - 0.01, 0.12, 0.37, ON + 0.1, 0.03))
    # The flap over the top, and a pocket on the back.
    p.add("dark", rbox(-0.115, 0.27, ON + 0.05, 0.115, 0.38, ON + 0.108, 0.02) - zband(-1.0, ON + 0.05))
    p.add("light", rbox(-0.08, 0.15, ON + 0.07, 0.08, 0.25, ON + 0.122, 0.015) - zband(-1.0, ON + 0.07))
    p.add("gold", block(-0.015, 0.25, ON + 0.11, 0.015, 0.285, ON + 0.118, 0.004))
    return p.done()


def jet_pack(pose):
    p = Piece()
    p.add("ink", rbox(-0.11, 0.16, ON - 0.01, 0.11, 0.37, ON + 0.028, 0.012))
    for s in (-1.0, 1.0):
        x = 0.06 * s
        z = ON + 0.028 + 0.042
        p.add("main", tube((x, 0.18, z), (x, 0.34, z), 0.044, 0.044, 14) + (ball((x, 0.34, z), 0.044, 14) ^ yband(0.34, 1.0)))
        p.add("silver", tube((x, 0.185, z), (x, 0.115, z), 0.03, 0.04, 14))
    p.paint("dark", yband(0.27, 0.29), ["main"])
    return p.done()


def _feather(length, width, depth=0.018):
    """A long rounded feather lying along +x from the origin."""
    pts = [(0.0, -width * 0.5), (length * 0.7, -width * 0.5), (length, -width * 0.15), (length, width * 0.1), (length * 0.85, width * 0.5), (0.0, width * 0.5)]
    return slab(pts, depth, 0.006, 12)


def angel_wings(pose):
    p = Piece()
    for s in (-1.0, 1.0):
        parts = []
        lower = []
        for k, (length, angle) in enumerate(((0.3, 16.0), (0.27, -2.0), (0.22, -20.0), (0.17, -38.0))):
            f = turned(_feather(length, 0.06), angle, 0.0, (0.0, 0.0, 0.004 * k))
            (parts if k < 2 else lower).append(f)
        covert = turned(slab([(0.0, -0.045), (0.12, -0.03), (0.15, 0.0), (0.12, 0.035), (0.0, 0.05)], 0.026, 0.01, 12), 18.0, 0.0, (0.0, 0.0, -0.012))
        wing = [union(parts), union(lower), covert]
        place = lambda m: m.mirror([1.0, 0.0, 0.0]) if s < 0 else m
        moved = [place(turned(w, 0.0, -24.0, (0.0, 0.0, 0.0))).translate([0.045 * s, 0.34, ON + 0.022]) for w in wing]
        p.add("main", moved[0] + moved[1])
        p.add("light", moved[2])
    return p.done()


def bat_wings(pose):
    p = Piece()
    for s in (-1.0, 1.0):
        root = np.array([0.0, 0.0])
        tips = [np.array([0.3, 0.13]), np.array([0.32, -0.02]), np.array([0.24, -0.12]), np.array([0.12, -0.15])]
        panels = []
        for a, b in zip(tips, tips[1:]):
            mid = (a + b) * 0.5
            inward = mid + (root - mid) * 0.28
            for tri in ((root, a, inward), (root, inward, b)):
                panels.append(poly([tuple(v) for v in tri]).extrude(0.008).translate([0.0, 0.0, -0.004]))
        top = poly([(0.0, 0.0), (0.3, 0.13), (0.0, 0.04)]).extrude(0.008).translate([0.0, 0.0, -0.004])
        # Thicker than the skin to their tips, so they never lie flush with it.
        bones = [tube((0.0, 0.0, 0.0), (t[0], t[1], 0.0), 0.009, 0.0055, 10) for t in tips]
        wing = union(panels + [top])
        frame = union(bones) + ball((0.0, 0.0, 0.0), 0.022, 16)
        place = lambda m: (m.mirror([1.0, 0.0, 0.0]) if s < 0 else m)
        p.add("main", place(turned(wing, 0.0, -18.0)).translate([0.04 * s, 0.34, ON + 0.02]))
        p.add("dark", place(turned(frame, 0.0, -18.0)).translate([0.04 * s, 0.34, ON + 0.02]))
    return p.done()


def fairy_wings(pose):
    p = Piece()
    for s in (-1.0, 1.0):
        lobes = []
        for length, width, angle, at in ((0.2, 0.11, 16.0, (0.03, 0.33)), (0.13, 0.08, -35.0, (0.03, 0.27))):
            pts = [(length * 0.5 * (1 + math.cos(2 * math.pi * k / 14)), width * 0.5 * math.sin(2 * math.pi * k / 14)) for k in range(14)]
            body = slab(pts, 0.007, 0.0025, 10)
            lobe = turned(body, angle, 0.0)
            lobes.append((lobe, length, width, angle, at))
        for lobe, length, width, angle, at in lobes:
            # The see-through middle, with a rim round it.
            inner_pts = [(length * 0.5 + (length * 0.5 - 0.014) * math.cos(2 * math.pi * k / 14), (width * 0.5 - 0.014) * math.sin(2 * math.pi * k / 14)) for k in range(14)]
            middle = turned(poly(inner_pts).extrude(0.1).translate([0.0, 0.0, -0.05]), angle, 0.0)
            place = lambda m: (m.mirror([1.0, 0.0, 0.0]) if s < 0 else m)
            moved = place(turned(lobe, 0.0, -20.0)).translate([at[0] * s, at[1], ON + 0.012])
            hole = place(turned(middle, 0.0, -20.0)).translate([at[0] * s, at[1], ON + 0.012])
            p.add("main", moved - hole)
            p.add("clear", moved ^ hole)
        p.add("light", ball((0.02 * s, 0.3, ON + 0.01), 0.022, 12))
    return p.done()


def _tail(points, radii, segments=20):
    return chain([tuple(q) for q in points], radii, segments)


def dino_tail(pose):
    if pose in ("seated", "reclined"):
        y = 0.2 if pose == "seated" else 0.32
        pts = [(0.0, y, 0.12), (0.13, y, 0.135), (0.26, y + 0.01, 0.13), (0.37, y + 0.04, 0.1), (0.43, y + 0.09, 0.07)]
        radii = [0.055, 0.048, 0.036, 0.022, 0.008]
    else:
        pts = [(0.0, 0.18, 0.12), (0.0, 0.13, 0.24), (0.0, 0.07, 0.36), (0.0, 0.05, 0.46), (0.0, 0.08, 0.53)]
        radii = [0.068, 0.052, 0.036, 0.02, 0.006]
    body = _tail(pts, radii)
    p = Piece(body)
    # Spikes along the top.
    spikes = []
    for a, b, ra, rb in zip(pts, pts[1:4], radii, radii[1:4]):
        mid = (np.array(a) + np.array(b)) * 0.5
        r = (ra + rb) * 0.5
        d = np.array(b) - np.array(a)
        d /= np.linalg.norm(d)
        up = np.array([0.0, 1.0, 0.0]) - d * d[1]
        up /= np.linalg.norm(up)
        base = mid + up * (r - 0.012)
        side = np.cross(d, up)
        tri = Manifold.hull_points([tuple(base - d * 0.03), tuple(base + d * 0.03), tuple(base + up * (0.04 + r * 0.2)),
                                    tuple(base - d * 0.03 + side * 0.008), tuple(base + d * 0.03 + side * 0.008),
                                    tuple(base - d * 0.03 - side * 0.008), tuple(base + d * 0.03 - side * 0.008)])
        spikes.append(tri)
    p.under("dark", union(spikes))
    return p.done()


def fox_tail(pose):
    if pose in ("seated", "reclined"):
        y = 0.2 if pose == "seated" else 0.32
        pts = [(0.0, y, 0.12), (0.14, y + 0.01, 0.13), (0.27, y + 0.04, 0.128), (0.37, y + 0.11, 0.11), (0.4, y + 0.19, 0.09)]
        radii = [0.04, 0.05, 0.054, 0.048, 0.02]
    else:
        pts = [(0.0, 0.17, 0.13), (0.03, 0.12, 0.24), (0.07, 0.14, 0.35), (0.1, 0.24, 0.42), (0.11, 0.33, 0.44)]
        radii = [0.04, 0.062, 0.078, 0.06, 0.02]
    body = _tail(pts, radii, 24)
    p = Piece(body)
    # A white tip.
    a, b = np.array(pts[2]), np.array(pts[3])
    p.paint("white", _beyond(a, a + (b - a) * 0.55))
    return p.done()


def _beyond(a, b):
    """Everything past the plane through b, facing away from a."""
    a, b = np.array(a), np.array(b)
    d = b - a
    d /= np.linalg.norm(d)
    big = Manifold.cube([2.0, 2.0, 2.0]).translate([-1.0, -1.0, 0.0])
    z = np.array([0.0, 0.0, 1.0])
    axis = np.cross(z, d)
    s = np.linalg.norm(axis)
    if s < 1e-9:
        m = np.eye(3)
    else:
        axis /= s
        ang = math.atan2(s, z.dot(d))
        K = np.array([[0, -axis[2], axis[1]], [axis[2], 0, -axis[0]], [-axis[1], axis[0], 0]])
        m = np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * K @ K
    return big.transform(np.hstack([m, b.reshape(3, 1)]))


def flag(pose):
    """A chequered flag on a pole in a holder on the back. The pole leans
    out past the shoulder, clear of the head and hair."""
    lo = np.array([0.14, 0.16, ON + 0.022])
    hi = np.array([0.4, 0.74, ON + 0.03])
    d = (hi - lo) / np.linalg.norm(hi - lo)
    p = Piece()
    p.add("silver", tube(lo, hi, 0.009, 0.009, 12) + ball(hi, 0.016, 12))
    p.add("ink", tube(lo - d * 0.01, lo + d * 0.13, 0.019, 0.019, 16))
    # The cloth, back from the pole, or out to the side lying back, its
    # edge along the pole.
    rows, cols = 4, 5
    size = 0.044
    top = hi[1] - 0.025
    if pose == "reclined":
        cloth = Manifold.cube([cols * size, rows * size, 0.008]).translate([hi[0], top - rows * size, hi[2] - 0.004])
    else:
        cloth = Manifold.cube([0.008, rows * size, cols * size]).translate([hi[0] - 0.004, top - rows * size, hi[2]])
    cloth = cloth.refine_to_length(size * 0.5)
    checks = []
    for i in range(cols):
        for j in range(rows):
            if (i + j) % 2:
                y0 = top - (j + 1) * size
                if pose == "reclined":
                    checks.append(Manifold.cube([size, size, 0.1]).translate([hi[0] + i * size, y0, hi[2] - 0.05]))
                else:
                    checks.append(Manifold.cube([0.1, size, size]).translate([hi[0] - 0.05, y0, hi[2] + i * size]))

    def along(q):
        q = np.array(q, copy=True)
        q[:, 0] += (q[:, 1] - hi[1]) * d[0] / d[1]
        q[:, 2] += (q[:, 1] - hi[1]) * d[2] / d[1]
        return q

    p.add("main", cloth.warp_batch(along))
    p.paint("white", union(checks).warp_batch(along), ["main"])
    return p.done()


def sword(pose):
    """A sword in its sheath across the back, the hilt over the left
    shoulder."""
    angle = 36.0
    length = 0.3
    sheath = slab([(-0.024, 0.0), (0.024, 0.0), (0.024, length - 0.03), (0.0, length), (-0.024, length - 0.03)], 0.028, 0.008, 12)
    sheath = sheath.rotate([0.0, 0.0, 180.0])
    p = Piece()
    guard = rbox(-0.05, -0.012, -0.016, 0.05, 0.006, 0.016, 0.006)
    grip = tube((0.0, 0.0, 0.0), (0.0, 0.06, 0.0), 0.011, 0.011, 12)
    pommel = ball((0.0, 0.066, 0.0), 0.016, 12)
    band = rbox(-0.026, -0.05, -0.016, 0.026, -0.036, 0.016, 0.004)

    def place(m):
        return m.rotate([0.0, 0.0, angle]).translate([-0.1, 0.375, ON + 0.016])

    p.add("main", place(sheath))
    p.add("gold", place(guard + pommel + band))
    p.add("ink", place(grip))
    return p.done()


def guitar(pose):
    """A guitar slung across the back, its neck up over the left
    shoulder."""
    depth = 0.048
    lower = disc(0.092, depth, 0.012, 28)
    upper = disc(0.072, depth, 0.012, 24).translate([0.0, 0.12, 0.0])
    waist = slab([(-0.065, 0.03), (0.065, 0.03), (0.055, 0.1), (-0.055, 0.1)], depth, 0.012, 12)
    body = lower + upper + waist
    neck = rbox(-0.017, 0.17, depth * 0.5 - 0.02, 0.017, 0.33, depth * 0.5 + 0.003, 0.006)
    head = rbox(-0.024, 0.325, depth * 0.5 - 0.022, 0.024, 0.38, depth * 0.5 + 0.004, 0.008)
    hole = Manifold.cylinder(0.05, 0.03, 0.03, 24).translate([0.0, 0.09, depth * 0.5 - 0.004])
    bridge = Manifold.cube([0.07, 0.016, 0.05]).translate([-0.035, -0.04, depth * 0.5 - 0.004])

    def place(m):
        return m.translate([0.0, 0.0, depth * 0.5]).rotate([0.0, 0.0, 28.0]).translate([0.08, 0.1, ON])

    p = Piece(place(body))
    p.paint("ink", place(hole))
    p.paint("dark", place(bridge))
    p.add("brown", place(neck))
    p.add("ink", place(head))
    return p.done()


def air_tanks(pose):
    """Two tanks on a plate on the back, joined by a valve at the top."""
    p = Piece()
    p.add("ink", block(-0.1, 0.17, ON - 0.01, 0.1, 0.34, ON + 0.026, 0.01))
    z = ON + 0.026 + 0.046
    for s in (-1.0, 1.0):
        x = 0.051 * s
        p.add("main", tube((x, 0.17, z), (x, 0.34, z), 0.046, 0.046, 16) + (ball((x, 0.34, z), 0.046, 16) ^ yband(0.34, 1.0)) + (ball((x, 0.17, z), 0.046, 16) ^ yband(-1.0, 0.17)))
    p.paint("ink", yband(0.19, 0.205) + yband(0.305, 0.32), ["main"])
    p.add("silver", tube((-0.051, 0.37, z), (-0.051, 0.4, z), 0.012, 0.012, 12) + tube((0.051, 0.37, z), (0.051, 0.4, z), 0.012, 0.012, 12) + tube((-0.06, 0.4, z), (0.06, 0.4, z), 0.01, 0.01, 12))
    return p.done()


def parachute(pose):
    p = Piece(rbox(-0.13, 0.12, ON - 0.01, 0.13, 0.38, ON + 0.075, 0.03))
    p.paint("dark", yband(0.245, 0.255) ^ zband(ON + 0.03, 1.0))
    p.paint("dark", xband(-0.005, 0.005) ^ zband(ON + 0.06, 1.0))
    p.add("silver", Manifold.cylinder(0.012, 0.022, 0.022, 20).rotate([0.0, 90.0, 0.0]).translate([0.13, 0.2, ON + 0.035])
          - Manifold.cylinder(0.05, 0.012, 0.012, 20).rotate([0.0, 90.0, 0.0]).translate([0.1, 0.2, ON + 0.035]))
    return p.done()


def quiver(pose):
    """A quiver of arrows across the back, leaning over the left
    shoulder."""
    r = 0.042
    tube_ = tube((0.0, 0.0, 0.0), (0.0, 0.25, 0.0), r * 0.85, r, 20) + ball((0.0, 0.0, 0.0), r * 0.85, 20) ^ yband(-0.03, 1.0)
    # The rim stands a little above the tube, so their tops aren't in the same place.
    rim = tube((0.0, 0.225, 0.0), (0.0, 0.253, 0.0), r + 0.004, r + 0.004, 20)
    mouth = Manifold.cylinder(0.05, r - 0.008, r - 0.008, 20).rotate([-90.0, 0.0, 0.0]).translate([0.0, 0.235, 0.0])
    shafts = []
    vanes = []
    for x, h in ((-0.016, 0.08), (0.004, 0.1), (0.022, 0.07)):
        shafts.append(tube((x, 0.2, 0.0), (x, 0.25 + h, 0.0), 0.005, 0.005, 8))
        top = 0.25 + h
        vanes.append(slab([(x - 0.014, top - 0.045), (x, top - 0.04), (x + 0.014, top - 0.045), (x + 0.014, top - 0.012), (x, top), (x - 0.014, top - 0.012)], 0.004, 0.0015, 8))

    def place(m):
        return m.rotate([0.0, 0.0, 24.0]).translate([0.03, 0.1, ON + r])

    p = Piece(place(tube_ - mouth))
    p.add("dark", place(rim - mouth))
    p.add("brown", place(union(shafts)))
    p.add("white", place(union(vanes)))
    return p.done()


def radio(pose):
    p = Piece(rbox(-0.1, 0.13, ON - 0.01, 0.1, 0.34, ON + 0.085, 0.022))
    for y in (0.17, 0.19, 0.21):
        p.paint("ink", yband(y, y + 0.008) ^ xband(-0.07, 0.01) ^ zband(ON + 0.07, 1.0))
    p.add("silver", Manifold.cylinder(0.016, 0.022, 0.022, 20).translate([0.05, 0.27, ON + 0.075]))
    p.add("dark", rbox(-0.07, 0.25, ON + 0.07, 0.0, 0.3, ON + 0.09, 0.006))
    p.add("ink", tube((0.07, 0.33, ON + 0.06), (0.07, 0.43, ON + 0.06), 0.008, 0.006, 10) + ball((0.07, 0.43, ON + 0.06), 0.011, 10))
    return p.done()


def shield(pose):
    r = 0.15
    face = disc(r, 0.03, 0.01, 32).translate([0.0, 0.0, 0.015])
    dome = blob((0.0, 0.0, 0.03), (r - 0.012, r - 0.012, 0.02), 24) ^ zband(0.03, 1.0)
    p = Piece((face + dome).translate([0.0, MIDDLE + 0.01, ON]))
    rim = (Manifold.cylinder(0.036, r + 0.004, r + 0.004, 32) - Manifold.cylinder(0.04, r - 0.018, r - 0.018, 32).translate([0.0, 0.0, -0.002])).translate([0.0, MIDDLE + 0.01, ON + 0.002])
    p.add("silver", rim)
    p.add("silver", blob((0.0, MIDDLE + 0.01, ON + 0.045), (0.035, 0.035, 0.025), 20))
    p.paint("light", xband(-0.012, 0.012) ^ zband(ON + 0.03, 1.0), ["main"])
    p.paint("light", yband(MIDDLE - 0.002, MIDDLE + 0.022) ^ zband(ON + 0.03, 1.0), ["main"])
    return p.done()


STYLES = {
    "spiky_shell": spiky_shell,
    "shell": shell,
    "cape": cape,
    "short_cape": short_cape,
    "backpack": backpack,
    "jet_pack": jet_pack,
    "angel_wings": angel_wings,
    "bat_wings": bat_wings,
    "fairy_wings": fairy_wings,
    "dino_tail": dino_tail,
    "flag": flag,
    "sword": sword,
    "guitar": guitar,
    "air_tanks": air_tanks,
    "parachute": parachute,
    "quiver": quiver,
    "radio": radio,
    "fox_tail": fox_tail,
    "shield": shield,
}
# Styles made again for each pose; the rest are squashed to fit.
OWN_POSES = {"cape", "short_cape", "dino_tail", "fox_tail", "flag"}
# Styles that use their seated shape astride, instead of their standing one.
SEATED_ASTRIDE = {"cape", "short_cape"}
# Styles held on by straps over the shoulders, in this region, and which
# shoulders.
STRAPS = {
    "backpack": ("dark", "both"), "jet_pack": ("ink", "both"), "air_tanks": ("ink", "both"),
    "parachute": ("ink", "both"), "radio": ("ink", "both"), "sword": ("ink", "left"), "quiver": ("ink", "left"),
}
# Styles whose own colour is shiny.
METAL = {}


def _with_straps(style, regions):
    if style not in STRAPS:
        return regions
    region, which = STRAPS[style]
    band = straps()
    if which == "left":
        band = band ^ xband(-1.0, 0.0)
    out = dict(regions)
    band = keep(band)
    for k in list(out):
        band = band - out[k].as_original()
    out[region] = out[region] + band if region in out else band
    return out


def make(style):
    """A style's regions in every pose, {pose: regions}, not yet cut back
    from the figure."""
    out = {}
    standing = STYLES[style]("standing")
    out["standing"] = _with_straps(style, standing)
    for pose in ("seated", "reclined"):
        if style in OWN_POSES:
            out[pose] = STYLES[style](pose)
        else:
            out[pose] = _with_straps(style, squash(standing, pose))
    out["astride"] = out["seated"] if style in SEATED_ASTRIDE else out["standing"]
    return out
