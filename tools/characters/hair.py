"""Hair, one function a style, like moulded toy hair pieces: a cap over the
head with a soft rounded edge and a few big lobes, with ties and partings
as flat colour regions. Each gives its solids by colour region in the
head's own space (before it's scaled up by HEAD_SCALE), before they're cut
back from the head and the stud.

The head is a rounded cylinder HEAD_RADIUS round from -0.1 to 0.1, facing
-z. Hair keeps out of the face (below FACE_TOP within FACE_ANGLE of the
front), only comes down past the cheeks behind SIDE_ANGLE, where raised
sideburns and beards don't reach, and stops at LOWEST, just under the
head, so it clears the shoulders and what's around the neck however far
the head turns.

Each style also has a cut version for under a hat: what's below CUT_Y,
kept within CUT_RADIUS for CUT_BAND under that and sloping out below, so a
hat whose rim comes down to CUT_Y and fits over CUT_RADIUS covers its top
edge.
"""

import math

import numpy as np
from manifold3d import CrossSection, Manifold

import figure as F
from shapes import GAP, angles_round, ball, blob, curve, lathe_at

R0 = F.HEAD_RADIUS
FACE_TOP = 0.068
FACE_ANGLE = 58.0
SIDE_ANGLE = 78.0
LOWEST = -0.105
# Raised beards and sideburns stay within BEARD_ANGLE of the front and
# under BEARD_TOP, a little lower than the hair comes there.
BEARD_ANGLE = 72.0
BEARD_TOP = 0.052
CUT_Y = 0.05
CUT_RADIUS = R0 + 0.02
CUT_BAND = 0.012
# Under the band the cut hair can reach out by as much as it drops.
SLOPE = 0.1
# Lobes are this smooth.
SEG = 16


def _value(v):
    return v if callable(v) else (lambda a: v)


def head_outline(grow):
    """The head and its stud from the side, as (radius, height) points from
    under the bottom edge up to the middle of the top, `grow` out from them.
    The rounded edges have few points, set out so the lines between them
    stay outside."""
    def arc(cu, cv, rho, a0, a1, steps):
        out = []
        for k in range(steps + 1):
            t = math.radians(a0 + (a1 - a0) * k / steps)
            far = rho / math.cos(math.radians(abs(a1 - a0) / steps * 0.5)) if 0 < k < steps else rho
            out.append((cu + far * math.cos(t), cv + far * math.sin(t)))
        return out

    pts = arc(0.085, -0.065, 0.035 + grow, -60.0, 0.0, 2)
    pts += arc(0.085, 0.065, 0.035 + grow, 0.0, 90.0, 3)
    pts.append((0.06 + grow, 0.1 + grow))
    pts += arc(0.046, 0.126, 0.008 + grow, 0.0, 90.0, 2)
    pts.append((0.002, 0.134 + grow))
    return pts


def _inside(outline, b, lip_at):
    """The inside of the cap at one angle: along its flat lower edge from
    near the lip in to the head at height b, then over the head along the
    outline. Always the same number of points, so the outline's points
    below b are spread along the lower edge."""
    low = max(b, -0.094)
    above = [p for p in outline if p[1] > low + 1e-9]
    below = len(outline) - len(above)
    if b >= -0.094:
        i = next(k for k in range(len(outline) - 1) if outline[k + 1][1] > low)
        (u0, v0), (u1, v1) = outline[i], outline[i + 1]
        t = (low - v0) / (v1 - v0)
        start = (u0 + (u1 - u0) * t, b)
    else:
        start = (0.106, b)
    edge = [(lip_at + (start[0] - lip_at) * (k + 1) / (below + 1), b) for k in range(below)]
    return edge + [start] + above


# The cap's inside sits this far off the head, more than the gap the lobes
# are cut back by, so cutting doesn't touch it.
INSIDE = GAP + 0.0035


def cap(bottom, radius=0.138, top=0.15, dome=0.012, lip=0.009, corner=0.05, bulge=0.003, extra=(), step=18.0):
    """The cap over the head, hollow inside: its lower edge at `bottom` (a
    number or a function of the angle round the head, 0 at the front),
    `radius` out at the sides, flat-ish on top at `top` rising by `dome` in
    the middle, with a rounded lip and top corner. The top and the corner can
    change round the head too. `bulge` pushes the sides
    out between them. `extra` adds sections at these angles (degrees), where
    the edge drops."""
    bottom, radius, bulge, top_at, corner_at = _value(bottom), _value(radius), _value(bulge), _value(top), _value(corner)
    outline = head_outline(INSIDE)

    def profile(a):
        b, r, g, top, corner = bottom(a), radius(a), bulge(a), top_at(a), corner_at(a)
        # Up the inside from the lower edge, over the head to the middle.
        pts = _inside(outline, b, r - lip)
        # Then from the middle of the top out and down the outside.
        inner = r - corner
        for k in range(3):
            u = inner * k / 3
            pts.append((max(u, 0.002), top + dome * (1.0 - (u / inner) ** 2)))
        for k in range(3):
            t = math.radians(90.0 - 90.0 * k / 2)
            pts.append((r - corner + corner * math.cos(t), top - corner + corner * math.sin(t)))
        # Down the side, bowed out by the bulge.
        for k in (1, 2, 3):
            pts.append((r + g * math.sin(math.pi * k / 4), top - corner + (b + lip - top + corner) * k / 4))
        for k in range(3):
            t = math.radians(0.0 - 90.0 * k / 2)
            pts.append((r - lip + lip * math.cos(t), b + lip + lip * math.sin(t)))
        return pts

    return lathe_at(angles_round(step, extra), profile)


