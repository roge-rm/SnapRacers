#!/usr/bin/env bash
# Builds every file of a release into ~/Projects/releases/snapracers-V, V being the version in
# project.godot, with SHA256SUMS:
#   SnapRacers-V.apk  SnapRacers-V-32bit.apk   phones (the names earlier releases used)
#   web/                                       the browser version
#   snapracers_V_amd64.deb  snapracers_V_arm64.deb
#   snapracers-V-x86_64.AppImage  snapracers-V-aarch64.AppImage
#   snapracers-V-setup.exe  snapracers-V-windows-x64.zip
#
#   tools/build-release.sh              build with the engines as they are now
#   tools/build-release.sh --release    build the engines fully optimised first (slow)
#   tools/build-release.sh --publish    and copy the APKs and .debs to the F-Droid inbox
#   tools/build-release.sh --out DIR    put the files in DIR instead
#   tools/build-release.sh --no-android | --no-web | --no-desktop   leave a part out
#   tools/build-release.sh --dry-run    only print the commands
#
# Each step runs through heavy, so it waits for a free build slot.
set -euo pipefail

cd "$(dirname "$0")/.."
RELEASE=0 PUBLISH=0 DRY=0 ANDROID=1 WEB=1 DESKTOP=1
V=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
OUT=$HOME/Projects/releases/snapracers-$V
while [ $# -gt 0 ]; do
	case "$1" in
		--release) RELEASE=1 ;;
		--publish) PUBLISH=1 ;;
		--dry-run) DRY=1 ;;
		--no-android) ANDROID=0 ;;
		--no-web) WEB=0 ;;
		--no-desktop) DESKTOP=0 ;;
		--out) OUT=$(realpath -m "$2"); shift ;;
		*) echo "I don't know $1" >&2; exit 1 ;;
	esac
	shift
done
INBOX=$HOME/Projects/fdroid/inbox

run() {
	echo "+ heavy build $*"
	[ "$DRY" = 1 ] || heavy build "$@"
}

# The Android presets and the Windows versions all have to say V.
for name in $(sed -n 's/^version\/name="\(.*\)"/\1/p; s/^application\/file_version="\(.*\)"/\1/p; s/^application\/product_version="\(.*\)"/\1/p' export_presets.cfg); do
	[ "$name" = "$V" ] || { echo "export_presets.cfg has version $name, project.godot has $V" >&2; exit 1; }
done

# Each Android version/code has to be higher than the last one published. Skipped when offline.
if [ "$ANDROID" = 1 ]; then
	PKG=$(sed -n 's/^package\/unique_name="\(.*\)"/\1/p' export_presets.cfg | head -1)
	LAST=$(curl -sf -m 15 https://hunke.ws/fdroid/repo/index-v2.json | python3 -I -c "
import json, sys
p = json.load(sys.stdin)['packages'].get(sys.argv[1], {})
print(max([int(v['manifest']['versionCode']) for v in p.get('versions', {}).values()] or [0]))" "$PKG" 2>/dev/null) || LAST=
	if [ -z "$LAST" ]; then
		echo "Warning: can't reach the F-Droid index, so the version codes aren't checked." >&2
	else
		for code in $(sed -n 's/^version\/code=\(.*\)/\1/p' export_presets.cfg); do
			[ "$code" -gt "$LAST" ] || { echo "export_presets.cfg has version/code $code, the F-Droid repo already has $LAST" >&2; exit 1; }
		done
		echo "Version codes are above $LAST, the last one published."
	fi
fi

# OUT is cleared of what this script makes. Any other file in it stops the build.
if [ "$DRY" = 0 ]; then
	mkdir -p "$OUT"
	shopt -s nullglob
	OLD=("$OUT"/SnapRacers-*.apk "$OUT"/snapracers_*.deb "$OUT"/snapracers-*.AppImage "$OUT"/snapracers-*-setup.exe \
		"$OUT"/snapracers-*-windows-x64.zip "$OUT"/SHA256SUMS)
	for f in "$OUT"/* "$OUT"/.[!.]*; do
		[ -e "$f" ] || continue
		[ "$f" = "$OUT/web" ] && continue
		case " ${OLD[*]} " in *" $f "*) ;; *) echo "$OUT has $f, which this script doesn't make. Use an empty folder." >&2; exit 1 ;; esac
	done
	rm -rf "${OLD[@]}" "$OUT/web"
	shopt -u nullglob
fi

if [ "$RELEASE" = 1 ]; then
	[ "$ANDROID" = 0 ] || { run tools/build-engine.sh --release arm64; run tools/build-engine.sh --release arm32; }
	[ "$WEB" = 0 ] || run tools/build-engine.sh web
	[ "$DESKTOP" = 0 ] || run tools/build-engine.sh --release desktop
fi

if [ "$ANDROID" = 1 ]; then
	rm -f build/snapracers-debug.apk build/snapracers-arm32.apk
	run tools/build-android.sh
	run tools/build-android.sh --arm32
	if [ "$DRY" = 0 ]; then
		cp build/snapracers-debug.apk "$OUT/SnapRacers-$V.apk"
		cp build/snapracers-arm32.apk "$OUT/SnapRacers-$V-32bit.apk"
		# Each APK's version and key. A debug-signed one means ../Keys was missing.
		TOOLS=$(ls -d "$HOME"/Android/Sdk/build-tools/*/ | sort -V | tail -1)
		for f in "$OUT/SnapRacers-$V.apk" "$OUT/SnapRacers-$V-32bit.apk"; do
			"${TOOLS}aapt2" dump badging "$f" | grep -E "^package|native-code"
			certs=$("${TOOLS}apksigner" verify --print-certs "$f")
			echo "$certs" | grep "certificate SHA-256"
			! echo "$certs" | grep -q "CN=Android Debug" || { echo "$f: signed with the debug key" >&2; exit 1; }
		done
	fi
fi

if [ "$WEB" = 1 ]; then
	# The F-Droid publisher uses publish_play.sh for the live page; this is the same build.
	run tools/build-web.sh
	if [ "$DRY" = 0 ]; then
		rm -rf "${OUT:?}/web"
		cp -rL build/web "$OUT/web"
	fi
fi

if [ "$DESKTOP" = 1 ]; then
	run tools/package-desktop.sh "$OUT"
fi

[ "$DRY" = 0 ] || exit 0
cd "$OUT"
shopt -s nullglob
FILES=()
for f in SnapRacers-"$V"*.apk snapracers_"$V"_*.deb snapracers-"$V"-*.AppImage snapracers-"$V"-setup.exe snapracers-"$V"-windows-x64.zip; do
	[ ! -f "$f" ] || FILES+=("$f")
done
[ ${#FILES[@]} -gt 0 ] || { echo "No release files in $OUT to sum" >&2; exit 1; }
sha256sum "${FILES[@]}" > SHA256SUMS
cat SHA256SUMS

if [ "$PUBLISH" = 1 ]; then
	PUB=(SnapRacers-"$V"*.apk snapracers_"$V"_*.deb)
	[ ${#PUB[@]} -gt 0 ] || { echo "No APKs or .debs to copy to the inbox" >&2; exit 1; }
	cp "${PUB[@]}" "$INBOX/"
	echo "Copied the APKs and .debs to $INBOX. systemctl --user start fdroid-publish.service publishes them."
fi
echo DONE
