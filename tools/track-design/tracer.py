#!/usr/bin/env python3
"""Traces a real kart circuit with SnapRacers track pieces.

Usage: tracer.py <osm name> <scale> <out.txt> [beam] [reverse]

The real middle line (from OpenStreetMap) is scaled down, and the start is put
on its longest straight, facing north. Then a beam search lays pieces one at
a time, keeping the sequences that stay closest to the real line, never let
the road run into itself, and finish exactly back on the start facing north.
Writes the result in design.py's short hand, with the pieces that follow
gravel or dirt on the real circuit marked as gravel.
"""
import json, math, os, sys
import numpy as np

TILE = 32.0
WIDTH = 13
here = os.path.dirname(os.path.abspath(__file__))
name, scale, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
BEAM = int(sys.argv[4]) if len(sys.argv) > 4 else 400
REVERSE = len(sys.argv) > 5 and sys.argv[5] == "reverse"
# The middles of two bits of road must be at least this far apart, which
# leaves grass runoff and room for a line of tire stacks between them.
CLEAR = TILE
# How far the road may stray from the real line.
STRAY = 1.4 * TILE
# How far along the road laid so far counts as what it's joining onto, and
# can be close.
JOINING = int(CLEAR * 2.0 / 2.0)


def smoothstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def slant_shift(t, tiles):
    ease = min(max(1.0 / tiles, 0.15), 0.5)
    def eased(u):
        if u < ease:
            return u * 0.5 - ease / (2 * math.pi) * math.sin(2 * math.pi * u / (ease * 2.0))
        return ease * 0.5 + (u - ease)
    total = 1.0 - ease
    return eased(t) / total if t <= 0.5 else 1.0 - eased(1.0 - t) / total


# The pieces the tracer can use: token, local points (right, forward) every
# couple of metres, exit (right, forward) in metres, and turn (+1 right).
PIECES = []
def add(token, pts, ex, turn):
    PIECES.append((token, np.array(pts), np.array(ex), turn))
for n in (1, 2, 3):
    add("S%d" % n, [(0, f) for f in np.arange(2, n * TILE + 0.1, 2)], (0, n * TILE), 0)
for size in (1, 2, 3):
    r = (size - 0.5) * TILE
    for turn, letter in ((1, "R"), (-1, "L")):
        k = max(4, int(r * math.pi / 2 / 2))
        pts = [(turn * (r - r * math.cos(a)), r * math.sin(a)) for a in np.linspace(0, math.pi / 2, k + 1)[1:]]
        add("%s%d" % (letter, size), pts, (turn * r, r), turn)
for length, across in ((2, 1), (3, 1), (3, 2), (4, 1), (4, 2), (4, 3), (5, 2), (5, 3), (5, 4), (6, 3), (6, 4), (6, 5), (7, 5), (7, 6)):
    for turn, letter in ((1, "R"), (-1, "L")):
        k = int(length * 8)
        pts = [(turn * across * TILE * slant_shift(t, length), length * TILE * t) for t in np.linspace(0, 1, k + 1)[1:]]
        add("S%s%d.%d" % (letter, length, across), pts, (turn * across * TILE, length * TILE), 0)


# OpenStreetMap surfaces that are loose, which the game makes gravel.
LOOSE = {"gravel", "fine_gravel", "dirt", "unpaved", "ground", "compacted", "sand", "earth"}


def load_real():
    pick = json.load(open(os.path.join(here, "picks.json")))[name]
    lines = [l for l in json.load(open(os.path.join(here, name + ".json"))) if l["id"] in pick]
    pts = [p for l in lines for p in l["points"]]
    # Where each surface starts along the real lap (see fetch_picks.py).
    surfaces = lines[0]["tags"].get("surfaces", []) if len(lines) == 1 else []
    pts = np.array(pts, dtype=float)
    # Screen y is down, so make y up (north) and turns keep their direction.
    pts[:, 1] = -pts[:, 1]
    if REVERSE:
        pts = pts[::-1]
    if np.linalg.norm(pts[0] - pts[-1]) > 1:
        pts = np.vstack([pts, pts[:1]])
    pts *= scale
    # Resample every metre.
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    total = s[-1]
    ss = np.arange(0, total, 1.0)
    res = np.stack([np.interp(ss, s, pts[:, 0]), np.interp(ss, s, pts[:, 1])], axis=1)
    # Whether each metre is loose, going the way the lap is driven.
    loose = np.zeros(len(ss), dtype=bool)
    for k, (at, kind) in enumerate(surfaces):
        end = surfaces[k + 1][0] if k + 1 < len(surfaces) else total / scale
        if kind in LOOSE:
            a, b = (at * scale, end * scale) if not REVERSE else (total - end * scale, total - at * scale)
            loose |= (ss >= a) & (ss < b)
    return res, total, loose


