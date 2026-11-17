#!/usr/bin/env python3
"""Writes and reads a course's "ground" key, the same as scripts/track/ground_map.gd.

Usage: ground_map.py fixture <out.json>
       ground_map.py course <out.json>

Heights are rounded to 0.05 m, each stored as the difference from the plane
through its left, upper and upper left neighbours (left only on the first row,
upper only on the first column), as zigzag varints, zlib deflated and base64.

`fixture` writes the small map tests/ground_map_test.gd checks the game
decodes the same. `course` writes tests/data/ground_course.json, the
course tests/terrain_test.gd builds.
"""
import base64, json, math, sys, zlib
import numpy as np

CELL = 8.0
STEP = 0.05
MOST_POINTS = 65536
HIGHEST = 200.0


def _predict(q, x, z):
    if z == 0:
        return int(q[0, x - 1]) if x > 0 else 0
    if x == 0:
        return int(q[z - 1, 0])
    return int(q[z, x - 1]) + int(q[z - 1, x]) - int(q[z - 1, x - 1])


def encode(heights):
    """heights: rows x cols in metres. Gives the base64 text."""
    h = np.clip(np.asarray(heights, dtype=np.float64), -HIGHEST, HIGHEST)
    # Round half away from zero like Godot's roundi.
    q = (np.sign(h) * np.floor(np.abs(h) / STEP + 0.5)).astype(np.int64)
    rows, cols = q.shape
    out = bytearray()
    for z in range(rows):
        for x in range(cols):
            d = int(q[z, x]) - _predict(q, x, z)
            u = d * 2 if d >= 0 else -d * 2 - 1
            while u >= 0x80:
                out.append((u & 0x7F) | 0x80)
                u >>= 7
            out.append(u)
    return base64.b64encode(zlib.compress(bytes(out), 9)).decode("ascii")


def decode(text, cols, rows):
    raw = zlib.decompress(base64.b64decode(text))
    q = np.zeros((rows, cols), dtype=np.int64)
    at = 0
    for i in range(cols * rows):
        u = shift = 0
        while True:
            b = raw[at]
            at += 1
            u |= (b & 0x7F) << shift
            shift += 7
            if b < 0x80:
                break
        d = u >> 1 if u & 1 == 0 else -((u + 1) >> 1)
        z, x = divmod(i, cols)
        q[z, x] = d + _predict(q, x, z)
    if at != len(raw):
        raise ValueError("bytes left over")
    return q * STEP


def to_dict(heights, origin):
    """The "ground" entry for a course file, origin as (x, z) of the first point."""
    rows, cols = np.asarray(heights).shape
    if cols * rows > MOST_POINTS:
        raise ValueError("a ground map can have up to %d points" % MOST_POINTS)
    return {"cell": CELL, "origin": [float(origin[0]), float(origin[1])],
            "size": [cols, rows], "step": STEP, "data": encode(heights)}


def fixture():
    """A small hill and valley with a slope across, 9 across and 7 down."""
    z, x = np.mgrid[0:7, 0:9].astype(np.float64)
    h = 6.0 * np.exp(-((x - 2) ** 2 + (z - 2) ** 2) / 4.0) - 4.0 * np.exp(-((x - 6) ** 2 + (z - 4) ** 2) / 3.0) + 0.3 * x - 0.55 * z
    h[6, 8] = -199.95
    h[0, 8] = 200.0
    q = np.round(h / STEP) * STEP
    return {"ground": to_dict(q, (-32.0, -24.0)), "heights": [round(float(v), 2) for v in q.ravel()]}


