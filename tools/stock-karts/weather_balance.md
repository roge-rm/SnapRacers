# Stock vehicle weather balance

Two laps from a standing start, one AI-driven vehicle at a time, on Peach Pit, Foundry Flats, Launchpad Loop and Dune Drift. All 40 stock vehicles; clear, rain and snow; daytime. Clear uses the dry baseline seed 12345; rain and snow use seeds 12345, 54321, 8675309, reset before every race.

Each percentage is the mean of the vehicle's time divided by the median time on each course, minus one, averaged across seeds. Negative is quicker than the field; positive is slower. Each seed has its own field medians. The rain/snow change columns subtract the dry percentage: negative means the vehicle gains relative to its peers in that weather. These are percentage-point changes, not raw speed changes.

These are AI runs on four courses, not a measure of human performance or consistency on every course. Snow has no puddles; its extra seeds check race variation rather than puddle layouts. A DNF on any seed makes the weather's overall score DNF.

## Findings

- Clear: vehicles outside the usual roughly ±10% overall target: none.
- Rain: vehicles outside the usual roughly ±10% overall target: none.
- Snow: vehicles outside the usual roughly ±10% overall target: none.

The ±10% target applies to the four-course overall score; individual courses can show larger strengths and weaknesses. Changes to a vehicle apply in every weather, so any tuning also needs a dry recheck.

- Rain individual-seed outliers: none.
- Rain largest two-lap spread across seeds: 14.1 s (streak on launchpad_loop).
- Snow individual-seed outliers: none.
- Snow largest two-lap spread across seeds: 14.0 s (fire_chief on foundry_flats).

## Relative pace

| Vehicle | Clear | Rain | Snow | Rain change | Snow change |
| --- | ---: | ---: | ---: | ---: | ---: |
| arrowhead | -2.6% | +2.4% | +7.8% | +5.0 pp | +10.3 pp |
| big_block | -7.2% | -8.7% | -7.1% | -1.5 pp | +0.1 pp |
| bogtrotter | +3.0% | -3.6% | -6.5% | -6.6 pp | -9.5 pp |
| crusher | +8.8% | +3.9% | +0.3% | -5.0 pp | -8.6 pp |
| desert_pro | +0.7% | -3.7% | -5.9% | -4.4 pp | -6.6 pp |
| dirt_wing | -1.5% | -3.9% | -5.4% | -2.4 pp | -3.9 pp |
| dune_bug | +7.3% | +4.0% | +2.2% | -3.3 pp | -5.1 pp |
| dust_devil | -2.1% | -7.2% | -9.7% | -5.1 pp | -7.6 pp |
| fire_chief | +4.4% | +0.5% | -1.8% | -3.9 pp | -6.2 pp |
| flat_track | -2.1% | -4.1% | -2.8% | -2.0 pp | -0.7 pp |
| flathead | -1.3% | +3.3% | +8.7% | +4.6 pp | +10.0 pp |
| gravel_rat | +7.6% | -0.1% | -3.0% | -7.7 pp | -10.5 pp |
| hot_hatch | +7.9% | +0.7% | -4.1% | -7.2 pp | -12.0 pp |
| kart_kid | -0.7% | +3.5% | +7.2% | +4.2 pp | +7.9 pp |
| kerb_hopper | +2.3% | +3.5% | +4.7% | +1.2 pp | +2.4 pp |
| long_fork | -8.5% | -6.6% | -2.6% | +1.8 pp | +5.9 pp |
| long_haul | -2.5% | +1.5% | +6.2% | +4.0 pp | +8.7 pp |
| long_lap | -5.8% | -0.3% | +3.8% | +5.5 pp | +9.5 pp |
| mudlark_quad | +5.3% | -0.5% | -3.9% | -5.9 pp | -9.2 pp |
| night_shift | -6.4% | -5.5% | -2.8% | +0.9 pp | +3.6 pp |
| oval_ace | -1.5% | -0.7% | +0.9% | +0.9 pp | +2.5 pp |
| pip | +2.1% | -3.6% | -6.3% | -5.8 pp | -8.5 pp |
| quarter_mile | -8.9% | -4.0% | +4.5% | +4.9 pp | +13.4 pp |
| redline | -8.1% | -7.6% | -3.2% | +0.5 pp | +4.9 pp |
| rock_crawler | +6.3% | +1.4% | -2.2% | -5.0 pp | -8.5 pp |
| sandhopper | +7.8% | +3.1% | +2.5% | -4.7 pp | -5.3 pp |
| scrambler | +4.5% | +1.1% | -0.3% | -3.4 pp | -4.8 pp |
| shifter | -1.0% | -0.9% | +5.6% | +0.1 pp | +6.6 pp |
| six_pack | +8.1% | +3.3% | +0.6% | -4.9 pp | -7.6 pp |
| spark | +8.2% | +8.0% | +9.4% | -0.2 pp | +1.3 pp |
| streak | -2.7% | +2.8% | +7.8% | +5.5 pp | +10.5 pp |
| sunday_trike | -6.6% | -2.7% | +2.1% | +3.9 pp | +8.7 pp |
| tiddler | +0.5% | +2.1% | +6.1% | +1.7 pp | +5.6 pp |
| ton_up | +2.6% | +2.5% | +3.1% | -0.1 pp | +0.5 pp |
| tow_boss | +3.6% | -0.1% | -2.3% | -3.7 pp | -5.8 pp |
| tuk_tuk | +0.6% | +2.3% | +6.0% | +1.7 pp | +5.4 pp |
| twin_nose | +3.1% | +0.6% | -0.2% | -2.5 pp | -3.2 pp |
| volt | -7.0% | -4.5% | -0.8% | +2.4 pp | +6.2 pp |
| zipper | -1.5% | -6.8% | -9.5% | -5.3 pp | -8.0 pp |
| zippy | -2.1% | +1.9% | +6.6% | +3.9 pp | +8.7 pp |

