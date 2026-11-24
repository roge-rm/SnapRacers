"""Headgear, one function a piece, like moulded toy hats and helmets: one or
a few chunky smooth shapes, with bands, spots and the like as flat colour
regions. Each gives its solids by colour region in the head's own space
(before it's scaled up by HEAD_SCALE), before they're cut back from the
head and the stud.

What each does with the hair is in HAIR:
- "cut": a hat that covers the top of the head. The hair under it is its
  cut version (see hair.py), and the hat comes down to CUT_Y or lower all
  the way round where that has hair, fitting over CUT_RADIUS, so the cut
  edge is hidden. In front it stays above the brows.
- "hidden": a helmet or hood that comes down over the sides and back like
  hair does. No hair is shown under it.
- "full": something worn on the hair, like a headband. It's made to fit the
  bare head, and FIT says how it's grown or lifted to sit on each hairdo.
"""

import math

import numpy as np
from manifold3d import Manifold

import hair as H
from hair import around, face_line, lobe, tuft, union
from shapes import angles_round, ball, blob, curve, lathe_at, rounded_rect, tube

R0 = H.R0
# The hat's inside fits over the cut hair up to here.
BAND_TOP = H.CUT_Y + 0.004
INNER = H.CUT_RADIUS + 0.0035
# Above the printed brows in front.
BROW = 0.069
# How far a hat's inside keeps off the head and stud, and how much further
# out its points go so the flat faces between its sections stay off them
# too (sections are at most 24 degrees apart).
OFF = 0.004
SAG = 1.0 / math.cos(math.radians(12.5))

COLOURS = {
    "glass": ["#a8dcf4a6", 0.0],
    "velvet": ["#9c1f2e", 0.0],
    "ivory": ["#efe6c8", 0.0],
    "red": ["#c4281c", 0.0],
    "blue": ["#0d69ab", 0.0],
}


# A hat's rim drops from over the brows to over the cut hair between these
# angles, and the hat has sections there.
RIM_ANGLES = (57.0, 71.0)
RIM_SECTIONS = (-71.0, -57.0, 57.0, 71.0)


def rim_line(front=BROW, side=0.046, back=0.044):
    """A hat's lower edge round the head: above the brows across the face,
    down to `side` by the ears where the cut hair starts, and `back` behind."""
    return lambda a: curve([(0.0, front), (RIM_ANGLES[0], front), (RIM_ANGLES[1], side), (180.0, back)], a)


def inner_line(front=R0 * SAG + 0.004):
    """How far out a hat's inside is at its lower edge: close to the forehead
    in front, and over the cut hair from the sides back."""
    return lambda a: curve([(0.0, front), (RIM_ANGLES[0] + 2.0, front), (RIM_ANGLES[1], INNER * SAG), (180.0, INNER * SAG)], a)


def _v(v):
    return v if callable(v) else (lambda a: v)


def _corner(cu, cv, rho, a0, a1):
    """Two edges round a rounded corner, outside it: the points where the
    lines touching it at a0, the middle and a1 (degrees) meet."""
    out = []
    mid = (a0 + a1) * 0.5
    for x, y in ((a0, mid), (mid, a1)):
        t = math.radians((x + y) * 0.5)
        far = rho / math.cos(math.radians((y - x) * 0.5))
        out.append((cu + far * math.cos(t), cv + far * math.sin(t)))
    return out


def head_around():
    """Points round the head and stud from the side, a little off them, from
    under the bottom edge up to the middle of the top, as (radius, height)."""
    r, top = R0 + OFF, 0.1 + OFF
    pts = [(0.085, -0.1 - OFF)]
    pts += _corner(0.085, -0.065, 0.035 + OFF, -90.0, 0.0)
    pts += [(r, -0.065), (r, 0.065)]
    pts += _corner(0.085, 0.065, 0.035 + OFF, 0.0, 90.0)
    pts += [(0.054 + OFF, top)]
    pts += _corner(0.046, 0.126, 0.008 + OFF, 0.0, 90.0)
    pts += [(0.002, 0.134 + OFF)]
    return [(u * SAG, v) for u, v in pts]


AROUND = head_around()


def inside_from(level, first=0):
    """The inside of a hat from `level` on up over the head: where it meets
    the points round the head at that height, then the points above it, with
    the ones below moved to just past where it meets them, so there are
    always as many."""
    around = AROUND[first:]
    i = next(k for k in range(len(around) - 1) if around[k + 1][1] > level)
    (u0, v0), (u1, v1) = around[i], around[i + 1]
    t = (level - v0) / (v1 - v0)
    start = (u0 + (u1 - u0) * t, level)
    rest = around[i + 1:]
    nxt = rest[0]
    d = np.array(nxt) - np.array(start)
    step = d / max(np.linalg.norm(d), 1e-9) * 0.0004
    tucked = [(start[0] + step[0] * (k + 1), start[1] + step[1] * (k + 1)) for k in range(i + 1)]
    return [start] + tucked + rest