# Extra sections where long hair drops past the cheeks.
DROP = (-84.0, -78.0, -75.0, -72.0, -66.0, 66.0, 72.0, 75.0, 78.0, 84.0)


def face_line(front, side, back, drop_at=SIDE_ANGLE):
    """A lower edge at `front` across the face, coming down no lower than
    BEARD_TOP until BEARD_ANGLE, to `side` over the ears from `drop_at` back,
    and `back` at the back."""
    mid = max(BEARD_TOP, min(front, side + 0.02))
    return lambda a: curve([(0.0, front), (FACE_ANGLE, front), (BEARD_ANGLE, mid), (drop_at, side), (120.0, side * 0.5 + back * 0.5), (180.0, back)], a)


def around(r, degrees, y):
    a = math.radians(degrees)
    return np.array([r * math.sin(a), y, -r * math.cos(a)])


def tuft(base, tip, r0, r1, seg=12, tip_seg=None):
    """A chunky rounded cone from base to tip."""
    return Manifold.batch_hull([ball(base, r0, seg), ball(tip, r1, tip_seg or seg)])


def lobe(at, radii, along=None, seg=SEG):
    """An ellipsoid, its z radius along `along` if given."""
    turn = None
    if along is not None:
        z = np.asarray(along, float)
        z /= np.linalg.norm(z)
        x = np.cross([0.0, 1.0, 0.0], z) if abs(z[1]) < 0.95 else np.cross([1.0, 0.0, 0.0], z)
        x /= np.linalg.norm(x)
        y = np.cross(z, x)
        turn = np.column_stack([x, y, z])
    return blob(at, radii, seg, turn)


def chain(points, radii, seg=12):
    """Soft lobes hulled one to the next, like a tail or a braid."""
    balls = [ball(p, r, seg) for p, r in zip(points, radii)]
    return union([Manifold.batch_hull([a, b]) for a, b in zip(balls, balls[1:])])


def band(solid, at, along, half):
    """Splits a solid into a flat band across `along` at `at`, `half` either
    side, and the rest, for a hair tie printed on."""
    n = np.asarray(along, float)
    n /= np.linalg.norm(n)
    d = float(n.dot(at))
    slab = solid.trim_by_plane(list(n), d - half).trim_by_plane(list(-n), -(d + half))
    rest = solid.trim_by_plane(list(-n), -(d - half)) + solid.trim_by_plane(list(n), d + half)
    return rest, slab


def parting(solid, x, z0=-0.2, z1=0.05, width=0.006):
    """Splits off a parting line printed along the top at x, from z0 to z1."""
    line = Manifold.cube([width, 0.3, z1 - z0]).translate([x - width * 0.5, 0.1, z0])
    return solid - line, solid ^ line


def union(parts):
    from manifold3d import OpType
    parts = [p for p in parts if p is not None and not p.is_empty()]
    return Manifold.batch_boolean(parts, OpType.Add) if parts else Manifold()


# The styles. Each is one shell down over the sides past the ears and down
# the back, its front edge shaped to the style.

def short():
    return {"main": cap(face_line(0.078, -0.025, -0.06))}


def spiky():
    """Three broad spikes with round tips rising from short hair."""
    base = cap(face_line(0.08, -0.02, -0.055), top=0.148)
    spikes = []
    for deg, r, lean, h in ((0.0, 0.05, 0.45, 0.07), (-110.0, 0.07, 0.6, 0.062), (110.0, 0.07, 0.6, 0.062)):
        root = around(r, deg, 0.14)
        d = np.array([0.0, 1.0, 0.0]) + around(lean, deg, 0.0)
        spikes.append(tuft(root, root + d / np.linalg.norm(d) * h, 0.052, 0.024, 12, 8))
    return {"main": base + union(spikes)}


def flat_top():
    return {"main": cap(face_line(0.076, -0.005, -0.04), radius=0.136, top=0.172, dome=0.0, corner=0.022, bulge=0.0)}


def head_surface(direction):
    """Where a line from the middle of the head going this way meets its
    surface."""
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    lo, hi = 0.0, 0.3
    for _ in range(30):
        mid = (lo + hi) * 0.5
        x, y, z = d * mid
        q = np.array([max(math.hypot(x, z) - 0.085, 0.0), max(abs(y) - 0.065, 0.0)])
        inside = math.hypot(*q) <= 0.035 and math.hypot(x, z) <= 0.12 and abs(y) <= 0.1
        lo, hi = (mid, hi) if inside else (lo, mid)
    return d * lo


def mohawk():
    """A low cap over the top with one tall soft ridge from the brow to the
    back."""
    base = cap(0.075, radius=0.128, top=0.14, dome=0.004, corner=0.03, bulge=0.0)
    lobes = []
    for deg, h in ((-34.0, 0.036), (-10.0, 0.064), (20.0, 0.07), (50.0, 0.06), (80.0, 0.042)):
        t = math.radians(deg)
        out = np.array([0.0, math.cos(t), math.sin(t)])
        at = head_surface(out) + out * 0.03
        turn = np.column_stack([[1.0, 0.0, 0.0], np.cross(out, [1.0, 0.0, 0.0]), out])
        lobes.append(blob(at + out * (h * 0.3), (0.026, 0.03, h), 12, turn))
    ridge = union([Manifold.batch_hull([a, b]) for a, b in zip(lobes, lobes[1:])])
    return {"main": base + ridge}


