"""The leg styles: the standard hips and legs with each style printed on as
flat colour regions, and a few raised bits where the style needs them, like
boots, knee plates, big feet and skirts. One function a style.

Each leg is made standing, in the rig's space (see figure.py), and turned to
stick straight out for sitting. Skirts and gowns have their own shape for
each pose: a bell standing, a drape over both legs sitting, and a drape round
each leg on its own astride, kept up off the seat and out from between the
legs. Astride and forward (a chopper's pegs) the leg bends at the knee. The
hips stay the same in every pose.

Pieces are made for each side. The hips are on the rig and the legs on the
legs bone, which swings down astride.
"""

import math

import numpy as np
from manifold3d import CrossSection, Manifold, OpType

import figure as F
from shapes import rbox, tube
from torsos import Paint, keep

L = F.LEG_LENGTH
# Where the shoe starts, up from the bottom of the leg.
SHOE = -L + 0.045
# Where boots reach up to.
BOOT_TOP = -L * 0.62
# Where short shorts end, just under the hips.
SHORT_HEM = -0.05
HIPS_FRONT = -F.TORSO_DEPTH * 0.5

COLOURS = {
    "boot": ["#2a2a2a", 0.0],
    "tan": ["#8a5a2b", 0.0],
}

# Leg shapes: half widths at the top and bottom, half depth and the toe's
# half width.
NORMAL = {"top": 0.085, "bottom": 0.079, "depth": 0.065, "toe": 0.079}
THIN = {"top": 0.062, "bottom": 0.056, "depth": 0.056, "toe": 0.06}


# Shapes, standing, in the rig's space.

def _hull(levels, r=0.022, segments=16):
    """A rounded block through boxes at heights: each (y, x0, x1, z0, z1),
    y where the corner balls' middles are."""
    balls = []
    for y, x0, x1, z0, z1 in levels:
        for x in (x0 + r, x1 - r):
            for z in (z0 + r, z1 - r):
                balls.append(Manifold.sphere(r, segments).translate([x, y, z]))
    return Manifold.batch_hull(balls)


def shin(side, shape, grow=0.0, front=0.0, flare=0.0):
    """A leg without its toe, a little narrower at the ankle. `grow` widens it
    and `front` brings its front forward, never its back, so a seated leg
    still sits flat; `flare` widens it out and forward below the knee."""
    s = F.side_sign(side)
    x = F.LEG_X * s
    r = 0.022

    def level(y, half, out=0.0, ahead=0.0):
        lo, hi = x - half - grow, x + half + grow
        if s < 0.0:
            lo -= out
        else:
            hi += out
        return (y, lo, hi, -shape["depth"] - front - ahead, shape["depth"])

    top, bottom = -0.004 - r, -L + r
    if flare > 0.0:
        knee = -0.14
        upper = _hull([level(top, shape["top"]), level(knee, shape["top"])])
        lower = _hull([level(knee, shape["top"]), level(bottom, shape["bottom"], flare, flare * 0.9)])
        return upper + lower
    return _hull([level(top, shape["top"]), level(bottom, shape["bottom"])])


def toe(side, shape, grow=0.0, height=0.062, reach=0.135):
    """The toe, `grow` wider but never taller or further forward, as that's
    where the hands rest sitting."""
    x = F.LEG_X * F.side_sign(side)
    half = shape["toe"] + grow
    return rbox(x - half, -L, -reach, x + half, -L + height, -0.02, 0.022)


def leg(side, shape, flare=0.0):
    return shin(side, shape, flare=flare) + toe(side, shape)


# Where prints go, standing.

def yband(y0, y1):
    return Manifold.cube([2.0, y1 - y0, 2.0]).translate([-1.0, y0, -1.0])


def foot_zone():
    """The shoe: below the shoe line and the toe out in front."""
    return yband(-1.0, SHOE) + Manifold.cube([2.0, 0.08, 1.0]).translate([-1.0, -L - 0.01, -1.067])


def front_zone(z=-0.04):
    return Manifold.cube([2.0, 2.0, 1.0]).translate([-1.0, -1.0, -1.0 + z])


def outer_zone(side, inset):
    """Everything further out than `inset` from the middle of the leg."""
    s = F.side_sign(side)
    edge = F.LEG_X + inset
    return Manifold.cube([1.0, 2.0, 2.0]).translate([edge if s > 0.0 else -edge - 1.0, -1.0, -1.0])


