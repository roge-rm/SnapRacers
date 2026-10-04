#!/usr/bin/env bash
# Builds the debug APK. Everything goes in build/, which Godot and git both
# leave alone, and this puts the Android build template back there when it's
# missing.
#
# Phones and the emulator get separate APKs, each with only the engine they
# need, since the engine is most of the size. They're about 19 MB for phones
# and 23 MB for the emulator.
#
#   tools/build-android.sh            the phone build (arm64), copied to the drop folder
#   tools/build-android.sh --install  the emulator build (x86_64), installed on SnapRacers_Pixel_5
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION=4.7.2
GODOT="tools/godot/Godot_v${VERSION}-stable_linux.x86_64"
TEMPLATES="tools/godot/editor_data/export_templates/${VERSION}.stable"
BUILD="$PWD/build"
PRESET="Android"
APK="$BUILD/snapracers-debug.apk"
if [ "${1:-}" = "--install" ]; then
	PRESET="Android emulator"
	APK="$BUILD/snapracers-emulator-debug.apk"
fi
DROP=/srv/downloads/temp/debug/snapracers-debug.apk
ADB="${ANDROID_HOME:-$HOME/Android/Sdk}/platform-tools/adb"
# Our own adb server (see ~/.claude/resources.md), so neither this nor the
# Godot export ever starts or stops the shared one on 5037 that other
# projects' emulators and phones hang off.
export ANDROID_ADB_SERVER_PORT=5042

if [ ! -x "$GODOT" ] || [ ! -f "$TEMPLATES/android_source.zip" ]; then
	echo "Godot $VERSION or its export templates aren't in tools/godot. See README.md." >&2
	exit 1
fi

mkdir -p "$BUILD"
touch "$BUILD/.gdignore"

if [ ! -f "$BUILD/android/.build_version" ]; then
	echo "Unpacking the Android build template into $BUILD/android"
	rm -rf "$BUILD/android"
	mkdir -p "$BUILD/android/build"
	unzip -q "$TEMPLATES/android_source.zip" -d "$BUILD/android/build"
	touch "$BUILD/android/build/.gdignore"
	cat "$TEMPLATES/version.txt" > "$BUILD/android/.build_version"
fi

# The network plugin (NSD, Wi-Fi Direct and Bluetooth), built again whenever
# it's missing or its source has changed.
PLUGIN=addons/snapracers_net/bin/snapracers-net.aar
if [ ! -f "$PLUGIN" ] || [ -n "$(find android-plugin -newer "$PLUGIN" -type f -print -quit)" ]; then
	tools/build-plugin.sh
fi

# Our own cut down engine (see tools/build-engine.sh), when it's been built.
# Phones get a release build of it and the emulator a debug build, so the debug
# switches work there.
#
# The phone build is signed with my release key, which lives beside the project
# in ../Keys, so neither the keystore nor its passwords can be committed.
# Without it, on a fresh clone say, it's signed with the debug key so it can
# still be sideloaded.
SIGNING="../Keys/snapracers-keystore.properties"
ABI=arm64-v8a
KIND=release
if [ "$PRESET" = "Android emulator" ]; then
	ABI=x86_64
	KIND=debug
fi
CUSTOM="tools/godot/custom/$ABI/libgodot_android.so"
EXPORT=--export-debug
if [ -f "$CUSTOM" ]; then
	python3 tools/engine/swap_engine.py "$BUILD/android/build/libs/$KIND/godot-lib.template_$KIND.aar" "$ABI" "$CUSTOM"
	if [ "$KIND" = release ]; then
		EXPORT=--export-release
		if [ -f "$SIGNING" ]; then
			setting() { grep "^$1=" "$SIGNING" | head -1 | cut -d= -f2-; }
			export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$(setting storeFile)"
			export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$(setting keyAlias)"
			export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$(setting keyPassword)"
			echo "Signing with the release key"
		else
			export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/.android/debug.keystore"
			export GODOT_ANDROID_KEYSTORE_RELEASE_USER=androiddebugkey
			export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
			echo "No release key in $SIGNING, so signing with the debug key"
		fi
	fi
else
	echo "Using the stock engine. Run tools/build-engine.sh for a much smaller APK."
fi

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . "$EXPORT" "$PRESET" "$APK"
ls -l "$APK"

if [ "$PRESET" = "Android" ] && [ -d "$(dirname "$DROP")" ]; then
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
