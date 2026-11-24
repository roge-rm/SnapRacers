"""The arm styles: the one-piece bent arm and the C hand, in colour regions,
each in its bone's own space (see figure.py), made for each side. Sleeves,
cuffs, stripes and gloves are flat colour regions; a few styles have a raised
bit on the outside of the arm, like a rolled cuff, a watch or a shoulder pad,
cut back so it never meets the body as the arm swings.

What a style shows comes from its settings in data/characters/pieces.json:
`sleeve` (long, short, rolled or none), `hands` (skin, dark, white, colour
or metal) and flags like `stripes` or `watch`.
"""

import json
import math
import os

import numpy as np
from manifold3d import Manifold

import figure as F
from shapes import ball, tube
from torsos import Paint

PIECES = os.path.join(F.GAME, "data", "characters", "pieces.json")
# Where a short sleeve ends, down from the shoulder pivot.
SHORT = -0.06


def settings():
    with open(PIECES) as f:
        return json.load(f)["arms"]


class Path:
    """The middle of the forearm, from the elbow forward and then in to its
    end, the way make_characters.arm makes it."""

    def __init__(self, side):
        self.side = side
        self.s = F.side_sign(side)
        elbow = F.elbow(side)
        d = F.forearm_dir(side)
        end = F.wrist(side) - d * 0.013
        mid = elbow + (F.wrist(side) - elbow) * 0.6
        mid[0] = elbow[0]
        self.points = [elbow, mid, end]
        self.lengths = [float(np.linalg.norm(mid - elbow)), float(np.linalg.norm(end - mid))]
        self.length = sum(self.lengths)

    def at(self, t):
        """The point t along from the elbow, and the way the arm goes there."""
        if t <= self.lengths[0]:
            a, b, u = self.points[0], self.points[1], t / self.lengths[0]
        else:
            a, b, u = self.points[1], self.points[2], (t - self.lengths[0]) / self.lengths[1]
        along = (b - a) / np.linalg.norm(b - a)
        return a + (b - a) * u, along

    def band(self, t0, t1):
        """Everything between t0 and t1 along the forearm (t1 past the end
        reaches past it)."""
        p0, n0 = self.at(max(t0, 0.0))
        p1, n1 = self.at(min(t1, self.length))
        if t1 >= self.length:
            p1 = p1 + n1 * 0.05
        box = Manifold.cube([0.4, 0.4, 0.4], True).translate(list((p0 + p1) * 0.5))
        return (box ^ forearm(self.side)).trim_by_plane(list(n0), float(n0.dot(p0))).trim_by_plane(list(-n1), float(-n1.dot(p1)))

    def ring(self, t0, t1, r):
        """A raised ring around the forearm from t0 to t1, radius r."""
        p0, _ = self.at(t0)
        p1, _ = self.at(t1)
        return tube(p0, p1, r, r, 24)


def upper_band(y0, y1):
    """A band round the upper arm between two heights below the shoulder."""
    return Manifold.cube([0.4, y1 - y0, 0.4]).translate([-0.2, y0, -0.2])


def below(y):
    return Manifold.cube([0.4, 0.4, 0.4]).translate([-0.2, y - 0.4, -0.2])


def forearm(side):
    """The forearm's side of the elbow (see make_characters.arm_regions)."""
    elbow = F.elbow(side)
    d = F.forearm_dir(side)
    n = elbow / np.linalg.norm(elbow) + d
    n /= np.linalg.norm(n)
    return Manifold.cube([0.6, 0.6, 0.6], True).trim_by_plane(list(n), float(n.dot(elbow)))


def outside(side, solid):
    """What of a raised bit is on the outer side of the arm."""
    s = F.side_sign(side)
    return solid.trim_by_plane([s, 0.0, 0.0], 0.006)


HAND_REGION = {"skin": "skin", "dark": "ink", "white": "white", "colour": "main", "metal": "main"}


