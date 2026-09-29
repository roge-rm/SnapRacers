#!/usr/bin/env bash
# Builds the Android network plugin (android-plugin, see its settings.gradle)
# into addons/snapracers_net/bin, where the export picks it up. It uses the
# Gradle from Godot's Android build template, which tools/build-android.sh
# unpacks into /tmp, and builds in /tmp too. tools/build-android.sh runs this
# by itself whenever the plugin's changed.
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD=/tmp/snapracers-build
GRADLEW="$BUILD/android/build/gradlew"
OUT=addons/snapracers_net/bin/snapracers-net.aar

if [ ! -x "$GRADLEW" ]; then
	echo "Godot's Android build template isn't unpacked yet. Run tools/build-android.sh." >&2
	exit 1
fi
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
"$GRADLEW" -p android-plugin --quiet --project-cache-dir "$BUILD/plugin-gradle" assembleRelease
cp "$BUILD/plugin/outputs/aar/snapracers-net-release.aar" "$OUT"
echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
