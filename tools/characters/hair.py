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

Long hair (the long styles at the end) comes down past LOWEST: bobs round
the turn axis to about the shoulders, and drapes that hang down the back,
made for each pose to keep clear of the body, arms and seat as the head
turns up to DRAPE_TURN either way.
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


def cap(bottom, radius=0.138, top=0.15, dome=0.012, lip=0.009, corner=0.05, bulge=0.003, extra=(), step=18.0, flare=0.0, flare_at=0.78, sides=3):
    """The cap over the head, hollow inside: its lower edge at `bottom` (a
    number or a function of the angle round the head, 0 at the front),
    `radius` out at the sides, flat-ish on top at `top` rising by `dome` in
    the middle, with a rounded lip and top corner. The top and the corner can
    change round the head too. `bulge` pushes the sides
    out between them, and `flare` in a soft roll `flare_at` of the way down
    the side, turning back in under it like a bob, over `sides` points down
    the side. `extra` adds sections
    at these angles (degrees), where the edge drops."""
    bottom, radius, bulge, top_at, corner_at, flare_of = _value(bottom), _value(radius), _value(bulge), _value(top), _value(corner), _value(flare)
    outline = head_outline(INSIDE)

    def profile(a):
        b, r, g, top, corner, f = bottom(a), radius(a), bulge(a), top_at(a), corner_at(a), flare_of(a)
        # Up the inside from the lower edge, over the head to the middle.
        roll = lambda t: f * math.exp(-((t - flare_at) / 0.16) ** 2)
        pts = _inside(outline, b, r + roll(1.0) - lip)
        # Then from the middle of the top out and down the outside.
        inner = r - corner
        for k in range(3):
            u = inner * k / 3
            pts.append((max(u, 0.002), top + dome * (1.0 - (u / inner) ** 2)))
        for k in range(3):
            t = math.radians(90.0 - 90.0 * k / 2)
            pts.append((r - corner + corner * math.cos(t), top - corner + corner * math.sin(t)))
        # Down the side, bowed out by the bulge and flared out at the bottom.
        for k in range(1, sides + 1):
            t = k / (sides + 1)
            pts.append((r + g * math.sin(math.pi * t) + roll(t), top - corner + (b + lip - top + corner) * t))
        for k in range(3):
            t = math.radians(0.0 - 90.0 * k / 2)
            pts.append((r + roll(1.0) - lip + lip * math.cos(t), b + lip + lip * math.sin(t)))
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
    stays low round the back, for the short version of long hair."""
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


# Long hair, each style one piece on the head that turns with it. Curly and
# wavy are a full bob below the ears down to just over the shoulders, round
# about the neck and inside where the arms reach raised high, so turning the
# head only spins them in place. Straight, swept and fringe drape over the shoulders and down the
# back (drape()), and the low ponytail's tail hangs down the back, so those
# are made for each pose and the head turns no more than DRAPE_TURN with
# them. Each also has a short version (SHORT), the cap down to LOWEST like
# the other hair, worn with what the long one doesn't fit with.

# The bell's lower edge and where a drape rests on the shoulders, just over
# the top of the torso (0.42 m up in the upper body's space).
BELL_Y = -0.1208
# How far the head turns either way with a drape or tail on (radians).
DRAPE_TURN = 0.5
# A drape's hem standing, down to the shoulder blades (0.31 m up in the
# upper body's space).
DRAPE_HEM = -0.2167


def _ramp(x, x0, x1):
    """0 at x0 to 1 at x1, eased, either way round."""
    t = min(max((x - x0) / (x1 - x0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def _long_cap(front=0.09, top=0.15, step=18.0):
    line = face_line(front, LOWEST, LOWEST, 78.0)
    return cap(line, radius=_LONG_R, top=top, lip=0.005, bulge=0.008, extra=DROP, step=step)


def _LONG_R(a):
    return curve([(0.0, 0.138), (90.0, 0.148), (180.0, 0.15)], a)


def drape(r_cap, hem=DRAPE_HEM, back_out=lambda phi: 0.13 + 0.05 * (phi / 40.0) ** 2, side_flare=-0.004, inner=0.1, hem_at=lambda a: 0.0, locks=lambda a: 0.0, start=80.0, full=104.0, limits=None):
    """The hair below the cap from behind the ears round the back, in the
    head's own space: resting on the shoulders at the sides (BELL_Y, flared
    out by `side_flare`) and hanging down the back to `hem` (moved by
    `hem_at(a)`), its outside `back_out(phi)` from the middle, phi degrees
    from straight behind. It comes out from under the cap from `start` to
    `full` degrees from the front. `locks(a)` raises the outside below the
    cap into moulded locks. Its inside is `inner` round the neck.

    `limits(a, y)`, if given, is how far in and out from the middle it can
    reach at a degrees round and height y, (inside, outside), so it keeps
    clear of the body, arms and seat as the head turns. Where that leaves it
    thinner than THIN, its hem comes up."""
    def inside(a, y):
        r = inner if y < -0.1 else 0.09
        return max(r, limits(a, y)[0]) if limits else r

    def outer(a, y):
        phi = 180.0 - abs(a)
        g = _ramp(abs(a), start, full)
        rc = r_cap(math.radians(a))
        hang = _ramp(phi, 75.0, 40.0)
        if y >= -0.1:
            r = rc - 0.003 + 0.009 * ((-0.04 - y) / 0.06) ** 2
        else:
            u = _ramp(-0.1 - y, 0.0, 0.045)
            want = (1.0 - hang) * side_flare + hang * (back_out(phi) - rc - 0.006)
            r = rc + 0.006 + want * u + locks(a) * _ramp(-0.1 - y, 0.0, 0.03)
        r = rc - 0.003 + (r - (rc - 0.003)) * g
        return min(r, limits(a, y)[1]) if limits else r

    def wanted_hem(a):
        phi = 180.0 - abs(a)
        b = BELL_Y + (hem + hem_at(a) - BELL_Y) * _ramp(phi, 75.0, 40.0)
        return -0.1 + (b + 0.1) * _ramp(abs(a), start, full)

    # How low it can come at each degree round: down to where it would be
    # too thin, then widened a little each way, so the hem is a smooth curve
    # that stays above that everywhere.
    lowest = {}
    for d in range(int(start), int(360 - start) + 1):
        a = d if d <= 180 else d - 360
        b = wanted_hem(a)
        y = -0.1
        while limits and y > b:
            if outer(a, y - 0.002) - inside(a, y - 0.002) < THIN:
                b = y
                break
            y -= 0.002
        lowest[d] = b
    keys = sorted(lowest)
    held = {d: max(lowest[k] for k in keys if abs(k - d) <= 8) for d in keys}
    # Down the back it hangs in a rounded tongue between the shoulder
    # blades, as low as it can go and still be above that.
    def s_of(d):
        phi = 180.0 - abs(d if d <= 180 else d - 360)
        t = min(1.0, max(0.0, (phi - 4.0) / 24.0))
        return t * t * (3.0 - 2.0 * t)
    low = max([min(held.values())] + [(held[d] - BELL_Y * s_of(d)) / (1.0 - s_of(d)) for d in keys if s_of(d) < 0.98 and held[d] < BELL_Y - 0.002])
    eased = {d: max(held[d], low + (BELL_Y - low) * s_of(d)) for d in keys}
    for wide in (8,):
        eased = {d: max(held[d], sum(eased[k] for k in keys if abs(k - d) <= wide) / len([k for k in keys if abs(k - d) <= wide])) for d in keys}

    angles = sorted(set([start + (360.0 - 2.0 * start) * k / 24 for k in range(25)] + [180.0]))
    rings = []
    for deg in angles:
        a = deg if deg <= 180.0 else deg - 360.0
        d = min(max(int(round(deg)), keys[0]), keys[-1])
        b = eased[d]
        top = -0.04
        ys = [top + (b - top) * k / 9 for k in range(10)]
        ro = outer(a, b)
        ri = inside(a, b)
        rho = max(0.001, min(0.012, (ro - ri) * 0.45, (top - b) / 9 * 0.9))
        prof = [(outer(a, y), y) for y in ys[:-1]]
        # The hem, rounded at the outside and the inside.
        for k in range(4):
            t = math.radians(-90.0 * k / 3)
            prof.append((ro - rho + rho * math.cos(t), b + rho + rho * math.sin(t)))
        for k in range(4):
            t = math.radians(-90.0 - 90.0 * k / 3)
            prof.append((ri + rho + rho * math.cos(t), b + rho + rho * math.sin(t)))
        for y in reversed(ys[1:-1]):
            prof.append((inside(a, y), y))
        prof.append((0.09, top))
        t = math.radians(a)
        rings.append([(r * math.sin(t), y, -r * math.cos(t)) for r, y in prof])
    from shapes import from_grid
    return from_grid(rings, False)


# The thinnest a drape gets before its hem comes up.
THIN = 0.012


def _locks(count, depth):
    """Broad moulded locks round the back, `count` across the back half."""
    return lambda a: depth * (0.5 + 0.5 * math.cos(math.radians(abs(a)) * count * 2.0))


def long_straight(limits=None):
    main, part = parting(_long_cap() + drape(_LONG_R, locks=_locks(4, 0.004), hem_at=lambda a: -0.008 * (1.0 - min(1.0, ((180.0 - abs(a)) / 40.0) ** 2)), limits=limits), 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


def long_swept(limits=None):
    """Parted on the right, swept over to the left in a big wave, the back
    longer on the left."""
    line = lambda a: curve([(-180.0, LOWEST), (-78.0, LOWEST), (-72.0, BEARD_TOP), (-58.0, 0.074), (-30.0, 0.075), (0.0, 0.078), (30.0, 0.086), (58.0, 0.088), (72.0, BEARD_TOP), (78.0, LOWEST), (180.0, LOWEST)], a)
    base = cap(line, radius=_LONG_R, lip=0.005, bulge=0.008, extra=DROP)
    sweep = Manifold.batch_hull([blob((0.055, 0.156, -0.05), (0.045, 0.024, 0.05), 12), blob((-0.075, 0.114, -0.09), (0.06, 0.03, 0.05), 12)])
    hang = drape(_LONG_R, locks=_locks(3, 0.004), hem_at=lambda a: 0.014 * math.sin(math.radians(a)), limits=limits)
    main, part = parting(base + sweep + hang, 0.048, -0.15, -0.032)
    return {"main": main, "dark": part}


def long_fringe(limits=None):
    """A straight fringe low over the brow and a blunt cut hem."""
    line = lambda a: curve([(0.0, 0.073), (FACE_ANGLE, 0.073), (BEARD_ANGLE, BEARD_TOP), (78.0, LOWEST), (180.0, LOWEST)], a)
    radius = lambda a: curve([(0.0, 0.146), (90.0, 0.15), (180.0, 0.15)], a)
    base = cap(line, radius=radius, corner=0.055, lip=0.005, bulge=0.006, extra=DROP)
    return {"main": base + drape(radius, hem=DRAPE_HEM + 0.008, locks=_locks(5, 0.002), limits=limits)}


def long_wavy():
    """Waves all round, a full rounded bob down to just over the shoulders,
    turned in at the ends to keep inside the arms raised high."""
    wave = lambda a: 0.5 + 0.5 * math.cos(math.radians(abs(math.degrees(a))) * 7.0) if abs(a) > math.radians(80.0) else 0.0
    line = lambda a: face_line(0.088, BELL_Y + 0.007, BELL_Y + 0.007, 78.0)(a) - 0.007 * wave(a)
    out = lambda a: _LONG_R(a) - 0.003 + 0.003 * (2.0 * wave(a) - 1.0) * _ramp(abs(math.degrees(a)), 80.0, 90.0)
    flare = lambda a: 0.016 * _ramp(abs(math.degrees(a)), 72.0, 100.0)
    base = cap(line, radius=out, lip=0.006, bulge=0.006, flare=flare, extra=DROP, step=8.0, sides=7)
    main, part = parting(base, 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


def long_curly():
    """Bumpy all round with a scalloped edge and soft curls on top, a full
    rounded bob down to just over the shoulders."""
    bumps = lambda a: -math.cos(math.radians((math.degrees(abs(a)) - 72.0) * 6.923)) if abs(a) > math.radians(72.0) else -1.0
    line = lambda a: face_line(0.086, BELL_Y + 0.012, BELL_Y + 0.012, 78.0)(a) - 0.012 * (0.5 + 0.5 * bumps(a))
    out = lambda a: curve([(0.0, 0.142), (90.0, 0.145), (180.0, 0.147)], a) + 0.0025 * (1.0 + bumps(a)) * _ramp(abs(math.degrees(a)), 72.0, 80.0)
    flare = lambda a: 0.016 * _ramp(abs(math.degrees(a)), 72.0, 100.0)
    return {"main": cap(line, radius=out, lip=0.006, dome=0.03, bulge=0.01, flare=flare, extra=DROP, step=6.0, sides=7)}


# The low ponytail's tail, from a tie at the nape down the back, as points
# and radii in the upper body's space (metres).
TAIL = [((0.0, 0.452, 0.168), 0.027), ((0.0, 0.425, 0.163), 0.03), ((0.0, 0.39, 0.157), 0.036), ((0.0, 0.35, 0.155), 0.036), ((0.0, 0.318, 0.156), 0.025)]


def low_ponytail(limits=None):
    """Pulled back from a parting into a tail tied low at the nape, hanging
    down the back."""
    main, part = parting(_short_low_ponytail(), 0.0, -0.2, -0.02)
    pts = [np.array([x, (y - F.HEAD_Y) / F.HEAD_SCALE, z / F.HEAD_SCALE]) for (x, y, z), _ in TAIL]
    tail = chain(pts, [r / F.HEAD_SCALE for _, r in TAIL], 14)
    tail, tie = band(tail, pts[0] + (pts[1] - pts[0]) * 0.75, pts[1] - pts[0], 0.007)
    return {"main": main + tail, "dark": tie}


# The short versions, the cap down to LOWEST.

def _short_long_straight():
    main, part = parting(_long_cap(), 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


def _short_long_wavy():
    main, part = parting(wavy(True)["main"], 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


def _short_long_swept():
    line = lambda a: curve([(-180.0, LOWEST), (-78.0, LOWEST), (-72.0, BEARD_TOP), (-58.0, 0.074), (-30.0, 0.075), (0.0, 0.078), (30.0, 0.086), (58.0, 0.088), (72.0, BEARD_TOP), (78.0, LOWEST), (180.0, LOWEST)], a)
    base = cap(line, radius=_LONG_R, bulge=0.008, extra=DROP)
    sweep = Manifold.batch_hull([blob((0.055, 0.156, -0.05), (0.045, 0.024, 0.05), 12), blob((-0.075, 0.114, -0.09), (0.06, 0.03, 0.05), 12)])
    main, part = parting(base + sweep, 0.048, -0.15, -0.032)
    return {"main": main, "dark": part}


def _short_long_fringe():
    line = lambda a: curve([(0.0, 0.073), (FACE_ANGLE, 0.073), (BEARD_ANGLE, BEARD_TOP), (78.0, LOWEST), (180.0, LOWEST)], a)
    base = cap(line, radius=lambda a: curve([(0.0, 0.146), (90.0, 0.15), (180.0, 0.15)], a), corner=0.055, lip=0.014, bulge=0.006, extra=DROP)
    return {"main": base}


def _short_long_curly():
    bumps = lambda a: -math.cos(math.radians((min(math.degrees(abs(a)), 98.0) - 72.0) * 6.923)) if abs(a) > math.radians(72.0) else -1.0
    line = lambda a: face_line(0.086, LOWEST + 0.018, LOWEST + 0.018, 78.0)(a) - 0.018 * (0.5 + 0.5 * bumps(a))
    wide = lambda a: -math.cos(math.radians((min(math.degrees(abs(a)), 150.0) - 72.0) * 6.923)) if abs(a) > math.radians(72.0) else -1.0
    out = lambda a: curve([(0.0, 0.142), (90.0, 0.15), (180.0, 0.152)], a) + 0.005 * (1.0 + wide(a))
    return {"main": cap(line, radius=out, lip=0.006, dome=0.03, bulge=0.01, extra=DROP, step=12.0)}


def _short_low_ponytail():
    # Down behind the ear to the nape, with a small lip, so no neck shows at
    # the side from behind.
    line = lambda a: curve([(0.0, 0.088), (FACE_ANGLE, 0.088), (BEARD_ANGLE, BEARD_TOP), (78.0, -0.06), (88.0, LOWEST), (180.0, LOWEST)], a)
    return cap(line, radius=lambda a: curve([(0.0, 0.134), (90.0, 0.138), (180.0, 0.146)], a), top=0.144, lip=0.005, bulge=0.003, extra=DROP)


def _short_low_ponytail_regions():
    main, part = parting(_short_low_ponytail(), 0.0, -0.2, -0.02)
    return {"main": main, "dark": part}


SHORT = {
    "long_straight": _short_long_straight,
    "long_wavy": _short_long_wavy,
    "long_swept": _short_long_swept,
    "long_fringe": _short_long_fringe,
    "long_curly": _short_long_curly,
    "low_ponytail": _short_low_ponytail_regions,
}
# The long styles that hang down the back, made for each pose, with the
# smaller head turn.
DRAPES = ("long_straight", "long_swept", "long_fringe", "low_ponytail")
POSES = ("standing", "seated", "reclined", "astride")
# Under a helmet, what's below this shows.
BELOW_Y = LOWEST


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
        # reads as sitting on the head, then flares out to meet the hair below.
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