def make(side, arm, hand, flags):
    """An arm style's regions for the arm and the hand, from its settings.
    `arm` and `hand` are the bare figure's solids. Raised bits are given
    apart, to be cut back from the body."""
    s = F.side_sign(side)
    path = Path(side)
    p = Paint(arm)
    raised = {}

    def lift(region, solid):
        raised[region] = raised[region] + solid if region in raised else solid

    sleeve = flags.get("sleeve", "long")
    if sleeve == "none":
        p.paint("skin", Manifold.cube([1.0, 1.0, 1.0], True))
    elif sleeve == "short":
        p.paint("skin", below(SHORT))
    elif sleeve == "rolled":
        p.paint("skin", forearm(side))
        lift("main", outside(side, path.ring(0.006, 0.03, 0.047)))
    if flags.get("two_tone"):
        p.paint("dark", forearm(side))
    if flags.get("gauntlet") == "white":
        # Under a rolled cuff the glove starts lower, with skin between.
        top, ring = (0.045, 0.059) if sleeve == "rolled" else (0.012, 0.026)
        p.paint("white", path.band(top, 1.0))
        lift("white", outside(side, path.ring(top, ring, 0.045)))
    if flags.get("stripes"):
        for y in (-0.04, -0.07):
            p.paint("white", upper_band(y - 0.007, y + 0.007))
        p.paint("white", path.band(path.length - 0.05, path.length - 0.034))
    if flags.get("wraps"):
        for k in range(2):
            p.paint("white", path.band(0.035 + k * 0.045, 0.06 + k * 0.045))
    cuff = flags.get("cuff", "")
    if cuff == "colour":
        p.paint("main", path.band(path.length - 0.028, 1.0))
        lift("main", outside(side, path.ring(path.length - 0.026, path.length - 0.004, 0.04)))
    elif cuff == "dark":
        p.paint("ink", path.band(path.length - 0.045, 1.0))
        p.paint("light", path.band(path.length - 0.05, path.length - 0.045))
    if flags.get("watch"):
        p.paint("ink", path.band(path.length - 0.03, path.length - 0.014))
        at, along = path.at(path.length - 0.022)
        # The face on the outside of the wrist.
        out = np.array([s, 0.0, 0.0]) - along * along[0] * s
        out /= np.linalg.norm(out)
        lift("silver", tube(at + out * 0.028, at + out * 0.043, 0.014, 0.014, 16))
    if flags.get("bracer") == "spikes":
        p.paint("ink", path.band(0.03, 0.095))
        lift("ink", outside(side, path.ring(0.034, 0.09, 0.045)))
        for k in range(3):
            at, along = path.at(0.042 + k * 0.022)
            out = np.array([s, 0.0, 0.0]) - along * along[0] * s
            out /= np.linalg.norm(out)
            lift("silver", tube(at + out * 0.04, at + out * 0.058, 0.008, 0.002, 10))
    if flags.get("pads"):
        pad = ball((0.017 * s, -0.004, 0.0), 0.054, 24) - below(-0.04)
        lift("main", outside(side, pad))
        p.paint("dark", upper_band(-0.05, -0.044))
    if flags.get("puff"):
        puff = ball((0.02 * s, -0.012, 0.0), 0.053, 24) - below(SHORT + 0.004)
        lift("main", outside(side, puff))
    if flags.get("fur"):
        p.paint("light", path.band(path.length - 0.03, 1.0))
        p.paint("light", Manifold.cube([0.4, 0.4, 0.4]).translate([-0.2, -0.03, -0.2]))
        lift("light", outside(side, path.ring(path.length - 0.03, path.length - 0.006, 0.041)))
    if flags.get("scales"):
        # Rows of scales printed down the outside of the arm.
        for k in range(3):
            y = -0.035 - k * 0.026
            p.paint("light", chevron(side, y))
        for k in range(3):
            at, along = path.at(0.03 + k * 0.03)
            p.paint("light", chevron(side, at[1], at[2]))
    if flags.get("tattoo"):
        p.paint("blue", anchor(side, -0.07))
    if flags.get("metal") and not flags.get("pads"):
        # Joints printed at the elbow and shoulder.
        p.paint("dark", path.band(0.0, 0.01))
        p.paint("dark", upper_band(-0.05, -0.044))
    hand_region = HAND_REGION.get(flags.get("hands", "skin"), "skin")
    if flags.get("metal") and "hands" not in flags:
        hand_region = "main"
    return p.done(), raised, {hand_region: hand}


def chevron(side, y, z=0.0):
    """A small V printed on the outside of the arm at a height."""
    pts = [(z - 0.014, y + 0.008), (z, y - 0.004), (z + 0.014, y + 0.008), (z + 0.014, y), (z, y - 0.012), (z - 0.014, y)]
    return _side_print(side, pts)


def anchor(side, y):
    """A small anchor printed on the outside of the upper arm."""
    pts = [(z * 1.5, y + (v - y) * 1.5) for z, v in [
        (-0.003, y + 0.022), (0.003, y + 0.022), (0.003, y + 0.014), (0.011, y + 0.014), (0.011, y + 0.009),
        (0.003, y + 0.009), (0.003, y - 0.012), (0.012, y - 0.004), (0.016, y - 0.008), (0.0, y - 0.02),
        (-0.016, y - 0.008), (-0.012, y - 0.004), (-0.003, y - 0.012), (-0.003, y + 0.009), (-0.011, y + 0.009),
        (-0.011, y + 0.014), (-0.003, y + 0.014),
    ]]
    return _side_print(side, pts)


def _side_print(side, pts):
    """A print on the outside of the arm, the outline as (z, y) points."""
    from torsos import poly
    s = F.side_sign(side)
    solid = poly(pts).extrude(0.2)
    # The outline is in z, y; turn it so it goes along x, outward.
    m = np.array([[0.0, 0.0, 1.0, 0.0], [0.0, 1.0, 0.0, 0.0], [1.0, 0.0, 0.0, 0.0]])
    solid = solid.transform(m)
    return solid.translate([0.02 if s > 0 else -0.22, 0.0, 0.0])
