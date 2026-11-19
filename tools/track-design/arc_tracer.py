#!/usr/bin/env python3
"""Traces a real circuit again with the newer pieces: arcs of 15 to 90 degrees
in all four sizes, whole, half and quarter straights, closed off with an
adjustable offset before the start.

Usage: arc_tracer.py <osm name> <out.txt> [beam] [stray] [tight] [scale]

Follows <osm name>_aligned.json (written by tracer.py, start at the origin
facing north), times scale. A beam search lays pieces one at a time, keeping
the ones closest to the real line, never closer than a tile to road laid
earlier, and comes back to the start on the 15 degree heading grid. `stray`
is how far in metres the road may leave the real line (25 by default),
`tight` how much a tight bend (16 m) costs on top (60 by default).
In the environment, CLEAR is how far apart two bits of road stay middle to
middle (33 m), SMOOTH how far either way the real line is smoothed (12 m),
EACH what each piece costs (250) and START the tiles of straight laid first (2).
BRIDGE=<from>,<to> lets road between those metres of the real line pass
over road laid earlier, for a bridge; the climb and drop (^1, ^-1) go in
by hand. More than one bridge goes as BRIDGE=<from>,<to>;<from>,<to>.
FORCE=<piece>:<from>:<to>[,...] makes the lap use that piece once, starting
between those metres of the real line: J for a jump (laid like a 96 m
straight), JR or JL for a jump split (a 128 m straight), OL or OR for a
loop, or any piece above, like A90R2 for a bend to bank. The piece comes
out marked with a star, to swap by hand.

The Baseplate cup came from beam 300, with stray 35 and CLEAR=31.6 for
Pithead Park and tight 400 for Lemon Lake. In the Gearbox cup Timberline
is at scale 0.95, Dune Drift has BRIDGE=870,1010, and Whistlestop Woods has
CLEAR=31.6 SMOOTH=20 on its line turned round to run clockwise like the real
one (its aligned line reversed, with the start on its longest straight).
In the Keystone cup each line was turned so its start straight faces north,
Windmill Ridge has FORCE=A90R2:40:90 (its wall ride), Magma Mile FORCE=J:110:140
at scale 0.92, Launchpad Loop CLEAR=31.6 FORCE=OL:520:600 with stray 40 at
scale 1.12 on its line turned round to run clockwise, and Castle Keep tight 300,
with its jump put in by hand over the last three straights.
In the Gravel cup each OSM line was joined by hand from the ways of the
real lap, scaled 1.45 to 1.7 and turned so its start straight faces north,
Menhir Meadow with START=3 FORCE=JR:740:1000, Oast Hill FORCE=J:600:660 and
Pine Hill Leap START=3 FORCE=J:1320:1400.
In the Hangar cup Neon Nights is at scale 0.91 with CLEAR=31.6 and stray 35,
its tight hook at the far end tidied by hand. The other three halls are too
tight to follow with whole tiles at about 1700 m, so they were laid by hand
in the style of the real ones.
In the Corkscrew cup the coasters' legs run too close together to follow, so
Serpent Summit (scale 1.2) and Lakeshore Plunge (scale 0.95) were traced on
lines with the legs pushed 40 m apart, Red Rocket on a line drawn by hand in
the style of the real one with BRIDGE=760,800;1085,1125 and stray 20, and
Twister Pines on the old course's line with stray 30 and three bridges. The
corkscrews, loops and wall rides went in by hand.
In the Island cup each line was turned so its start straight faces north and
traced with SMOOTH=20 EACH=800: Windsurf Way CLEAR=31.6 with stray 35 and
tight 200 at scale 0.97, Coral Cove stray 35 and tight 400 at scale 1.07,
Blue Lagoon stray 30 and tight 150 at scale 0.93, and Penguin Point (the whole
GP circuit, its line already scaled down to about 1.7 km) tight 1000 at
scale 1.03, with the crest on the straight and a wider 45 put in by hand.
In the Alpine cup the lines were traced with SMOOTH=20: Cowbell Meadow
EACH=800 with stray 35 and tight 400 at scale 1.0, Gondola Gorge EACH=500
START=3 with stray 40 and tight 100 at scale 0.98, a stretch near the far leg
then moved out by hand, and Summit Switchback CLEAR=31.6 EACH=800 with stray
30 and tight 150 at scale 1.0. Slalom Slopes is laid by hand round the small
summer track scaled up to a whole lap. The slaloms, jump, ramps and rise bends
went in by hand.
In the Canyon cup the lines were traced with SMOOTH=20 EACH=800: Cactus Canyon
with stray 35 and tight 400 at scale 1.0, Rattlesnake Ridge on its line turned
so its start straight faces north, stray 40 and tight 800 at scale 1.13, Mirage
Mesa stray 35 and tight 400 at scale 1.0, and Gold Rush Gulch BRIDGE=1520,1690
FORCE=S2:660:700 with stray 35 and tight 400 at scale 1.07. Gold Rush Gulch's
line was joined by hand: way 879902542 to node 24, way 879902543 backwards,
then 879902542 from node 26, and aligned at scale 1.5. The crossings, banked
bowl, rim, crests, bridge climb, dirt split and rise bends went in by hand.
In the Jungle cup the lines were traced with SMOOTH=20 EACH=800 at scale 1.0:
Parrot Perch and Cascade Creek with beam 600, stray 35 and tight 400, Pyramid
Plunge the same with FORCE=J:1380:1480, and Monsoon Mire CLEAR=31.6 with beam
400, stray 40 and tight 200, on its line with the inner leg from 700 to 980 m
moved 8 m out so it clears the start straight. The raised bend, jump, banking,
mud pieces and closing slants went in by hand.
"""
import json, math, os, sys
import numpy as np