## Clear

160/160 runs finished; 3 resets in total.

Resets by course: foundry_flats: 2, dune_drift: 1.

Worker logs: 0 engine errors; 0 Jolt job-capacity warnings during concurrent runs.


### Seed 12345

Times are seconds for both laps.

| Vehicle | Peach Pit | Foundry Flats | Launchpad Loop | Dune Drift | Resets |
| --- | ---: | ---: | ---: | ---: | ---: |
| Field median | 165.7 | 171.6 | 177.1 | 173.6 | — |
| arrowhead | 166.6 | 164.7 | 170.0 | 168.8 | 0 |
| big_block | 158.1 | 156.8 | 163.8 | 159.6 | 0 |
| bogtrotter | 171.8 | 176.0 | 183.6 | 177.2 | 0 |
| crusher | 186.0 | 185.3 | 191.3 | 185.9 | 0 |
| desert_pro | 165.3 | 171.9 | 180.6 | 175.0 | 0 |
| dirt_wing | 162.2 | 168.7 | 176.4 | 170.3 | 0 |
| dune_bug | 179.4 | 182.6 | 192.0 | 184.5 | 0 |
| dust_devil | 162.9 | 166.6 | 175.5 | 168.4 | 0 |
| fire_chief | 174.4 | 177.9 | 186.1 | 179.9 | 0 |
| flat_track | 163.7 | 165.5 | 173.5 | 170.8 | 1 |
| flathead | 163.2 | 170.7 | 173.8 | 171.5 | 0 |
| gravel_rat | 175.8 | 192.3 | 189.0 | 183.1 | 2 |
| hot_hatch | 178.1 | 186.9 | 191.0 | 186.7 | 0 |
| kart_kid | 163.1 | 172.4 | 174.8 | 173.0 | 0 |
| kerb_hopper | 167.2 | 176.8 | 180.3 | 180.0 | 0 |
| long_fork | 149.9 | 156.4 | 163.7 | 159.9 | 0 |
| long_haul | 163.3 | 164.8 | 172.3 | 170.4 | 0 |
| long_lap | 149.5 | 163.2 | 169.6 | 166.4 | 0 |
| mudlark_quad | 178.7 | 179.3 | 186.6 | 180.0 | 0 |
| night_shift | 153.0 | 159.7 | 167.9 | 163.6 | 0 |
| oval_ace | 162.3 | 168.1 | 174.7 | 172.4 | 0 |
| pip | 172.7 | 173.7 | 182.0 | 174.2 | 0 |
| quarter_mile | 146.2 | 155.0 | 165.5 | 160.8 | 0 |
| redline | 156.5 | 155.5 | 162.3 | 157.5 | 0 |
| rock_crawler | 182.7 | 180.1 | 186.9 | 181.5 | 0 |
| sandhopper | 181.5 | 183.3 | 191.9 | 184.9 | 0 |
| scrambler | 171.4 | 181.3 | 183.6 | 182.7 | 0 |
| shifter | 168.7 | 167.2 | 173.5 | 171.3 | 0 |
| six_pack | 172.5 | 185.8 | 195.8 | 190.2 | 0 |
| spark | 175.4 | 189.1 | 190.3 | 189.6 | 0 |
| streak | 155.1 | 170.1 | 172.4 | 172.3 | 0 |
| sunday_trike | 153.6 | 158.6 | 166.4 | 163.7 | 0 |
| tiddler | 166.2 | 172.9 | 177.5 | 174.8 | 0 |
| ton_up | 164.9 | 178.6 | 182.1 | 180.7 | 0 |
| tow_boss | 172.7 | 176.7 | 184.2 | 178.9 | 0 |
| tuk_tuk | 166.9 | 171.2 | 177.6 | 176.4 | 0 |
| twin_nose | 172.4 | 177.8 | 179.9 | 178.9 | 0 |
| volt | 153.6 | 158.8 | 166.0 | 161.6 | 0 |
| zipper | 163.6 | 168.1 | 176.7 | 169.3 | 0 |
| zippy | 159.1 | 168.1 | 174.0 | 172.7 | 0 |

