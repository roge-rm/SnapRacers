#!/usr/bin/env python3
"""Makes a course's ground map from the real ground around its circuit.

Usage: dem.py <course id> [--exaggerate N] [--pick <osm name>]

Fits the course (courses/<id>.txt, started where build_courses.py starts it)
onto its OpenStreetMap line (<id>.json from fetch_picks.py, which has the
line's lat and lon), downloads the Copernicus GLO-30 tiles under it into
/mnt/scratch/snapracers/dem/ (a tile that isn't there is sea), and samples
them at every 8 m map point. GLO-30 has the trees and buildings in it, so a
60 m opening takes them out, then a 16 m blur. Heights are from the road at
the start, sized by the fit's scale, times the exaggeration (1.5 by default)
and squeezed into 25 m top to bottom.

Writes "ground" into courses/<id>.extra.json and drops "hills", prints the
road's height range, its steepest grade and the spots that want a ramp or a
rise bend on top, and draws a hillshade with the course (red) and the real
line (blue) to /srv/downloads/temp/debug/snapracers/terrain/<id>.png.
"""
import json, math, os, subprocess, sys
import numpy as np
from numpy.lib.stride_tricks import sliding_window_view
from PIL import Image, ImageDraw

here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import ground_map  # noqa: E402

src = open(os.path.join(here, "fit.py")).read().split('\nif __name__ == "__main__":')[0]
fitting = {"__file__": os.path.join(here, "fit.py"), "__name__": "fit"}
exec(compile(src, "fit.py", "exec"), fitting)
design = fitting["design"]
bsrc = open(os.path.join(here, "build_courses.py")).read().split("\nout_dir = sys.argv[1]")[0]
builder = {"__file__": os.path.join(here, "build_courses.py"), "__name__": "build_courses"}
exec(compile(bsrc, "build_courses.py", "exec"), builder)

CACHE = "/mnt/scratch/snapracers/dem"
PICTURES = "/srv/downloads/temp/debug/snapracers/terrain"
URL = "https://copernicus-dem-30m.s3.amazonaws.com/%s/%s.tif"
CELL = ground_map.CELL
# Map reach past the road's box, the same as the terrain's.
MARGIN = 128.0
OPENING = 60.0
TALLEST = 25.0
ROAD_STEEPEST = 0.12
# Road ground this far off the real profile over a stretch wants a ramp.
RAMP_GAP = 1.5
# metres per degree of latitude, as fetch_picks.py uses
DEGREE = 111320.0


def tile_name(lat, lon):
    ns = "N%02d" % lat if lat >= 0 else "S%02d" % -lat
    ew = "E%03d" % lon if lon >= 0 else "W%03d" % -lon
    return "Copernicus_DSM_COG_10_%s_00_%s_00_DEM" % (ns, ew)


def fetch(name):
    """The tile's path, or None for sea (no tile). Downloads it once."""
    os.makedirs(CACHE, exist_ok=True)
    path = os.path.join(CACHE, name + ".tif")
    sea = os.path.join(CACHE, name + ".sea")
    if os.path.exists(path):
        return path
    if os.path.exists(sea):
        return None
    part = path + ".part"
    code = subprocess.run(["curl", "-sS", "-A", "curl", "-o", part, "-w", "%{http_code}", URL % (name, name)],
                          capture_output=True, text=True).stdout.strip()
    if code in ("404", "403"):
        if os.path.exists(part):
            os.remove(part)
        open(sea, "w").close()
        print("no tile %s, sea" % name)
        return None
    if code != "200":
        raise SystemExit("downloading %s gave %s" % (name, code))
    os.rename(part, path)
    print("downloaded %s, %.1f MB" % (name, os.path.getsize(path) / 1e6))
    return path