def quiff():
    """Short at the sides with a big roll swept up off the brow."""
    base = cap(face_line(0.086, -0.02, -0.06), radius=0.136, top=0.146)
    roll = lobe((0.0, 0.158, -0.082), (0.078, 0.042, 0.06), (0.0, 0.55, -1.0))
    return {"main": base + roll}


def side_part():
    """Parted on the right and swept over to the left in one big wave."""
    line = lambda a: curve([(-180.0, -0.06), (-90.0, -0.03), (-62.0, 0.068), (-30.0, 0.07), (0.0, 0.074), (40.0, 0.088), (62.0, 0.088), (90.0, -0.02), (180.0, -0.06)], a)
    base = cap(line, top=0.148, extra=(-66.0, -62.0, -58.0, 58.0, 62.0, 66.0))
    sweep = Manifold.batch_hull([blob((0.055, 0.156, -0.05), (0.045, 0.024, 0.05), 12), blob((-0.07, 0.114, -0.09), (0.06, 0.03, 0.05), 12)])
    main, part = parting(base + sweep, 0.048, -0.15, -0.032)
    return {"main": main, "dark": part}


def bob():
    line = face_line(0.076, -0.09, -0.095)
    return {"main": cap(line, radius=lambda a: curve([(0.0, 0.138), (90.0, 0.144), (180.0, 0.146)], a), bulge=0.005, extra=DROP)}