## Rain

480/480 runs finished; 23 resets in total.

Resets by course: foundry_flats: 20, launchpad_loop: 2, dune_drift: 1.

Worker logs: 0 engine errors; 0 Jolt job-capacity warnings during concurrent runs.

Overall relative pace by seed (same calculation as above, before averaging):

| Vehicle | 12345 | 54321 | 8675309 |
| --- | ---: | ---: | ---: |
| arrowhead | +2.5% | +2.5% | +2.3% |
| big_block | -8.7% | -8.5% | -8.8% |
| bogtrotter | -3.6% | -3.6% | -3.7% |
| crusher | +3.8% | +4.1% | +3.7% |
| desert_pro | -3.7% | -3.6% | -3.8% |
| dirt_wing | -3.9% | -3.8% | -4.1% |
| dune_bug | +3.7% | +4.0% | +4.2% |
| dust_devil | -7.2% | -7.1% | -7.3% |
| fire_chief | +0.5% | +0.5% | +0.5% |
| flat_track | -4.1% | -4.0% | -4.2% |
| flathead | +3.3% | +3.5% | +3.1% |
| gravel_rat | -0.2% | +0.0% | -0.1% |
| hot_hatch | +0.8% | +0.6% | +0.8% |
| kart_kid | +3.8% | +3.5% | +3.3% |
| kerb_hopper | +3.6% | +3.6% | +3.5% |
| long_fork | -6.6% | -6.7% | -6.5% |
| long_haul | +1.6% | +1.7% | +1.4% |
| long_lap | -0.7% | +0.6% | -0.7% |
| mudlark_quad | -0.7% | -0.5% | -0.4% |
| night_shift | -5.5% | -5.4% | -5.6% |
| oval_ace | -0.5% | -0.9% | -0.6% |
| pip | -3.4% | -3.6% | -3.9% |
| quarter_mile | -3.7% | -4.1% | -4.1% |
| redline | -7.5% | -7.5% | -7.8% |
| rock_crawler | +1.5% | +1.4% | +1.2% |
| sandhopper | +3.0% | +3.3% | +3.1% |
| scrambler | +1.1% | +1.2% | +1.0% |
| shifter | -1.2% | -0.7% | -0.8% |
| six_pack | +3.2% | +3.4% | +3.2% |
| spark | +8.6% | +7.6% | +7.7% |
| streak | +3.9% | +2.4% | +2.2% |
| sunday_trike | -2.7% | -2.7% | -2.8% |
| tiddler | +2.1% | +2.1% | +2.3% |
| ton_up | +2.6% | +2.6% | +2.4% |
| tow_boss | -0.1% | -0.0% | -0.2% |
| tuk_tuk | +2.8% | +2.2% | +1.8% |
| twin_nose | +0.6% | +0.7% | +0.5% |
| volt | -4.6% | -4.5% | -4.5% |
| zipper | -6.8% | -6.7% | -6.9% |
| zippy | +1.8% | +1.9% | +1.9% |

### Seed 12345

Times are seconds for both laps.

