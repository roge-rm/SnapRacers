"""What's worn around the neck: scarves, ties, necklaces, collars and the
rest, one function a style. Each gives its solids by colour region, in the
upper body's space (see figure.py), before they're cut back from the torso,
the neck and the head.

There's only 3 cm between the top of the torso and the head, so what goes
around the neck is low and flat, and anything bigger hangs on the chest
below the head.
"""

import math

import numpy as np
from manifold3d import CrossSection, Manifold

import figure as F
from shapes import GAP, ball, blob, ellipse, flat as _flat, lathe, rbox, rounded_rect, smooth_path, soft_slab, sweep, tube

TOP = F.HIPS_TOP + F.TORSO_HEIGHT
HEAD_BOTTOM = F.NECK_Y + 0.015
CHEST = -F.TORSO_DEPTH * 0.5
FRONT = CHEST - GAP
# The torso's top front edge is rounded around this line (y, z), this much.
EDGE_Y, EDGE_Z, EDGE_R = TOP - 0.03, CHEST + 0.03, 0.03

# Colours that don't follow the piece's own: (colour, metallic).
COLOURS = {
    "white": ["#f2f2f2", 0.0],
    "gold": ["#c9a227", 0.6],
    "silver": ["#c8ccd0", 0.6],
    "ink": ["#3c3f44", 0.0],
    "gem": ["#3a8dde", 0.0],
    "yellow": ["#f2cd37", 0.0],
    "pink": ["#d86cb0", 0.0],
    "green": ["#4b9f4a", 0.0],
    "orange": ["#e8782b", 0.0],
    "grey": ["#9aa0a6", 0.0],
}


def around(r, angle, y):
    """A point r out from the neck at an angle (0 at the front, toward +x)."""
    return np.array([r * math.sin(angle), y, -r * math.cos(angle)])


def necklace(r, off, dip, angle=math.radians(55.0), x_end=0.0, steps=10):
    """Points and the surface's normals along a loop that lies on the top of
    the torso around the back of the neck, comes over the front edge and down
    the chest to `dip` in a U (or to +-x_end). `off` is how far the path's
    middle is off the surface. It runs from the left end round to the right."""
    pts, normals = [], []
    rho = EDGE_R + off

    def side(sign):
        out = []
        x_e = r * math.sin(angle) * sign
        # Down the chest in a quarter ellipse, so it hangs in a smooth U.
        for k in range(4, 0, -1):
            t = math.pi * 0.5 * k / 4
            out.append((np.array([(x_end + (abs(x_e) - x_end) * math.cos(t)) * sign, EDGE_Y - (EDGE_Y - dip) * math.sin(t), CHEST - off]), (0.0, 0.0, -1.0)))
        for a in (0.0, 30.0, 60.0, 90.0):
            t = math.radians(a)
            out.append((np.array([x_e, EDGE_Y + rho * math.sin(t), EDGE_Z - rho * math.cos(t)]), (0.0, math.sin(t), -math.cos(t))))
        return out

    for p, n in side(-1.0):
        pts.append(p)
        normals.append(n)
    for k in range(steps + 1):
        a = -angle - (2.0 * math.pi - 2.0 * angle) * k / steps
        pts.append(around(r, a, TOP + off))
        normals.append((0.0, 1.0, 0.0))
    for p, n in reversed(side(1.0)):
        pts.append(p)
        normals.append(n)
    return pts, normals


def resample(points, normals, spacing):
    """Points every `spacing` along a path, with normals."""
    out, outn = [np.asarray(points[0], float)], [np.asarray(normals[0], float)]
    left = spacing
    for a, b, na, nb in zip(points, points[1:], normals, normals[1:]):
        a, b = np.asarray(a, float), np.asarray(b, float)
        length = float(np.linalg.norm(b - a))
        at = 0.0
        while length - at >= left:
            at += left
            t = at / length
            out.append(a + (b - a) * t)
            n = np.asarray(na, float) * (1.0 - t) + np.asarray(nb, float) * t
            outn.append(n / np.linalg.norm(n))
            left = spacing
        left -= length - at
    return out, outn