def hat(rim=None, radius=0.153, top=0.152, dome=0.014, lip=0.006, corner=0.05, bulge=0.002, inner=None, step=24.0, extra=RIM_SECTIONS, over_hair=True, under=0.0):
    """The crown of a hat over the head, hollow inside: its lower edge on
    `rim`, `radius` out at the sides, `top` high at its edge rising by
    `dome` in the middle, each a number or a function of the angle round
    the head (0 at the front). Inside, it fits over the cut hair up to
    BAND_TOP and then follows the head and stud over the top, or with
    `over_hair` False follows the head all the way down, for a helmet.
    `under` raises the outside's lower edge, so the underside slopes up
    from the rim to it."""
    rim = rim or rim_line()
    inner = inner or inner_line()
    radius, top_at, corner_at, bulge, under = _v(radius), _v(top), _v(corner), _v(bulge), _v(under)
    angles = angles_round(step, extra)
    gap = max((b - a) % (2.0 * math.pi) for a, b in zip(angles, angles[1:] + angles[:1]))
    # Further out if its sections are further apart than AROUND allows for.
    wider = max(1.0, 1.0 / math.cos(gap * 0.5) / SAG)

    def profile(a):
        b, r, top, corner, g = rim(a), radius(a), top_at(a), corner_at(a), bulge(a)
        # A helmet coming down past the bottom of the head goes straight down
        # from there inside.
        level = (max(b, BAND_TOP) if over_hair else max(b, -0.099)) + 0.0008
        # Over hair the inside starts up the side of the head.
        pts = [(u * wider, v) for u, v in inside_from(level, 3 if over_hair else 0)]
        rin = inner(a) * wider if over_hair else pts[0][0]
        if over_hair:
            pts = [(rin, b), (rin, level - 0.0004)] + pts
        else:
            pts[0] = (pts[0][0], b)
        # Wide enough for the lip under it.
        r = max(r, rin + lip + 0.002)
        inner_top = r - corner
        for k in range(3):
            u = inner_top * k / 3
            pts.append((max(u, 0.002), top + dome * (1.0 - (u / inner_top) ** 2)))
        for k in range(3):
            q = math.radians(90.0 - 90.0 * k / 2)
            pts.append((r - corner + corner * math.cos(q), top - corner + corner * math.sin(q)))
        low = b + under(a)
        for k in (1, 2):
            pts.append((r + g * math.sin(math.pi * k / 3), top - corner + (low + lip - top + corner) * k / 3))
        for k in range(3):
            q = math.radians(-90.0 * k / 2)
            pts.append((r - lip + lip * math.cos(q), low + lip + lip * math.sin(q)))
        return pts

    return lathe_at(angles, profile)


# Extra sections where a helmet drops past the cheeks.
HELMET_DROP = (-80.0, -72.0, -58.0, 58.0, 72.0, 80.0)


def helmet(line, **kw):
    """A helmet or hood: a hat that comes down the sides and back like hair,
    following the head inside."""
    kw.setdefault("extra", HELMET_DROP)
    kw.setdefault("step", 22.5)
    return hat(line, over_hair=False, **kw)


def ring(bottom, height, r_in, r_out, soft=0.004, step=20.0, extra=RIM_SECTIONS):
    """A flat band round the head, like a hat band or a brim: from `bottom`
    up by `height`, from `r_in` out to `r_out`, each a number or a function
    of the angle round the head, with soft edges."""
    bottom, height, r_in, r_out = _v(bottom), _v(height), _v(r_in), _v(r_out)

    def profile(a):
        b, h, ri, ro = bottom(a), height(a), r_in(a), r_out(a)
        s = min(soft, h * 0.45, (ro - ri) * 0.45)
        return rounded_rect(ri, ro, b, b + h, s, 1)

    return lathe_at(angles_round(step, extra), profile)


def stripe(solid, half, y_min=-1.0):
    """Splits a stripe `half` wide either side of x = 0 off a solid, front to
    back over the top."""
    slab = Manifold.cube([half * 2.0, 1.0, 1.0]).translate([-half, y_min, -0.5])
    return solid - slab, solid ^ slab


def goggles(y, out, tilt=0.0, size=0.029):
    """Two round goggles side by side on the front of something `out` from
    the middle of the head at height y, and their strap round it."""
    frames, lenses = [], []
    n = np.array([0.0, math.sin(tilt), -math.cos(tilt)])
    for s in (-1.0, 1.0):
        c = np.array([0.04 * s, y, -out + 0.004])
        k = size / 0.029
        c[0] *= 0.6 + 0.4 * k
        frame = tube(c, c + n * 0.016, size, size - 0.002, 16) - tube(c + n * 0.009, c + n * 0.03, size * 0.69, size * 0.69, 16)
        frames.append(frame)
        lenses.append(tube(c + n * 0.006, c + n * 0.011, size * 0.71, size * 0.71, 16))
    frames.append(Manifold.batch_hull([ball((-0.012, y, -out - 0.002), 0.008, 8), ball((0.012, y, -out - 0.002), 0.008, 8)]))
    strap = ring(y - 0.009, 0.018, out - 0.004, out + 0.005, 0.003, 24.0)
    return union(frames), union(lenses), strap