def xband(x0, x1):
    return Manifold.cube([x1 - x0, 2.0, 2.0]).translate([x0, -1.0, -1.0])


def side_circle(side, y, z, r):
    """A spot on the outside of the leg."""
    s = F.side_sign(side)
    disc = CrossSection.circle(r, 10).extrude(0.5).rotate([0.0, 90.0, 0.0])
    # The disc now runs along +x from 0; put it on the outer face.
    edge = F.LEG_X + 0.07
    disc = disc.translate([edge, y, z]) if s > 0.0 else disc.translate([-edge - 0.5, y, z])
    return disc


def hips_front(points, depth=0.03):
    """A print on the front of the hips: the outline as (x, y) points."""
    s = CrossSection([points])
    if s.area() <= 0.0:
        s = CrossSection([list(reversed(points))])
    return s.extrude(0.3 + depth).translate([0.0, 0.0, -0.3 + HIPS_FRONT])


# Skirts, in each pose.

def bell(hem_y, hem_x, hem_front, hem_back):
    """A skirt standing: from the bottom of the hips, the same size as them,
    flaring out to its hem."""
    top = rbox(-0.19, -0.03, -0.1, 0.19, -0.002, 0.1, 0.022)
    hem = rbox(-hem_x, hem_y, -hem_front, hem_x, hem_y + 0.03, hem_back, 0.024)
    return Manifold.batch_hull([top, hem])


def drape(hem_z, x0=-0.196, x1=0.196, low=0.002):
    """A skirt sitting: over the legs from the hips to `hem_z` out in front,
    kept up off the seat, under where the hands rest and stopping short of
    the torso's front, where a belt buckle can be."""
    over = rbox(x0, low, hem_z, x1, 0.137, -0.06, 0.02)
    return over - Manifold.cube([1.0, 0.2, 0.2]).translate([-0.5, 0.127, -0.113])


def drape_round(side, hem_z):
    """A skirt astride: a drape round one leg, its sides ending part way down
    so it stays off the saddle and out from between the legs."""
    if side == 0:
        return drape(hem_z, -0.196, -0.004, 0.035)
    return drape(hem_z, 0.004, 0.196, 0.035)


# A style: what's printed and raised on the hips and legs, and its skirt.

class Style:
    def __init__(self):
        self.shape = NORMAL
        self.flare = 0.0
        # Each step is ("paint", region, zone(side)) or ("raise", region,
        # solid(side)), done in order on the standing leg.
        self.steps = []
        self.hips = []
        self.skirt = None

    def paint(self, region, zone):
        self.steps.append(("paint", region, zone if callable(zone) else (lambda side, z=zone: z)))
        return self

    def raise_(self, region, solid):
        self.steps.append(("raise", region, solid))
        return self

    def foot(self, region):
        return self.paint(region, foot_zone())


def boots(st, region, grow=0.006):
    """Raised boots from BOOT_TOP down, grown out round the leg, and only a
    little at the front, which is the top sitting, under the hands. The toe
    stays the leg's own."""
    def solid(side):
        b = shin(side, st.shape, grow, 0.003) ^ yband(-1.0, BOOT_TOP)
        return b + toe(side, st.shape)
    # The leg under the boot is painted first: the boot's back and toe are
    # the leg's own, and only cutting the leg by them leaves slivers there.
    st.paint(region, yband(-1.0, BOOT_TOP))
    return st.raise_(region, solid)


def knee(st, region, z0, y0=-0.18, y1=-0.12, half=0.05, r=0.006):
    """A raised plate on the front of the knee, out to `z0`."""
    def solid(side):
        x = F.LEG_X * F.side_sign(side)
        return rbox(x - half, y0, z0, x + half, y1, -st.shape["depth"] + 0.006, r)
    return st.raise_(region, solid)


def trousers(st):
    pass


def shorts(st):
    st.paint("skin", yband(-1.0, -L * 0.4)).foot("white")
    st.paint("ink", yband(-1.0, -L + 0.01))


def big_boots(st):
    boots(st, "boot")


def skinny(st):
    st.shape = THIN
    st.foot("boot")


