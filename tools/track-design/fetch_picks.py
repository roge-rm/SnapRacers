#!/usr/bin/env python3
"""Downloads the circuits picked in picks.json straight from their
OpenStreetMap ways, so they can be traced again without looking for them.

Usage: fetch_picks.py [--local <folder>] [name ...]
Writes <name>.json for each, the same as osm_track.py does, in metres from the
track's first point (x east, y south). A pick of several ways (see
find_lap.py) is joined into one line in the order it lists them, and a
negative id means that way runs backwards. With --local it uses the ways
osm_track.py already downloaded into that folder instead of asking the
server again. A joined lap keeps where each way starts along it, its
surface and its level, so the tracer can tell which bits are gravel and which
run over the top of others.
"""
import json, math, os, sys, time, urllib.parse, urllib.request

here = os.path.dirname(os.path.abspath(__file__))
picks = json.load(open(os.path.join(here, "picks.json")))
args = sys.argv[1:]
local = None
if args[:1] == ["--local"]:
    local, args = args[1], args[2:]
names = args or sorted(picks)
# Ways whose ends are closer than this meet, and a lap that ends within JOIN
# of a point on its first way joins it there.
GAP = 5.0
JOIN = 15.0


def download(ids):
    q = "[out:json][timeout:40];way(id:%s);out geom tags;" % ",".join(str(i) for i in ids)
    for attempt in range(3):
        for server in ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]:
            try:
                req = urllib.request.Request(server, data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": "SnapRacers-research/1.0"})
                return json.load(urllib.request.urlopen(req, timeout=60))
            except Exception as e:
                print("server failed", server, e)
        time.sleep(30)
    sys.exit(1)


def from_nearest(way, point):
    """The rest of the way from the spot nearest to this point, which can be
    between two of its points, leaving its last bit for a way that joins
    near its own end."""
    total = sum(math.dist(a, b) for a, b in zip(way, way[1:]))
    best, best_k, best_at, along = None, 0, way[0], 0.0
    for k, (a, b) in enumerate(zip(way, way[1:])):
        if along > total * 0.85:
            break
        seg = math.dist(a, b)
        t = 0.0 if seg == 0 else max(0.0, min(1.0, ((point[0] - a[0]) * (b[0] - a[0]) + (point[1] - a[1]) * (b[1] - a[1])) / seg ** 2))
        at = [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t]
        if best is None or math.dist(at, point) < best:
            best, best_k, best_at = math.dist(at, point), k, at
        along += seg
    return [best_at] + way[best_k + 1:]


for name in names:
    ids = [abs(i) for i in picks[name]]
    if local:
        lines = [l for l in json.load(open(os.path.join(local, name + ".json"))) if l["id"] in ids]
    else:
        ways = [e for e in download(ids)["elements"] if e.get("geometry")]
        lat = ways[0]["geometry"][0]["lat"]
        lon = ways[0]["geometry"][0]["lon"]
        k = 111320.0
        lines = []
        for w in ways:
            pts = [((g["lon"] - lon) * k * math.cos(math.radians(lat)), -(g["lat"] - lat) * k) for g in w["geometry"]]
            length = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
            lines.append({"id": w["id"], "tags": w.get("tags", {}), "points": pts, "length": length})
    if len(picks[name]) > 1:
        by_id = {l["id"]: l for l in lines}
        pts = []
        # Where each way starts along the lap, and what it's made of.
        surfaces = []
        for i in picks[name]:
            way = by_id[abs(i)]["points"]
            way = way if i > 0 else way[::-1]
            kind = by_id[abs(i)]["tags"].get("surface", "asphalt")
            level = int(by_id[abs(i)]["tags"].get("layer", "0") or 0)
            if pts and math.dist(pts[-1], way[0]) <= GAP:
                surfaces.append([len(pts) - 1, kind, level])
                pts += way[1:]
            else:
                # A way that the lap joins partway along starts where it joins.
                if pts:
                    way = from_nearest(way, pts[-1])
                surfaces.append([len(pts), kind, level])
                pts += way
        # A lap that comes back onto its first way partway along, past a
        # starting grid, starts there instead.
        if math.dist(pts[-1], pts[0]) > GAP:
            early = range(max(len(pts) * 3 // 10, 1))
            k = min(early, key=lambda k: math.dist(pts[-1], pts[k]))
            if k > 0 and math.dist(pts[-1], pts[k]) < JOIN:
                pts = pts[k:]
                surfaces = [[max(s[0] - k, 0)] + s[1:] for s in surfaces]
        along = [0.0]
        for a, b in zip(pts, pts[1:]):
            along.append(along[-1] + math.dist(a, b))
        tags = {"surfaces": [[round(along[s[0]], 1)] + s[1:] for s in surfaces]}
        lines = [{"id": picks[name][0], "tags": tags, "points": pts, "length": along[-1]}]
    json.dump(lines, open(os.path.join(here, name + ".json"), "w"))
    print("%s: %d ways, %.0f m" % (name, len(lines), sum(l["length"] for l in lines)), flush=True)
    time.sleep(8)