def visor_band(y0, y1, r, spread, thick=0.008):
    """A curved clear visor pushed up on the brow, `spread` degrees either
    side of the front."""
    def profile(a):
        return rounded_rect(r, r + thick, y0, y1, 0.0035, 2)
    angles = [math.radians(-spread + 2.0 * spread * k / 8) for k in range(9)]
    pts_rings = []
    from shapes import from_grid
    for a in angles:
        pts_rings.append([(u * math.sin(a), v, -u * math.cos(a)) for u, v in profile(a)])
    return from_grid(pts_rings, False)


def finish(regions, zones):
    """Prints on main's surface: what of main is in each zone goes in that
    zone's region, and main is cut by the zone itself, since cutting it by
    the print leaves slivers that flicker against it. `zones` is a list of
    (region, zone)."""
    for k, zone in zones:
        inside = regions["main"] ^ zone
        regions["main"] = regions["main"] - zone
        regions[k] = regions[k] + inside if k in regions else inside
    return regions


def _on(solid, direction):
    """Where a line from the middle of the head going this way leaves a
    hat, starting from inside its shell, 0.16 out."""
    d = np.asarray(direction, float)
    d /= np.linalg.norm(d)
    lo, hi = 0.16, 0.5
    for _ in range(20):
        mid = (lo + hi) * 0.5
        inside = not (solid ^ ball(d * mid, 0.0005, 4)).is_empty()
        lo, hi = (mid, hi) if inside else (lo, mid)
    return d * lo


def spot(solid, at, r, segments=12):
    """The part of a solid within r of a point, for a printed spot."""
    return solid ^ ball(at, r, segments)


# Brims stay above this, so hands held up in front of the face pass under
# them as the head turns.
BRIM_LOW = 0.057


def brim(rim, r_out, lift=lambda a: 0.0, thick=0.012, step=15.0):
    """A brim round a hat, sitting on its rim, raised by `lift`."""
    return ring(lambda a: max(rim(a) + 0.002 + lift(a), BRIM_LOW), thick, 0.15, r_out, 0.005, step)


def hat_band(rim, up, tall, out, step=30.0):
    """A band round a hat `up` from its rim, standing out to `out`."""
    return ring(lambda a: rim(a) + up(a), tall, 0.148, out, 0.002, step)


# The pieces.

def racing_helmet():
    """An open face helmet down to the jaw and the nape, where long hair's
    length starts, with a stripe over the top, a short peak and a clear
    visor pushed up."""
    line = face_line(0.082, -0.07, H.LOWEST, 78.0)
    shell = helmet(line, radius=lambda a: curve([(0.0, 0.15), (90.0, 0.158), (180.0, 0.16)], a), top=0.17, dome=0.016, lip=0.012, corner=0.06, bulge=0.004)
    main, white = stripe(shell, 0.024, 0.09)
    peak = blob((0.0, 0.098, -0.146), (0.1, 0.012, 0.035), 16)
    visor = visor_band(0.1, 0.13, 0.148, 44.0)
    return {"main": main + peak, "white": white, "glass": visor}


def open_helmet():
    """A round helmet down over the ears, with goggles on its brow."""
    line = face_line(0.084, -0.035, -0.05, 78.0)
    shell = helmet(line, radius=0.152, top=0.165, dome=0.016, lip=0.012, corner=0.065, bulge=0.003, extra=(-78.0, -60.0, 60.0, 78.0))
    frames, lenses, strap = goggles(0.112, 0.15, 0.2)
    return {"main": shell, "ink": frames + strap, "glass": lenses}


def cap_hat():
    """A round cap with a peak and a button on top."""
    crown = hat(top=0.152, dome=0.018, corner=0.055)
    peak = blob((0.0, 0.081, -0.15), (0.11, 0.011, 0.08), 20) ^ Manifold.cube([0.4, 0.2, 0.17]).translate([-0.2, 0.0, -0.3])
    button = ball((0.0, 0.171, 0.0), 0.016, 12)
    return {"main": crown + peak, "dark": button}


def beanie():
    """A round knitted toque with a folded cuff and a pom-pom."""
    rim = rim_line(0.07, 0.046, 0.044)
    crown = hat(rim, top=0.168, dome=0.03, corner=0.075)
    # Its inside a little out from the crown's and its bottom a little lower
    # from the sides back (not in front, over the face), so the two aren't
    # in the same place.
    cuff = ring(lambda a: rim(a) - curve([(0.0, 0.001), (59.0, 0.001), (66.0, 0.003), (180.0, 0.003)], a), 0.034, lambda a: inner_line()(a) + 0.0015, lambda a: curve([(0.0, 0.156), (60.0, 0.161), (180.0, 0.162)], a), 0.008)
    pom = ball((0.0, 0.225, 0.008), 0.038, 14)
    return {"main": crown, "dark": cuff, "white": pom}