def _add():
    from manifold3d import OpType
    return OpType.Add


def union(parts):
    parts = [p for p in parts if p is not None and not p.is_empty()]
    return Manifold.batch_boolean(parts, _add()) if parts else Manifold()


def flat(points, depth, z, r=None):
    """A flat piece on the chest (see shapes.flat), kept light."""
    return _flat(points, depth, z, r, 3, 20)


def flat_round(radius, depth, z, at=(0.0, 0.0)):
    """A round flat piece, its back at z."""
    return soft_slab(CrossSection.circle(radius, 20), depth, depth * 0.4, 2, 16).translate([at[0], at[1], z - depth * 0.5])


def loop(r, off, dip, angle=math.radians(55.0), x_end=0.0, spacing=0.012):
    """A closed necklace path (see necklace) with its corners rounded, points
    about `spacing` apart, with the surface's normals."""
    pts, normals = necklace(r, off, dip, angle, x_end)
    if x_end == 0.0:
        pts, normals = pts[:-1], normals[:-1]
    pts, normals = smooth_path(pts, normals, True, 3)
    pts, normals = resample(pts + [pts[0]], normals + [normals[0]], spacing)
    if np.linalg.norm(pts[-1] - pts[0]) < spacing * 0.5:
        pts, normals = pts[:-1], normals[:-1]
    return pts, normals


def cord(r, thick, dip, angle=math.radians(55.0), x_end=0.0, flat_ratio=1.0, spacing=0.012, sides=8):
    """A smooth moulded loop around the neck, `thick` across, lying on the
    shoulders and coming down the chest to `dip`. Gives the solid and the
    height of the middle of its lowest point, which comes out a little above
    `dip` once its corners are rounded."""
    half = thick * 0.5
    pts, normals = loop(r, GAP + half * flat_ratio + 0.0005, dip, angle, x_end, spacing)
    return sweep(pts, normals, ellipse(half, half * flat_ratio, sides)), min(p[1] for p in pts)


def ring(inner, outer, y0, y1, r=0.004, sides=32):
    """A ring around the neck from y0 to y1, its edges rounded by r."""
    profile = rounded_rect(inner, outer, y0, y1, r, 2)
    return lathe(lambda a: profile, sides)


def shoulder_ring(inner, outer, height):
    """A flat collar lying on the shoulders around the neck, wide enough to
    show past the head."""
    return ring(inner, outer, TOP + GAP, TOP + GAP + height, 0.005)


def printed(solid, prism):
    """Splits a solid into what's inside the prism, a print, and the rest."""
    return solid - prism, solid ^ prism


def stripes(solid, cuts, axis=1):
    """Splits a solid into what's inside the bands (lo, hi) along an axis and
    the rest."""
    bands = []
    for lo, hi in cuts:
        size = [2.0, 2.0, 2.0]
        size[axis] = hi - lo
        at = [-1.0, -1.0, -1.0]
        at[axis] = lo
        bands.append(Manifold.cube(size).translate(at))
    bands = union(bands)
    return solid - bands, solid ^ bands


def dots(solid, centres, r):
    """Splits a flat solid on the chest into round dots through it and the
    rest."""
    holes = union([tube((x, y, -0.3), (x, y, 0.0), r, r, 12) for x, y in centres])
    return solid - holes, solid ^ holes


def lanyard(bottom, r=0.0035):
    """A thin cord around the neck and down the chest in a V to `bottom`,
    and the height of its lowest point (see cord)."""
    return cord(0.08, r * 2.0, bottom, math.radians(50.0), 0.0, 1.0, 0.015, 6)


