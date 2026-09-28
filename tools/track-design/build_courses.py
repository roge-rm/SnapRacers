# Turns the course short hand into the game's track files, with where each
# one comes from and a line about it.
import importlib.util, json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("design", os.path.join(here, "design.py"))
src = open(os.path.join(here, "design.py")).read().replace("\nmain()\n", "\n")
design = {"__file__": os.path.join(here, "design.py"), "__name__": "design"}
exec(compile(src, "design.py", "exec"), design)
INFO = {
 "peach_pit": ("Atlanta Motorsports Park, Georgia, USA", "An easy first lap through the peach orchards and past the big red barns."),
 "trulli_turns": ("La Conca, Muro Leccese, Italy", "Twisty lanes between the trulli and the olive groves, with a hump on the first straight."),
 "lemon_lake": ("South Garda Karting, Lonato, Italy", "Tight hairpins by the lake among the lemon trees and cypresses, and a banked sweeper on the way home."),
 "pithead_park": ("Karting Genk, Belgium", "A fast, flowing lap around an old coal mine, with the pithead towers watching and a hump over the slag heap."),
 "delta_dash": ("Adria Karting Raceway, Italy", "Out across the marshes of the river delta, past the fishing huts on stilts and over a hump bridge."),
 "bucketwheel_bend": ("Erftlandring, Kerpen, Germany", "Around the rim of an open pit mine where the giant bucket wheel digger works, with dirt on the back section."),
 "foundry_flats": ("Prokart Raceland, Wackersdorf, Germany", "Long straights between the factory halls and the container stacks, and a jump off the loading ramp."),
 "amber_arc": ("Kandavas Kartodroms, Latvia", "A quiet old town by the river, and over the hump of the stone bridge."),
 "timberline": ("Greg Moore Raceway, Chilliwack, BC, Canada", "A mountain road through the pines and maples of the Fraser Valley that climbs up and drops back down."),
 "frostbite_forest": ("Kristianstad Karting, Sweden", "Snow on the ground, red cottages in the woods and icy patches on the road, so take it easy."),
 "dune_drift": ("Dubai Kartdrome, United Arab Emirates", "A figure eight in the desert under the skyscrapers, over a bridge, with sand blown across the back straight."),
 "whistlestop_woods": ("Karting des Fagnes, Mariembourg, Belgium", "Through the Ardennes woods and past the old steam railway, over the level crossing."),
 "windmill_ridge": ("Circuito Internacional de Zuera, Spain", "Up and over the ridges past the windmills, and a wall ride banked almost on its side."),
 "launchpad_loop": ("Orlando Kart Center, Florida, USA", "At the space centre, where a loop sends you upside down in the shadow of the rocket."),
 "magma_mile": ("Circuito Internazionale Napoli, Sarno, Italy", "In the shadow of the volcano, with a jump over the lava."),
 "castle_keep": ("New Castle Motorsports Park, Indiana, USA", "Around the castle walls and over the drawbridge, in the last race of the last cup."),
}
def rotate_to_longest_straight(pieces):
    """Moves the start line into the longest run of straights at ground level,
    with three tiles behind it for the grid where it can, and up to four in
    front so the pack spreads out before the first corner.
    The lap is the same, it just starts somewhere else."""
    units = []  # one entry per straight tile, or the piece itself
    level = 0
    for p in pieces:
        if p["type"] == "straight" and "surface" not in p and "edges" not in p:
            units += [("S", level)] * int(p.get("length", 1))
        else:
            units.append((p, level))
            level += int(p.get("rise", 0)) if p["type"] in ("ramp", "curve", "slant") else 0
    n = len(units)
    best, best_len = 0, 0
    for i in range(n):
        if units[i][0] != "S" or units[i][1] != 0 or units[i - 1][0] == "S":
            continue
        j = i
        while units[j % n][0] == "S" and j - i < n:
            j += 1
        if j - i > best_len:
            best, best_len = i, j - i
    ahead = max(1, min(4, best_len - 3))
    split = (best + best_len - ahead) % n
    rotated = units[split:] + units[:split]
    out = []
    run = 0
    for u, _ in rotated + [(None, 0)]:
        if u == "S":
            run += 1
            continue
        while run > 0:
            chunk = min(3, run)
            out.append({"type": "straight", "length": chunk})
            run -= chunk
        if u is not None:
            out.append(u)
    return out, best_len


out_dir = sys.argv[1]
for name in sys.argv[2:]:
    data = design["parse"](open(os.path.join(here, "courses", name + ".txt")).read())
    data["pieces"], run = rotate_to_longest_straight(data["pieces"])
    line, end = design["walk"](data["pieces"])
    import math
    assert math.hypot(end[0], end[1]) < 0.5 and abs(end[2]) < 0.1, name + " doesn't close after turning"
    clashes = design["clashes"](line, len(data["pieces"]), data.get("width", 10.0))
    assert not clashes, "%s clashes after turning: %s" % (name, clashes)
    if min(p[2] for p in line) < -0.1:
        raise SystemExit(name + " goes underground")
    where, about = INFO[name]
    ordered = {"name": data["name"], "inspired_by": where, "about": about, "theme": data.get("theme", "orchard"),
               "laps": data.get("laps", 3), "width": data.get("width", 10.0), "pieces": data["pieces"]}
    lines = ["{"]
    for k, v in ordered.items():
        if k == "pieces":
            lines.append('\t"pieces": [')
            lines.append(",\n".join("\t\t" + json.dumps(p) for p in v))
            lines.append("\t]")
        else:
            lines.append("\t%s: %s," % (json.dumps(k), json.dumps(v)))
    lines.append("}")
    open(os.path.join(out_dir, name + ".json"), "w").write("\n".join(lines) + "\n")
    print("wrote %s (start on a %d tile straight)" % (name, run))