def hard_hat():
    """A domed hard hat with a ridge over the top and a brim all round,
    longer in front."""
    rim = rim_line(0.074, 0.048, 0.046)
    crown = hat(rim, top=0.172, dome=0.032, corner=0.07)
    ring_round = brim(rim, lambda a: curve([(0.0, 0.2), (90.0, 0.178), (180.0, 0.19)], a), step=20.0)
    ridge = hat(rim, radius=0.167, top=0.186, dome=0.032, corner=0.078, step=36.0, extra=()) ^ Manifold.cube([0.034, 0.3, 0.6]).translate([-0.017, 0.1, -0.3])
    # Only what stands out from the crown, so its inside and lower edge
    # aren't in the same place as the crown's.
    ridge = ridge - crown.hull() - ring_round
    return {"main": crown + ring_round, "light": ridge}


def top_hat():
    """A tall top hat with a band round it and a flat brim, curled up a
    little at the sides."""
    rim = rim_line(BROW, 0.047, 0.045)
    crown = hat(rim, top=0.31, dome=0.0, corner=0.02, bulge=0.0)
    lift = lambda a: 0.014 * math.sin(a) ** 2
    ring_round = brim(rim, lambda a: curve([(0.0, 0.2), (90.0, 0.19), (180.0, 0.2)], a), lift)
    # The band starts inside the brim, above its underside where it curls up.
    band = hat_band(rim, lambda a: max(0.012, BRIM_LOW + 0.014 - rim(a), 0.006 + lift(a)), 0.03, 0.16)
    return {"main": crown + ring_round, "dark": band}


def crown():
    """A gold crown with five points and gems on it, and a velvet
    cap inside."""
    rim = rim_line(0.072, 0.046, 0.044)
    velvet = hat(lambda a: 0.085, radius=0.142, top=0.152, dome=0.028, corner=0.06, step=40.0, extra=(), over_hair=False)
    pts = [0.0, 72.0, 144.0, -72.0, -144.0]

    def top(a):
        d = math.degrees(a)
        nearest = min(abs(((d - p + 180.0) % 360.0) - 180.0) for p in pts)
        t = nearest / 36.0
        return 0.045 + 0.05 * (1.0 - t * t * (3.0 - 2.0 * t))

    extra = pts + [p + 36.0 for p in pts] + [p + 14.0 for p in pts] + [p - 14.0 for p in pts]
    band = ring(lambda a: rim(a) - 0.002, top, inner_line(), lambda a: inner_line()(a) + 0.011, 0.004, 72.0, extra)
    zones = [(colour, ball(around(inner_line()(math.radians(p)) + 0.014, p, rim(math.radians(p)) + 0.022), 0.013, 10)) for p, colour in ((0.0, "red"), (72.0, "gem"), (-72.0, "gem"))]
    return finish({"main": band, "velvet": velvet}, zones)


def mushroom():
    """A big round spotted cap, like a toadstool's, over a snug crown."""
    rim = rim_line(0.072, 0.046, 0.044)
    dome = hat(rim, radius=0.19, top=0.2, dome=0.026, corner=0.1, lip=0.02, bulge=0.012, under=lambda a: 0.072 - rim(a), step=30.0)
    middle, radii = np.array([0.0, 0.12, 0.0]), np.array([0.2, 0.105, 0.2])
    spots = []
    for tilt, turn, r in ((0.0, 0.0, 0.05), (55.0, -30.0, 0.042), (55.0, 90.0, 0.042), (55.0, 200.0, 0.042), (58.0, -100.0, 0.036), (35.0, 50.0, 0.032)):
        t, u = math.radians(tilt), math.radians(turn)
        d = np.array([math.sin(t) * math.sin(u), math.cos(t), -math.sin(t) * math.cos(u)])
        normal = d / radii
        normal /= np.linalg.norm(normal)
        # Sitting on the surface, flat, standing out a little.
        at = _on(dome, middle + radii * d) - normal * 0.0025
        spots.append(lobe(at, (r, r, 0.0055), normal, 10))
    # Only what stands out from the cap, so the spots' undersides don't lie
    # just under its surface.
    return {"main": dome, "white": union(spots) - dome}


def dino_hood():
    """A hood down to the jaw with soft spikes down the back and two round
    eyes on top."""
    line = face_line(0.084, -0.07, -0.09, 78.0)
    hood = helmet(line, radius=lambda a: curve([(0.0, 0.152), (90.0, 0.16), (180.0, 0.164)], a), top=0.168, dome=0.02, lip=0.012, corner=0.07, bulge=0.005)
    spikes = []
    for deg, h in ((20.0, 0.05), (55.0, 0.045), (90.0, 0.036)):
        t = math.radians(deg)
        out = np.array([0.0, math.cos(t), math.sin(t)])
        root = H.head_surface(out) + out * 0.042
        spikes.append(tuft(root, root + out * h, 0.03, 0.012, 10, 8))
    eyes, dots = [], []
    for s in (-1.0, 1.0):
        at = np.array([0.055 * s, 0.17, -0.085])
        eyes.append(ball(at, 0.032, 12))
        dots.append(ball(at + np.array([0.0, 0.004, -0.03]), 0.014, 10))
    eyes, dots = union(eyes), union(dots)
    # The eyes are cut by the dots themselves, not by the pupils, which share
    # their surface, and the spikes are only what stands out from the hood.
    return {"main": hood, "dark": union(spikes) - hood.hull(), "white": eyes - dots, "ink": eyes ^ dots}