def edge_path(x, thick, length, back=False):
    """A path from the top of the shoulder at x over the torso's front (or
    back) edge and `length` down, `thick` off the surface, with normals."""
    rho = EDGE_R + GAP + thick * 0.5 + 0.001
    off = GAP + thick * 0.5 + 0.001
    pts, normals = [np.array([x, TOP + off, -0.055]), np.array([x, TOP + off, EDGE_Z])], [(0.0, 1.0, 0.0), (0.0, 1.0, 0.0)]
    for a in (75.0, 45.0, 15.0):
        t = math.radians(a)
        pts.append(np.array([x, EDGE_Y + rho * math.sin(t), EDGE_Z - rho * math.cos(t)]))
        normals.append((0.0, math.sin(t), -math.cos(t)))
    for y in (EDGE_Y - 0.03, TOP - length):
        pts.append(np.array([x, y, CHEST - off]))
        normals.append((0.0, 0.0, -1.0))
    if back:
        pts = [p * np.array([1.0, 1.0, -1.0]) for p in pts]
        normals = [np.array(n) * np.array([1.0, 1.0, -1.0]) for n in normals]
    return pts, normals


def scarf_tail(x, width, length, back=False, thick=0.011):
    """A long flat end of scarf from the top of the shoulder over the edge
    and down, with two stripes printed near its end."""
    pts, normals = edge_path(x, thick, length, back)
    pts, normals = smooth_path(pts, normals, False, 1)
    tail = sweep(pts, normals, rounded_rect(-width * 0.5, width * 0.5, -thick * 0.5, thick * 0.5, thick * 0.4, 1), False, thick)
    bottom = TOP - length
    return stripes(tail, [(bottom + 0.016, bottom + 0.026), (bottom + 0.036, bottom + 0.046)])


def wrap(centre, half_w, half_h):
    """A soft roll of cloth around the neck on the shoulders."""
    profile = [(centre + half_w * math.cos(a), TOP + 0.002 + half_h + half_h * math.sin(a)) for a in np.linspace(0.0, 2.0 * math.pi, 10, endpoint=False)]
    return lathe(lambda a: profile, 24)


def scarf():
    """A thick wrap with a knot at the front left and two short ends."""
    knot = blob((-0.042, TOP - 0.012, FRONT - 0.019), (0.03, 0.024, 0.019), 16)
    ends = []
    for top_x, bottom_x, w, drop in ((-0.054, -0.08, 0.04, 0.085), (-0.03, -0.008, 0.034, 0.07)):
        y0, y1 = TOP - 0.018, TOP - drop
        ends.append(flat([(top_x - w * 0.5, y0), (top_x + w * 0.5, y0), (bottom_x + w * 0.5, y1), (bottom_x - w * 0.5, y1)], 0.011, FRONT))
    plain, striped = [], []
    for end, drop in zip(ends, (0.085, 0.07)):
        a, b = stripes(end, [(TOP - drop + 0.01, TOP - drop + 0.019)])
        plain.append(a)
        striped.append(b)
    return {"main": wrap(0.098, 0.026, 0.012) + knot + union(plain), "dark": union(striped)}


def long_scarf():
    """A slim wrap with one long end down the front on the right and the
    other down the back on the left."""
    front, front_stripes = scarf_tail(0.064, 0.046, 0.25)
    back, back_stripes = scarf_tail(-0.064, 0.046, 0.27, True)
    return {"main": wrap(0.098, 0.024, 0.01) + front + back, "dark": front_stripes + back_stripes}


def tie():
    knot = flat([(-0.02, TOP + 0.004), (0.02, TOP + 0.004), (0.013, TOP - 0.03), (-0.013, TOP - 0.03)], 0.018, FRONT + 0.004)
    blade = flat([(-0.011, TOP - 0.026), (0.011, TOP - 0.026), (0.025, TOP - 0.19), (0.0, TOP - 0.215), (-0.025, TOP - 0.19)], 0.008, FRONT)
    # Stripes across the blade, slanting.
    slants = union([Manifold.cube([0.2, 0.009, 0.2]).translate([-0.1, -0.0045, -0.25]).rotate([0.0, 0.0, -30.0]).translate([0.0, y, 0.0]) for y in (TOP - 0.07, TOP - 0.11, TOP - 0.15)])
    striped = blade ^ slants
    return {"main": knot + (blade - slants), "dark": striped}


