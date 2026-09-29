#!/usr/bin/env python3
"""Downloads the kart tracks picked in picks.json straight from their
OpenStreetMap ways, so they can be traced again without looking for them.

Usage: fetch_picks.py [name ...]
Writes <name>.json for each, the same as osm_track.py does, in metres from the
track's first point (x east, y south).
"""
import json, math, os, sys, time, urllib.parse, urllib.request

here = os.path.dirname(os.path.abspath(__file__))
picks = json.load(open(os.path.join(here, "picks.json")))
names = sys.argv[1:] or sorted(picks)
for name in names:
    ids = ",".join(str(i) for i in picks[name])
    q = "[out:json][timeout:40];way(id:%s);out geom tags;" % ids
    data = None
    for server in ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]:
        try:
            req = urllib.request.Request(server, data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": "SnapRacers-research/1.0"})
            data = json.load(urllib.request.urlopen(req, timeout=60))
            break
        except Exception as e:
            print("server failed", server, e)
    if data is None:
        sys.exit(1)
    ways = [e for e in data["elements"] if e.get("geometry")]
    lat = ways[0]["geometry"][0]["lat"]
    lon = ways[0]["geometry"][0]["lon"]
    k = 111320.0
    lines = []
    for w in ways:
        pts = [((g["lon"] - lon) * k * math.cos(math.radians(lat)), -(g["lat"] - lat) * k) for g in w["geometry"]]
        length = sum(math.dist(pts[i], pts[i + 1]) for i in range(len(pts) - 1))
        lines.append({"id": w["id"], "tags": w.get("tags", {}), "points": pts, "length": length})
    json.dump(lines, open(os.path.join(here, name + ".json"), "w"))
    print("%s: %d ways, %.0f m" % (name, len(lines), sum(l["length"] for l in lines)), flush=True)
    time.sleep(8)
