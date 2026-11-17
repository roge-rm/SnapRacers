#!/usr/bin/env python3
"""Writes tools/track-design/baseline.md from the soak logs in
build/soak-baseline (see baseline.sh), a row a course in cup order. Courses
with no log yet are listed as not raced."""
import json, os, re

root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
logs = os.path.join(root, "build", "soak-baseline")
cups = json.load(open(os.path.join(root, "data", "grand_prix.json")))["cups"]
rows = []
for cup in cups:
    for course in cup["tracks"]:
        log = os.path.join(logs, course + ".log")
        name = json.load(open(os.path.join(root, "data", "tracks", course + ".json")))["name"]
        if not os.path.exists(log):
            rows.append("| %s | %s | | | | | not raced yet |" % (cup["name"].replace(" Cup", ""), name))
            continue
        text = open(log).read()
        best = re.search(r"^BEST \S+: ([\d.]+) s", text, re.M)
        result = re.search(r"^RESULT .*: (\d+) of (\d+) finished, (\d+) resets, (\d+) stalls, (\d+) s", text, re.M)
        # Leaks reported as the engine shuts down after the race don't count.
        errors = len(re.findall(r"^(ERROR|SCRIPT ERROR)", text.split("\nRESULT")[0], re.M))
        if not result:
            rows.append("| %s | %s | | | | | no result |" % (cup["name"].replace(" Cup", ""), name))
            continue
        finished, racers, resets, stalls, took = (int(v) for v in result.groups())
        rows.append("| %s | %s | %s | %d | %s | %d | %s |" % (
            cup["name"].replace(" Cup", ""), name, best.group(1) if best else "", resets,
            "all" if finished == racers else "%d of %d" % (finished, racers), stalls,
            "%d engine errors" % errors if errors else ""))
out = os.path.join(root, "tools", "track-design", "baseline.md")
with open(out, "w") as f:
    f.write("# Course baseline\n\n")
    f.write("Before the stock courses redo (PLAN-tracks.md). Eight AI karts at Expert, clear weather by day, seed 1, 3 laps, from tools/track-design/baseline.sh. Best lap is the fastest lap any kart did, in seconds. Resets are for all eight karts together.\n\n")
    f.write("| Cup | Course | Best lap | Resets | Finished | Stalls | Notes |\n|---|---|---|---|---|---|---|\n")
    f.write("\n".join(rows) + "\n")
print("wrote", out)
