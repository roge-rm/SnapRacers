#!/usr/bin/env bash
# Builds the debug APK. Everything heavy happens in /tmp, which is a RAM disk
# on my build machine, because /home is on a slow hard drive. /tmp is emptied
# on a reboot, so this puts the Android build template back when it's missing.
#
#   tools/build-android.sh            build it
#   tools/build-android.sh --install  build it and install it on the SnapRacers_Pixel_5 emulator
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION=4.7.2
GODOT="tools/godot/Godot_v${VERSION}-stable_linux.x86_64"
TEMPLATES="tools/godot/editor_data/export_templates/${VERSION}.stable"
BUILD=/tmp/snapracers-build
APK="$BUILD/snapracers-debug.apk"
DROP=/srv/downloads/temp/debug/snapracers-debug.apk
ADB="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb"

if [ ! -x "$GODOT" ] || [ ! -f "$TEMPLATES/android_source.zip" ]; then
	echo "Godot $VERSION or its export templates aren't in tools/godot. See README.md." >&2
	exit 1
fi

if [ ! -f "$BUILD/android/.build_version" ]; then
	echo "Unpacking the Android build template into $BUILD/android"
	rm -rf "$BUILD/android"
	mkdir -p "$BUILD/android/build"
	unzip -q "$TEMPLATES/android_source.zip" -d "$BUILD/android/build"
	touch "$BUILD/android/build/.gdignore"
	cat "$TEMPLATES/version.txt" > "$BUILD/android/.build_version"
fi

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --export-debug Android "$APK"
ls -l "$APK"

if [ -d "$(dirname "$DROP")" ]; then
	cp "$APK" "$DROP"
	echo "Copied to $DROP"
fi

if [ "${1:-}" = "--install" ]; then
	"$ADB" start-server > /dev/null 2>&1
	sleep 2 # a freshly started adb server takes a moment to see the emulators
	serial=""
	for s in $("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}'); do
		if [ "$("$ADB" -s "$s" emu avd name 2>/dev/null | head -1 | tr -d '\r')" = "SnapRacers_Pixel_5" ]; then
			serial="$s"
		fi
	done
	if [ -z "$serial" ]; then
		echo "The SnapRacers_Pixel_5 emulator isn't running." >&2
		exit 1
	fi
	"$ADB" -s "$serial" install -r "$APK"
	activity=$("$ADB" -s "$serial" shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER com.rm.snapracers | tail -1 | tr -d '\r')
	"$ADB" -s "$serial" shell am start -n "$activity"
fi