def bow_tie():
    y = TOP - 0.015
    wings = []
    for s in (-1.0, 1.0):
        wings.append(flat([(0.006 * s, y - 0.009), (0.006 * s, y + 0.009), (0.052 * s, y + 0.021), (0.052 * s, y - 0.021)], 0.016, FRONT, 0.006))
    knot = rbox(-0.011, y - 0.012, FRONT - 0.021, 0.011, y + 0.012, FRONT, 0.006)
    return {"main": union(wings), "dark": knot}


def neckerchief():
    # A flat band round the neck that comes over the front edge to the
    # triangle hanging on the chest.
    band_loop, _ = cord(0.08, 0.016, TOP - 0.012, math.radians(40.0), 0.04, 0.45, 0.014, 8)
    tri = flat([(-0.07, TOP - 0.006), (0.07, TOP - 0.006), (0.0, TOP - 0.115)], 0.008, FRONT, 0.003)
    knot = ball((0.0, TOP - 0.008, FRONT - 0.012), 0.013, 16)
    cloth = band_loop + tri + knot
    rest, spots = dots(tri, [(-0.03, TOP - 0.03), (0.03, TOP - 0.03), (0.0, TOP - 0.055), (0.0, TOP - 0.09)], 0.006)
    return {"main": cloth - spots, "white": spots}


def star_prism(outer, inner, at, points=5):
    pts = []
    for k in range(points * 2):
        a = math.pi * k / points
        rr = outer if k % 2 == 0 else inner
        pts.append((at[0] + rr * math.sin(a), at[1] + rr * math.cos(a)))
    section = CrossSection([pts])
    if section.area() <= 0.0:
        section = CrossSection([list(reversed(pts))])
    return section.extrude(0.3).translate([0.0, 0.0, -0.3])


def medal():
    pts, normals = loop(0.084, GAP + 0.0025, TOP - 0.1, math.radians(50.0), 0.009, 0.014)
    ribbon = sweep(pts, normals, rounded_rect(-0.009, 0.009, -0.002, 0.002, 0.0015, 1))
    low = min(p[1] for p in pts)
    y = low - 0.032
    disc = flat_round(0.03, 0.008, FRONT - 0.004, (0.0, y))
    loop_tab = rbox(-0.009, y + 0.025, FRONT - 0.009, 0.009, low + 0.004, FRONT - 0.002, 0.003)
    # A star printed on the front.
    star_zone = star_prism(0.017, 0.007, (0.0, y)).translate([0.0, 0.0, FRONT - 0.0105])
    return {"main": ribbon, "gold": (disc - star_zone) + loop_tab, "dark": disc ^ star_zone}


def beads():
    """A chunky moulded loop with three big beads at the front."""
    solid, low = cord(0.086, 0.014, TOP - 0.08, math.radians(55.0), 0.02, 1.0, 0.017, 8)
    big = union([ball((x, low + dy, CHEST - GAP - 0.012), 0.014, 12) for x, dy in ((-0.03, 0.006), (0.0, 0.0), (0.03, 0.006))])
    return {"main": solid - big, "light": big}


def pearls():
    """A slim white loop in a V with a drop pearl at the bottom."""
    solid, low = cord(0.082, 0.009, TOP - 0.1, math.radians(52.0), 0.0, 1.0, 0.015, 8)
    drop = blob((0.0, low - 0.012, CHEST - GAP - 0.009), (0.009, 0.012, 0.009), 14)
    return {"white": solid + drop}


def spiked_collar():
    collar = shoulder_ring(0.07, 0.118, 0.017)
    spikes = []
    for k in range(8):
        a = math.pi * 2.0 * (k + 0.5) / 8
        base = around(0.11, a, TOP + GAP + 0.0085)
        tip = around(0.146, a, TOP + GAP + 0.0085)
        spikes.append(tube(base, tip, 0.0085, 0.0025, 10))
    return {"main": collar, "silver": union(spikes)}