def cowboy():
    """A cowboy hat: a creased crown, a band, and a wide brim curled up at
    the sides."""
    rim = rim_line(BROW, 0.048, 0.046)
    crown = hat(rim, top=0.212, dome=0.004, corner=0.04, bulge=0.004, step=30.0)
    crown = crown - blob((0.0, 0.235, 0.01), (0.03, 0.03, 0.1), 8)
    curl = lambda a: 0.04 * math.sin(a) ** 2
    ring_round = brim(rim, lambda a: curve([(0.0, 0.232), (90.0, 0.222), (180.0, 0.232)], a), curl, step=20.0)
    band = ring(0.08, 0.024, 0.148, 0.162, 0.002, 30.0, ())
    return {"main": crown + ring_round, "dark": band}


def horn(root, s, h=1.0, r=0.03, segments=10):
    """A horn curving out to the side (s = -1 or 1) and up from `root`, in
    soft tapering steps."""
    root = np.asarray(root, float)
    pts = [root, root + np.array([0.045 * s, 0.012, 0.0]) * h, root + np.array([0.085 * s, 0.045, 0.0]) * h, root + np.array([0.1 * s, 0.09, 0.0]) * h]
    radii = [r, r * 0.8, r * 0.55, r * 0.25]
    return H.chain(pts, radii, segments)


def viking():
    """A round helmet with a band round its brow and two curved horns."""
    rim = rim_line(0.074, 0.046, 0.044)
    dome = hat(rim, top=0.17, dome=0.03, corner=0.075)
    # Like the beanie's cuff, a little out from the dome inside and below it.
    band = ring(lambda a: rim(a) - 0.003, 0.026, lambda a: inner_line()(a) + 0.0025, 0.162, 0.006)
    horns_out = union([horn((0.15 * s, 0.112, 0.0), s) for s in (-1.0, 1.0)])
    return {"main": dome, "dark": band, "ivory": horns_out}


def pirate():
    """A three cornered hat: its brim turned up into walls all round, lowest
    at the three points, with a white trim along their top."""
    rim = rim_line(0.074, 0.047, 0.045)
    crown = hat(rim, top=0.165, dome=0.02, corner=0.06, step=30.0)

    def shape(a):
        c = math.cos(3.0 * a)
        b = max(rim(a) + 0.002, BRIM_LOW)
        return b, 0.172 + 0.05 * max(0.0, c) ** 4, 0.075 - 0.04 * c

    def wall(a):
        b, r, h = shape(a)
        top = b + h - 0.012
        inner = r - 0.01 + 0.004 * (h - 0.028) / (h - 0.016)
        return [(0.15, b), (r - 0.004, b), (r + 0.006, b + 0.006), (r + 0.0115, top), (inner, top), (r - 0.01, b + 0.016), (0.15, b + 0.016)]

    def trim(a):
        b, r, h = shape(a)
        top = b + h - 0.012
        inner = r - 0.01 + 0.004 * (h - 0.028) / (h - 0.016)
        return [(r + 0.0115, top), (r + 0.014, b + h), (r + 0.004, b + h + 0.004), (r - 0.006, b + h), (inner, top)]

    angles = angles_round(12.0, (0.0, 120.0, -120.0, 60.0, -60.0, 180.0))
    return {"main": crown + lathe_at(angles, wall), "white": lathe_at(angles, trim)}


def wizard():
    """A tall pointed hat with a wide brim and a gold band."""
    rim = rim_line(BROW, 0.047, 0.045)
    crown = hat(rim, top=0.14, dome=0.0, corner=0.03, bulge=0.0)
    cone = Manifold.batch_hull([Manifold.cylinder(0.01, 0.155, 0.155, 28).rotate([-90.0, 0.0, 0.0]).translate([0.0, 0.12, 0.0]), ball((0.0, 0.43, 0.035), 0.012, 8)])
    ring_round = brim(rim, lambda a: 0.225, step=20.0)
    band = hat_band(rim, lambda a: BRIM_LOW + 0.012 - rim(a), 0.028, 0.162)
    return {"main": crown + cone + ring_round, "gold": band}


def bandana():
    """A cloth tied tight over the head, knotted at the back with two short
    tails, and white dots."""
    rim = rim_line(0.072, 0.046, 0.046)
    cloth = hat(rim, top=0.146, dome=0.012, corner=0.06, bulge=0.0, step=30.0)
    knot = ball((0.0, 0.085, 0.158), 0.022, 12)
    tails = union([tuft((0.012 * s, 0.085, 0.166), (0.045 * s, 0.058, 0.205), 0.016, 0.01, 10, 8) for s in (-1.0, 1.0)])
    def dot(d, y):
        at = _on(cloth, around(0.15, d, y))
        n = at - np.array([0.0, 0.03, 0.0])
        n /= np.linalg.norm(n)
        return tube(at - n * 0.004, at + n * 0.0012, 0.015, 0.014, 10)

    dots = union([dot(d, y) for d, y in ((-35.0, 0.11), (35.0, 0.11), (90.0, 0.1), (-90.0, 0.1), (150.0, 0.11), (-150.0, 0.11), (0.0, 0.152))])
    return {"main": cloth + knot + tails, "white": dots}