def jeans(st):
    for s in (-1.0, 1.0):
        pocket = [(0.07 * s, 0.075), (0.16 * s, 0.075), (0.16 * s, 0.035), (0.12 * s, 0.035)]
        st.hips.append(("light", hips_front(pocket)))
    st.hips.append(("light", hips_front([(-0.003, 0.0), (0.003, 0.0), (0.003, 0.06), (-0.003, 0.06)])))
    st.paint("light", lambda side: xband(F.LEG_X * F.side_sign(side) + 0.045 * F.side_sign(side) - 0.003, F.LEG_X * F.side_sign(side) + 0.045 * F.side_sign(side) + 0.003) ^ front_zone() ^ yband(SHOE + 0.03, 0.0))
    st.paint("light", yband(SHOE + 0.012, SHOE + 0.03))


def gown(st):
    st.skirt = "long"


def skirt(st):
    st.skirt = "short"
    st.paint("skin", yband(-1.0, -0.1))
    st.foot("boot")


def skirt_socks(st):
    st.skirt = "short"
    st.paint("skin", yband(-1.0, -0.1))
    sock_print(st)


def short_shorts(st):
    st.paint("skin", yband(-1.0, SHORT_HEM)).foot("white")
    st.paint("ink", yband(-1.0, -L + 0.01))


def short_shorts_socks(st):
    st.paint("skin", yband(-1.0, SHORT_HEM))
    sock_print(st)


def kilt(st):
    st.skirt = "kilt"
    st.paint("skin", yband(-1.0, -0.1))
    st.paint("white", yband(-1.0, -0.17))
    st.foot("boot")


def dino_feet(st):
    def foot(side):
        x = F.LEG_X * F.side_sign(side)
        # No further forward than the usual toe with its claws, which is the
        # top sitting, under where the hands hold.
        # Wider only on the inside, as the hands rest just outside the toes.
        s = F.side_sign(side)
        lo, hi = sorted((x + 0.079 * s, x - 0.088 * s))
        return rbox(lo, -L, -0.116, hi, -L + 0.062, -0.01, 0.024)

    def claws(side):
        x = F.LEG_X * F.side_sign(side)
        out = []
        for k in (-1, 0, 1):
            cx = x - F.side_sign(side) * 0.006 + k * 0.05
            out.append(tube((cx, -L + 0.026, -0.108), (cx, -L + 0.026, -0.135), 0.017, 0.002, 10))
        return out[0] + out[1] + out[2]
    st.raise_("main", foot)
    st.raise_("white", claws)


def robot_legs(st):
    st.hips.append(("dark", yband(0.03, 0.05)))
    st.paint("dark", yband(-0.165, -0.135))
    for y in (-0.06, -0.23):
        st.paint("silver", lambda side, y=y: side_circle(side, y, 0.0, 0.011))
    st.foot("dark")
    knee(st, "dark", -0.073, -0.2, -0.1, 0.05)


def armoured(st):
    st.hips.append(("dark", yband(0.03, 0.052)))
    boots(st, "boot")
    knee(st, "silver", -0.077, -0.175, -0.1, 0.06, 0.01)


def stripy(st):
    for k in range(4):
        y = -0.035 - k * 0.05
        st.paint("white", yband(y - 0.018, y))
    st.foot("boot")


def flares(st):
    st.flare = 0.016
    st.foot("boot")


def cowboy(st):
    st.hips.append(("brown", yband(0.042, 0.072)))
    st.hips.append(("gold", hips_front([(-0.024, 0.04), (0.024, 0.04), (0.024, 0.074), (-0.024, 0.074)])))
    st.paint("tan", lambda side: (front_zone(-0.03) + outer_zone(side, 0.04)) ^ yband(BOOT_TOP, -0.012))
    boots(st, "brown")


def sneakers(st):
    st.foot("white")
    st.paint("ink", yband(-1.0, -L + 0.012))


def barefoot(st):
    st.paint("skin", yband(-1.0, -L * 0.6))
    st.paint("light", yband(-L * 0.6, -L * 0.6 + 0.022))


def racing_boots(st):
    st.paint("white", lambda side: outer_zone(side, 0.068) ^ yband(BOOT_TOP, -0.01))
    boots(st, "boot")
    st.paint("white", yband(BOOT_TOP - 0.018, BOOT_TOP + 0.001))


