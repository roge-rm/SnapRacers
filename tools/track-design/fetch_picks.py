#!/usr/bin/env python3
"""Downloads the circuits picked in picks.json straight from their
OpenStreetMap ways, so they can be traced again without looking for them.

Usage: fetch_picks.py [--local <folder>] [name ...]
Writes <name>.json for each, the same as osm_track.py does, in metres from the
track's first point (x east, y south). A pick of several ways (see
find_lap.py) is joined into one line in the order it lists them, and a
negative id means that way runs backwards. With --local it uses the ways
osm_track.py already downloaded into that folder instead of asking the
server again.
"""
import json, math, os, sys, time, urllib.parse, urllib.request

here = os.path.dirname(os.path.abspath(__file__))
picks = json.load(open(os.path.join(here, "picks.json")))
args = sys.argv[1:]
local = None
if args[:1] == ["--local"]:
    local, args = args[1], args[2:]
names = args or sorted(picks)


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
        for i in picks[name]:
            way = by_id[abs(i)]["points"]
            way = way if i > 0 else way[::-1]
            pts += way if not pts else way[1:]
        length = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
        lines = [{"id": picks[name][0], "tags": {}, "points": pts, "length": length}]
    json.dump(lines, open(os.path.join(here, name + ".json"), "w"))
    print("%s: %d ways, %.0f m" % (name, len(lines), sum(l["length"] for l in lines)), flush=True)
    time.sleep(8)
