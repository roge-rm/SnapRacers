#!/usr/bin/env python3
"""Previews a SnapRacers track design next to the real circuit it's based on.

Usage: design.py <track.json> [<osm name>] [out.png]

Works out the middle line from the pieces the same way TrackPiece does (in
2D, with levels), reports whether it closes, how long it is, and any places
where two bits of road at the same level come closer than a tile. Draws it on
the tile grid beside the real layout.
"""
import json, math, os, subprocess, sys

TILE = 32.0
# How sharply the top of a crest curves, one over its radius.
CREST_BEND = 0.0128
here = os.path.dirname(os.path.abspath(__file__))


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


def piece_points(p):
    """Local points (x right, f forward, h height in metres) and the exit (x, f, turn)."""
    kind = p.get("type", "straight")
    n = 24
    pts = []
    if kind == "curve":
        turn = -1 if p.get("turn", "right") == "left" else 1
        r = (int(p.get("size", 2)) - 0.5) * TILE
        rise = float(p.get("rise", 0)) * 3.0
        for k in range(n + 1):
            a = k / n * math.pi / 2
            pts.append((turn * (r - r * math.cos(a)), r * math.sin(a), rise * smoothstep(0, 1, k / n)))
        return pts, (turn * r, r, turn), rise
    if kind == "slant":
        tiles = max(int(p.get("length", 2)), 2)
        across = abs(int(p.get("across", 1))) * (-1 if p.get("turn", "right") == "left" else 1)
        rise = float(p.get("rise", 0)) * 3.0
        for k in range(n + 1):
            t = k / n
            pts.append((across * TILE * slant_shift(t, tiles), tiles * TILE * t, rise * smoothstep(0, 1, t)))
        return pts, (across * TILE, tiles * TILE, 0), rise
    if kind == "corkscrew":
        # It rolls once round while it steps a tile across, three tiles
        # along. Seen from above it's close to a slant, and it rises about
        # 18 m at the top of the roll.
        side = -1 if p.get("side", "right") == "left" else 1
        for k in range(n + 1):
            t = k / n
            pts.append((side * TILE * smoothstep(0.15, 0.85, t), 3 * TILE * t, 18.0 * math.sin(math.pi * smoothstep(0.1, 0.9, t)) ** 2))
        return pts, (side * TILE, 3 * TILE, 0), 0.0
    if kind == "loop":
        side = -1 if p.get("side", "right") == "left" else 1
        for k in range(n + 1):
            t = k / n
            pts.append((side * TILE * smoothstep(0.3, 0.7, t), 3 * TILE * t, 10.0 * math.sin(math.pi * t)))
        return pts, (side * TILE, 3 * TILE, 0), 0.0
    tiles = 3 if kind == "jump" else int(p.get("length", 1 if kind == "straight" else 2))
    rise = float(p.get("rise", 0)) * 3.0 if kind == "ramp" else 0.0
    for k in range(n + 1):
        t = k / n
        pts.append((0.0, tiles * TILE * t, rise * smoothstep(0, 1, t)))
    return pts, (0.0, tiles * TILE, 0), rise


def walk(pieces):
    x, y, h = 0.0, 0.0, 0.0
    hx, hy = 0.0, 1.0  # heading: +y is "north" (the game's -Z)
    line = []  # (x, y, height, piece index)
    for i, p in enumerate(pieces):
        pts, (ex, ef, turn), rise = piece_points(p)
        rx, ry = hy, -hx  # right of the heading
        for (px, pf, ph) in pts[:-1]:
            line.append((x + rx * px + hx * pf, y + ry * px + hy * pf, h + ph, i))
        x, y = x + rx * ex + hx * ef, y + ry * ex + hy * ef
        h += rise
        if turn:
            hx, hy = (rx, ry) if turn > 0 else (-rx, -ry)
    return line, (x, y, h, hx, hy)


def clashes(line, n_pieces, width=12.0):
    """Like TrackPath.clashes(): spots on the road more than twice the reach
    apart along the lap that are closer than the reach, at the same level."""
    out = []
    reach = width + 3.0
    arc = [0.0]
    for k in range(1, len(line)):
        arc.append(arc[-1] + math.hypot(line[k][0] - line[k - 1][0], line[k][1] - line[k - 1][1]))
    total = arc[-1]
    for a in range(0, len(line), 2):
        for b in range(a + 1, len(line), 2):
            along = arc[b] - arc[a]
            if along < reach * 2 or total - along < reach * 2:
                continue
            pa, pb = line[a], line[b]
            if abs(pa[2] - pb[2]) >= 5.0:
                continue
            if math.hypot(pa[0] - pb[0], pa[1] - pb[1]) < reach:
                out.append((pa[3], pb[3]))
    return sorted(set(out))


