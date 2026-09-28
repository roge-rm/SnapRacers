# Track design tools

Every course in SnapRacers is based on a real kart circuit. These are the tools I used to turn the real layouts into brick track pieces.

The real layouts come from OpenStreetMap, where kart tracks are mapped as raceways. The courses are traced from that map data, which is © OpenStreetMap contributors and available under the Open Database License.

## How a course gets made

1. `osm_track.py <name> <lat> <lon> [radius]` downloads the raceways near a circuit and draws them, so I can pick out the kart track. The ones I picked are in `picks.json`.
2. `real.py <name>` draws the picked track large, with arrows for the way it runs and a grid of game tiles over it.
3. `tracer.py <name> <scale> <out.txt>` lays track pieces along the real line. It keeps the sequences that stay closest to it, never let the road run into itself, and finish exactly back on the start. It takes a few minutes, so I run several at once. Where the real track crosses itself on a bridge, it lets the road cross there too.
4. The traced pieces go into `courses/<id>.txt` in a short hand (see the top of `design.py`), where I add the name, the theme and the stunts, like a hump, a jump, a loop, a wall ride or a bridge.
5. `design.py courses/<id>.txt [<name>] [out.png]` checks a course closes and doesn't run into itself, and draws it beside the real circuit.
6. `build_courses.py ../../data/tracks <id> ...` writes the game's course files. It moves each start line onto the course's longest straight, so there's room for the grid behind it and a run to the first corner.

The cups and the order of the courses are in `data/grand_prix.json`.
