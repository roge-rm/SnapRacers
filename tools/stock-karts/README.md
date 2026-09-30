# Stock kart tools

These build and check the sixteen stock karts in `data/karts/stock`, which the AI drivers race in and you can pick too.

`make_karts.py` writes the karts. Each one is laid out part by part in there, and most parts go down in pairs, one on each side, like Mirror in the garage. Change a kart there and run it again instead of editing the JSON.

```
python3 tools/stock-karts/make_karts.py
```

`report.gd` prints each kart's top speed, pull, cornering, control, off-road grip, weight and drag, where most of the drag comes from, and anything that stops it being driven.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/report.gd
```

`balance.tscn` times every kart for two laps on four courses (twisty Peach Pit, fast Foundry Flats, Launchpad Loop with its loop and Dune Drift) with the AI driving, and shows how each one compares with the middle of the field. I keep them all within about 7% of each other overall, while each is still best or worst at something. It takes about 25 minutes. Name karts or courses after `--` to only do those, and set `RACE_DEBUG=1` to see why a kart was reset.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/balance.tscn -- rocket peach_pit
```

`handling.gd` checks each kart is steady at speed. With the throttle down on a flat stretch of road it steers hard one way, then flicks left and right like a lane change, and prints how far each kart slid and whether it spun. It takes about three minutes.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tools/stock-karts/handling.gd
```