real, total, loose = load_real()
n = len(real)
# Headings, smoothed, to find the longest straight for the start.
d = np.roll(real, -3, axis=0) - np.roll(real, 3, axis=0)
head = np.arctan2(d[:, 0], d[:, 1])
turning = np.abs(np.angle(np.exp(1j * (np.roll(head, -4) - np.roll(head, 4)))))
straight = turning < 0.08
best_len, best_mid, run = 0, 0, 0
for i in range(2 * n):
    if straight[i % n]:
        run += 1
        if run > best_len:
            best_len, best_mid = run, i - run // 3
    else:
        run = 0
start = best_mid % n
real = np.roll(real, -start, axis=0)
loose = np.roll(loose, -start)
# Turn the whole circuit so its straights line up with the grid as well as
# they can (the grid only does 90 degree bends, plus slants), then by a whole
# number of quarter turns so the start faces north.
w = (~np.roll(straight, -start)).astype(float) * 0.05 + np.roll(straight, -start).astype(float)
theta = np.arctan2(np.roll(real, -2, axis=0)[:, 0] - real[:, 0], np.roll(real, -2, axis=0)[:, 1] - real[:, 1])
phi = math.atan2((w * np.sin(4 * theta)).sum(), (w * np.cos(4 * theta)).sum()) / 4
start_head = math.atan2(real[3][0] - real[0][0], real[3][1] - real[0][1])
quarter = round((start_head - phi) / (math.pi / 2))
head0 = phi + quarter * math.pi / 2
c, s_ = math.cos(head0), math.sin(head0)
rot = np.array([[c, -s_], [s_, c]])
real = (real - real[0]) @ rot.T
json.dump(real.tolist(), open(os.path.join(here, name + "_aligned.json"), "w"))
print("turned by %.0f degrees, the start is %.0f degrees off north" % (math.degrees(head0), math.degrees(start_head - head0)))
real_s = np.arange(n, dtype=float)
print("%s: %.0f m at scale %.2f, start straight %.0f m" % (name, total, scale, best_len), flush=True)


# Where the real line crosses itself (a bridge), road can cross there too, and
# I turn it into a bridge by hand afterwards.
def _crossings(line):
    out = []
    m = len(line)
    for i in range(0, m - 1, 2):
        a, b = line[i], line[(i + 2) % m]
        for j in range(i + 20, m - 1, 2):
            if (j + 20) % m < i:
                continue
            c, d = line[j], line[(j + 2) % m]
            def cross(o, p, q):
                return (p[0] - o[0]) * (q[1] - o[1]) - (p[1] - o[1]) * (q[0] - o[0])
            if cross(a, b, c) * cross(a, b, d) < 0 and cross(c, d, a) * cross(c, d, b) < 0:
                out.append(((a + b + c + d) / 4.0))
    return out
CROSSINGS = _crossings(real)
if CROSSINGS:
    print("the real line crosses itself at", [tuple(np.round(c)) for c in CROSSINGS])


class Beam:
    __slots__ = ("x", "y", "hx", "hy", "s", "cost", "tokens", "pts", "ss", "spans")


def place(b, piece):
    token, pts, ex, turn = piece
    rx, ry = b.hy, -b.hx
    world = np.stack([b.x + rx * pts[:, 0] + b.hx * pts[:, 1], b.y + ry * pts[:, 0] + b.hy * pts[:, 1]], axis=1)
    end = (b.x + rx * ex[0] + b.hx * ex[1], b.y + ry * ex[0] + b.hy * ex[1])
    if turn > 0:
        h = (rx, ry)
    elif turn < 0:
        h = (-rx, -ry)
    else:
        h = (b.hx, b.hy)
    return world, end, h


