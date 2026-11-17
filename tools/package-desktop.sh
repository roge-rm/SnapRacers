#!/usr/bin/env bash
# Exports the desktop builds and packs them, into the folder given (default build/desktop/release):
#   snapracers_V_amd64.deb  snapracers_V_arm64.deb
#   snapracers-V-x86_64.AppImage  snapracers-V-aarch64.AppImage
#   snapracers-V-setup.exe  snapracers-V-windows-x64.zip
# V is the version in project.godot. The engines come from tools/build-engine.sh desktop. The
# installer is made in the apogee-windows image, which has NSIS, and the AppImages with
# appimagetool, downloaded once into build/downloads and checked against its SHA-256.
#
#   tools/package-desktop.sh [OUTDIR]
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT=$PWD
OUT=$(realpath -m "${1:-build/desktop/release}")
V=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
GODOT=tools/godot/Godot_v4.7.2-stable_linux.x86_64
SRC=tools/desktop
BUILD=$ROOT/build/desktop
DL=$ROOT/build/downloads
mkdir -p "$BUILD" "$DL" "$OUT" "$ROOT/build"
touch "$ROOT/build/.gdignore"

for engine in linux_x86_64_release linux_arm64_release windows_x86_64_release.exe; do
	[ -f "tools/godot/custom/desktop/$engine" ] || { echo "No $engine. Run: heavy build tools/build-engine.sh --release desktop" >&2; exit 1; }
done

docker image inspect apogee-windows > /dev/null 2>&1 || { echo "The Docker image apogee-windows (from the Apogee project, it has makensis) isn't here. Build it there first." >&2; exit 1; }

# Version checks: the Windows preset's file version has to match.
grep -q "^application/file_version=\"$V\"" export_presets.cfg || { echo "export_presets.cfg: Windows version isn't $V" >&2; exit 1; }

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
export_one() { # preset, file
	mkdir -p "$(dirname "$2")"
	"$GODOT" --headless --path . --export-release "$1" "$2" > "$BUILD/export.log" 2>&1 || { tail -20 "$BUILD/export.log"; exit 1; }
}
export_one "Linux x86_64" "$BUILD/linux-x86_64/snapracers"
export_one "Linux arm64" "$BUILD/linux-arm64/snapracers"
export_one "Windows x86_64" "$BUILD/windows-x86_64/snapracers.exe"

fetch() { # url sha256
	local f="$DL/${1##*/}"
	if [ ! -f "$f" ] || [ "$(sha256sum "$f" | cut -d' ' -f1)" != "$2" ]; then
		curl -fsSL -o "$f" "$1"
		[ "$(sha256sum "$f" | cut -d' ' -f1)" = "$2" ] || { echo "$f: wrong checksum" >&2; exit 1; }
	fi
	echo "$f"
}
TOOL=$(fetch https://github.com/AppImage/appimagetool/releases/download/1.9.1/appimagetool-x86_64.AppImage ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0)
chmod +x "$TOOL"
RUNTIME_x86_64=$(fetch https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-x86_64 2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d)
RUNTIME_aarch64=$(fetch https://github.com/AppImage/type2-runtime/releases/download/20251108/runtime-aarch64 00cbdfcf917cc6c0ff6d3347d59e0ca1f7f45a6df1a428a0d6d8a78664d87444)

# The icons in two sizes, for the menus.
ICON256=$BUILD/icon-256.png
convert art/snapracers-icon-1024.png -resize 256x256 "$ICON256"

# The Debian packages: the game in /usr/lib/snapracers, a launcher in /usr/games.
make_deb() { # arch, dir
	local stage=$BUILD/deb-$1
	rm -rf "$stage"
	install -d -m 755 "$stage/usr/lib/snapracers" "$stage/usr/games" "$stage/usr/share/applications" \
		"$stage/usr/share/icons/hicolor/1024x1024/apps" "$stage/usr/share/icons/hicolor/256x256/apps" \
		"$stage/usr/share/doc/snapracers" "$stage/DEBIAN"
	install -m 755 "$BUILD/$2/snapracers" "$stage/usr/lib/snapracers/snapracers"
	install -m 755 $SRC/launcher "$stage/usr/games/snapracers"
	install -m 644 $SRC/snapracers.desktop "$stage/usr/share/applications/snapracers.desktop"
	install -m 644 art/snapracers-icon-1024.png "$stage/usr/share/icons/hicolor/1024x1024/apps/snapracers.png"
	install -m 644 "$ICON256" "$stage/usr/share/icons/hicolor/256x256/apps/snapracers.png"
	install -m 644 LICENSE "$stage/usr/share/doc/snapracers/copyright"
	local kb
	kb=$(du -sk --exclude=DEBIAN "$stage" | cut -f1)
	sed "s/@VERSION@/$V/; s/@ARCH@/$1/; s/@SIZE@/$kb/" $SRC/control > "$stage/DEBIAN/control"
	dpkg-deb --root-owner-group -Zxz --build "$stage" "$OUT/snapracers_${V}_$1.deb" > /dev/null
	rm -rf "$stage"
}
make_deb amd64 linux-x86_64
make_deb arm64 linux-arm64

# The AppImages.
make_appimage() { # arch, dir
	local dir=$BUILD/AppDir-$1 runtime=RUNTIME_$1
	rm -rf "$dir"
	install -d -m 755 "$dir/usr/lib/snapracers"
	install -m 755 "$BUILD/$2/snapracers" "$dir/usr/lib/snapracers/snapracers"
	install -m 755 $SRC/AppRun "$dir/AppRun"
	install -m 644 $SRC/snapracers.desktop "$dir/snapracers.desktop"
	install -m 644 "$ICON256" "$dir/snapracers.png"
	rm -f "$OUT/snapracers-$V-$1.AppImage"
	ARCH=$1 APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream --runtime-file "${!runtime}" "$dir" "$OUT/snapracers-$V-$1.AppImage" > /dev/null
	rm -rf "$dir"
}
make_appimage x86_64 linux-x86_64
make_appimage aarch64 linux-arm64

# Windows: the installer, made in the NSIS image, and the zip.
rm -f "$OUT/snapracers-$V-setup.exe" "$OUT/snapracers-$V-windows-x64.zip"
# The exe folder is mounted on its own, since build/desktop may be a link to another disk.
docker run --rm -u "$(id -u):$(id -g)" -v "$ROOT":/src -v "$(realpath "$BUILD/windows-x86_64")":/exe -v "$OUT":/out \
	-w /src/tools/desktop apogee-windows \
	makensis -V1 -DVERSION="$V" -DEXE=/exe/snapracers.exe -DLICENSE=/src/LICENSE \
	-DOUT="/out/snapracers-$V-setup.exe" installer.nsi
python3 -I - "$OUT/snapracers-$V-windows-x64.zip" "$V" "$BUILD/windows-x86_64/snapracers.exe" LICENSE <<'PY'
import sys, zipfile
out, v, exe, lic = sys.argv[1:]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(exe, f"snapracers-{v}/SnapRacers.exe")
    z.write(lic, f"snapracers-{v}/LICENSE.txt")
PY
rm -f "$ICON256"
ls -l "$OUT"