def parse(text):
    """Short hand for piece lists, one token per piece:
    S3 straight, R2/L2 curve right/left (size), R2b22 banked, R2c cut,
    SR4.3/SL4.3 slant right/left 4 long 3 across, U2+1/U2-1 ramp up/down a
    level, C2 crest (C2h3 for one 3 m high), J jump, OR/OL loop, XR/XL corkscrew. Add ^1 or ^-1 to any piece to climb
    or drop a level along it, !o for open edges, !d dirt, !v gravel, !i ice,
    !s sand, !g grass."""
    import re
    lines = [l.split('#')[0].strip() for l in text.splitlines()]
    lines = [l for l in lines if l]
    data = {"name": lines[0], "laps": 3, "width": 13.0, "pieces": []}
    for key, value in re.findall(r'(\w+)=(\S+)', lines[1]):
        data[key] = float(value) if key == "width" else (int(value) if value.isdigit() else value)
    for tok in " ".join(lines[2:]).split():
        flags = ""
        climb = 0
        if "!" in tok:
            tok, flags = tok.split("!", 1)
        if "^" in tok:
            tok, c = tok.split("^", 1)
            climb = int(c)
        m = re.fullmatch(r'S(\d+)', tok)
        spec = None
        if m:
            spec = {"type": "straight", "length": int(m[1])}
        elif re.fullmatch(r'S([RL])(\d+)\.(\d+)', tok):
            m = re.fullmatch(r'S([RL])(\d+)\.(\d+)', tok)
            spec = {"type": "slant", "turn": "right" if m[1] == "R" else "left", "length": int(m[2]), "across": int(m[3])}
        elif re.fullmatch(r'([RL])(\d)(b\d+)?(c)?', tok):
            m = re.fullmatch(r'([RL])(\d)(b\d+)?(c)?', tok)
            spec = {"type": "curve", "turn": "right" if m[1] == "R" else "left", "size": int(m[2])}
            if m[3]: spec["bank"] = int(m[3][1:])
            if m[4]: spec["cut"] = True
        elif re.fullmatch(r'U(\d+)([+-]\d+)', tok):
            m = re.fullmatch(r'U(\d+)([+-]\d+)', tok)
            spec = {"type": "ramp", "length": int(m[1]), "rise": int(m[2])}
        elif re.fullmatch(r'C(\d+)(h[\d.]+)?', tok):
            m = re.fullmatch(r'C(\d+)(h[\d.]+)?', tok)
            # Tall enough that its top curves as sharply as a 1.5 m hump on a
            # 16 m tile, so it still throws you in the air.
            run = int(m[1]) * TILE
            height = float(m[2][1:]) if m[2] else round(CREST_BEND * run * run / (2 * math.pi ** 2), 1)
            spec = {"type": "crest", "length": int(m[1]), "height": height}
        elif tok == "J":
            spec = {"type": "jump"}
        elif tok in ("OR", "OL"):
            spec = {"type": "loop", "side": "right" if tok == "OR" else "left"}
        elif tok in ("XR", "XL"):
            spec = {"type": "corkscrew", "side": "right" if tok == "XR" else "left"}
        else:
            raise SystemExit("bad token " + tok)
        if climb:
            if spec["type"] == "straight":
                spec = {"type": "ramp", "length": spec["length"], "rise": climb}
            else:
                spec["rise"] = climb
        for f in flags:
            if f == "o": spec["edges"] = "open"
            elif f == "d": spec["surface"] = "dirt"
            elif f == "v": spec["surface"] = "gravel"
            elif f == "i": spec["surface"] = "ice"
            elif f == "s": spec["surface"] = "sand"
            elif f == "g": spec["surface"] = "grass"
        data["pieces"].append(spec)
    return data