def course():
    """A loop on hand-made ground: a hill beside the east straight (a cutting),
    a valley across both straights (a bridge on the west one, an embankment on
    the east) with a drop in it, a river down the valley under the bridge, a
    lake in a hollow on the side of a second hill, a lava lake in a hollow
    outside the loop and a barn on the first hill's slope. The ground tilts up
    to the east, so that edge is high."""
    origin = (-136.0, -504.0)
    cols, rows = 71, 87
    z, x = np.mgrid[0:rows, 0:cols].astype(np.float64)
    x = origin[0] + x * CELL
    z = origin[1] + z * CELL

    def height(x, z):
        tilt = 0.03 * x
        hill = 12.0 * np.exp(-((x - 345.0) ** 2 + (z + 80.0) ** 2) / (2 * 32.0 ** 2))
        lake_hill = 9.0 * np.exp(-((x - 210.0) ** 2 + (z + 290.0) ** 2) / (2 * 30.0 ** 2))
        valley = -9.0 * np.exp(-((z + 160.0) ** 2) / (2 * 18.0 ** 2))
        # The valley floor steps up 4 m over about 30 m inside the loop.
        drop = 4.0 / (1.0 + np.exp(-(x - 110.0) / 8.0)) * np.exp(-((z + 160.0) ** 2) / (2 * 24.0 ** 2))
        hollow = -7.0 * np.exp(-((x - 150.0) ** 2 + (z + 282.0) ** 2) / (2 * 20.0 ** 2))
        lava_hollow = -6.0 * np.exp(-((x - 130.0) ** 2 + (z + 40.0) ** 2) / (2 * 16.0 ** 2))
        return tilt + hill + lake_hill + valley + drop + hollow + lava_hollow

    h = height(x, z) - height(0.0, 0.0)

    def level(at):
        """Two thirds of the way from the bottom of the hollow round `at` to
        where it would spill."""
        seed = (int(round((at[1] - origin[1]) / CELL)), int(round((at[0] - origin[0]) / CELL)))
        lo, hi = float(h[seed]), float(h[seed]) + 20.0
        for _ in range(30):
            mid = (lo + hi) / 2.0
            seen = {seed}
            todo = [seed]
            spilled = False
            while todo and not spilled:
                r, c = todo.pop()
                for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    n = (r + dr, c + dc)
                    if not (0 <= n[0] < rows and 0 <= n[1] < cols):
                        spilled = True
                        break
                    if n not in seen and h[n] < mid:
                        seen.add(n)
                        todo.append(n)
                if len(seen) > 400:
                    spilled = True
            lo, hi = (mid, hi) if not spilled else (lo, mid)
        bottom = float(h[seed])
        return round(bottom + (lo - bottom) * 0.66, 2)

    lake = (150.0, -282.0)
    lava = (130.0, -40.0)
    # The river down the valley from inside the loop, west under the bridge
    # and out, winding a little.
    river = [[round(float(px), 2), round(-160.0 + 5.0 * math.sin(px / 37.0), 2), 10.0] for px in range(236, -110, -16)]
    water = [
        {"kind": "lake", "type": "water", "at": list(lake), "level": level(lake)},
        {"kind": "lake", "type": "lava", "at": list(lava), "level": level(lava)},
        {"kind": "river", "type": "water", "points": river},
    ]
    return {
        "name": "Ground course", "theme": "orchard", "about": "A test loop on a hand-made ground map.",
        "laps": 3, "width": 13.0, "grid": 32,
        "ground": to_dict(h, origin),
        "water": water,
        "landmarks": [{"prop": "barn", "at": [360, -20], "facing": 3}],
        "pieces": [
            {"type": "straight", "length": 2},
            {"type": "ramp", "length": 2, "rise": 1}, {"type": "straight", "length": 2}, {"type": "ramp", "length": 2, "rise": -1},
            {"type": "straight", "length": 1},
            {"type": "curve", "turn": "right", "size": 3},
            {"type": "straight", "length": 4},
            {"type": "curve", "turn": "right", "size": 3},
            {"type": "straight", "length": 9},
            {"type": "curve", "turn": "right", "size": 3},
            {"type": "straight", "length": 4},
            {"type": "curve", "turn": "right", "size": 3},
        ],
    }


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "course":
        with open(sys.argv[2], "w") as f:
            json.dump(course(), f, indent="\t")
            f.write("\n")
        return
    if len(sys.argv) == 3 and sys.argv[1] == "fixture":
        data = fixture()
        back = decode(data["ground"]["data"], *data["ground"]["size"])
        assert np.allclose(back.ravel(), data["heights"], atol=1e-6)
        with open(sys.argv[2], "w") as f:
            json.dump(data, f, indent="\t")
            f.write("\n")
        return
    print(__doc__)
    sys.exit(1)


if __name__ == "__main__":
    main()
