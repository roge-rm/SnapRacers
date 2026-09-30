#!/usr/bin/env python3
"""Finds the lap in a circuit OpenStreetMap has split into many ways.

Usage: find_lap.py <osm name> <lap length in m> [skip words ...]

Reads <name>.json from osm_track.py, joins the ways where their ends meet
(going the way they run, when they're one way), and prints the loops closest
to the real lap length, as the way ids in order. Ways whose name has one of
the skip words in it (like "pit") are left out. Put the ids of the one you
want in picks.json, and fetch_picks.py joins them up in that order.
"""
import json, math, os, sys

here = os.path.dirname(os.path.abspath(__file__))
name, target = sys.argv[1], float(sys.argv[2])
skip = [w.lower() for w in sys.argv[3:]]
lines = json.load(open(name + ".json") if os.path.exists(name + ".json") else open(os.path.join(here, name + ".json")))


def skipped(line):
    tags = line.get("tags", {})
    words = " ".join(str(tags.get(k, "")) for k in ("name", "name:en", "service")).lower()
    return any(w in words for w in skip)


# Ends closer than this are the same place.
NEAR = 1.0
ends = []


def end_of(p):
    for i, e in enumerate(ends):
        if math.dist(e, p) < NEAR:
            return i
    ends.append(p)
    return len(ends) - 1


# Edges as (from end, to end, way id, forwards, length).
edges = []
for line in lines:
    if skipped(line) or len(line["points"]) < 2:
        continue
    a, b = end_of(line["points"][0]), end_of(line["points"][-1])
    edges.append((a, b, line["id"], True, line["length"]))
    if line.get("tags", {}).get("oneway") != "yes":
        edges.append((b, a, line["id"], False, line["length"]))
out_of = {}
for e in edges:
    out_of.setdefault(e[0], []).append(e)

found = {}


def walk(start, at, path, used, length):
    if length > target * 1.25:
        return
    for e in out_of.get(at, []):
        if e[2] in used:
            continue
        if e[1] == start:
            loop = path + [e]
            total = length + e[4]
            key = frozenset(x[2] for x in loop)
            if key not in found:
                found[key] = (total, loop)
            continue
        walk(start, e[1], path + [e], used | {e[2]}, length + e[4])


for s in list(out_of):
    walk(s, s, [], set(), 0.0)
best = sorted(found.values(), key=lambda f: abs(f[0] - target))[:5]
for total, loop in best:
    print("%.0f m, %d ways: %s" % (total, len(loop), json.dumps([e[2] if e[3] else -e[2] for e in loop])))