TILE = 32.0
here = os.path.dirname(os.path.abspath(__file__))
name, out = sys.argv[1], sys.argv[2]
BEAM = int(sys.argv[3]) if len(sys.argv) > 3 else 600
STRAY = float(sys.argv[4]) if len(sys.argv) > 4 else 25.0
TIGHT = float(sys.argv[5]) if len(sys.argv) > 5 else 60.0
SCALE = float(sys.argv[6]) if len(sys.argv) > 6 else 1.0
CLEAR = float(os.environ.get("CLEAR", "33"))
# Road this far back along the lap is what a piece joins onto, so it can be close.
JOINING = 100.0
BRIDGE = [[float(v) for v in r.split(",")] for r in os.environ.get("BRIDGE", "").split(";") if r]

real = np.array(json.load(open(os.path.join(here, name + "_aligned.json")))) * SCALE
if SCALE != 1.0:
    seg = np.linalg.norm(np.diff(real, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    ss = np.arange(0, s[-1], 1.0)
    real = np.stack([np.interp(ss, s, real[:, 0]), np.interp(ss, s, real[:, 1])], axis=1)
# Smoothed over SMOOTH metres either way, which takes out the wobble in
# the mapped line.
SMOOTH = int(os.environ.get("SMOOTH", "12"))
if SMOOTH:
    k = np.ones(2 * SMOOTH + 1) / (2 * SMOOTH + 1)
    wrap = np.vstack([real[-SMOOTH:], real, real[:SMOOTH]])
    real = np.stack([np.convolve(wrap[:, 0], k, "valid"), np.convolve(wrap[:, 1], k, "valid")], axis=1)
n = len(real)
total = float(n)
# Cost of each piece, so it takes longer pieces where they fit nearly as well.
EACH = float(os.environ.get("EACH", "250"))
# Tiles of straight laid first, for the start.
START = int(os.environ.get("START", "2"))
# The real line twice round, so a window past the start doesn't wrap.
REAL2 = np.vstack([real, real])
REAL_SQ = (REAL2 * REAL2).sum(axis=1)

# Pieces: token, local points (right, forward) about every 2 m, exit, turn in
# 15 degree steps (right positive) and length.
PIECES = []
for token, run in (("S1", TILE), ("S2", 2 * TILE), ("S3", 3 * TILE), ("H", TILE / 2), ("Q", TILE / 4)):
    k = max(2, int(run / 2))
    PIECES.append((token, np.array([(0.0, run * (i + 1) / k) for i in range(k)]), (0.0, run), 0, run))
for size in (1, 2, 3, 4):
    r = (size - 0.5) * TILE
    for angle in (15, 30, 45, 60, 75, 90):
        a_end = math.radians(angle)
        length = r * a_end
        k = max(3, int(length / 2))
        for turn, letter in ((1, "R"), (-1, "L")):
            pts = [(turn * (r - r * math.cos(a)), r * math.sin(a)) for a in np.linspace(0, a_end, k + 1)[1:]]
            PIECES.append(("A%d%s%d" % (angle, letter, size), np.array(pts), pts[-1], turn * angle // 15, length))


# Pieces the lap has to use once (FORCE), and where.
FORCED = {}
for f in filter(None, os.environ.get("FORCE", "").split(",")):
    token, a, b = f.split(":")
    FORCED[token] = (float(a), float(b))
    if token == "J":
        PIECES.append(("J", np.array([(0.0, 96.0 * (i + 1) / 48) for i in range(48)]), (0.0, 96.0), 0, 96.0))
    elif token in ("JR", "JL"):
        # A jump split, laid like a 128 m straight.
        PIECES.append((token, np.array([(0.0, 128.0 * (i + 1) / 64) for i in range(64)]), (0.0, 128.0), 0, 128.0))
    elif token in ("OL", "OR"):
        # A loop comes out a tile to its side, easing across its middle.
        side = 1 if token == "OR" else -1
        ts = np.linspace(0, 1, 49)[1:]
        pts = [(side * TILE * (u * u * (3 - 2 * u)), 3 * TILE * t) for t, u in ((t, min(max((t - 0.3) / 0.4, 0.0), 1.0)) for t in ts)]
        PIECES.append((token, np.array(pts), pts[-1], 0, 3 * TILE))
HEADINGS = [(round(math.sin(math.radians(k * 15)), 12), round(math.cos(math.radians(k * 15)), 12)) for k in range(24)]


def heading(steps):
    return HEADINGS[steps]


class Beam:
    __slots__ = ("x", "y", "steps", "s", "cost", "tokens", "chunks", "dist")


def place(b, piece):
    _, pts, ex, turn, length = piece
    hx, hy = heading(b.steps)
    rx, ry = hy, -hx
    world = np.stack([b.x + rx * pts[:, 0] + hx * pts[:, 1], b.y + ry * pts[:, 0] + hy * pts[:, 1]], axis=1)
    end = (b.x + rx * ex[0] + hx * ex[1], b.y + ry * ex[0] + hy * ex[1])
    return world, end, (b.steps + turn) % 24


def clear_of_old(b, world, along0, coming_home):
    lo, hi = world.min(axis=0) - CLEAR, world.max(axis=0) + CLEAR
    for (blo, bhi, pts, a0, a1) in b.chunks:
        if a0 >= along0 - JOINING or (coming_home and a1 <= JOINING):
            continue
        if blo[0] > hi[0] or bhi[0] < lo[0] or blo[1] > hi[1] or bhi[1] < lo[1]:
            continue
        if a1 > along0 - JOINING or (coming_home and a0 < JOINING):
            along = np.linspace(a0, a1, len(pts) + 1)[1:]
            ok = along < along0 - JOINING
            if coming_home:
                ok &= along > JOINING
            pts = pts[ok]
            if not len(pts):
                continue
        dd = np.linalg.norm(world[:, None, :] - pts[None, :, :], axis=2)
        if dd.min() < CLEAR:
            return False
    return True


def step(b, piece):
    world, end, steps = place(b, piece)
    length = piece[4]
    lo = int(b.s)
    hi = min(int(b.s + length * 1.6 + 20), n + 60)
    ref = REAL2[lo:hi]
    d2 = (world * world).sum(axis=1)[:, None] + REAL_SQ[lo:hi][None, :] - 2.0 * (world @ ref.T)
    near2 = d2.min(axis=1)
    if near2.max() > STRAY * STRAY:
        return None
    near = np.sqrt(np.maximum(near2, 0.0))
    s_end = lo + int(np.argmin(d2[-1]))
    if s_end <= b.s + length * 0.3:
        return None
    along0 = b.dist
    over = any(b.s < z and s_end > a for a, z in BRIDGE)
    if not over and not clear_of_old(b, world, along0, s_end > total - 3 * TILE):
        return None
    token = piece[0]
    if token in ("J", "JR", "JL", "OL", "OR") and (not FORCED[token][0] <= b.s <= FORCED[token][1] or token + "*" in b.tokens):
        return None
    # Past a forced piece's stretch without it, this lap can't be used.
    for want, (a, z) in FORCED.items():
        if b.s <= z < s_end and want + "*" not in b.tokens and not (token == want and a <= b.s <= z):
            return None
    nb = Beam()
    nb.x, nb.y = end
    nb.steps = steps
    nb.s = s_end
    extra = EACH
    tok = piece[0]
    if tok.endswith("1") and tok.startswith("A"):
        extra += TIGHT
    if tok in ("H", "Q"):
        extra += 20.0
    # Keep turns in one piece where they can be: a bend straight after one
    # the same way and size costs more.
    last = b.tokens[-1] if b.tokens else ""
    if tok.startswith("A") and last.startswith("A") and last[-2:] == tok[-2:]:
        extra += 100.0
    # A small flick one way straight after a small one the other is a wiggle.
    if tok.startswith("A") and last.startswith("A") and last[-2] != tok[-2] and int(tok[1:3]) <= 30 and int(last[1:3]) <= 30:
        extra += 200.0
    if tok in FORCED and FORCED[tok][0] <= b.s <= FORCED[tok][1] and tok + "*" not in b.tokens:
        tok += "*"
        extra -= EACH
    nb.cost = b.cost + float((near ** 2).sum()) * 2.0 + extra
    nb.tokens = b.tokens + [tok]
    nb.chunks = b.chunks + [(world.min(axis=0), world.max(axis=0), world, along0, along0 + length)]
    nb.dist = along0 + length
    return nb


def close(b):
    """Closes the lap with an adjustable offset (or straight) straight into the
    start, if it can from here."""
    if b.steps != 0 or b.y > -24 or b.s < total - 220:
        return None
    metres = -b.y
    shift = -b.x
    if abs(shift) > 0.05 and metres * metres < 150 * abs(shift):
        return None
    k = max(2, int(metres / 2))
    t = np.linspace(0, 1, k + 1)[1:]
    smooth = t ** 3 * (10 + t * (-15 + 6 * t))
    world = np.stack([b.x + shift * smooth, b.y + metres * t], axis=1)
    idx = np.arange(int(b.s) - 10, n + 10) % n
    near = np.linalg.norm(world[:, None, :] - real[idx][None, :, :], axis=2).min(axis=1)
    if near.max() > STRAY:
        return None
    if not clear_of_old(b, world, b.dist, True):
        return None
    nb = Beam()
    nb.cost = b.cost + float((near ** 2).sum()) * 2.0 + 30
    if abs(shift) < 0.05:
        tok = "S%.3fm" % metres
    else:
        tok = "S%s%.3fm%.3f" % ("R" if shift > 0 else "L", metres, abs(shift))
    nb.tokens = b.tokens + [tok]
    nb.dist = b.dist + metres
    return nb


b0 = Beam()
b0.x = b0.y = 0.0
b0.steps = 0
b0.s = 0
b0.cost = 0.0
b0.tokens = []
b0.chunks = []
b0.dist = 0.0
for _ in range(START):
    b0 = step(b0, PIECES[0])
    b0.cost = 0.0
beams = [b0]
done = []
for depth in range(220):
    nxt = []
    for b in beams:
        for piece in PIECES:
            nb = step(b, piece)
            if nb is None:
                continue
            c = close(nb)
            if c is not None:
                done.append(c)
            if nb.s < total + 10:
                nxt.append(nb)
    if not nxt:
        break
    seen = {}
    for b in sorted(nxt, key=lambda b: b.cost):
        key = (round(b.x / 2), round(b.y / 2), b.steps, int(b.s // 6))
        if key not in seen:
            seen[key] = b
    beams = sorted(seen.values(), key=lambda b: b.cost / max(b.s, 1))[:BEAM]
    if depth % 10 == 0:
        print("depth %d, %d beams, furthest %.0f of %.0f m, %d closed" % (depth, len(beams), max(b.s for b in beams), total, len(done)), flush=True)
if not done:
    print("no closed layout found")
    sys.exit(1)
best = min(done, key=lambda b: b.cost)


def home_straight(tokens):
    """Shortens the closing offset to leave whole straight tiles before the
    start, so the grid stands on straights."""
    import re
    m = re.fullmatch(r'S([RL]?)([\d.]+)m([\d.]*)', tokens[-1])
    metres, shift = float(m[2]), float(m[3] or 0)
    tiles = 0
    while metres - (tiles + 1) * TILE >= 24 and (metres - (tiles + 1) * TILE) ** 2 >= 150 * shift:
        tiles += 1
    if tiles == 0:
        return tokens
    rest = metres - tiles * TILE
    last = ("S%s%.3fm%.3f" % (m[1], rest, shift)) if m[1] else "S%.3fm" % rest
    return tokens[:-1] + [last] + ["S1"] * tiles
print("best: %d pieces, %.0f m, cost %.0f" % (len(best.tokens), best.dist, best.cost))
tokens = " ".join(home_straight(best.tokens))
open(out, "w").write("%s\nwidth=13 laps=3\n%s\n" % (name, tokens))
print(tokens)