| Vehicle | Peach Pit | Foundry Flats | Launchpad Loop | Dune Drift | Resets |
| --- | ---: | ---: | ---: | ---: | ---: |
| Field median | 181.5 | 190.0 | 194.3 | 189.7 | — |
| arrowhead | 194.2 | 191.5 | 194.3 | 193.6 | 0 |
| big_block | 166.6 | 170.8 | 179.2 | 173.6 | 0 |
| bogtrotter | 175.9 | 179.5 | 190.5 | 182.7 | 0 |
| crusher | 195.0 | 195.0 | 200.3 | 193.9 | 0 |
| desert_pro | 174.2 | 180.6 | 189.1 | 183.4 | 0 |
| dirt_wing | 173.2 | 182.7 | 187.7 | 182.1 | 0 |
| dune_bug | 188.3 | 200.8 | 201.2 | 193.0 | 0 |
| dust_devil | 168.0 | 173.7 | 183.3 | 176.2 | 0 |
| fire_chief | 184.6 | 189.9 | 195.4 | 189.4 | 0 |
| flat_track | 173.8 | 178.8 | 188.4 | 183.8 | 0 |
| flathead | 191.1 | 193.7 | 198.8 | 196.8 | 0 |
| gravel_rat | 181.3 | 187.0 | 195.4 | 190.2 | 0 |
| hot_hatch | 181.4 | 195.3 | 194.9 | 189.8 | 2 |
| kart_kid | 185.8 | 203.8 | 197.6 | 196.7 | 2 |
| kerb_hopper | 188.0 | 196.6 | 199.5 | 198.6 | 0 |
| long_fork | 163.1 | 178.5 | 184.2 | 180.0 | 0 |
| long_haul | 189.1 | 190.0 | 194.6 | 193.2 | 0 |
| long_lap | 175.1 | 189.4 | 194.2 | 191.3 | 0 |
| mudlark_quad | 183.1 | 185.4 | 194.3 | 187.1 | 0 |
| night_shift | 164.7 | 180.0 | 187.1 | 182.8 | 0 |
| oval_ace | 174.1 | 194.5 | 192.5 | 191.2 | 1 |
| pip | 176.7 | 179.9 | 188.9 | 184.6 | 1 |
| quarter_mile | 163.1 | 186.5 | 191.1 | 187.7 | 2 |
| redline | 166.9 | 174.4 | 181.1 | 176.6 | 0 |
| rock_crawler | 191.0 | 190.2 | 195.5 | 189.5 | 0 |
| sandhopper | 189.4 | 194.8 | 200.9 | 193.2 | 0 |
| scrambler | 183.4 | 192.4 | 195.4 | 192.8 | 0 |
| shifter | 181.6 | 183.6 | 192.5 | 188.8 | 0 |
| six_pack | 183.2 | 196.2 | 204.1 | 196.3 | 0 |
| spark | 192.4 | 209.5 | 211.5 | 207.2 | 0 |
| streak | 182.1 | 193.6 | 211.2 | 198.5 | 2 |
| sunday_trike | 175.1 | 182.7 | 189.8 | 187.5 | 0 |
| tiddler | 181.2 | 193.7 | 199.9 | 196.9 | 0 |
| ton_up | 183.0 | 193.2 | 201.3 | 197.6 | 0 |
| tow_boss | 183.3 | 188.0 | 194.4 | 189.0 | 0 |
| tuk_tuk | 181.4 | 199.3 | 199.3 | 197.0 | 0 |
| twin_nose | 186.7 | 190.3 | 193.0 | 189.7 | 0 |
| volt | 166.4 | 184.6 | 187.5 | 182.7 | 1 |
| zipper | 168.1 | 174.7 | 184.3 | 177.0 | 0 |
| zippy | 181.5 | 191.7 | 199.2 | 197.1 | 0 |

### Seed 54321

Times are seconds for both laps.

| Vehicle | Peach Pit | Foundry Flats | Launchpad Loop | Dune Drift | Resets |
| --- | ---: | ---: | ---: | ---: | ---: |
| Field median | 181.1 | 190.0 | 194.3 | 189.6 | — |
| arrowhead | 193.5 | 192.7 | 194.0 | 193.4 | 0 |
| big_block | 166.6 | 171.2 | 179.4 | 173.6 | 0 |
| bogtrotter | 176.2 | 179.9 | 189.2 | 182.7 | 0 |
| crusher | 194.3 | 197.1 | 200.2 | 193.7 | 0 |
| desert_pro | 174.0 | 180.9 | 189.7 | 183.0 | 0 |
| dirt_wing | 172.7 | 184.5 | 187.7 | 181.7 | 0 |
| dune_bug | 188.2 | 203.1 | 201.8 | 192.5 | 0 |
| dust_devil | 168.2 | 173.9 | 183.0 | 176.2 | 0 |
| fire_chief | 184.1 | 189.5 | 195.5 | 189.3 | 0 |
| flat_track | 173.8 | 178.9 | 188.6 | 183.4 | 0 |
| flathead | 190.5 | 194.8 | 198.9 | 197.0 | 0 |
| gravel_rat | 181.0 | 188.6 | 195.9 | 189.8 | 0 |
| hot_hatch | 182.1 | 192.2 | 195.4 | 190.0 | 0 |
| kart_kid | 185.2 | 202.1 | 197.7 | 196.4 | 1 |
| kerb_hopper | 187.2 | 197.6 | 198.8 | 198.4 | 0 |
| long_fork | 162.6 | 178.3 | 183.6 | 180.3 | 0 |
| long_haul | 188.5 | 190.6 | 195.0 | 193.1 | 0 |
| long_lap | 174.7 | 199.3 | 194.1 | 191.7 | 2 |
| mudlark_quad | 183.5 | 186.1 | 194.2 | 187.0 | 0 |
| night_shift | 164.7 | 179.7 | 187.6 | 183.0 | 0 |
| oval_ace | 173.2 | 189.8 | 192.5 | 192.7 | 0 |
| pip | 177.1 | 180.4 | 189.2 | 180.7 | 0 |
| quarter_mile | 162.5 | 183.8 | 190.6 | 187.7 | 1 |
| redline | 166.6 | 174.3 | 181.1 | 176.4 | 0 |
| rock_crawler | 190.4 | 190.3 | 195.2 | 189.4 | 0 |
| sandhopper | 189.4 | 195.9 | 201.5 | 193.0 | 0 |
| scrambler | 182.9 | 193.5 | 194.8 | 192.6 | 0 |
| shifter | 181.2 | 186.7 | 192.8 | 188.8 | 0 |
| six_pack | 183.1 | 197.6 | 204.3 | 196.3 | 0 |
| spark | 191.6 | 205.0 | 209.5 | 206.8 | 0 |
| streak | 181.4 | 195.1 | 198.9 | 198.0 | 0 |
| sunday_trike | 174.6 | 183.3 | 189.4 | 187.4 | 0 |
| tiddler | 180.4 | 194.1 | 199.5 | 196.7 | 0 |
| ton_up | 182.5 | 194.0 | 201.0 | 197.4 | 0 |
| tow_boss | 182.8 | 188.7 | 194.4 | 188.8 | 0 |
| tuk_tuk | 180.7 | 195.6 | 198.8 | 196.6 | 0 |
| twin_nose | 186.2 | 191.9 | 192.7 | 189.4 | 0 |
| volt | 166.1 | 184.8 | 187.6 | 182.6 | 1 |
| zipper | 168.7 | 175.0 | 183.9 | 176.7 | 0 |
| zippy | 180.8 | 194.4 | 197.9 | 196.5 | 0 |