def socks(st):
    st.paint("skin", yband(-1.0, -L * 0.4))
    sock_print(st)


def sock_print(st):
    """Long white socks with two stripes at the top, and shoes."""
    st.paint("white", yband(-1.0, -L * 0.55))
    for y in (-L * 0.55 - 0.012, -L * 0.55 - 0.032):
        st.paint("main", yband(y - 0.01, y))
    st.foot("boot")


def overalls(st):
    st.hips.append(("dark", hips_front([(-0.05, 0.072), (0.05, 0.072), (0.05, 0.068), (-0.05, 0.068)])))
    st.paint("light", yband(SHOE + 0.005, SHOE + 0.03))
    st.foot("boot")


def leggings(st):
    st.shape = THIN
    st.paint("white", lambda side: outer_zone(side, 0.05) ^ yband(SHOE, 0.0))


STYLES = {
    "trousers": trousers,
    "shorts": shorts,
    "boots": big_boots,
    "skinny": skinny,
    "jeans": jeans,
    "gown": gown,
    "skirt": skirt,
    "kilt": kilt,
    "dino_feet": dino_feet,
    "robot_legs": robot_legs,
    "armoured": armoured,
    "stripy": stripy,
    "flares": flares,
    "cowboy": cowboy,
    "sneakers": sneakers,
    "barefoot": barefoot,
    "racing_boots": racing_boots,
    "socks": socks,
    "overalls": overalls,
    "leggings": leggings,
    "skirt_socks": skirt_socks,
    "short_shorts": short_shorts,
    "short_shorts_socks": short_shorts_socks,
}
# Styles whose own colour is shiny.
METAL = {"robot_legs": 0.5}
POSES = ("standing", "seated", "astride", "forward")


# Making them.

def seat(shape):
    """Turns a standing leg forward so it sticks straight out, its back on
    the seat."""
    b = F.rot_x(math.pi * 0.5)
    return np.hstack([b, np.array([[0.0], [shape["depth"]], [0.0]])])


def ride(solid, side, pose, top, whole=None):
    """A seated leg (or what's on it) riding a bike in `pose` (see
    figure.RIDES): cut at the knee, the thigh swung down and out and the
    shin bent down from it. `top` is how high the seated leg's top is.
    `whole` is the whole seated leg, when `solid` is one region of it."""
    thigh_m, shin_m = F.ride_leg(side, pose, top)
    thigh = solid.trim_by_plane([0.0, 0.0, 1.0], F.KNEE_Z).transform(thigh_m)
    shin = solid.trim_by_plane([0.0, 0.0, -1.0], -F.KNEE_Z).transform(shin_m)
    if whole is not None:
        # Where the bent knee folds the thigh into the shin, each is cut back
        # from the other, so neither has faces just under the other's, which
        # would flicker through. The cuts are inside, so they don't show.
        thigh_whole = whole.trim_by_plane([0.0, 0.0, 1.0], F.KNEE_Z).transform(thigh_m)
        thigh = thigh - whole.trim_by_plane([0.0, 0.0, -1.0], -F.KNEE_Z).transform(shin_m).as_original()
        shin = shin - thigh_whole.as_original()
    # Lightly simplified, since the cut adds triangles.
    return (thigh + shin).simplify(0.0001)


def _paint(regions, name, zone):
    """Paints what's inside `zone` in a region. The rest is cut by the zone
    itself, not by what's inside it, which would leave thin sheets where the
    two share the surface."""
    for k in list(regions):
        if k == name:
            continue
        inside = regions[k] ^ zone
        if inside.is_empty():
            continue
        regions[k] = regions[k] - zone
        regions[name] = regions[name] + inside if name in regions else inside


def _cover(regions, name, solid):
    """Puts a raised bit or a skirt over the regions, in its own."""
    for k in list(regions):
        regions[k] = regions[k] - solid
    regions[name] = regions[name] + solid if name in regions else solid


def _cover_cut(regions, name, solid, keepout):
    """Like _cover, for a skirt on a seated leg: the regions are cut by the
    whole skirt and the skirt then by `keepout`, so the leg's cut against the
    hips doesn't stay under the skirt's, in the same place."""
    for k in list(regions):
        regions[k] = regions[k] - solid
    solid = solid - keepout
    regions[name] = regions[name] + solid if name in regions else solid


