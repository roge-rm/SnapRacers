#!/usr/bin/env python3
"""How closely a course follows the real circuit it was traced from.

Usage: fit.py <course.json or .txt> <osm name> [out.png] [label]

Lays the course's middle line over the real one from <osm name>_aligned.json,
turned and shifted to fit it best, and prints the average and worst distance
between the two lines in metres, both ways. With out.png it draws them on top
of each other, the real line grey and the course red.
"""
import json, math, os, subprocess, sys
import numpy as np

here = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(here, "design.py")).read().replace("\nmain()\n", "\n")
design = {"__file__": os.path.join(here, "design.py"), "__name__": "design"}
exec(compile(src, "design.py", "exec"), design)


def course_line(path):
    text = open(path).read()
    data = design["parse"](text) if path.endswith(".txt") else json.loads(text)
    line, _ = design["walk"](data["pieces"])
    pts = np.array([(p[0], p[1]) for p in line])
    return resample(np.vstack([pts, pts[:1]]))


def resample(pts, step=1.0):
    seg = np.linalg.norm(np.diff(pts, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    ss = np.arange(0, s[-1], step)
    return np.stack([np.interp(ss, s, pts[:, 0]), np.interp(ss, s, pts[:, 1])], axis=1)


def nearest(a, b):
    """For each point of a, the distance to the closest point of b."""
    out = np.empty(len(a))
    for k in range(0, len(a), 256):
        d = np.linalg.norm(a[k:k + 256, None, :] - b[None, :, :], axis=2)
        out[k:k + 256] = d.min(axis=1)
    return out


def nearest_index(a, b):
    out = np.empty(len(a), dtype=int)
    for k in range(0, len(a), 256):
        d = np.linalg.norm(a[k:k + 256, None, :] - b[None, :, :], axis=2)
        out[k:k + 256] = d.argmin(axis=1)
    return out


def fit(course, real):
    """Turns and shifts the course onto the real line (closest point fitting
    from each of the four quarter turns), and gives back the moved course,
    the average distance and the worst."""
    best = None
    sub = course[::3]
    for quarter in range(4):
        a = quarter * math.pi / 2
        rot = np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])
        moved = sub @ rot.T
        moved += real.mean(axis=0) - moved.mean(axis=0)
        R, t = rot, real.mean(axis=0) - (sub @ rot.T).mean(axis=0)
        for _ in range(40):
            cur = sub @ R.T + t
            match = real[nearest_index(cur, real)]
            ca, cb = sub.mean(axis=0), match.mean(axis=0)
            H = (sub - ca).T @ (match - cb)
            U, _, Vt = np.linalg.svd(H)
            Rn = Vt.T @ U.T
            if np.linalg.det(Rn) < 0:
                Vt[1] *= -1
                Rn = Vt.T @ U.T
            R, t = Rn, cb - ca @ Rn.T
        moved = course @ R.T + t
        d1, d2 = nearest(moved, real), nearest(real, moved)
        avg = (d1.mean() + d2.mean()) / 2
        worst = max(d1.max(), d2.max())
        if best is None or avg < best[1]:
            best = (moved, avg, worst)
    return best


def draw(real, moved, out, label):
    allp = np.vstack([real, moved])
    lo, hi = allp.min(axis=0) - 30, allp.max(axis=0) + 30
    size = 560
    sc = (size - 20) / max(hi - lo)
    X = lambda v: 10 + (v[0] - lo[0]) * sc
    Y = lambda v: 40 + (hi[1] - v[1]) * sc
    svg = ['<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><rect width="100%%" height="100%%" fill="white"/>' % (size, size + 30)]
    for pts, colour, w in ((real, "#999", 13 * sc), (moved, "#c4281c", max(4 * sc, 2))):
        d = " ".join("%.1f,%.1f" % (X(p), Y(p)) for p in pts[::2])
        svg.append('<polygon points="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (d, colour, max(w, 2)))
    svg.append('<text x="10" y="24" font-size="17" font-family="sans-serif">%s</text>' % label)
    svg.append('</svg>')
    open(out + ".svg", "w").write("\n".join(svg))
    subprocess.run(["convert", out + ".svg", out], check=True, stderr=subprocess.DEVNULL)
    os.remove(out + ".svg")


if __name__ == "__main__":
    course = course_line(sys.argv[1])
    real = np.array(json.load(open(os.path.join(here, sys.argv[2] + "_aligned.json"))))
    moved, avg, worst = fit(course, real)
    length = len(course)
    print("%s: %.0f m, average %.1f m, worst %.1f m from the real line" % (os.path.basename(sys.argv[1]), length, avg, worst))
    if len(sys.argv) > 3:
        label = sys.argv[4] if len(sys.argv) > 4 else os.path.basename(sys.argv[1])
        draw(real, moved, sys.argv[3], "%s  avg %.1f m  worst %.1f m" % (label, avg, worst))
