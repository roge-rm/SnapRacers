# Track design tools

Every course in SnapRacers is based on a real circuit. These are the tools I used to turn the real layouts into brick track pieces.

The real layouts come from OpenStreetMap, where kart tracks are mapped as raceways. That map data is © OpenStreetMap contributors and available under the Open Database Licence.

## How a course gets made

1. `osm_track.py <name> <lat> <lon> [radius]` downloads the raceways near a circuit and draws them, so I can pick out the kart track (`--coaster` looks for roller coaster track instead, and `fetch_picks.py --flat` leaves out a coaster's map levels, which only say how high its track stands). A big circuit is usually split into many ways, and `find_lap.py <name> <lap length> pit` joins them up and lists the loops closest to the real lap length. The ones I picked are in `picks.json`, and `fetch_picks.py` downloads them again by their map ids and joins them in order (or `--local <folder>` joins them from what osm_track.py already downloaded). It keeps what each way is made of and which level it's on, so a rallycross circuit's gravel comes out as gravel and an indoor track with an upper deck keeps it.
2. `real.py <name>` draws the picked track large, with arrows for the way it runs and a grid of game tiles over it.
3. `tracer.py <name> <scale> <out.txt> [beam] [reverse]` lays track pieces along the real line. The scale makes a lap about 1600 to 1850 m, which is about 1.5 times a real kart circuit since the karts are about 1.6 times the size of real ones, and a quarter to a half of a big race track. A bigger beam (like 1500) fits a big circuit shrunk down better, and bits of road stay at least a tile (32 m) apart middle to middle, for grass and tire stacks between them. It keeps the pieces that stay closest to the real line, never run into themselves and finish exactly back at the start. Where the real track crosses itself on a bridge, the road can cross there too. It takes a few minutes, so I run several at once. Pieces that follow gravel or dirt on the real circuit come out as gravel (`!v`). Where the real track runs over itself on an upper level, the road only keeps clear of road on its own level, and it climbs up two levels and back down where the real one does (`^2`, `^-2`). Indoor tracks are small, so I make them three to six times as big. A roller coaster runs out and back beside itself, so I give it two levels by hand, the first half of the lap up high and the rest low, or its own map levels where they say which bit runs over which. Where the road still crosses itself, I search for somewhere to lift it onto a bridge, and turn a slant that's up high into a corkscrew (`XR`, `XL`).
4. The traced pieces go into `courses/<id>.txt` in a short hand (see the top of `design.py`), where I add the name, the theme, how hilly it is (`hills=` in metres) and the stunts, like a hump, a jump, a loop, a wall ride or a bridge.
5. `design.py courses/<id>.txt [<name>] [out.png]` checks a course closes and doesn't run into itself, and draws it beside the real circuit.
6. `build_courses.py ../../data/tracks <id> ...` writes the game's course files, with each start line on the course's longest straight.

The short hand knows every piece in the track editor's drawer: straights of any length, arcs of 15 to 75°, 90° curves, slants and offsets, ramps, humps, banked bends, jumps, loops, corkscrews, crossings, shortcut bends and all the splits (the list is at the top of `parse()` in `design.py`). Anything else can go in as JSON with `@{...}`.

Landmarks, paint, weather, time, road colour and map rotation aren't in the short hand. `build_courses.py` keeps them from the course file it's replacing, or takes them from `courses/<id>.extra.json` when there is one, which can set any course key but the pieces.

To check courses with the game's own code, run `res://tools/track-design/course_check.tscn` headless, with course ids or course files after `--`, or nothing for all of them. It prints a line a course: closes, clashes, length, the closest two stretches come middle to middle, the editor's problems, paint squares, landmarks, the start, and whether it closes mirrored and reversed. Landmarks the editor wouldn't let you drop and paint it wouldn't put by the road count as fails.

`arc_tracer.py <id> <out.txt>` traces a circuit again from its `<id>_aligned.json` with the newer pieces: arcs of 15 to 90 degrees in all four sizes and half and quarter straights, closed with an adjustable offset and whole straights before the start. Its short hand goes in `courses/<id>.txt` like the old tracer's. `fit.py <course> <id> [out.png]` says how far a course strays from the real line, on average and at worst, and draws one over the other.

`baseline.sh [<id> ...]` races eight Expert AI karts round each course in clear weather by day and writes `baseline.md` with the best lap, resets and who finished, from the logs in `build/soak-baseline`.

The cups and the order of the courses are in `data/grand_prix.json`.