### Seed 8675309

Times are seconds for both laps.

| Vehicle | Peach Pit | Foundry Flats | Launchpad Loop | Dune Drift | Resets |
| --- | ---: | ---: | ---: | ---: | ---: |
| Field median | 181.5 | 190.9 | 193.6 | 189.8 | — |
| arrowhead | 193.3 | 192.4 | 193.3 | 193.6 | 0 |
| big_block | 166.1 | 170.9 | 178.3 | 173.8 | 0 |
| bogtrotter | 175.7 | 180.6 | 188.8 | 182.5 | 0 |
| crusher | 194.3 | 195.4 | 200.0 | 193.9 | 0 |
| desert_pro | 174.3 | 181.0 | 188.7 | 182.9 | 0 |
| dirt_wing | 173.0 | 182.8 | 187.2 | 181.8 | 0 |
| dune_bug | 188.3 | 205.9 | 200.8 | 192.8 | 1 |
| dust_devil | 167.7 | 174.1 | 182.9 | 175.8 | 0 |
| fire_chief | 184.3 | 191.0 | 194.8 | 189.2 | 0 |
| flat_track | 173.2 | 179.3 | 188.2 | 183.4 | 0 |
| flathead | 190.1 | 194.7 | 197.2 | 197.1 | 0 |
| gravel_rat | 181.5 | 187.9 | 195.0 | 190.5 | 0 |
| hot_hatch | 182.6 | 195.4 | 194.3 | 189.7 | 1 |
| kart_kid | 185.3 | 202.4 | 196.9 | 196.6 | 1 |
| kerb_hopper | 187.4 | 197.3 | 198.4 | 198.8 | 0 |
| long_fork | 163.3 | 179.9 | 183.6 | 180.2 | 0 |
| long_haul | 188.5 | 190.8 | 193.6 | 193.3 | 0 |
| long_lap | 174.4 | 191.7 | 192.9 | 191.8 | 0 |
| mudlark_quad | 182.8 | 189.5 | 193.9 | 186.9 | 0 |
| night_shift | 164.7 | 180.1 | 186.7 | 182.7 | 0 |
| oval_ace | 175.2 | 193.5 | 191.7 | 190.8 | 1 |
| pip | 176.7 | 180.8 | 188.5 | 180.5 | 0 |
| quarter_mile | 162.9 | 183.7 | 189.9 | 189.2 | 1 |
| redline | 166.2 | 174.5 | 180.2 | 176.3 | 0 |
| rock_crawler | 190.5 | 190.1 | 194.9 | 189.3 | 0 |
| sandhopper | 189.3 | 195.9 | 200.6 | 193.1 | 0 |
| scrambler | 182.9 | 193.0 | 194.8 | 193.0 | 0 |
| shifter | 181.6 | 187.5 | 191.4 | 188.9 | 0 |
| six_pack | 182.8 | 197.5 | 203.0 | 197.3 | 0 |
| spark | 193.1 | 204.1 | 208.6 | 208.7 | 0 |
| streak | 181.6 | 194.5 | 197.1 | 199.4 | 0 |
| sunday_trike | 174.5 | 183.9 | 188.7 | 187.7 | 0 |
| tiddler | 180.3 | 197.0 | 198.5 | 197.4 | 0 |
| ton_up | 182.4 | 194.2 | 199.7 | 198.2 | 0 |
| tow_boss | 183.0 | 188.7 | 193.6 | 188.8 | 0 |
| tuk_tuk | 180.7 | 193.8 | 197.8 | 197.6 | 0 |
| twin_nose | 186.1 | 191.3 | 192.2 | 189.9 | 0 |
| volt | 165.9 | 187.1 | 186.3 | 182.9 | 2 |
| zipper | 168.2 | 175.3 | 183.9 | 176.3 | 0 |
| zippy | 181.1 | 192.0 | 199.8 | 197.4 | 0 |

## Snow

480/480 runs finished; 21 resets in total.

Resets by course: foundry_flats: 21.

Worker logs: 0 engine errors; 0 Jolt job-capacity warnings during concurrent runs.

