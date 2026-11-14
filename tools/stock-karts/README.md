# Stock kart tools

These build and check the 40 stock vehicles in `data/karts/stock`, which the AI drivers race in and you can pick too. Kart Kid is the one you start with and Volt is player two's.

| Kind | Ids |
|---|---|
| Racers | `redline`, `big_block`, `oval_ace`, `kart_kid`, `gravel_rat`, `night_shift`, `quarter_mile`, `flathead`, `sandhopper`, `volt`, `shifter`, `dirt_wing`, `hot_hatch`, `long_lap`, `dune_bug` |
| Trucks | `crusher`, `long_haul`, `desert_pro`, `six_pack`, `tow_boss`, `rock_crawler`, `fire_chief` |
| Bikes | `streak`, `scrambler`, `zippy`, `long_fork`, `ton_up`, `kerb_hopper`, `spark` |
| Trikes | `twin_nose`, `sunday_trike`, `tiddler`, `arrowhead`, `tuk_tuk` |
| Quads | `zipper`, `mudlark_quad` (called Mudlark in the game), `flat_track`, `dust_devil`, `pip`, `bogtrotter` |

The id is the file name. Saved settings with an old id (`starter`, `rocket` and the rest) are moved to a new one by `Game.OLD_STOCK` the first time the game starts.

`make_karts.py` writes them all, along with each one's name and the line about it in the kart picker. Each one is laid out part by part in there, and most parts go down in pairs, one on each side, like Mirror in the garage. Racers and trucks go down with `racer()`, which lays the black chassis of kart axle plates with the wheels on their pins, and `arches()` and `fenders()` put the bodywork over the wheels. Bikes and trikes go down with `bike()`, each part at its corner measured from the front axle, and quads with `quad()`. Change one there and run it again instead of editing the JSON.

```
python3 tools/stock-karts/make_karts.py
```

`check.gd` says which parts are inside each other or aren't joined to the rest, when the report says something's wrong.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/check.gd -- streak
```

`tools/shots/stock_shots.gd` takes a picture of every one of them on one sheet, or bigger pictures of the ones named after `--`. It needs a screen.

```
DISPLAY=:0 tools/godot/Godot_v4.7.2-stable_linux.x86_64 --path . -s tools/shots/stock_shots.gd -- streak long_fork
```

`report.gd` prints each one's top speed, pull, cornering, control, off-road grip, weight and drag, where most of the drag comes from, and anything that stops it being driven.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path . -s tools/stock-karts/report.gd
```

`balance.sh` is the quick way to balance them. It runs several copies of `balance.tscn` at once, each timing a few of them, and puts their times together with the last run in the same weather (kept in `build/balance/<weather>/results.json`). Then it shows how each compares with the middle of the field, with the ones it just timed starred. All 40 take about 8 minutes. Name some to only time those, and the rest keep their last times. Name courses to only do those. `JOBS` sets how many copies run at once. `BALANCE_WEATHER` picks clear (the default), rain, snow, fog, storm or dust, and each has its own results and logs. Every run is in daytime and resets the random seed before each race, so every vehicle gets the same conditions and puddles. `BALANCE_SEED` defaults to 12345; other seeds keep their results in `build/balance/<weather>/seed_<seed>/`, separately from the default seed and each other.

```
tools/stock-karts/balance.sh
tools/stock-karts/balance.sh streak long_fork launchpad_loop
BALANCE_WEATHER=rain tools/stock-karts/balance.sh
BALANCE_WEATHER=snow tools/stock-karts/balance.sh
BALANCE_WEATHER=rain BALANCE_SEED=54321 tools/stock-karts/balance.sh
```

`last_balance.json` is a copy of the last full clear run of all 40, kept in git as the dry times to compare against. To update it, copy `build/balance/clear/results.json` over it after a full clear run. `balance_table.py` reads it when you run it on its own.

`balance.tscn` times every vehicle for two laps on four courses (twisty Peach Pit, fast Foundry Flats, Launchpad Loop with its loop and Dune Drift) with the AI driving, and shows how each one compares with the middle of the field. I keep them all within about 10% of each other overall, while each is still best or worst at something. On its own it does them one at a time, which takes about an hour and a half. Name vehicles or courses after `--` to only do those, and set `RACE_DEBUG=1` to see why one was reset.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . res://tools/stock-karts/balance.tscn -- redline peach_pit
```

`handling.gd` checks each one is steady at speed. With the throttle down on a flat stretch of road it steers hard one way, then flicks left and right like a lane change, and prints how far each one slid and whether it spun. It takes about three minutes.

```
tools/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --fixed-fps 60 --path . -s tools/stock-karts/handling.gd
```

After full clear, rain and snow runs, `python3 tools/stock-karts/weather_report.py > tools/stock-karts/weather_balance.md` compares every vehicle against the field in each weather and lists the raw two-lap times and resets. Pass `--seeds 12345 54321 8675309` after running rain and snow with those seeds to average their relative pace and show the results for each seed. Clear always uses the seed 12345 dry baseline. See [weather_balance.md](weather_balance.md) for the measured roster and results.

The 40 vehicle roster passed the weather check on 2026-11-14: all 40 were within ±10% overall in clear and on each of three rain and snow seeds. All 1,120 two-lap races finished, with 3 clear, 23 rain and 21 snow resets, most of them on Foundry Flats. The report lists the individual course times and the larger course-specific gaps too.
