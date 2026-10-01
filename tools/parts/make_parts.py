#!/usr/bin/env python3
"""Makes every part in library.py: its mesh, and its entry in
data/parts_made.json with its connectors, size and stats. Nothing is
downloaded or copied, every part is modelled here.

  uv run --with manifold3d --with numpy tools/parts/make_parts.py [ids...]

With ids it only makes those, and keeps the rest of the file as it was. The
meshes and the file are kept in the repository, so building the game doesn't
need this. After making parts, run the Godot import (tools/run-tests.sh does
it first thing).
"""

import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

import library  # noqa: E402
from kit import FINE, PLATE, STUD, fine, save_obj  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.normpath(os.path.join(HERE, "..", ".."))
MESHES = "parts/meshes"
OUT = os.path.join(GAME, "data", "parts_made.json")


def entry_for(p):
    size = p.size
    out = {
        "name": p.name,
        "kind": p.kind,
        "group": p.group,
        # The box it fills on the stud grid, rounded up, for the things that
        # still go by the grid.
        "size": [max(1, math.ceil(size[0] / STUD - 0.01)), max(1, math.ceil(size[1] / PLATE - 0.01)), max(1, math.ceil(size[2] / STUD - 0.01))],
        "fine_size": fine(size),
        "color": p.color,
        "mesh": "res://%s/%s.obj" % (MESHES, p.id),
        "connectors": [],
    }
    if p.finish != "plastic":
        out["finish"] = p.finish
    for c in p.connectors:
        con = {"type": c["type"], "at": fine(c["at"]), "axis": c["axis"]}
        if c.get("length"):
            con["length"] = round(c["length"] / FINE, 3)
        out["connectors"].append(con)
    solids = p.stats.pop("solids", None)
    if solids is not None:
        out["solids"] = [fine(s[:3]) + fine(s[3:]) for s in solids]
    if p.trim is not None:
        out["trim"] = {"mesh": "res://%s/%s_trim.obj" % (MESHES, p.id), "color": p.trim[1], "finish": p.trim[2]}
    for k, v in p.stats.items():
        out[k] = v
    return out


def main():
    only = set(sys.argv[1:])
    made = {}
    if only and os.path.exists(OUT):
        made = json.load(open(OUT)).get("parts", {})
    triangles = 0
    for make in library.PARTS:
        p = make()
        if only and p.id not in only:
            continue
        triangles += save_obj(p.solid, p.size, os.path.join(GAME, MESHES, p.id + ".obj"))
        if p.trim is not None:
            triangles += save_obj(p.trim[0], p.size, os.path.join(GAME, MESHES, p.id + "_trim.obj"))
        made[p.id] = entry_for(p)
        print("made", p.id)
    data = {
        "_comment": "Made by tools/parts/make_parts.py, so change the parts there. Sizes and connector spots are in the fine unit, a twentieth of a stud (see scripts/parts/grid.gd).",
        "parts": made,
    }
    with open(OUT, "w") as f:
        json.dump(data, f, indent="\t")
    print("%d parts, %d triangles in all" % (len(made), triangles))


if __name__ == "__main__":
    main()