Overall relative pace by seed (same calculation as above, before averaging):

| Vehicle | 12345 | 54321 | 8675309 |
| --- | ---: | ---: | ---: |
| arrowhead | +7.7% | +7.9% | +7.8% |
| big_block | -7.1% | -7.1% | -7.2% |
| bogtrotter | -6.4% | -6.6% | -6.5% |
| crusher | +0.5% | +0.2% | +0.2% |
| desert_pro | -5.6% | -5.9% | -6.2% |
| dirt_wing | -4.4% | -6.0% | -5.8% |
| dune_bug | +1.6% | +2.3% | +2.6% |
| dust_devil | -9.7% | -9.6% | -9.8% |
| fire_chief | -2.3% | -2.3% | -0.9% |
| flat_track | -2.8% | -2.8% | -2.9% |
| flathead | +8.7% | +8.7% | +8.8% |
| gravel_rat | -2.8% | -2.9% | -3.2% |
| hot_hatch | -3.8% | -3.9% | -4.5% |
| kart_kid | +7.2% | +7.2% | +7.2% |
| kerb_hopper | +4.5% | +4.8% | +4.9% |
| long_fork | -2.7% | -2.6% | -2.6% |
| long_haul | +6.1% | +6.2% | +6.2% |
| long_lap | +3.8% | +3.8% | +3.7% |
| mudlark_quad | -3.8% | -3.8% | -4.0% |
| night_shift | -2.7% | -2.8% | -3.0% |
| oval_ace | +1.1% | +1.0% | +0.6% |
| pip | -5.9% | -6.5% | -6.6% |
| quarter_mile | +4.7% | +4.5% | +4.5% |
| redline | -3.3% | -3.2% | -3.3% |
| rock_crawler | -2.4% | -2.2% | -2.0% |
| sandhopper | +2.6% | +3.1% | +1.7% |
| scrambler | -0.4% | -0.2% | -0.2% |
| shifter | +5.2% | +5.4% | +6.2% |
| six_pack | +0.6% | +0.7% | +0.5% |
| spark | +9.5% | +9.7% | +9.1% |
| streak | +7.7% | +7.9% | +7.9% |
| sunday_trike | +1.8% | +2.4% | +2.1% |
| tiddler | +5.9% | +6.1% | +6.2% |
| ton_up | +3.1% | +3.1% | +3.2% |
| tow_boss | -2.6% | -2.1% | -2.0% |
| tuk_tuk | +5.9% | +6.0% | +6.1% |
| twin_nose | -0.2% | -0.1% | -0.2% |
| volt | -0.8% | -0.7% | -0.8% |
| zipper | -9.5% | -9.5% | -9.5% |
| zippy | +6.5% | +6.5% | +6.9% |

### Seed 12345

Times are seconds for both laps.

| Vehicle | Peach Pit | Foundry Flats | Launchpad Loop | Dune Drift | Resets |
| --- | ---: | ---: | ---: | ---: | ---: |
| Field median | 194.1 | 207.7 | 210.5 | 204.7 | — |
| arrowhead | 221.0 | 218.1 | 219.2 | 220.6 | 0 |
| big_block | 177.2 | 189.9 | 197.8 | 194.1 | 0 |
| bogtrotter | 180.9 | 191.1 | 200.1 | 192.4 | 0 |
| crusher | 199.8 | 208.8 | 209.4 | 203.1 | 1 |
| desert_pro | 181.2 | 197.2 | 199.3 | 193.6 | 0 |
| dirt_wing | 180.9 | 208.4 | 198.0 | 194.0 | 1 |
| dune_bug | 195.4 | 220.1 | 212.2 | 202.9 | 2 |
| dust_devil | 173.2 | 183.8 | 194.1 | 186.7 | 0 |
| fire_chief | 191.5 | 201.0 | 205.6 | 200.1 | 0 |
| flat_track | 186.6 | 196.6 | 207.5 | 203.1 | 0 |
| flathead | 217.1 | 219.8 | 225.1 | 225.5 | 0 |
| gravel_rat | 187.2 | 202.5 | 206.0 | 198.9 | 1 |
| hot_hatch | 186.2 | 197.8 | 204.5 | 197.3 | 0 |
| kart_kid | 208.6 | 223.5 | 221.1 | 222.3 | 0 |
| kerb_hopper | 205.0 | 215.3 | 217.2 | 216.3 | 0 |
| long_fork | 183.7 | 200.8 | 207.3 | 203.7 | 0 |
| long_haul | 213.7 | 215.0 | 218.1 | 219.5 | 0 |
| long_lap | 198.8 | 212.6 | 218.3 | 218.4 | 0 |
| mudlark_quad | 187.6 | 197.3 | 204.2 | 196.9 | 0 |
| night_shift | 179.9 | 200.1 | 210.0 | 205.7 | 0 |
| oval_ace | 190.1 | 207.6 | 215.6 | 213.4 | 0 |
| pip | 181.0 | 198.8 | 198.5 | 190.5 | 0 |
| quarter_mile | 196.3 | 214.3 | 223.7 | 221.2 | 0 |
| redline | 184.2 | 200.2 | 204.3 | 201.7 | 0 |
| rock_crawler | 195.7 | 199.2 | 204.2 | 198.2 | 0 |
| sandhopper | 196.5 | 228.3 | 211.0 | 203.0 | 2 |
| scrambler | 192.9 | 207.0 | 208.1 | 205.7 | 0 |
| shifter | 206.9 | 214.1 | 218.9 | 219.5 | 0 |
| six_pack | 190.5 | 207.8 | 214.6 | 209.0 | 0 |
| spark | 207.7 | 233.9 | 227.8 | 225.4 | 0 |
| streak | 208.7 | 220.3 | 225.2 | 225.4 | 0 |
| sunday_trike | 198.1 | 207.7 | 213.2 | 212.2 | 0 |
| tiddler | 203.7 | 215.5 | 223.8 | 222.5 | 0 |
| ton_up | 197.3 | 212.1 | 218.0 | 214.7 | 0 |
| tow_boss | 190.5 | 200.5 | 204.7 | 199.9 | 0 |
| tuk_tuk | 203.8 | 215.5 | 223.0 | 222.6 | 0 |
| twin_nose | 198.1 | 206.3 | 206.7 | 203.7 | 0 |
| volt | 184.5 | 205.6 | 211.4 | 209.5 | 0 |
| zipper | 173.3 | 184.8 | 194.7 | 187.0 | 0 |
| zippy | 206.0 | 217.4 | 224.0 | 222.7 | 0 |

