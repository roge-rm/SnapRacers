# Stock kart tools

These build and check the stock karts, bikes and trikes in `data/karts/stock`, fifteen karts, four bikes and three trikes, which the AI drivers race in and you can pick too.

`make_karts.py` writes them. Each one is laid out part by part in there, and most parts go down in pairs, one on each side, like Mirror in the garage. Karts sit on a chassis of kart axle plates with the wheels on their pins, and bikes are built round a fork, a swingarm and a bike body. Change one there and run it again instead of editing the JSON.

```
python3 tools/stock-karts/make_karts.py
```

`check.gd` says which parts are inside each other or aren't joined to the rest, when the report says something's wrong.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/check.gd -- superbike
```

`tools/shots/stock_shots.gd` takes a picture of every one of them on one sheet, or bigger pictures of the ones named after `--`. It needs a screen.

```
DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . -s tools/shots/stock_shots.gd -- superbike chopper
```

`report.gd` prints each kart's top speed, pull, cornering, control, off-road grip, weight and drag, where most of the drag comes from, and anything that stops it being driven.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/report.gd
```

`balance.sh` is the quick way to balance them. It runs several copies of `balance.tscn` at once, each timing a few of them, and puts their times together with the last full run's (kept in `last_balance.json`). Then it shows how each compares with the middle of the field, with the ones it just timed starred. All of them take about 5 minutes. Name some to only time those, and the rest keep their last times. Name courses to only do those. `JOBS` sets how many copies run at once.

```
tools/stock-karts/balance.sh
tools/stock-karts/balance.sh superbike chopper launchpad_loop
```

`balance.tscn` times every kart for two laps on four courses (twisty Peach Pit, fast Foundry Flats, Launchpad Loop with its loop and Dune Drift) with the AI driving, and shows how each one compares with the middle of the field. I keep them all within about 10% of each other overall, while each is still best or worst at something. On its own it does them one at a time, which takes about an hour and a half. Name karts or courses after `--` to only do those, and set `RACE_DEBUG=1` to see why a kart was reset.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/balance.tscn -- rocket peach_pit
```

`handling.gd` checks each kart is steady at speed. With the throttle down on a flat stretch of road it steers hard one way, then flicks left and right like a lane change, and prints how far each kart slid and whether it spun. It takes about three minutes.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tools/stock-karts/handling.gd
```
