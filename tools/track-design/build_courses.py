# Turns the course short hand into the game's track files, with a line about
# each one.
# Usage: build_courses.py <out dir> <id> ...
# Landmarks, paint, weather, time, road colour, map rotation and the real
# circuit come from courses/<id>.extra.json when there is one (any course key
# but the pieces, and it wins over what's here), or else from the course file
# already in <out dir>.
import importlib.util, json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("design", os.path.join(here, "design.py"))
src = open(os.path.join(here, "design.py")).read().replace("\nmain()\n", "\n")
design = {"__file__": os.path.join(here, "design.py"), "__name__": "design"}
exec(compile(src, "design.py", "exec"), design)
INFO = {
 "peach_pit": "A long easy lap through the peach orchard, round the pond and past the red barns.",
 "trulli_turns": "Twisting lanes and tight hairpins between the trulli and the olive groves, over a low stone hump.",
 "lemon_lake": "Tight hairpins back and forth beside the lake, past the lemon trees and villas.",
 "pithead_park": "Tight bends and quick wiggles round an old coal mine, over a hump and past the slag heaps and gravel traps.",
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
 "cowbell_meadow": ("Karting de Crolles, Isère, France", "Over the green hills under the cliffs, past the chalets and the cows with their bells."),
 "gondola_gorge": ("Kartodromo di Ala, Trentino, Italy", "Down in the valley by the lake, under the cable car going up to the peaks."),
 "slalom_slopes": ("Karting Track Saalbach, Salzburg, Austria", "Through the snow at the ski resort, across the ice and off the ski jump."),
 "summit_switchback": ("Karting du Grand Arc, Albertville, Savoie, France", "Up the switchbacks with nothing at the edge, and the snowy peaks all around."),
 "cactus_canyon": ("Phoenix Kart Racing Association, Phoenix, Arizona, USA", "Through the saguaros under the red mesa, over the crest and across the railroad."),
 "rattlesnake_ridge": ("Willow Springs Kart Track, Rosamond, California, USA", "Twisting through the dry hills of the ranch, past the water tower and the windpumps."),
 "mirage_mesa": ("Thermal Club Karting Circuit, Thermal, California, USA", "Up onto the canyon rim with a drop on both sides, among the mesas and buttes."),
 "gold_rush_gulch": ("Desert Park Raceway, Reno, Nevada, USA", "Past the old gold mine and its carts, over the level crossing and the bridge in the gulch."),
 "parrot_perch": ("Sepang International Kart Circuit, Selangor, Malaysia", "Under the giant trees of the rainforest, where the parrots watch from the walkway up in the treetops."),
 "cascade_creek": ("Kart track in Pavas, San José, Costa Rica", "Down by the waterfall and over the creek on the rope bridge, through the mud on the river bank."),
 "pyramid_plunge": ("Kart track in Cancún, Quintana Roo, Mexico", "Past the old stepped pyramid and the stone heads, and off the jump into the jungle."),
 "monsoon_mire": ("Sentul Gokart Raceway, Bogor, West Java, Indonesia", "Through the mud in the monsoon rain, among the stilt houses and the tall green rock towers."),
 "lantern_lane": ("Shin-Tokyo Circuit, Ichihara, Chiba, Japan", "Between the walls under the neon signs, past the lantern gates and the tunnel."),
 "skyline_sprint": ("Jebel Ali Go Karting, Dubai, United Arab Emirates", "Fast and walled in among the tallest towers in the desert, lit up all night."),
 "double_decker_dash": ("Revolution Karting, Mile End, London, UK", "Round and round the old streets by the clock tower, past the parked buses."),
 "tuk_tuk_turns": ("Topkart Bangkok, Bangkok, Thailand", "Twisting back and forth under the expressway, past the golden temple spires."),
 "cumulus_curl": ("Kartódromo Internacional Lucas Guerrero, Chiva, Valencia, Spain", "Round and round the spiral above the clouds, past the waterfalls and under the rainbow."),
 "weathervane_way": ("Goodwood Kartways, Uxbridge, Ontario, Canada", "Out over the open edges between the windmill islands, where the weather vanes turn in the wind."),
 "zeppelin_zigzag": ("Bahrain International Karting Circuit, Sakhir, Bahrain", "Zigzagging past the airship dock and the sky lighthouse, and round the loop."),
 "skylark_swoop": ("Oakleigh Go Kart Racing Club, Clayton South, Victoria, Australia", "Round two loops among the hot air balloons, and off the jump over the clouds."),
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
    The lap is the same, it just starts somewhere else. Straights with walls
    all along count too, and keep their walls."""
    units = []  # one entry per straight tile, or the piece itself
    level = 0
    for p in pieces:
        walls = p.get("edges") == "walls"
        if p["type"] == "straight" and "surface" not in p and ("edges" not in p or walls):
            units += [("S" if not walls else "W", level)] * int(p.get("length", 1))
        else:
            units.append((p, level))
            level += int(p.get("rise", 0)) if p["type"] in ("ramp", "curve", "arc", "slant") else 0
    n = len(units)
    straight = lambda u: u in ("S", "W")
    best, best_len = 0, 0
    for i in range(n):
        if not straight(units[i][0]) or units[i][1] != 0 or straight(units[i - 1][0]):
            continue
        j = i
        while straight(units[j % n][0]) and j - i < n:
            j += 1
        if j - i > best_len:
            best, best_len = i, j - i
    ahead = max(1, min(4, best_len - 3))
    split = (best + best_len - ahead) % n
    rotated = units[split:] + units[:split]
    out = []
    run = 0
    kind = "S"
    for u, _ in rotated + [(None, 0)]:
        if straight(u) and (run == 0 or u == kind):
            kind = u
            run += 1
            continue
        while run > 0:
            chunk = min(3, run)
            piece = {"type": "straight", "length": chunk}
            if kind == "W":
                piece["edges"] = "walls"
            out.append(piece)
            run -= chunk
        if straight(u):
            kind = u
            run = 1
        elif u is not None:
            out.append(u)
    return out, best_len


# Kept from the old course file when there's no extra file. The start pose
# isn't, since it goes with the old pieces.
KEPT = ["inspired_by", "road_colour", "map_rotation", "weather", "time", "fixed_time", "landmarks", "paint"]


def extras_for(name, out_dir):
    path = os.path.join(here, "courses", name + ".extra.json")
    if os.path.exists(path):
        extra = json.load(open(path))
        extra.pop("pieces", None)
        return extra
    old = os.path.join(out_dir, name + ".json")
    if not os.path.exists(old):
        return {}
    data = json.load(open(old))
    return {k: data[k] for k in KEPT if k in data}


def value_lines(key, value):
    """A key and its value, with lists of dictionaries one per line."""
    if isinstance(value, list) and value and all(isinstance(v, dict) for v in value):
        return ['\t%s: [' % json.dumps(key), ",\n".join("\t\t" + json.dumps(v) for v in value), "\t]"]
    return ["\t%s: %s" % (json.dumps(key), json.dumps(value))]


out_dir = sys.argv[1]
for name in sys.argv[2:]:
    data = design["parse"](open(os.path.join(here, "courses", name + ".txt")).read())
    data["pieces"], run = rotate_to_longest_straight(data["pieces"])
    line, end = design["walk"](data["pieces"])
    import math
    assert math.hypot(end[0], end[1]) < 0.5 and abs(end[2]) < 0.1 and end[5] == 0, name + " doesn't close after turning"
    clashes = design["clashes"](line, len(data["pieces"]), data.get("width", 13.0), design["reaches"](line, data["pieces"]))
    assert not clashes, "%s clashes after turning: %s" % (name, clashes)
    if min(p[2] for p in line) < -0.1:
        raise SystemExit(name + " goes underground")
    about = INFO[name]
    ordered = {"name": data["name"]}
    # A pair is the real circuit it's based on and then the line about it.
    if isinstance(about, tuple):
        ordered["inspired_by"], about = about
    ordered.update({"about": about, "theme": data.get("theme", "orchard"),
                    "laps": data.get("laps", 3), "width": data.get("width", 13.0), "grid": 32})
    # How much the ground rises and falls around it (see TrackPath.hills).
    if data.get("hills", 0):
        ordered["hills"] = data["hills"]
    extra = extras_for(name, out_dir)
    if "inspired_by" in extra and "inspired_by" not in ordered:
        ordered = {"name": ordered["name"], "inspired_by": extra["inspired_by"], **{k: v for k, v in ordered.items() if k != "name"}}
    for k, v in extra.items():
        ordered[k] = v
    ordered["pieces"] = data["pieces"]
    lines = ["{"]
    for k, v in ordered.items():
        if k == "pieces":
            lines.append('\t"pieces": [')
            lines.append(",\n".join("\t\t" + json.dumps(p) for p in v))
            lines.append("\t]")
        else:
            entry = value_lines(k, v)
            entry[-1] += ","
            lines += entry
    lines.append("}")
    open(os.path.join(out_dir, name + ".json"), "w").write("\n".join(lines) + "\n")
    print("wrote %s (start on a %d tile straight)" % (name, run))