### Seed 54321

Times are seconds for both laps.

| Vehicle | Peach Pit | Foundry Flats | Launchpad Loop | Dune Drift | Resets |
| --- | ---: | ---: | ---: | ---: | ---: |
| Field median | 194.8 | 206.6 | 210.0 | 204.7 | — |
| arrowhead | 221.8 | 218.5 | 218.9 | 220.4 | 0 |
| big_block | 177.7 | 190.5 | 197.3 | 193.3 | 0 |
| bogtrotter | 181.1 | 189.6 | 199.7 | 192.3 | 0 |
| crusher | 200.6 | 204.9 | 209.1 | 202.3 | 0 |
| desert_pro | 181.6 | 194.6 | 198.9 | 193.1 | 0 |
| dirt_wing | 181.5 | 194.5 | 197.7 | 193.2 | 0 |
| dune_bug | 196.2 | 225.0 | 210.9 | 203.0 | 2 |
| dust_devil | 173.5 | 183.9 | 193.6 | 186.6 | 0 |
| fire_chief | 192.1 | 200.8 | 205.2 | 199.4 | 0 |
| flat_track | 187.3 | 196.5 | 206.6 | 202.9 | 0 |
| flathead | 218.0 | 219.9 | 224.0 | 224.3 | 0 |
| gravel_rat | 187.2 | 202.2 | 204.7 | 198.2 | 0 |
| hot_hatch | 187.3 | 196.4 | 203.8 | 196.8 | 0 |
| kart_kid | 209.3 | 223.3 | 220.5 | 221.6 | 0 |
| kerb_hopper | 205.9 | 215.2 | 217.2 | 216.7 | 0 |
| long_fork | 184.3 | 200.7 | 206.9 | 203.8 | 0 |
| long_haul | 214.6 | 215.0 | 217.6 | 219.0 | 0 |
| long_lap | 199.5 | 212.7 | 217.9 | 217.4 | 0 |
| mudlark_quad | 187.8 | 196.7 | 204.0 | 196.6 | 0 |
| night_shift | 180.4 | 198.7 | 209.5 | 205.6 | 0 |
| oval_ace | 191.2 | 207.9 | 211.9 | 213.7 | 0 |
| pip | 181.3 | 193.3 | 197.9 | 190.4 | 1 |
| quarter_mile | 196.7 | 211.8 | 224.1 | 220.5 | 0 |
| redline | 185.0 | 200.0 | 203.9 | 201.0 | 0 |
| rock_crawler | 196.4 | 199.9 | 203.7 | 197.6 | 0 |
| sandhopper | 197.0 | 230.6 | 210.5 | 203.3 | 2 |
| scrambler | 193.5 | 206.9 | 208.2 | 205.8 | 0 |
| shifter | 207.7 | 215.0 | 218.6 | 218.5 | 0 |
| six_pack | 190.8 | 208.5 | 214.7 | 207.8 | 0 |
| spark | 208.7 | 233.5 | 227.7 | 225.9 | 0 |
| streak | 209.9 | 220.6 | 224.1 | 225.6 | 0 |
| sunday_trike | 198.5 | 212.0 | 212.8 | 212.3 | 1 |
| tiddler | 204.5 | 215.5 | 223.6 | 222.3 | 0 |
| ton_up | 198.2 | 211.7 | 216.6 | 214.7 | 0 |
| tow_boss | 191.1 | 204.0 | 204.4 | 199.4 | 1 |
| tuk_tuk | 204.5 | 215.5 | 222.6 | 222.5 | 0 |
| twin_nose | 198.8 | 206.3 | 206.6 | 203.6 | 0 |
| volt | 185.3 | 205.8 | 211.1 | 208.3 | 0 |
| zipper | 173.5 | 184.8 | 193.9 | 186.9 | 0 |
| zippy | 206.8 | 217.6 | 221.9 | 222.8 | 0 |