class Tile:
    """A GLO-30 tile: heights and where its pixel centres are."""

    def __init__(self, path):
        im = Image.open(path)
        tags = im.tag_v2
        sx, sy = tags[33550][0], tags[33550][1]
        tie = tags[33922]
        keys = tags.get(34735, ())
        # GTRasterTypeGeoKey 1025: 1 is pixel is area, so centres sit half a pixel in.
        area = True
        for k in range(4, len(keys), 4):
            if keys[k] == 1025:
                area = keys[k + 3] == 1
        half = 0.5 if area else 0.0
        self.lon0 = tie[3] - tie[0] * sx + half * sx
        self.lat0 = tie[4] + tie[1] * sy - half * sy
        self.sx, self.sy = sx, sy
        self.h = np.asarray(im, dtype=np.float32)

    def sample(self, lat, lon):
        fx = np.clip((lon - self.lon0) / self.sx, 0, self.h.shape[1] - 1.001)
        fy = np.clip((self.lat0 - lat) / self.sy, 0, self.h.shape[0] - 1.001)
        ix, iy = fx.astype(int), fy.astype(int)
        ax, ay = fx - ix, fy - iy
        h = self.h
        top = h[iy, ix] * (1 - ax) + h[iy, ix + 1] * ax
        bottom = h[iy + 1, ix] * (1 - ax) + h[iy + 1, ix + 1] * ax
        return top * (1 - ay) + bottom * ay


def sample_dem(lat, lon):
    out = np.zeros(lat.shape)
    for la in range(int(math.floor(lat.min())), int(math.floor(lat.max())) + 1):
        for lo in range(int(math.floor(lon.min())), int(math.floor(lon.max())) + 1):
            inside = (np.floor(lat) == la) & (np.floor(lon) == lo)
            if not inside.any():
                continue
            path = fetch(tile_name(la, lo))
            if path:
                out[inside] = Tile(path).sample(lat[inside], lon[inside])
    return out


def opening(h, k):
    """Minimum then maximum over k x k squares, held at the edges."""
    r = k // 2
    low = sliding_window_view(np.pad(h, r, mode="edge"), (k, k)).min(axis=(2, 3))
    return sliding_window_view(np.pad(low, r, mode="edge"), (k, k)).max(axis=(2, 3))


def blur(h, weights):
    r = len(weights) // 2
    for axis in (0, 1):
        p = np.pad(h, [(r, r) if a == axis else (0, 0) for a in (0, 1)], mode="edge")
        n = h.shape[axis]
        h = sum(w * np.take(p, range(i, i + n), axis=axis) for i, w in enumerate(weights))
    return h


ROAD_BLUR = [1 / 16, 4 / 16, 6 / 16, 4 / 16, 1 / 16]


def limited(h, raise_):
    """GroundMap._limited, point for point."""
    h = h.copy()
    rows, cols = h.shape
    straight = ROAD_STEEPEST * CELL
    diagonal = straight * math.sqrt(2.0)
    pick = max if raise_ else min
    sign = -1.0 if raise_ else 1.0
    for back in (False, True):
        step = 1 if back else -1
        for zn in range(rows):
            z = rows - 1 - zn if back else zn
            zs = z + step
            z_in = 0 <= zs < rows
            for xn in range(cols):
                x = cols - 1 - xn if back else xn
                xs, xd = x + step, x - step
                best = h[z, x]
                if 0 <= xs < cols:
                    best = pick(best, h[z, xs] + sign * straight)
                    if z_in:
                        best = pick(best, h[zs, xs] + sign * diagonal)
                if z_in:
                    best = pick(best, h[zs, x] + sign * straight)
                    if 0 <= xd < cols:
                        best = pick(best, h[zs, xd] + sign * diagonal)
                a = h[z, x - 1] if x > 0 else h[z, x]
                if x < cols - 1:
                    a = pick(a, h[z, x + 1])
                b = h[z - 1, x] if z > 0 else h[z, x]
                if z < rows - 1:
                    b = pick(b, h[z + 1, x])
                apart = abs(a - b)
                if apart < straight:
                    best = pick(best, (a + b) * 0.5 + sign * math.sqrt(2.0 * straight * straight - apart * apart) * 0.5)
                h[z, x] = best
    return h


def road_heights(h):
    """GroundMap.road_heights: the ground the road follows."""
    h = blur(h, ROAD_BLUR)
    h = (limited(h, False) + limited(h, True)) * 0.5
    return blur(h, ROAD_BLUR)


def height_at(h, origin, x, z):
    rows, cols = h.shape
    fx = np.clip((np.asarray(x) - origin[0]) / CELL, 0, cols - 1)
    fz = np.clip((np.asarray(z) - origin[1]) / CELL, 0, rows - 1)
    ix = np.minimum(fx.astype(int), cols - 2)
    iz = np.minimum(fz.astype(int), rows - 2)
    ax, az = fx - ix, fz - iz
    top = h[iz, ix] * (1 - ax) + h[iz, ix + 1] * ax
    bottom = h[iz + 1, ix] * (1 - ax) + h[iz + 1, ix + 1] * ax
    return top * (1 - az) + bottom * az