def ruff():
    """A moulded frill on the shoulders, its edge in soft waves."""
    def profile(a):
        out = 0.114 + 0.009 * math.cos(a * 10.0)
        return rounded_rect(0.074, out, TOP + GAP, TOP + 0.024, 0.006, 2)
    return {"white": lathe(profile, 50)}


def whistle():
    cord_solid, low = lanyard(TOP - 0.09)
    y, z = low - 0.01, FRONT - 0.012
    body = Manifold.batch_hull([ball((-0.012, y, z), 0.012, 16), ball((0.016, y, z), 0.012, 16)])
    mouth = rbox(0.018, y - 0.004, FRONT - 0.018, 0.044, y + 0.01, FRONT - 0.005, 0.003)
    # The hole printed on top.
    rest, hole = printed(body, Manifold.cube([0.012, 0.1, 0.012]).translate([0.002, y + 0.004, z - 0.006]))
    return {"main": cord_solid, "silver": rest + mouth, "ink": hole}


def race_pass():
    cord_solid, low = lanyard(TOP - 0.075)
    # Its back stands off the cord's, so the two don't fight.
    clip = rbox(-0.008, low - 0.02, FRONT - 0.008, 0.008, low + 0.003, FRONT - 0.002, 0.003)
    top = low - 0.016
    bottom = top - 0.084
    card = rbox(-0.032, bottom, FRONT - 0.005, 0.032, top, FRONT, 0.002)
    # Each print is cut from the card by its zone, not by the print itself.
    stripe_zone = Manifold.cube([0.1, 0.016, 0.1]).translate([-0.05, top - 0.018, -0.2])
    photo_zone = Manifold.cube([0.022, 0.026, 0.1]).translate([-0.025, bottom + 0.03, -0.2])
    lines_zone = union([Manifold.cube([0.026, 0.005, 0.1]).translate([0.0, bottom + y, -0.2]) for y in (0.046, 0.034)])
    stripe, photo, lines = card ^ stripe_zone, card ^ photo_zone, card ^ lines_zone
    white = card - stripe_zone - photo_zone - lines_zone
    return {"main": cord_solid + stripe, "white": white, "silver": clip, "grey": photo, "ink": lines}


def gold_chain():
    """A smooth gold loop with a round pendant."""
    solid, low = cord(0.082, 0.008, TOP - 0.09, math.radians(50.0), 0.0, 1.0, 0.015, 8)
    y = low - 0.022
    pendant = flat_round(0.017, 0.007, FRONT - 0.001, (0.0, y))
    bail = rbox(-0.004, y + 0.012, FRONT - 0.008, 0.004, low + 0.003, FRONT - 0.001, 0.002)
    return {"main": solid + pendant + bail}


def brooch():
    y = TOP - 0.035
    setting = flat_round(0.023, 0.006, FRONT, (0.0, y))
    gem = Manifold.sphere(1.0, 10).scale([0.014, 0.014, 0.008]).translate([0.0, y, FRONT - 0.006])
    gem = gem - Manifold.cube([1.0, 1.0, 1.0]).translate([-0.5, -0.5, FRONT - 0.006])
    return {"gold": setting, "main": gem}


def lei():
    """A chunky ring with a few flowers moulded on at the front."""
    solid, low = cord(0.094, 0.022, TOP - 0.07, math.radians(60.0), 0.0, 0.6, 0.016, 8)
    regions = {"white": [], "yellow": [], "pink": []}
    spots = [(-0.052, low + 0.03), (0.0, low), (0.052, low + 0.03)]
    for (x, y), colour in zip(spots, ("pink", "yellow", "white")):
        regions[colour].append(blob((x, y, CHEST - GAP - 0.012), (0.019, 0.019, 0.007), 12))
    flowers = {c: union(v) for c, v in regions.items()}
    return {"main": solid - union(list(flowers.values())), **flowers}