### Seed 8675309

Times are seconds for both laps.

| Vehicle | Peach Pit | Foundry Flats | Launchpad Loop | Dune Drift | Resets |
| --- | ---: | ---: | ---: | ---: | ---: |
| Field median | 196.0 | 209.5 | 210.7 | 204.6 | — |
| arrowhead | 222.6 | 220.6 | 219.8 | 220.7 | 0 |
| big_block | 178.4 | 192.0 | 198.0 | 193.6 | 0 |
| bogtrotter | 181.9 | 192.8 | 200.1 | 192.8 | 0 |
| crusher | 201.3 | 207.9 | 210.1 | 202.5 | 0 |
| desert_pro | 182.5 | 195.1 | 199.3 | 193.3 | 0 |
| dirt_wing | 182.3 | 199.9 | 198.3 | 193.1 | 1 |
| dune_bug | 197.3 | 230.4 | 211.9 | 203.1 | 2 |
| dust_devil | 174.4 | 185.1 | 194.1 | 187.1 | 0 |
| fire_chief | 193.2 | 214.8 | 205.8 | 199.6 | 0 |
| flat_track | 188.3 | 198.0 | 207.8 | 203.4 | 0 |
| flathead | 219.4 | 222.8 | 225.7 | 224.7 | 0 |
| gravel_rat | 188.7 | 202.4 | 205.5 | 198.3 | 0 |
| hot_hatch | 186.9 | 196.1 | 204.0 | 197.1 | 0 |
| kart_kid | 210.9 | 226.1 | 221.4 | 221.8 | 0 |
| kerb_hopper | 207.3 | 218.8 | 218.0 | 216.7 | 0 |
| long_fork | 184.9 | 203.6 | 207.5 | 204.1 | 0 |
| long_haul | 215.8 | 217.6 | 218.5 | 219.2 | 0 |
| long_lap | 201.0 | 214.6 | 218.5 | 217.5 | 0 |
| mudlark_quad | 188.9 | 196.9 | 204.8 | 197.5 | 0 |
| night_shift | 181.2 | 200.9 | 209.7 | 205.2 | 0 |
| oval_ace | 191.8 | 209.4 | 212.6 | 212.4 | 0 |
| pip | 182.2 | 195.1 | 198.6 | 190.9 | 1 |
| quarter_mile | 197.8 | 214.9 | 224.9 | 220.6 | 0 |
| redline | 186.2 | 202.5 | 204.7 | 201.0 | 0 |
| rock_crawler | 197.1 | 204.3 | 204.7 | 197.8 | 0 |
| sandhopper | 198.4 | 221.9 | 211.3 | 203.4 | 2 |
| scrambler | 194.9 | 209.8 | 208.8 | 205.9 | 0 |
| shifter | 209.0 | 224.2 | 219.8 | 218.8 | 1 |
| six_pack | 192.5 | 209.7 | 215.1 | 207.9 | 0 |
| spark | 210.5 | 231.0 | 228.5 | 225.7 | 0 |
| streak | 211.1 | 224.2 | 224.4 | 225.9 | 0 |
| sunday_trike | 199.8 | 211.7 | 213.9 | 212.3 | 0 |
| tiddler | 206.3 | 218.4 | 224.8 | 222.5 | 0 |
| ton_up | 199.7 | 214.9 | 217.8 | 214.8 | 0 |
| tow_boss | 192.2 | 206.9 | 205.3 | 199.7 | 0 |
| tuk_tuk | 206.4 | 217.9 | 223.9 | 222.7 | 0 |
| twin_nose | 199.8 | 208.2 | 207.3 | 203.8 | 0 |
| volt | 186.6 | 207.9 | 211.9 | 208.3 | 0 |
| zipper | 174.4 | 186.5 | 194.5 | 187.3 | 0 |
| zippy | 207.9 | 219.9 | 227.3 | 222.7 | 0 |

Raw results and worker logs are in `build/balance/<weather>/` for seed 12345 and `build/balance/<weather>/seed_<seed>/` for other seeds. Reproduce with:

```sh
tools/stock-karts/balance.sh
for weather in rain snow; do
  for seed in 12345 54321 8675309; do
    BALANCE_WEATHER="$weather" BALANCE_SEED="$seed" tools/stock-karts/balance.sh
  done
done
python3 tools/stock-karts/weather_report.py --seeds 12345 54321 8675309 > tools/stock-karts/weather_balance.md
```
