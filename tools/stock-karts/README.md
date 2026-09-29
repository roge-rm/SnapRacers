# Stock kart tools

These build and check the sixteen stock karts in `data/karts/stock`. The AI drivers race in them, dealt out at random at the start of a race, or once for a whole Grand Prix. You can pick any of them to race in too.

`make_karts.py` writes the karts. Each one is laid out part by part in there, and most parts go down in pairs, one on each side, the way Mirror works in the garage. Change a kart there and run it again rather than editing the JSON.

```
python3 tools/stock-karts/make_karts.py
```

`report.gd` prints how each kart comes out: top speed, pull, cornering, control, off-road grip, weight and drag, and where most of the drag comes from. It also lists anything that stops a kart being driven.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/report.gd
```

`balance.tscn` times every kart for two laps on three courses (twisty Peach Pit, fast Foundry Flats and Launchpad Loop with its loop) with the AI driving, and shows how each one compares with the middle of the field. I aim to keep them all within about 7% of each other overall, so any of them can win, while each is still best or worst at something. It takes about ten minutes. Name karts or courses after `--` to only do those, and set `RACE_DEBUG=1` to see why a kart was reset.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/balance.tscn -- rocket peach_pit
```

`handling.gd` checks each kart is steady at speed. On a flat stretch of road it steers hard one way with the throttle down, then flicks left and right like a lane change, and prints how far each kart slid and whether it spun. It takes about three minutes.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tools/stock-karts/handling.gd
```