def aviator():
    """A leather flying cap down over the ears, and goggles on the brow."""
    line = face_line(0.084, -0.06, -0.07, 78.0)
    shell = helmet(line, radius=0.15, top=0.162, dome=0.016, lip=0.01, corner=0.065, bulge=0.003)
    frames, lenses, strap = goggles(0.112, 0.148, 0.2)
    return {"main": shell, "ink": frames + strap, "glass": lenses}


def propeller():
    """A round cap in coloured panels with a little propeller on top."""
    rim = rim_line(0.072, 0.046, 0.044)
    crown = hat(rim, top=0.158, dome=0.024, corner=0.07)
    quarters = [Manifold.cube([0.4, 0.4, 0.4]).translate([0.0, -0.1, 0.0]).rotate([0.0, 45.0 + 180.0 * k, 0.0]) for k in range(2)]
    post = tube((0.0, 0.17, 0.0), (0.0, 0.205, 0.0), 0.009, 0.009, 12)
    blades = [blob((0.06 * s, 0.208, 0.0), (0.06, 0.006, 0.018), 12).rotate([0.0, 20.0, 0.0]) for s in (-1.0, 1.0)]
    hub = ball((0.0, 0.208, 0.0), 0.012, 10)
    return finish({"main": crown, "grey": post + hub, "red": blades[0], "blue": blades[1]}, [("yellow", union(quarters))])


def beret():
    """A soft flat beret, one puffed shape over the head, a little higher on
    one side, with a little stalk."""
    rim = rim_line(0.072, 0.046, 0.044)
    puff = hat(rim, radius=lambda a: 0.176 + 0.006 * math.sin(a), top=lambda a: 0.158 + 0.01 * math.sin(a), dome=0.012, corner=0.045, lip=0.014, bulge=0.004, under=0.02, step=15.0)
    stalk = tube((0.01, 0.164, 0.0), (0.013, 0.196, 0.0), 0.006, 0.005, 10)
    return {"main": puff, "dark": stalk}


# Worn on the hair: bands made for each hairdo, snug on it at their height.

SLICE_YS = np.arange(0.056, 0.172, 0.004)
BIN = 3.0
BINS = int(360 / BIN)


def _window(values, k, pick):
    """Each value with its k neighbours either side round the ring, picked
    over by `pick` (np.max or np.min)."""
    return pick(np.stack([np.roll(values, i) for i in range(-k, k + 1)]), axis=0)


class Surface:
    """How far out a head and its hair reach at each angle round the head
    (BIN degrees apiece, from the front towards +x) and each height."""

    def __init__(self, solid):
        turned = solid.rotate([90.0, 0.0, 0.0])
        rows = []
        for y in SLICE_YS:
            reach = np.zeros(BINS)
            for poly in turned.slice(float(y)).to_polygons():
                pts = np.asarray(poly, float)
                nxt = np.roll(pts, -1, axis=0)
                dense = [pts]
                for t in np.linspace(0.0, 1.0, 9)[1:-1]:
                    dense.append(pts + (nxt - pts) * t)
                pts = np.concatenate(dense)
                ang = np.degrees(np.arctan2(pts[:, 0], pts[:, 1])) % 360.0
                idx = (ang / BIN).astype(int) % BINS
                np.maximum.at(reach, idx, np.hypot(pts[:, 0], pts[:, 1]))
            # Wide enough that chords between a band's sections stay clear.
            rows.append(_window(reach, 2, np.max))
        self.rows = np.array(rows)

    def reach(self, bottom, height):
        """How far out it reaches at each bin between `bottom` and `bottom`
        + `height`, each a function of the angle in radians."""
        out = np.zeros(BINS)
        for k in range(BINS):
            a = math.radians(k * BIN)
            b = bottom(a)
            use = (SLICE_YS >= b - 0.002) & (SLICE_YS <= b + height(a) + 0.002)
            out[k] = self.rows[use, k].max()
        return out

    def most(self, degrees, y0, y1):
        """The furthest it reaches within `degrees` of the front between two
        heights."""
        k = int(degrees / BIN)
        cols = [i % BINS for i in range(-k, k + 1)]
        use = (SLICE_YS >= y0) & (SLICE_YS <= y1)
        return float(self.rows[use][:, cols].max())


def _ring_fn(values):
    """A function of the angle (radians) going smoothly between bins."""
    def f(a):
        x = (math.degrees(a) % 360.0) / BIN
        i = int(x)
        t = x - i
        return float(values[i % BINS] * (1.0 - t) + values[(i + 1) % BINS] * t)
    return f


