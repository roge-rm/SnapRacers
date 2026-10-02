# Turns the course short hand into the game's track files, with a line about
# each one.
import importlib.util, json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("design", os.path.join(here, "design.py"))
src = open(os.path.join(here, "design.py")).read().replace("\nmain()\n", "\n")
design = {"__file__": os.path.join(here, "design.py"), "__name__": "design"}
exec(compile(src, "design.py", "exec"), design)
INFO = {
 "peach_pit": "An easy first lap through the peach orchards and past the big red barns.",
 "trulli_turns": "Twisty lanes between the trulli and the olive groves, with a hump on the first straight.",
 "lemon_lake": "Tight hairpins by the lake among the lemon trees and cypresses, and a banked sweeper on the way home.",
 "pithead_park": "A fast, flowing lap around an old coal mine, with the pithead towers watching and a hump over the slag heap.",
 "delta_dash": "Out across the marshes of the river delta, past the fishing huts on stilts and over a hump bridge.",
 "bucketwheel_bend": "Around the rim of an open pit mine where the giant bucket wheel digger works, with dirt on the back section.",
 "foundry_flats": "Long straights between the factory halls and the container stacks, and a jump off the loading ramp.",
 "amber_arc": "A quiet old town by the river, and over the hump of the stone bridge.",
 "timberline": "A mountain road through the pines and maples of the Fraser Valley that climbs up and drops back down.",
 "frostbite_forest": "Snow on the ground, red cottages in the woods and icy patches on the road, so take it easy.",
 "dune_drift": "A figure eight in the desert under the skyscrapers, over a bridge, with sand blown across the back straight.",
 "whistlestop_woods": "Through the Ardennes woods and past the old steam railway, over the level crossing.",
 "windmill_ridge": "Up and over the ridges past the windmills, and a wall ride banked almost on its side.",
 "launchpad_loop": "At the space centre, where a loop sends you upside down in the shadow of the rocket.",
 "magma_mile": "In the shadow of the volcano, with a jump over the lava.",
 "castle_keep": "Around the castle walls and over the drawbridge, in the last race of the Keystone Cup.",
 "sakura_swirl": "A figure eight under the cherry blossom, under the bridge and back over it, with the big wheel watching.",
 "rouge_ridge": "Down to the stream and straight back up the steep climb, then out through the forest hills of the Ardennes.",
 "royal_run": "Flat out through the royal park and past the old banking, braking hard for the chicanes.",
 "dry_lagoon": "Over the golden California hills and down the steep corkscrew drop.",
 "oast_hill": "Down the hill past the oast houses, then off the tarmac and over the crest on the gravel.",
 "windsurf_way": "Twisting around between the palms and the parasols, a stone's throw from the beach.",
 "coral_cove": "Fast and open on the coast, past the old watchtower and the white villas.",
 "blue_lagoon": "Tight and twisty under the walls of the old harbour fort.",
 "penguin_point": "Big fast bends along the clifftops, where the little penguins come up from the sea.",
 "menhir_meadow": "Half tarmac and half gravel, among the standing stones and the crowd on the banks.",
 "pine_hill_leap": "Through the pine forest and the red cottages, in and out of the gravel all the way around.",
 "devils_dust": "Around the tarmac by the airport, then a long twisty stretch of gravel and over the crest on the way home.",
 "hairpin_hall": "Hairpin after hairpin between the barriers, around and around the hall.",
 "bohemian_bends": "A tangle of tight bends that fold back on each other, under the lights.",
 "spark_deck": "Up onto the deck and back down under it, around a hall built on two levels.",
 "neon_nights": "Around the hall in the glow of the lights, with the crowd watching from the deck.",
 "serpent_summit": "Up the lift and around the park on the high rails, through a corkscrew and over the camelback.",
 "lakeshore_plunge": "Out along the lake shore and back, over an airtime hill and upside down through the corkscrew.",
 "red_rocket": "A figure eight out of the desert, up over the top hat and down under the big red roof.",
 "twister_pines": "Twisting around and around itself in the pines, upside down on the way.",
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
    clashes = design["clashes"](line, len(data["pieces"]), data.get("width", 13.0))
    assert not clashes, "%s clashes after turning: %s" % (name, clashes)
    if min(p[2] for p in line) < -0.1:
        raise SystemExit(name + " goes underground")
    about = INFO[name]
    ordered = {"name": data["name"], "about": about, "theme": data.get("theme", "orchard"),
               "laps": data.get("laps", 3), "width": data.get("width", 13.0), "grid": 32}
    # How much the ground rises and falls around it (see TrackPath.hills).
    if data.get("hills", 0):
        ordered["hills"] = data["hills"]
    ordered["pieces"] = data["pieces"]
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