def course_line(name):
    """The game's middle line (x, z, piece rise) every metre, as built."""
    data = design["parse"](open(os.path.join(here, "courses", name + ".txt")).read())
    pieces, _ = builder["rotate_to_longest_straight"](data["pieces"])
    line, _ = design["walk"](pieces)
    pts = np.array([(p[0], -p[1], p[2]) for p in line] + [(line[0][0], -line[0][1], line[0][2])])
    seg = np.linalg.norm(np.diff(pts[:, :2], axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    ss = np.arange(0, s[-1], 1.0)
    out = np.stack([np.interp(ss, s, pts[:, k]) for k in range(3)], axis=1)
    pieces_at = np.interp(ss, s, np.array([p[3] for p in line] + [len(pieces)]))
    return out, pieces_at.astype(int), pieces


def stretches(mask):
    """(first, last) index runs where mask is set, round the lap."""
    n = len(mask)
    if mask.all():
        return [(0, n - 1)]
    out = []
    k = int(np.argmin(mask))
    run = None
    for j in range(k, k + n + 1):
        i = j % n
        if mask[i] and run is None:
            run = j
        elif not mask[i] and run is not None:
            out.append((run % n, (j - 1) % n))
            run = None
    return out


def hillshade(h):
    gz, gx = np.gradient(h, CELL)
    # Light from the north west, high up.
    lx, lz, ly = -0.5, -0.5, 0.7
    n = np.sqrt(gx * gx + gz * gz + 1)
    shade = (-gx * lx - gz * lz + ly) / n / math.sqrt(lx * lx + lz * lz + ly * ly)
    return np.clip(shade, 0, 1)


def draw(h, origin, course, real, out, label):
    px = 4
    rows, cols = h.shape
    shade = hillshade(h)
    lo, hi = h.min(), h.max()
    t = (h - lo) / max(hi - lo, 0.1)
    # Low green to high brown, shaded.
    base = np.stack([90 + 110 * t, 140 + 20 * t, 70 + 30 * t], axis=2)
    rgb = np.clip(base * (0.35 + 0.8 * shade)[:, :, None], 0, 255).astype(np.uint8)
    im = Image.fromarray(rgb).resize((cols * px, rows * px), Image.BILINEAR)
    d = ImageDraw.Draw(im)
    P = lambda p: ((p[0] - origin[0]) / CELL * px, (p[1] - origin[1]) / CELL * px)
    d.line([P(p) for p in real[::2]] + [P(real[0])], fill=(40, 90, 230), width=7)
    d.line([P(p) for p in course[::2]] + [P(course[0])], fill=(220, 30, 30), width=3)
    x, y = P((0.0, 0.0))
    d.ellipse([x - 6, y - 6, x + 6, y + 6], outline=(255, 255, 255), width=2)
    d.rectangle([0, 0, len(label) * 6 + 8, 16], fill=(255, 255, 255))
    d.text((4, 3), label, fill=(0, 0, 0))
    os.makedirs(os.path.dirname(out), exist_ok=True)
    im.save(out)


def write_extra(name, ground):
    path = os.path.join(here, "courses", name + ".extra.json")
    extra = json.load(open(path)) if os.path.exists(path) else {}
    extra.pop("hills", None)
    extra["ground"] = ground
    lines = ["{"]
    items = list(extra.items())
    for k, (key, value) in enumerate(items):
        entry = builder["value_lines"](key, value)
        if k < len(items) - 1:
            entry[-1] += ","
        lines += entry
    lines.append("}")
    open(path, "w").write("\n".join(lines) + "\n")


def main():
    args = sys.argv[1:]
    exaggerate = 1.5
    if "--exaggerate" in args:
        k = args.index("--exaggerate")
        exaggerate = float(args[k + 1])
        del args[k:k + 2]
    pick = None
    if "--pick" in args:
        k = args.index("--pick")
        pick = args[k + 1]
        del args[k:k + 2]
    name = args[0]
    pick = pick or name

    line, piece_at, pieces = course_line(name)
    real, origin_ll = fitting["real_line"](pick)
    if not origin_ll:
        raise SystemExit("%s.json has no origin, run fetch_picks.py %s again" % (pick, pick))
    moved, avg, worst, (sc, R, t) = fitting["fit"](line[:, :2], real, scale=True)
    flipped = fitting["fit"](line[:, :2] * [1.0, -1.0], real, scale=True)
    print("%s: scale %.3f, %.1f m average and %.1f m worst from the real line (mirrored it would be %.1f m)"
          % (name, 1.0 / sc, avg / sc, worst / sc, flipped[1] / flipped[3][0]))

    # The map: the road's box and MARGIN each side, on the 8 m squares.
    lo = np.floor((line[:, :2].min(axis=0) - MARGIN) / CELL) * CELL
    hi = np.ceil((line[:, :2].max(axis=0) + MARGIN) / CELL) * CELL
    cols, rows = int((hi[0] - lo[0]) / CELL) + 1, int((hi[1] - lo[1]) / CELL) + 1
    # Sampled wider, so the opening and blur have room at the edges.
    pad = 8
    gz, gx = np.mgrid[-pad:rows + pad, -pad:cols + pad].astype(float)
    gx, gz = lo[0] + gx * CELL, lo[1] + gz * CELL
    pts = np.stack([gx.ravel(), gz.ravel()], axis=1)
    osm = sc * pts @ R.T + t
    lat0, lon0 = origin_ll
    lat = lat0 - osm[:, 1] / DEGREE
    lon = lon0 + osm[:, 0] / (DEGREE * math.cos(math.radians(lat0)))
    raw = sample_dem(lat, lon).reshape(gx.shape)

    k = max(3, int(OPENING / CELL) | 1)
    ground = blur(opening(raw, k), [1 / 16, 4 / 16, 6 / 16, 4 / 16, 1 / 16])[pad:-pad, pad:-pad]
    # Real metres to course metres, then the exaggeration, from the start.
    h = (ground - height_at(ground, lo, 0.0, 0.0)) / sc * exaggerate
    squeeze = 1.0
    if h.max() - h.min() > TALLEST:
        squeeze = TALLEST / (h.max() - h.min())
        h *= squeeze
    q = np.round(h / ground_map.STEP) * ground_map.STEP
    # The road copy is blurred, so the whole map moves to put the road at
    # the start level with the start line, as with hills.
    road = road_heights(q)
    q -= np.round(height_at(road, lo, 0.0, 0.0) / ground_map.STEP) * ground_map.STEP
    q = np.round(q / ground_map.STEP) * ground_map.STEP
    road = road_heights(q)
    entry = ground_map.to_dict(q, lo)
    write_extra(name, entry)

    xs, zs = line[:, 0], line[:, 1]
    road_h = height_at(road, lo, xs, zs)
    # Grade over 8 m of road.
    grade = np.abs(np.roll(road_h, -4) - np.roll(road_h, 4)) / 8.0
    steep = int(np.argmax(grade))
    print("  map %d x %d, %d bytes, %.1f m top to bottom%s; road %.1f to %.1f m, steepest %.1f%% at %.0f m (piece %d)"
          % (cols, rows, len(entry["data"]), q.max() - q.min(), " (squeezed by %.2f)" % squeeze if squeeze < 1 else "",
             road_h.min(), road_h.max(), grade[steep] * 100, steep, piece_at[steep]))

    # The real profile: the map under the nearest point of the real line,
    # brought into the course, smoothed over 16 m.
    real_game = (real - t) @ R / sc
    near = fitting["nearest_index"](line[:, :2], real_game)
    profile = height_at(q, lo, real_game[near, 0], real_game[near, 1])
    kern = np.ones(33) / 33
    profile = np.convolve(np.concatenate([profile[-16:], profile, profile[:16]]), kern, "valid")
    gap = profile - road_h
    for a, b in stretches(np.abs(gap) > RAMP_GAP):
        length = (b - a) % len(line) + 1
        if length < 16:
            continue
        span = np.arange(a, a + length) % len(line)
        k = span[np.argmax(np.abs(gap[span]))]
        print("  ramp wanted: %.0f to %.0f m (pieces %d to %d), real ground %+.1f m off the road at %.0f m"
              % (a, b, piece_at[a], piece_at[b], gap[k], k))
    draw(q, lo, line[:, :2], real_game, os.path.join(PICTURES, name + ".png"),
         "%s  x%.1f  %.1f m top to bottom" % (name, exaggerate * squeeze, q.max() - q.min()))


if __name__ == "__main__":
    main()