def fit_band(on, front, height):
    """Where a band `height` tall sits on a hairdo: its bottom `front` high
    at the front, rising towards the back if that keeps it snugger, and how
    far out its inside is round the head. Narrow bits standing out (a
    mohawk's crest, spikes, ties) are left out, so the band goes under
    them."""
    tall = _v(height)
    best = None
    for tilt in (0.0, 0.01, 0.02, 0.03):
        bottom = (lambda t: lambda a: front + t * (1.0 - math.cos(a)) * 0.5)(tilt)
        reach = on.reach(bottom, tall)
        opened = _window(_window(reach, 4, np.min), 4, np.max)
        score = opened.mean() + tilt * 0.2
        if best is None or score < best[0]:
            best = (score, bottom, opened)
    return best[1], _ring_fn(best[2] + 0.0015)


def headband(on):
    """A sweatband round the brow with goggles on its front."""
    bottom, inside = fit_band(on, 0.07, 0.024)
    band = ring(bottom, 0.024, inside, lambda a: inside(a) + 0.011, 0.006, 10.0, ())
    out = max(inside(0.0) + 0.011, on.most(24.0, 0.074, 0.12) + 0.006)
    frames, lenses, _ = goggles(0.094, out, 0.35, 0.021)
    return {"main": band, "ink": frames, "glass": lenses}


def tiara(on):
    """A slim band over the front of the hair, rising to a point with a gem."""
    def top(a):
        d = abs(math.degrees((a + math.pi) % (2.0 * math.pi) - math.pi))
        return 0.016 + 0.03 * max(0.0, 1.0 - d / 22.0) ** 1.5 + 0.012 * max(0.0, 1.0 - abs(d - 38.0) / 10.0)

    bottom, inside = fit_band(on, 0.074, top)
    from shapes import from_grid
    rings = []
    for k in range(21):
        a = math.radians(-70.0 + 140.0 * k / 20)
        r, b = inside(a), bottom(a)
        rings.append([(u * math.sin(a), v, -u * math.cos(a)) for u, v in rounded_rect(r, r + 0.008, b, b + top(a), 0.003, 2)])
    band = from_grid(rings, False)
    ends = union([ball(around(inside(math.radians(70.0 * s)) + 0.004, 70.0 * s, bottom(math.radians(70.0)) + 0.008), 0.007, 8) for s in (-1.0, 1.0)])
    # Raised gems on the front of the band, only the part standing out from
    # it, as gems printed on a band this thin flicker at their edges.
    gem = ball((0.0, 0.098, -inside(0.0) - 0.01), 0.008, 14)
    side_gems = union([ball(around(inside(math.radians(38.0 * s)) + 0.008, 38.0 * s, bottom(math.radians(38.0)) + 0.016), 0.006, 10) for s in (-1.0, 1.0)])
    main = band + ends
    return {"main": main, "gem": gem - main, "pink": side_gems - main}


def party():
    """A party hat: a cone on top, a little to one side, with a pom-pom and a
    white trim round its base."""
    # The cone's bottom is a little up inside the trim, not level with it.
    cone = Manifold.batch_hull([Manifold.cylinder(0.006, 0.07, 0.07, 28).rotate([-90.0, 0.0, 0.0]).translate([0.0, 0.003, 0.0]), ball((0.0, 0.17, 0.0), 0.008, 8)])
    trim = ring(0.0, 0.016, 0.03, 0.076, 0.006, 15.0, ())
    pom = ball((0.0, 0.18, 0.0), 0.024, 12)
    turn = lambda m: m.rotate([0.0, 0.0, -8.0]).translate([0.012, 0.136, 0.0])
    # The cone is cut back from the trim, so they aren't both cut against
    # the head in the same place.
    white = turn(trim + pom)
    return {"main": turn(cone) - white, "white": white}


def horns(on):
    """Two curved horns on a band round the brow."""
    bottom, inside = fit_band(on, 0.07, 0.022)
    band = ring(bottom, 0.022, inside, lambda a: inside(a) + 0.01, 0.006, 10.0, ())
    out = []
    for s in (-1.0, 1.0):
        a = math.radians(90.0 * s)
        out.append(horn(around(inside(a) + 0.016, 90.0 * s, bottom(a) + 0.012) + np.array([0.0, 0.0, 0.01]), s, 0.8, 0.02))
    # The horns and band are cut back from each other, so neither has faces
    # just under the other's where they meet.
    out = union(out)
    return {"main": out - band, "dark": band - out}


STYLES = {
    "racing_helmet": racing_helmet,
    "open_helmet": open_helmet,
    "cap": cap_hat,
    "beanie": beanie,
    "hard_hat": hard_hat,
    "headband": headband,
    "top_hat": top_hat,
    "crown": crown,
    "tiara": tiara,
    "mushroom": mushroom,
    "dino_hood": dino_hood,
    "cowboy": cowboy,
    "viking": viking,
    "pirate": pirate,
    "wizard": wizard,
    "bandana": bandana,
    "aviator": aviator,
    "propeller": propeller,
    "party": party,
    "beret": beret,
    "horns": horns,
}

