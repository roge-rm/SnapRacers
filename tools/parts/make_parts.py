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


# Parts with a twin among the first parts weigh the same and are as strong,
# so karts built from either drive the same.
TWINS = {
    "p_plate_1x4": "plate_1x4", "p_plate_2x4": "plate_2x4", "p_plate_2x6": "plate_2x6", "p_plate_4x4": "plate_4x4",
    "p_plate_4x8": "plate_4x8", "p_plate_6x10": "plate_6x10", "p_plate_6x12": "plate_6x12",
    "p_brick_1x1": "brick_1x1", "p_brick_1x2": "brick_1x2", "p_brick_1x4": "brick_1x4", "p_brick_1x6": "brick_1x6",
    "p_brick_2x2": "brick_2x2", "p_brick_2x4": "brick_2x4", "p_round_brick_2x2": "brick_round_2x2", "p_tile_2x4": "tile_2x4",
    "p_slope_1x2": "slope_1x2", "p_slope_2x2": "slope_2x2", "p_slope_2x4": "slope_long_2x4", "p_curve_2x4": "curve_2x4", "p_curve_4x4": "curve_4x4",
    "w_kart": "wheel_small", "w_kart_wide": "wheel_small_wide", "w_racing": "wheel_medium", "w_slick": "wheel_big_slick",
    "w_offroad": "wheel_knobbly", "w_moto": "wheel_skinny", "w_moto_trail": "wheel_skinny", "w_scooter": "wheel_small",
}
# The 6 wide plates are chassis plates, heavy and strong like the first ones,
# for each stud of them.
CHASSIS = {"p_plate_6x6": 36, "p_plate_6x8": 48}
FIRST = json.load(open(os.path.join(GAME, "data", "parts.json")))["parts"]


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
    if p.lamp is not None:
        out["lamp"] = {"mesh": "res://%s/%s_lamp.obj" % (MESHES, p.id), "color": p.lamp[1]}
    for k, v in p.stats.items():
        out[k] = v
    twin_of = out.pop("twin", None)
    if twin_of:
        # A remodelled first part takes everything but its look from it.
        for key, value in FIRST[twin_of].items():
            if key not in ("size", "color", "kind"):
                out[key] = value
        out["name"] = FIRST[twin_of]["name"]
    engine_twin = out.pop("engine_twin", None)
    if engine_twin:
        # A motorbike frame has an engine in it, and sounds like one of the
        # first ones.
        twin = FIRST[engine_twin]
        out["sound"] = engine_twin
        out["mass"] = round(twin["mass"] * 0.8 + 6.0, 1)
        out["strength"] = twin["strength"]
    if "seat_box" in out:
        out["seat_box"] = fine(out["seat_box"][:3]) + fine(out["seat_box"][3:])
    if p.id in TWINS:
        twin = FIRST[TWINS[p.id]]
        out["mass"] = twin["mass"]
        out["strength"] = twin["strength"]
    elif p.id in CHASSIS:
        studs = CHASSIS[p.id]
        out["mass"] = round(FIRST["plate_6x10"]["mass"] * studs / 60.0, 1)
        out["strength"] = round(FIRST["plate_6x10"]["strength"] * math.sqrt(studs / 60.0), -1)
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
        if p.lamp is not None:
            triangles += save_obj(p.lamp[0], p.size, os.path.join(GAME, MESHES, p.id + "_lamp.obj"))
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