def headphones():
    # The band goes round the back of the neck on the shoulders and comes
    # forward to the cups, which rest on the chest under the chin.
    pts, normals = [], []
    for k in range(9):
        a = math.radians(70.0 + 220.0 * k / 8)
        pts.append(around(0.088, a, TOP + GAP + 0.006))
        normals.append((0.0, 1.0, 0.0))
    left = [np.array([-0.07, TOP - 0.004, FRONT - 0.012]), np.array([-0.08, TOP + GAP + 0.004, CHEST + 0.02]), around(0.088, math.radians(-70.0), TOP + GAP + 0.006)]
    right = [around(0.088, math.radians(70.0), TOP + GAP + 0.006), np.array([0.08, TOP + GAP + 0.004, CHEST + 0.02]), np.array([0.07, TOP - 0.004, FRONT - 0.012])]
    path = left + list(reversed(pts)) + right
    up = [(0.0, 0.0, -1.0), (0.0, 1.0, 0.0), (0.0, 1.0, 0.0)] + normals + [(0.0, 1.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, -1.0)]
    path, up = smooth_path(path, up, False, 1)
    strap = sweep(path, up, ellipse(0.007, 0.005, 6), False, 0.004)
    cups, pads = [], []
    for sign in (-1.0, 1.0):
        at = (0.074 * sign, TOP - 0.026)
        pads.append(flat_round(0.026, 0.006, FRONT, at))
        cups.append(flat_round(0.025, 0.016, FRONT - 0.006, at))
    return {"ink": strap + union(pads), "main": union(cups)}


def choker():
    collar = shoulder_ring(0.076, 0.104, 0.011)
    tab = rbox(-0.004, TOP - 0.008, -0.108, 0.004, TOP + 0.008, -0.096, 0.002)
    # A cut drop, its few sides catching the light.
    gem = Manifold.sphere(1.0, 10).scale([0.012, 0.015, 0.008]).translate([0.0, TOP - 0.018, FRONT - 0.008])
    return {"main": collar, "gold": tab, "gem": gem}


def bell():
    collar = shoulder_ring(0.072, 0.112, 0.016)
    # A round bell hanging under the chin, with its slot printed on.
    x, y, z = 0.0, TOP - 0.036, FRONT - 0.021
    tab = tube((0.0, TOP + 0.01, -0.106), (0.0, y + 0.03, z), 0.0045, 0.0045, 10)
    body = ball((x, y, z), 0.021, 16)
    slot = rbox(x - 0.016, y - 0.01, z - 0.03, x + 0.016, y - 0.004, z, 0.0015)
    body, slot = printed(body, slot)
    return {"main": collar + tab, "gold": body, "ink": slot}


def big_bow():
    y = TOP - 0.035
    z = FRONT
    wings = []
    for s in (-1.0, 1.0):
        knot_end = blob((0.012 * s, y, z - 0.012), (0.006, 0.012, 0.009), 16)
        far = blob((0.066 * s, y + 0.01, z - 0.012), (0.012, 0.03, 0.011), 16)
        loop_solid = Manifold.batch_hull([knot_end, far])
        # The loop's hole, pressed in.
        dent = blob((0.044 * s, y + 0.006, z - 0.026), (0.016, 0.016, 0.008), 16)
        wings.append(loop_solid - dent)
        tail = flat([(0.004 * s, y - 0.006), (0.016 * s, y - 0.006), (0.04 * s, y - 0.07), (0.022 * s, y - 0.074)], 0.007, z)
        wings.append(tail)
    knot = blob((0.0, y, z - 0.014), (0.015, 0.015, 0.013), 16)
    return {"main": union(wings), "dark": knot}


STYLES = {
    "scarf": scarf,
    "long_scarf": long_scarf,
    "tie": tie,
    "bow_tie": bow_tie,
    "neckerchief": neckerchief,
    "medal": medal,
    "beads": beads,
    "pearls": pearls,
    "spiked_collar": spiked_collar,
    "ruff": ruff,
    "whistle": whistle,
    "pass": race_pass,
    "gold_chain": gold_chain,
    "brooch": brooch,
    "lei": lei,
    "headphones": headphones,
    "choker": choker,
    "bell": bell,
    "big_bow": big_bow,
}
# Styles whose own colour is shiny metal.
METAL = {"gold_chain": 0.6}