HAIR = {k: "cut" for k in STYLES}
HAIR.update({"racing_helmet": "hidden", "open_helmet": "hidden", "dino_hood": "hidden", "aviator": "hidden"})
HAIR.update({"headband": "full", "tiara": "full", "party": "full", "horns": "full"})

# How a piece worn on the hair is fitted to each hairdo: "around" grows it
# out round the hair (and may lift it a little and move it back), "over"
# grows it all over from the middle of the head, "on" lifts it onto the top.
FIT = {"party": "on"}

# Made for each hairdo, from the Surface of the head and that hair.
BANDS = ("headband", "tiara", "horns")


def placed(solid, fit):
    s, sy, dy, dz = fit
    return solid.scale([s, sy, s]).translate([0.0, dy, dz])


def fit_to(solid, keepout, kind):
    """The smallest change [scale across, scale up, lift, back] that keeps
    `solid` out of `keepout` (the head, the stud and the hair)."""
    box = keepout.bounding_box()

    def clear(f):
        p = placed(solid, f)
        b = p.bounding_box()
        if not all(b[i] <= box[i + 3] and box[i] <= b[i + 3] for i in range(3)):
            return True
        return (p ^ keepout).volume() < 1e-9

    best, cost = None, 1e9
    if kind == "on":
        for dz in (0.0, 0.015, -0.015, 0.03):
            lo, hi = -0.04, 0.2
            if not clear([1.0, 1.0, hi, dz]):
                continue
            for _ in range(12):
                mid = (lo + hi) * 0.5
                lo, hi = (lo, mid) if clear([1.0, 1.0, mid, dz]) else (mid, hi)
            c = hi + abs(dz) * 2.0
            if c < cost:
                best, cost = [1.0, 1.0, hi + 0.002, dz], c
        return best
    lifts = (0.0,) if kind == "over" else (0.0, 0.01, 0.02, 0.03, 0.05)
    backs = (0.0,) if kind == "over" else (0.0, 0.01, 0.02, 0.025, 0.03, 0.04)
    for dy in lifts:
        for dz in backs:
            def f(s):
                return [s, s, 0.0, 0.0] if kind == "over" else [s, 1.0, dy, dz]
            if clear(f(1.0)):
                c = dy * 2.0 + dz * 2.0
                if c < cost:
                    best, cost = f(1.0), c
                continue
            lo, hi = 1.0, 1.9
            if not clear(f(hi)):
                continue
            for _ in range(9):
                mid = (lo + hi) * 0.5
                lo, hi = (lo, mid) if clear(f(mid)) else (mid, hi)
            c = (hi - 1.0) + dy * 2.0 + dz * 2.0
            if c < cost:
                best, cost = f(hi * 1.012), c
    return best


def wedge(degrees, half=3.0):
    """A thin slice of the space round the head at this angle."""
    a0, a1 = math.radians(degrees - half), math.radians(degrees + half)
    pts = [(0.0, 0.0), (0.4 * math.sin(a0), -0.4 * math.cos(a0)), (0.4 * math.sin(a1), -0.4 * math.cos(a1))]
    from manifold3d import CrossSection
    section = CrossSection([pts])
    if section.area() <= 0.0:
        section = CrossSection([list(reversed(pts))])
    return section.extrude(0.6).rotate([90.0, 0.0, 0.0]).translate([0.0, 0.3, 0.0])


def _wedges(step=6.0):
    d = -180.0
    while d < 180.0:
        yield round(d, 1), wedge(d)
        d += step


WEDGES = None


def hat_reach(hat_solid):
    """How low the hat comes at each angle round the head, outside the cut
    hair's radius, by angle (degrees)."""
    global WEDGES
    if WEDGES is None:
        WEDGES = list(_wedges())
    shell = Manifold.cylinder(0.6, 0.4, 0.4, 48) - Manifold.cylinder(0.6, H.CUT_RADIUS - 0.004, H.CUT_RADIUS - 0.004, 48)
    outside = hat_solid ^ shell.rotate([-90.0, 0.0, 0.0]).translate([0.0, -0.3, 0.0])
    out = {}
    for d, w in WEDGES:
        o = outside ^ w
        out[d] = None if o.is_empty() else o.bounding_box()[1]
    return out


def hair_tops(cut_hair):
    """How high the cut hair's top edge is at each angle round the head,
    where it has one."""
    global WEDGES
    if WEDGES is None:
        WEDGES = list(_wedges())
    top_band = cut_hair.trim_by_plane([0.0, 1.0, 0.0], H.CUT_Y - 0.006)
    out = {}
    for d, w in WEDGES:
        h = top_band ^ w
        if not h.is_empty() and h.volume() > 1e-10:
            out[d] = h.bounding_box()[4]
    return out


def uncovered(reach, tops):
    """The angles where the hat doesn't come down to the cut hair's top."""
    return [d for d, top in tops.items() if reach.get(d) is None or reach[d] > top - 0.0005]