def main():
    src = open(sys.argv[1]).read()
    data = parse(src) if sys.argv[1].endswith(".txt") else json.loads(src)
    if len(sys.argv) > 4:
        json.dump(data, open(sys.argv[4], "w"), indent="\t")
    osm = sys.argv[2] if len(sys.argv) > 2 else None
    out = sys.argv[3] if len(sys.argv) > 3 else os.path.splitext(os.path.basename(sys.argv[1]))[0] + "_design.png"
    pieces = data["pieces"]
    line, end = walk(pieces)
    gap = math.hypot(end[0], end[1])
    length = sum(math.hypot(line[k][0] - line[k - 1][0], line[k][1] - line[k - 1][1]) for k in range(1, len(line))) + gap
    closes = gap < 0.5 and abs(end[2]) < 0.1 and end[3] == 0 and end[4] == 1
    bad = clashes(line, len(pieces), float(data.get("width", 13)))
    print("%s: %.0f m, %s (gap %.1f m, height %.1f, heading %s), clashes %s" % (
        data.get("name"), length, "closes" if closes else "DOESN'T CLOSE", gap, end[2], (end[3], end[4]), bad[:8]))
    # Draw.
    xs = [p[0] for p in line]
    ys = [p[1] for p in line]
    minx, maxx, miny, maxy = min(xs) - 24, max(xs) + 24, min(ys) - 24, max(ys) + 24
    size = 520
    scale = (size - 20) / max(maxx - minx, maxy - miny)
    W = size * 2 if osm else size
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect width="100%%" height="100%%" fill="white"/>' % (W, size + 30)]
    X = lambda v: 10 + (v - minx) * scale
    Y = lambda v: 40 + (maxy - v) * scale
    gx = math.floor(minx / TILE) * TILE
    while gx < maxx:
        svg.append('<line x1="%.1f" y1="40" x2="%.1f" y2="%d" stroke="#eee"/>' % (X(gx + 8), X(gx + 8), size + 30))
        gx += TILE
    gy = math.floor(miny / TILE) * TILE
    while gy < maxy:
        svg.append('<line x1="10" y1="%.1f" x2="%d" y2="%.1f" stroke="#eee"/>' % (Y(gy + 8), size, Y(gy + 8)))
        gy += TILE
    for k in range(1, len(line)):
        a, b = line[k - 1], line[k]
        h = (a[2] + b[2]) / 2
        colour = "#c4281c" if h < 1 else ("#e07000" if h < 5.5 else "#0d69ab")
        svg.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/>' % (X(a[0]), Y(a[1]), X(b[0]), Y(b[1]), colour, max(12 * scale, 3)))
    svg.append('<circle cx="%.1f" cy="%.1f" r="6" fill="black"/>' % (X(0), Y(0)))
    svg.append('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="black" stroke-width="3"/>' % (X(0), Y(0), X(0), Y(20)))
    for i, p in enumerate(pieces):
        first = next(q for q in line if q[3] == i)
        svg.append('<text x="%.1f" y="%.1f" font-size="11" fill="#555">%d</text>' % (X(first[0]) + 4, Y(first[1]) - 4, i))
    svg.append('<text x="10" y="22" font-size="18" font-family="sans-serif">%s  %.0f m  %s  clashes %d</text>' % (data.get("name"), length, "closes" if closes else "OPEN", len(bad)))
    if osm:
        aligned = os.path.join(here, osm + "_aligned.json")
        if os.path.exists(aligned):
            pts = json.load(open(aligned))
            sx = [p[0] for p in pts] + xs
            sy = [p[1] for p in pts] + ys
            amin, amax, bmin, bmax = min(sx) - 24, max(sx) + 24, min(sy) - 24, max(sy) + 24
            osc = (size - 20) / max(amax - amin, bmax - bmin)
            d = " ".join("%.1f,%.1f" % (size + 10 + (x - amin) * osc, 40 + (bmax - y) * osc) for x, y in pts[::3])
            svg.append('<polyline points="%s" fill="none" stroke="#888" stroke-width="5" stroke-linejoin="round"/>' % d)
            svg.append('<circle cx="%.1f" cy="%.1f" r="6" fill="black"/>' % (size + 10 + (0 - amin) * osc, 40 + (bmax - 0) * osc))
        svg.append('<text x="%d" y="22" font-size="18" font-family="sans-serif">real: %s, lined up the same way</text>' % (size + 20, osm))
    svg.append('</svg>')
    open(out + ".svg", "w").write("\n".join(svg))
    subprocess.run(["convert", out + ".svg", out], check=True, stderr=subprocess.DEVNULL)
    os.remove(out + ".svg")


main()
