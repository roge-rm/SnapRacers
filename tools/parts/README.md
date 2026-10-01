# Part tools

The parts modelled for SnapRacers are made here in Python, the same way the sounds are made in `tools/sound`. Nothing is downloaded or copied. Every part is built from code and looks like a generic toy brick part.

- `kit.py` has the building blocks: boxes with rounded edges, cylinders, side views and top views pushed out into solids, studs, and writing a part out as an OBJ mesh centred on its box.
- `library.py` has every part. Each one builds its shape and lists its connectors, the spots where it joins other parts: studs and sockets, bars and clips, pins and holes, axles, wheel hubs, hinges and ball joints. A part can also have solid boxes (for bumping into other parts, when its box isn't solid all through) and a trim, a second piece in its own colour like a tire or a lens.
- `make_parts.py` makes them all into `parts/meshes` and writes `data/parts_made.json`, which the game reads alongside `data/parts.json`.

It needs manifold3d and numpy, which `uv` fetches:

```
uv run --with manifold3d --with numpy tools/parts/make_parts.py
uv run --with manifold3d --with numpy tools/parts/make_parts.py w_kart p_curve_2x4
```

The first makes everything and the second only the parts named. The finished meshes and the file are in the repository, so building the game doesn't need any of this.

After making parts, run the Godot import (`tools/run-tests.sh` does it first thing). If a mesh came out empty once, Godot keeps it marked as broken even after it's fixed, so delete its `.obj.import` file and import again.

Sizes and connector spots in `data/parts_made.json` are in the game's fine unit, a twentieth of a stud (`scripts/parts/grid.gd`). Which connector types join which is in `scripts/parts/connectors.gd`.
