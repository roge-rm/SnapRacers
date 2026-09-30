# Track design tools

Every course in SnapRacers is based on a real circuit. These are the tools I used to turn the real layouts into brick track pieces.

The real layouts come from OpenStreetMap, where kart tracks are mapped as raceways. That map data is © OpenStreetMap contributors and available under the Open Database Licence.

## How a course gets made

1. `osm_track.py <name> <lat> <lon> [radius]` downloads the raceways near a circuit and draws them, so I can pick out the kart track (`--coaster` looks for roller coaster track instead). A big circuit is usually split into many ways, and `find_lap.py <name> <lap length> pit` joins them up and lists the loops closest to the real lap length. The ones I picked are in `picks.json`, and `fetch_picks.py` downloads them again by their map ids and joins them in order (or `--local <folder>` joins them from what osm_track.py already downloaded). It keeps what each way is made of, so a rallycross circuit's gravel comes out as gravel.
2. `real.py <name>` draws the picked track large, with arrows for the way it runs and a grid of game tiles over it.
3. `tracer.py <name> <scale> <out.txt> [beam] [reverse]` lays track pieces along the real line. The scale makes a lap about 1600 to 1850 m, which is about 1.5 times a real kart circuit since the karts are about 1.6 times the size of real ones, and a quarter to a half of a big race track. A bigger beam (like 1500) fits a big circuit shrunk down better, and bits of road stay at least a tile (32 m) apart middle to middle, for grass and tire stacks between them. It keeps the pieces that stay closest to the real line, never run into themselves and finish exactly back at the start. Where the real track crosses itself on a bridge, the road can cross there too. It takes a few minutes, so I run several at once. Pieces that follow gravel or dirt on the real circuit come out as gravel (`!v`).
4. The traced pieces go into `courses/<id>.txt` in a short hand (see the top of `design.py`), where I add the name, the theme, how hilly it is (`hills=` in metres) and the stunts, like a hump, a jump, a loop, a wall ride or a bridge.
5. `design.py courses/<id>.txt [<name>] [out.png]` checks a course closes and doesn't run into itself, and draws it beside the real circuit.
6. `build_courses.py ../../data/tracks <id> ...` writes the game's course files, with each start line on the course's longest straight.

The cups and the order of the courses are in `data/grand_prix.json`.