def step(b, piece):
    world, end, h = place(b, piece)
    length = len(world) * 2.0
    lo = int(b.s)
    hi = min(int(b.s + length * 2.0 + 30), n + 40)
    idx = np.arange(lo, hi) % n
    ref = real[idx]
    # Distance from each new point to the real line near where we are.
    dd = np.linalg.norm(world[:, None, :] - ref[None, :, :], axis=2)
    near = dd.min(axis=1)
    if near.max() > STRAY:
        return None
    s_end = lo + int(np.argmin(dd[-1]))
    if s_end <= b.s + length * 0.3:
        return None
    # Don't run into road already laid (leaving out the last bit, which it
    # joins onto, and the start when it's coming home).
    if len(b.pts) > JOINING:
        old = b.pts[:-JOINING]
        olds = b.ss[:-JOINING]
        if s_end > total - CLEAR * 2.5:
            keep = olds > CLEAR * 2.0
            old = old[keep]
        if len(old):
            dd2 = np.linalg.norm(world[:, None, :] - old[None, :, :], axis=2)
            if CROSSINGS:
                ok = np.ones(len(world), dtype=bool)
                for c in CROSSINGS:
                    ok &= np.linalg.norm(world - c, axis=1) > CLEAR * 1.6
                dd2 = dd2[ok]
            if dd2.size and dd2.min() < CLEAR:
                return None
    nb = Beam()
    nb.x, nb.y = end
    nb.hx, nb.hy = h
    nb.s = s_end
    penalty = 4.0 if piece[0] in ("R1", "L1") else 0.0
    nb.cost = b.cost + float((near ** 2).sum()) * 2.0 + 30.0 + penalty * 30
    nb.tokens = b.tokens + [piece[0]]
    nb.spans = b.spans + [(int(b.s), s_end)]
    nb.pts = np.vstack([b.pts, world]) if len(b.pts) else world
    nb.ss = np.concatenate([b.ss, np.linspace(b.s, s_end, len(world))])
    return nb


b0 = Beam()
b0.x = b0.y = 0.0
b0.hx, b0.hy = 0.0, 1.0
b0.s = 0
b0.cost = 0.0
b0.tokens = []
b0.spans = []
b0.pts = np.zeros((0, 2))
b0.ss = np.zeros(0)
beams = [b0]
done = []
for depth in range(160):
    nxt = []
    for b in beams:
        for piece in PIECES:
            nb = step(b, piece)
            if nb is None:
                continue
            if nb.s >= total - 3 * TILE and abs(nb.x) < 0.1 and abs(nb.y) < 0.1 and nb.hy > 0.99:
                done.append(nb)
                continue
            if nb.s < total + 10:
                nxt.append(nb)
    if not nxt:
        break
    # Keep the best of each distinct state, then the best overall.
    seen = {}
    for b in sorted(nxt, key=lambda b: b.cost):
        key = (round(b.x), round(b.y), round(b.hx), round(b.hy), int(b.s // 6))
        if key not in seen:
            seen[key] = b
    beams = sorted(seen.values(), key=lambda b: b.cost / max(b.s, 1))[:BEAM]
    if depth % 10 == 0:
        print("depth %d, %d beams, furthest %.0f of %.0f m, %d closed" % (depth, len(beams), max(b.s for b in beams), total, len(done)), flush=True)
if not done:
    print("no closed layout found")
    sys.exit(1)
best = min(done, key=lambda b: b.cost)
print("best: %d pieces, cost %.0f" % (len(best.tokens), best.cost))
# A piece that follows mostly loose real road is gravel.
marked = []
for token, (a, b) in zip(best.tokens, best.spans):
    part = loose[np.arange(a, max(b, a + 1)) % n]
    marked.append(token + ("!v" if part.mean() > 0.5 else ""))
tokens = " ".join(marked)
open(out, "w").write("%s\nwidth=%d laps=3\n%s\n" % (name, WIDTH, tokens))
print(tokens)
