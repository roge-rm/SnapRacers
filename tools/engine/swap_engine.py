#!/usr/bin/env python3
"""Puts SnapRacers' own engine library into the Android build template.

The template keeps Godot's engine in an AAR (a zip) for each of debug and
release, with a library for every architecture. This swaps the one for this
architecture for ours, and drops the rest, since each APK is only for one.

    swap_engine.py <template.aar> <abi> <libgodot_android.so>
"""

import os
import shutil
import sys
import tempfile
import zipfile

aar, abi, lib = sys.argv[1:4]
keep_prefix = "jni/%s/" % abi
fd, temp = tempfile.mkstemp(suffix=".aar", dir=os.path.dirname(aar))
os.close(fd)
with zipfile.ZipFile(aar) as old, zipfile.ZipFile(temp, "w", zipfile.ZIP_DEFLATED) as new:
    for item in old.infolist():
        name = item.filename
        if name.startswith("jni/") and not name.startswith(keep_prefix) and name != "jni/":
            continue
        if name == keep_prefix + "libgodot_android.so":
            new.write(lib, name)
        else:
            new.writestr(item, old.read(name))
shutil.move(temp, aar)
print("Put %s into %s for %s" % (lib, os.path.basename(aar), abi))
