#!/usr/bin/env python3
"""Puts the times from balance.sh's copies of the game together with the
last full run's, keeps them in last_balance.json, and prints how each
vehicle compares with the middle of the field on each course and overall.
The ones just timed are marked with a *.

  python3 tools/stock-karts/balance_table.py [times.json ...]
"""

import json
import os
import statistics
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KEPT = os.path.join(HERE, "last_balance.json")
COURSES = ["peach_pit", "foundry_flats", "launchpad_loop", "dune_drift"]


def main():
    kept = json.load(open(KEPT)) if os.path.exists(KEPT) else {}
    fresh = set()
    for path in sys.argv[1:]:
        for key, courses in json.load(open(path)).items():
            kept.setdefault(key, {}).update(courses)
            fresh.add(key)
    stock = {name[:-5] for name in os.listdir(os.path.join(HERE, "..", "..", "data", "karts", "stock")) if name.endswith(".json")}
    kept = {key: value for key, value in kept.items() if key in stock}
    with open(KEPT, "w") as f:
        json.dump(kept, f, indent="\t", sort_keys=True)
        f.write("\n")
    courses = [c for c in COURSES if any(c in v for v in kept.values())]
    middles = {}
    for course in courses:
        times = [v[course]["time"] for v in kept.values() if course in v and v[course]["time"] > 0]
        middles[course] = statistics.median(times) if times else 1.0
    print("\n%-14s %s   overall  resets" % ("", "   ".join("%-14s" % c for c in courses)))
    for key in sorted(kept):
        line = "%-13s%s" % (key, "*" if key in fresh else " ")
        ratios = []
        resets = 0
        for course in courses:
            result = kept[key].get(course)
            if result is None or result["time"] <= 0:
                line += "   %-14s" % "   -"
                continue
            ratio = result["time"] / middles[course]
            ratios.append(ratio)
            resets += result["resets"]
            line += "   %+5.1f%%        " % ((ratio - 1.0) * 100.0)
        overall = (sum(ratios) / len(ratios) - 1.0) * 100.0 if ratios else 0.0
        print(line + "   %+5.1f%%   %d" % (overall, resets))


if __name__ == "__main__":
    main()