def long_hair():
    line = face_line(0.09, LOWEST, LOWEST, 78.0)
    base = cap(line, radius=lambda a: curve([(0.0, 0.138), (90.0, 0.148), (180.0, 0.15)], a), bulge=0.008, extra=DROP)
    main, part = parting(base, 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


def wavy(low_back=False):
    """With `low_back` the waves in the edge stop behind the ears and it
    stays low round the back, over the top of long hair's length."""
    line = lambda a: face_line(0.088, LOWEST + 0.012, LOWEST + 0.012, 78.0)(a) - (0.012 * (0.5 + 0.5 * math.cos(math.radians(math.degrees(abs(a)) * 7.0))) if abs(a) > math.radians(80.0) else 0.0)
    if low_back:
        waved = line
        fade = lambda a: curve([(0.0, 0.0), (100.0, 0.0), (115.0, 1.0), (180.0, 1.0)], a)
        line = lambda a: waved(a) + (LOWEST - waved(a)) * fade(a)
    out = lambda a: curve([(0.0, 0.138), (90.0, 0.148), (180.0, 0.15)], a) + (0.006 * math.cos(math.radians(math.degrees(abs(a)) * 7.0)) if abs(a) > math.radians(80.0) else 0.0)
    base = cap(line, radius=out, bulge=0.006, extra=DROP, step=12.0)
    return {"main": base}


def ponytail():
    """Pulled back tight from a high hairline into a tail."""
    base = cap(face_line(0.092, -0.025, -0.04), radius=0.134, top=0.144, bulge=0.0)
    pts = [(0.0, 0.06, 0.13), (0.0, 0.02, 0.19), (0.0, -0.04, 0.215), (0.0, -0.08, 0.205)]
    tail = chain(pts, [0.036, 0.042, 0.036, 0.022])
    tail, tie = band(tail, np.array(pts[0]) + np.array([0.0, -0.012, 0.022]), (0.0, -0.5, 1.0), 0.008)
    return {"main": base + tail, "dark": tie}


def pigtails():
    """Two bunches tied high on the sides of the crown, sticking up and out."""
    base = cap(face_line(0.08, -0.02, -0.05))
    main, part = parting(base, 0.0, -0.2, 0.15)
    tails, ties = [], []
    for s in (-1.0, 1.0):
        pts = [np.array([0.1 * s, 0.14, 0.02]), np.array([0.145 * s, 0.17, 0.025]), np.array([0.18 * s, 0.19, 0.03])]
        tail = chain(pts, [0.026, 0.03, 0.02], 10)
        tail, tie = band(tail, pts[0] + np.array([0.012 * s, 0.008, 0.0]), (s, 0.6, 0.0), 0.007)
        tails.append(tail)
        ties.append(tie)
    return {"main": main + union(tails), "dark": union(ties)}


def bun():
    base = cap(face_line(0.084, -0.02, -0.05), radius=0.135, bulge=0.0)
    knot = ball((0.0, 0.195, 0.03), 0.05, SEG)
    knot, tie = band(knot, np.array([0.0, 0.16, 0.03]), (0.0, 1.0, 0.0), 0.007)
    return {"main": base + knot, "dark": tie}


def afro():
    """One big round soft mass, wider than the head all round, with the face
    left open."""
    mass = blob((0.0, 0.09, 0.025), (0.19, 0.15, 0.19), 28)
    corners = [ball((x * s, y, z), 0.016, 10) for s in (-1.0, 1.0) for y in (-0.4, 0.07) for x, z in ((0.126, -0.027), (0.33, -0.19), (0.33, -0.4))]
    return {"main": mass - Manifold.batch_hull(corners)}


def curly():
    base = cap(face_line(0.08, -0.02, -0.055), radius=0.138, dome=0.026)
    curls = []
    for deg, y in ((-40.0, 0.128), (40.0, 0.128), (-130.0, 0.1), (130.0, 0.1)):
        curls.append(ball(around(0.115, deg, y), 0.04, 10))
    return {"main": base + union(curls)}


def bowl():
    """A straight fringe low over the brow and the same edge all round."""
    line = lambda a: curve([(0.0, 0.07), (FACE_ANGLE, 0.07), (90.0, 0.04), (180.0, 0.03)], a)
    return {"main": cap(line, radius=0.15, top=0.15, corner=0.06, lip=0.016, bulge=0.004)}


def messy():
    """Short hair with three broad tufts flopping different ways."""
    base = cap(face_line(0.08, -0.02, -0.05))
    tufts = []
    for x, z, lx, lz, h in ((-0.045, -0.05, -0.06, -0.045, 0.03), (0.04, -0.03, 0.055, -0.02, 0.04), (0.0, 0.06, 0.02, 0.06, 0.04)):
        tufts.append(tuft((x, 0.14, z), (x + lx, 0.14 + h, z + lz), 0.05, 0.024, 10, 8))
    return {"main": base + union(tufts)}


def princess():
    """Long curls: long hair with big round curls at the ends."""
    line = face_line(0.088, -0.07, -0.07, 78.0)
    base = cap(line, radius=lambda a: curve([(0.0, 0.138), (90.0, 0.146), (180.0, 0.148)], a), bulge=0.006, extra=DROP)
    curls = []
    for deg in (-110.0, 180.0, 110.0):
        curls.append(ball(around(0.15, deg, -0.07), 0.034, 8))
    sweep = lobe((0.03, 0.136, -0.06), (0.09, 0.028, 0.06), (-0.4, 0.3, -1.0), 8)
    return {"main": base + union(curls) + sweep}


def braids():
    base = cap(face_line(0.08, -0.02, -0.05))
    main, part = parting(base, 0.0, -0.2, 0.15)
    plaits, ties = [], []
    for s in (-1.0, 1.0):
        at = [around(0.146, 100.0 * s, y) for y in (0.0, -0.035, -0.07)]
        plaits += [ball(p, 0.024, 8) for p in at]
        plaits.append(Manifold.batch_hull([ball(at[0], 0.018, 8), ball(at[-1], 0.018, 8)]))
        tip = around(0.146, 100.0 * s, -0.094)
        ties.append(ball(tip, 0.013, 8))
    return {"main": main + union(plaits), "dark": union(ties)}


def fringe():
    """A long fringe swept across the brow from the right, down past the
    left eye."""
    base = cap(face_line(0.094, -0.025, -0.06), top=0.148)
    fall = chain([around(0.128, 35.0, 0.122), around(0.134, 0.0, 0.11), around(0.134, -35.0, 0.106), around(0.13, -66.0, 0.09)], [0.03, 0.03, 0.028, 0.018], 14)
    return {"main": base + fall}


def messy_side_part():
    """A side parting with the hair swept over in three loose tufts."""
    line = lambda a: curve([(-180.0, -0.06), (-90.0, -0.025), (-62.0, 0.068), (-30.0, 0.07), (0.0, 0.074), (40.0, 0.086), (62.0, 0.086), (90.0, -0.02), (180.0, -0.06)], a)
    base = cap(line, top=0.146, extra=(-66.0, -62.0, -58.0, 58.0, 62.0, 66.0))
    tufts = []
    for x, z, lx, lz, h in ((0.03, -0.07, -0.07, -0.03, 0.022), (0.02, -0.01, -0.085, 0.0, 0.03), (0.0, 0.06, -0.07, 0.04, 0.024)):
        tufts.append(tuft((x, 0.142, z), (x + lx, 0.142 + h, z + lz), 0.046, 0.022, 10, 8))
    main, part = parting(base + union(tufts), 0.05, -0.15, -0.04)
    return {"main": main, "dark": part}


def swept_messy():
    """Short at the back with big tufts swept over the top to one side and
    forward, their tips flicking up."""
    base = cap(face_line(0.084, -0.022, -0.055), top=0.146)
    tufts = []
    for x, z, h in ((0.07, -0.07, 0.012), (0.08, 0.0, 0.016), (0.06, 0.07, 0.01)):
        tufts.append(tuft((x, 0.14, z), (x - 0.17, 0.13 + h, z - 0.03), 0.045, 0.02, 12, 8))
    return {"main": base + union(tufts)}


def slicked_back():
    """Combed straight back off a high hairline, fuller at the back, with
    comb lines printed front to back."""
    base = cap(face_line(0.096, -0.03, -0.065), radius=lambda a: curve([(0.0, 0.134), (90.0, 0.14), (180.0, 0.148)], a), top=lambda a: curve([(0.0, 0.146), (180.0, 0.156)], a), dome=0.01, bulge=0.004)
    roll = lobe((0.0, 0.148, -0.088), (0.07, 0.022, 0.04), (0.0, 0.3, -1.0), 14)
    main, lines = base + roll, []
    for x in (-0.045, 0.045):
        # Starting a little behind the front edge, where the hair is thin and
        # the line's sides would come out in the same place as the hair's.
        main, line = parting(main, x, -0.12, 0.12, 0.005)
        lines.append(line)
    return {"main": main, "dark": union(lines)}


# Long hair. The cap on the head stops at the neck like the rest, and the
# length down the back is its own piece on the upper body (see length()).

def _long_cap(front=0.09, top=0.15, step=18.0):
    line = face_line(front, LOWEST, LOWEST, 78.0)
    return cap(line, radius=lambda a: curve([(0.0, 0.138), (90.0, 0.148), (180.0, 0.15)], a), top=top, lip=0.005, bulge=0.008, extra=DROP, step=step)


def long_straight():
    main, part = parting(_long_cap(), 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


def long_wavy():
    main, part = parting(wavy(True)["main"], 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


def long_swept():
    """Parted on the right, swept over to the left in a big wave."""
    line = lambda a: curve([(-180.0, LOWEST), (-78.0, LOWEST), (-72.0, BEARD_TOP), (-58.0, 0.074), (-30.0, 0.075), (0.0, 0.078), (30.0, 0.086), (58.0, 0.088), (72.0, BEARD_TOP), (78.0, LOWEST), (180.0, LOWEST)], a)
    base = cap(line, radius=lambda a: curve([(0.0, 0.138), (90.0, 0.148), (180.0, 0.15)], a), bulge=0.008, extra=DROP)
    sweep = Manifold.batch_hull([blob((0.055, 0.156, -0.05), (0.045, 0.024, 0.05), 12), blob((-0.075, 0.114, -0.09), (0.06, 0.03, 0.05), 12)])
    main, part = parting(base + sweep, 0.048, -0.15, -0.032)
    return {"main": main, "dark": part}


def long_fringe():
    """A straight fringe low over the brow."""
    line = lambda a: curve([(0.0, 0.073), (FACE_ANGLE, 0.073), (BEARD_ANGLE, BEARD_TOP), (78.0, LOWEST), (180.0, LOWEST)], a)
    base = cap(line, radius=lambda a: curve([(0.0, 0.146), (90.0, 0.15), (180.0, 0.15)], a), corner=0.055, lip=0.014, bulge=0.006, extra=DROP)
    return {"main": base}


def long_curly():
    """Bumpy all round with a scalloped edge, and soft curls on top."""
    # A scallop down each side, the edge low behind where the length is.
    bumps = lambda a: -math.cos(math.radians((min(math.degrees(abs(a)), 98.0) - 72.0) * 6.923)) if abs(a) > math.radians(72.0) else -1.0
    line = lambda a: face_line(0.086, LOWEST + 0.018, LOWEST + 0.018, 78.0)(a) - 0.018 * (0.5 + 0.5 * bumps(a))
    # Bumps out and in round the head, in further behind the ears, where a
    # hand on the wheel comes by as the head turns.
    wide = lambda a: -math.cos(math.radians((min(math.degrees(abs(a)), 150.0) - 72.0) * 6.923)) if abs(a) > math.radians(72.0) else -1.0
    out = lambda a: curve([(0.0, 0.142), (90.0, 0.15), (180.0, 0.152)], a) + 0.005 * (1.0 + wide(a))
    return {"main": cap(line, radius=out, lip=0.006, dome=0.03, bulge=0.01, extra=DROP, step=12.0)}


def low_ponytail():
    """Pulled back from a parting into a tail tied low at the nape."""
    # Down behind the ear to the nape, with a small lip, so no neck shows at
    # the side from behind.
    line = lambda a: curve([(0.0, 0.088), (FACE_ANGLE, 0.088), (BEARD_ANGLE, BEARD_TOP), (78.0, -0.06), (88.0, LOWEST), (180.0, LOWEST)], a)
    base = cap(line, radius=lambda a: curve([(0.0, 0.134), (90.0, 0.138), (180.0, 0.146)], a), top=0.144, lip=0.005, bulge=0.003, extra=DROP)
    main, part = parting(base, 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


STYLES = {
    "short": short,
    "spiky": spiky,
    "flat_top": flat_top,
    "mohawk": mohawk,
    "quiff": quiff,
    "side_part": side_part,
    "bob": bob,
    "long": long_hair,
    "wavy": wavy,
    "ponytail": ponytail,
    "pigtails": pigtails,
    "bun": bun,
    "afro": afro,
    "curly": curly,
    "bowl": bowl,
    "princess": princess,
    "messy": messy,
    "braids": braids,
    "fringe": fringe,
    "messy_side_part": messy_side_part,
    "swept_messy": swept_messy,
    "slicked_back": slicked_back,
    "long_straight": long_straight,
    "long_wavy": long_wavy,
    "long_swept": long_swept,
    "long_fringe": long_fringe,
    "long_curly": long_curly,
    "low_ponytail": low_ponytail,
}


# Long hair under a hat keeps in to CUT_RADIUS down to here.
HUG_Y = -0.06


def cut(regions, long=False):
    """The cut version for under a hat: what's below CUT_Y, kept in to
    CUT_RADIUS over the top CUT_BAND, and sloping out from there, so hair
    wider than that (like an afro) bulges out under the hat's edge. With
    `long` it keeps in much further down (see HUG_Y)."""
    below = Manifold.cube([1.0, 1.0, 1.0]).translate([-0.5, CUT_Y - 1.0, -0.5])
    rim = Manifold.cylinder(CUT_BAND + 0.001, CUT_RADIUS, CUT_RADIUS, 48).rotate([-90.0, 0.0, 0.0]).translate([0.0, CUT_Y - CUT_BAND, 0.0])
    slope = Manifold.cylinder(SLOPE, CUT_RADIUS + SLOPE, CUT_RADIUS, 48).rotate([-90.0, 0.0, 0.0]).translate([0.0, CUT_Y - CUT_BAND - SLOPE, 0.0])
    low = Manifold.cube([1.0, 1.0, 1.0]).translate([-0.5, CUT_Y - CUT_BAND - SLOPE - 1.0 + 0.0005, -0.5])
    keep = below ^ (rim + slope + low)
    if long:
        # Long hair stays in close to the head down to HUG_Y, so the hat
        # reads as sitting on the head, then flares out to meet the length.
        drop = HUG_Y - LOWEST - 0.01
        hug = Manifold.cylinder(CUT_Y - HUG_Y + 0.001, CUT_RADIUS, CUT_RADIUS, 48).rotate([-90.0, 0.0, 0.0]).translate([0.0, HUG_Y, 0.0])
        flare = Manifold.cylinder(drop, CUT_RADIUS + 0.016, CUT_RADIUS, 48).rotate([-90.0, 0.0, 0.0]).translate([0.0, HUG_Y - drop, 0.0])
        under = Manifold.cube([1.0, 1.0, 1.0]).translate([-0.5, HUG_Y - drop - 1.0 + 0.0005, -0.5])
        keep = below ^ (hug + flare + under)
    return {k: v ^ keep for k, v in regions.items()}


def radius_profile(solid, step=0.01):
    """How far out from the middle the hair reaches at heights up the head,
    as [height, radius] pairs, and how high its top is."""
    box = solid.bounding_box()
    out = []
    y = round(math.floor(box[1] / step) * step, 4)
    while y <= box[4]:
        polys = _slice_y(solid, y)
        if polys:
            r = max(math.hypot(p[0], p[1]) for poly in polys for p in poly)
            out.append([round(y, 4), round(r, 4)])
        y = round(y + step, 4)
    return out, round(float(box[4]), 4)


def _slice_y(solid, y):
    # Manifold slices across z, so turn y up to z first.
    turned = solid.rotate([90.0, 0.0, 0.0])
    # After turning, a point (x, y, z) is at (x, -z, y).
    return [list(map(tuple, p)) for p in turned.slice(y).to_polygons()]


# The length of long hair, below the neck down the back. It's on the upper
# body, so it doesn't turn with the head, made for each pose like the back
# pieces: hanging down the back standing, shorter and close to the back in
# front of the seat's back seated, shorter still lying back, and hanging
# back a little astride. It comes up to the cap's lower edge (LOWEST) round
# the back of the head, with its top tucked up inside the cap (see length()),
# and keeps clear of what's worn round the neck. In the upper body's space,
# in metres.

LENGTH_POSES = ("standing", "seated", "reclined", "astride")
# The cap's lower edge in the upper body's space, and how far round the
# middle of the head the top of the length curves.
NAPE_Y = F.HEAD_Y + LOWEST * F.HEAD_SCALE - GAP
NAPE_R = 0.166
# How far the top of the length tucks up inside the cap, so no gap shows
# between them as the head turns.
TUCK = 0.012
# The tuck keeps this far inside the cap's outside, and inside it as the
# head turns this far either way (radians). Turned further, as when looking
# right round, the ends of the tuck show under the cheek.
TUCK_IN = 0.003
TUCK_TURN = 0.8

# The middle of the length from the nape down, as (y, z), for each pose.
# Standing it hangs down the back to below the shoulder blades. Seated it
# lies down the back in front of the seat's back (ROOM in backs.py), shorter
# and close to the back, and lying back it's shorter still. Astride it hangs
# back a little as the body leans forward.
PATHS = {
    "standing": [(NAPE_Y, NAPE_R), (0.43, 0.166), (0.41, 0.158), (0.385, 0.146), (0.35, 0.135), (0.31, 0.13), (0.27, 0.128), (0.23, 0.127)],
    "seated": [(NAPE_Y, NAPE_R), (0.43, 0.165), (0.41, 0.156), (0.385, 0.143), (0.355, 0.132), (0.325, 0.128), (0.295, 0.127)],
    "reclined": [(NAPE_Y, NAPE_R), (0.43, 0.164), (0.41, 0.154), (0.39, 0.141), (0.365, 0.131), (0.34, 0.128), (0.32, 0.127)],
    "astride": [(NAPE_Y, NAPE_R), (0.43, 0.164), (0.41, 0.157), (0.385, 0.152), (0.35, 0.15), (0.31, 0.152), (0.27, 0.157)],
}


def along(points):
    """A value along the length, smooth through (s, value) points."""
    return lambda s: curve([(p * 180.0, v) for p, v in points], math.radians(min(max(s, 0.0), 1.0) * 180.0))


def _resample(points, count):
    """`count` points evenly along a smooth curve through the points."""
    p = [np.asarray(q, float) for q in points]
    dense = []
    for i in range(len(p) - 1):
        a, b = p[max(i - 1, 0)], p[i]
        c, d = p[i + 1], p[min(i + 2, len(p) - 1)]
        for k in range(12):
            t = k / 12.0
            dense.append(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t ** 3))
    dense.append(p[-1])
    steps = [0.0] + list(np.cumsum([np.linalg.norm(q1 - q0) for q0, q1 in zip(dense, dense[1:])]))
    total = steps[-1]
    out = []
    for k in range(count):
        want = total * k / (count - 1)
        i = min(np.searchsorted(steps, want), len(dense) - 1)
        if i == 0:
            out.append(dense[0])
            continue
        t = (want - steps[i - 1]) / max(steps[i] - steps[i - 1], 1e-12)
        out.append(dense[i - 1] * (1 - t) + dense[i] * t)
    return out


def strand(path, width, thick, arc=lambda s: 0.0, outer=lambda u, s: 0.0, hem=lambda u: 0.0, shift=lambda s: 0.0, sag=lambda s: 0.0, rings=14, across=13, inside=9, soft=0.022):
    """A soft flat length of hair down a path of (y, z) points from the
    nape, as one mesh. Along it, s goes from 0 at the top to 1 at the hem;
    across, u from -1 to 1. `width` and `thick` give its half width and half
    thickness at s, `arc` how much it curves round the head there (1 round
    NAPE_R, 0 flat, its edges brought forward by `sag`), `shift` moves it to
    the side, `outer` raises its outside
    (waves, curls; 0 at the edges) and `hem` makes it longer at u. The hem is
    rounded off over `soft`."""
    pts = _resample([(0.0, y, z) for y, z in path], rings)
    frames = []
    for i, p in enumerate(pts):
        t = pts[min(i + 1, rings - 1)] - pts[max(i - 1, 0)]
        t /= np.linalg.norm(t)
        n = np.array([0.0, t[2], -t[1]])
        n /= np.linalg.norm(n)
        frames.append((p, t, n, i / (rings - 1)))
    # Rounding off the hem: more rings past the end, thinner and narrower.
    p, t, n, _ = frames[-1]
    ends = [(p + t * soft * 0.55, t, n, 1.0, 0.92, 0.72), (p + t * soft, t, n, 1.0, 0.82, 0.32)]
    frames = [f + (1.0, 1.0) for f in frames] + ends
    x_axis = np.array([1.0, 0.0, 0.0])
    edge = [math.radians(a) for a in (45.0, 90.0, 135.0)]
    out_u = [-1.0 + 2.0 * k / (across - 1) for k in range(across)]
    in_u = [1.0 - 2.0 * k / (inside - 1) for k in range(inside)]
    grid = []
    for p, t, n, s, wide, deep in frames:
        hw, ht, a, dx, dip = width(s) * wide, thick(s) * deep, arc(s), shift(s), sag(s)
        theta = math.asin(min(hw / NAPE_R, 0.95))

        # It curves round the head across, level, whichever way the path
        # goes.
        back = np.array([0.0, 0.0, 1.0])

        def centre(u):
            flat = x_axis * (hw * u + dx) - back * dip * u * u
            bent = x_axis * (NAPE_R * math.sin(theta * u) + dx) + back * (NAPE_R * math.cos(theta * u) - NAPE_R)
            return p + flat * (1.0 - a) + bent * a

        def frame(u):
            d = centre(min(u + 0.01, 1.0)) - centre(max(u - 0.01, -1.0))
            d /= np.linalg.norm(d)
            m = np.cross(d, t)
            m /= np.linalg.norm(m)
            return d, (m if m.dot(n) > 0.0 else -m)

        def longer(u):
            return t * (hem(u) * (1.0 if s >= 1.0 else 0.0))

        ring = []
        for u in out_u:
            d, m = frame(u)
            ring.append(centre(u) + m * (ht + outer(u, s) * deep) + longer(u))
        d, m = frame(1.0)
        for e in edge:
            ring.append(centre(1.0) + (m * math.cos(e) + d * math.sin(e)) * ht + longer(1.0))
        for u in in_u:
            d, m = frame(u)
            ring.append(centre(u) - m * ht + longer(u))
        d, m = frame(-1.0)
        for e in edge:
            ring.append(centre(-1.0) + (-m * math.cos(e) - d * math.sin(e)) * ht + longer(-1.0))
        grid.append(ring)
    from shapes import from_grid
    # Kept under the cap's lower edge.
    return from_grid(grid, False).trim_by_plane([0.0, -1.0, 0.0], -NAPE_Y)


def _ridges(count, depth):
    """Broad moulded locks down the outside, `count` across."""
    return lambda u, s: depth * (1.0 - abs(u) ** 4) * (0.5 + 0.5 * math.cos(math.pi * u * count))


def _scallops(count, depth):
    return lambda u: depth * (0.5 + 0.5 * math.cos(math.pi * u * count))


# How wide the length is along it: as wide as the head at the top, a little
# narrower at the neck, out over the shoulder blades and in again at the hem.
WIDTH = along([(0.0, 0.152), (0.14, 0.14), (0.5, 0.15), (0.85, 0.146), (1.0, 0.13)])


def _sheet(pose, outer=lambda u, s: 0.0, hem=lambda u: 0.0, wide=lambda s: 0.0, **kw):
    """The usual length: round the head at the top, then down the back,
    rounded across like a mass of hair, its sides lying forward over the
    shoulders, longer in the middle at the hem. `outer` adds the style's
    locks, waves or curls, `hem` its ends."""
    base = dict(
        width=lambda s: WIDTH(s) + wide(s),
        # Thinner at the top, its outside in line with the cap's, so the
        # cap's lower edge sits over it.
        thick=along([(0.0, 0.0095), (0.1, 0.0145), (0.3, 0.017), (1.0, 0.014)]),
        arc=along([(0.0, 1.0), (0.2, 0.55), (0.45, 0.25), (1.0, 0.2)]),
        sag=along([(0.0, 0.0), (0.1, 0.0), (0.25, 0.025), (0.45, 0.018), (1.0, 0.012)]),
        outer=lambda u, s: (0.009 * (1.0 - u * u) * min(1.0, s * 4.0) + outer(u, s)) * min(1.0, 0.2 + s * 6.0),
        hem=lambda u: 0.03 * (1.0 - u * u) + hem(u),
    )
    base.update(kw)
    return strand(PATHS[pose], **base)


def length_long_straight(pose):
    return {"main": _sheet(pose, outer=_ridges(4, 0.005), hem=_scallops(4, 0.008), across=17)}


def length_long_wavy(pose):
    # Waves down the length, rolling in and out across it.
    sway = lambda s: 0.14 * math.sin(s * math.pi * 2.0)
    waves = lambda u, s: 0.01 * (1.0 - abs(u) ** 4) * (0.5 + 0.5 * math.cos(math.pi * (u + sway(s)) * 3.0))
    return {"main": _sheet(pose, outer=waves, hem=lambda u: 0.014 * (0.5 + 0.5 * math.cos(math.pi * (u + sway(1.0)) * 3.0)), wide=lambda s: 0.006 * math.sin(s * math.pi * 4.0) * s, rings=16, across=21, inside=7)}


def length_long_swept(pose):
    # Longer on the left, where it's swept over to.
    return {"main": _sheet(pose, outer=_ridges(3, 0.005), hem=lambda u: 0.022 * (0.5 - 0.5 * u) + _scallops(3, 0.005)(u), shift=lambda s: -0.008 * s, across=15)}


def length_long_fringe(pose):
    return {"main": _sheet(pose, outer=_ridges(5, 0.003), hem=lambda u: -0.02 * (1.0 - u * u) + 0.004, across=17)}


def length_long_curly(pose):
    # Three columns of round curls down it, bumpy at the edges, ending in a
    # row of bigger curls.
    curls_at = lambda u, s: 0.5 + 0.5 * math.cos(s * math.pi * 7.0 + (math.pi if abs(u) < 0.34 else 0.0))
    locks = lambda u, s: 0.012 * (1.0 - abs(u) ** 4) * (0.5 + 0.5 * math.cos(math.pi * u * 3.0)) * (0.35 + 0.65 * curls_at(u, s)) * min(1.0, s * 6.0)
    sheet = _sheet(pose, outer=locks, wide=lambda s: 0.008 * curls_at(1.0, s) * min(1.0, s * 4.0), hem=lambda u: -0.02 * (1.0 - u * u), rings=15, across=11, inside=7)
    p = _resample([(0.0, y, z) for y, z in PATHS[pose]], 14)
    t = p[-1] - p[-2]
    t /= np.linalg.norm(t)
    n = np.array([0.0, t[2], -t[1]])
    curls = [ball(p[-1] + np.array([0.085 * u, 0.0, 0.0]) + n * (0.016 - 0.008 * abs(u)) - np.array([0.0, 0.0, 0.012 * abs(u)]) - t * 0.002, 0.034, 9) for u in (-1.0, 0.0, 1.0)]
    return {"main": sheet + union(curls)}


def _pushed(path, by):
    """The path moved out from the back by `by`, all but its top."""
    out = [path[0]]
    for i in range(1, len(path)):
        (y0, z0), (y1, z1) = path[i - 1], path[min(i + 1, len(path) - 1)]
        ty, tz = y1 - y0, z1 - z0
        k = by * min(1.0, i / 2.0) / math.hypot(ty, tz)
        out.append((path[i][0] + tz * k, path[i][1] - ty * k))
    return out


def length_low_ponytail(pose):
    """A round tail from a tie at the nape."""
    path = _pushed(PATHS[pose], 0.019)
    tail = strand(path, width=lambda s: curve([(0.0, 0.034), (25.0, 0.03), (45.0, 0.04), (110.0, 0.044), (180.0, 0.028)], math.radians(s * 180.0)),
                  thick=lambda s: curve([(0.0, 0.024), (25.0, 0.022), (45.0, 0.035), (110.0, 0.036), (180.0, 0.024)], math.radians(s * 180.0)), across=9, rings=14, soft=0.03)
    p = _resample([(0.0, y, z) for y, z in path], 14)
    tail, tie = band(tail, p[2], p[3] - p[2], 0.008)
    return {"main": tail, "dark": tie}


LENGTHS = {
    "long_straight": length_long_straight,
    "long_wavy": length_long_wavy,
    "long_swept": length_long_swept,
    "long_fringe": length_long_fringe,
    "long_curly": length_long_curly,
    "low_ponytail": length_low_ponytail,
}


def _section(solid, y):
    """The solid's section across it at height y, as (x, -z)."""
    return solid.rotate([90.0, 0.0, 0.0]).slice(y)


def length(style):
    """A long style's length in every pose, {pose: regions}. Its top is
    carried straight up TUCK inside the cap, kept TUCK_IN inside the cap's
    solid as the head turns up to TUCK_TURN, so no gap shows between them."""
    cap = union(list(STYLES[style]().values())).scale([F.HEAD_SCALE] * 3).translate([0.0, F.HEAD_Y, 0.0])
    shrink = 1.0 - TUCK_IN / NAPE_R
    most = TUCK_TURN
    # Where the cap is solid all the way up the tuck, as the head turns.
    inside = None
    for y in (NAPE_Y + GAP + 0.0005, NAPE_Y + GAP + 0.005, NAPE_Y + TUCK):
        at = _section(cap, y).scale([shrink, shrink])
        for k in range(-3, 4):
            turned = at.rotate(math.degrees(most) * k / 3.0)
            inside = turned if inside is None else inside ^ turned
    inside = inside.simplify(0.0005)
    low = NAPE_Y - 0.004
    out = {}
    for pose in LENGTH_POSES:
        regions = {}
        for k, v in LENGTHS[style](pose).items():
            # Up from just under the top, across the gap under the cap.
            tuck = _section(v, low) ^ inside
            if not tuck.is_empty():
                v = v + Manifold.extrude(tuck, NAPE_Y + TUCK - low).rotate([-90.0, 0.0, 0.0]).translate([0.0, low, 0.0])
            regions[k] = v
        out[pose] = regions
    return out