def _place(regions, m):
    return {k: v.transform(np.asarray(m, float)) for k, v in regions.items()}


def _half(solid, side):
    return solid.trim_by_plane([-1.0, 0.0, 0.0] if side == 0 else [1.0, 0.0, 0.0], 0.0)


def make(style, hips_solid, keepout):
    """A style's hips (in colour regions) and its legs, by pose and side:
    {"hips": regions, ("seated", 0): regions, ...}. `keepout` is what seated
    legs are cut back from (make_characters.leg_keepout, marked to show)."""
    st = Style()
    STYLES[style](st)
    hips = Paint(keep(hips_solid))
    for region, zone in st.hips:
        # A region starting with + is raised.
        if region.startswith("+"):
            hips.add(region[1:], zone)
        else:
            hips.paint(region, zone)
    out = {"hips": hips.done()}
    m = seat(st.shape)
    for side in (0, 1):
        regions = {"main": keep(leg(side, st.shape, st.flare))}
        for kind, region, make_zone in st.steps:
            if kind == "paint":
                _paint(regions, region, make_zone(side))
            else:
                _cover(regions, region, keep(make_zone(side)))
        standing = {k: v for k, v in regions.items() if not v.is_empty()}
        seated = {k: v - keepout for k, v in _place(standing, m).items()}
        astride = dict(seated)
        if st.skirt:
            standing = dict(standing)
            long = st.skirt == "long"
            b = _half(keep(bell(-L if long else -0.125, 0.25 if long else 0.218, 0.21 if long else 0.138, 0.19 if long else 0.13)), side)
            _cover(standing, "main", b)
            # Sitting, the hips take up the top of the thigh, so a short skirt
            # reaches further along the leg than standing to show as much.
            hem_z = -0.236 if long else -0.2
            seated = dict(seated)
            _cover_cut(seated, "main", _half(keep(drape(hem_z)), side), keepout)
            astride = dict(astride)
            _cover_cut(astride, "main", keep(drape_round(side, hem_z)), keepout)
            if long:
                _paint(standing, "gold", yband(-1.0, -L + 0.022))
                for regions_ in (seated, astride):
                    _paint(regions_, "gold", Manifold.cube([2.0, 2.0, 0.022]).translate([-1.0, -1.0, hem_z]))
            if st.skirt == "kilt":
                for x in (-0.15, -0.07, 0.07, 0.15):
                    _paint(standing, "dark", xband(x - 0.003, x + 0.003) ^ yband(-0.126, -0.01))
                    for regions_ in (seated, astride):
                        _paint(regions_, "dark", xband(x - 0.003, x + 0.003) ^ yband(0.1, 1.0) ^ Manifold.cube([2.0, 2.0, 1.0]).translate([-1.0, -1.0, -1.0 - 0.105]))
                # A pouch on the front, half on each side.
                sporran = Manifold.batch_hull([rbox(-0.03, -0.03, -0.124, 0.03, -0.015, -0.1, 0.008), rbox(-0.03, -0.085, -0.15, 0.03, -0.07, -0.124, 0.008)])
                _cover(standing, "brown", _half(keep(sporran), side))
                lap = _half(keep(rbox(-0.03, 0.13, -0.175, 0.03, 0.156, -0.112, 0.008)), side)
                _cover(seated, "brown", lap)
                _cover(astride, "brown", lap)
        top = 2.0 * st.shape["depth"]
        # The whole leg as it rides, skirt and all, which the thigh and shin
        # are cut back from at the knee (see ride).
        whole = Manifold.batch_boolean(list(astride.values()), OpType.Add)
        forward = {k: ride(v, side, "forward", top, whole) - keepout for k, v in astride.items()}
        astride = {k: ride(v, side, "astride", top, whole) - keepout for k, v in astride.items()}
        if st.skirt:
            # A little simpler, so the drape cut at the knee stays under 1,500 triangles.
            astride = {k: v.simplify(0.0004) for k, v in astride.items()}
        for pose, regions_ in (("standing", standing), ("seated", seated), ("astride", astride), ("forward", forward)):
            out[(pose, side)] = {k: v for k, v in regions_.items() if not v.is_empty() and v.volume() > 1e-9}
    return out
