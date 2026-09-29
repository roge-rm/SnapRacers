#!/usr/bin/env bash
# Builds the web page, so the game can be played in a browser, like Apogee.
# It's the same game with the same saves kept in the browser, just without
# threads, so it runs on any web host (a threaded page needs the host to send
# special headers, which GitLab Pages can't).
#
# It uses our own cut down engine for the web (tools/build-engine.sh web),
# building it first if it isn't there. Everything goes in /tmp, like the
# Android builds.
#
#   tools/build-web.sh            the page, in /tmp/snapracers-build/web
#   tools/build-web.sh --serve    and serve it over HTTPS on port 8060 to try it
#                                 on other devices (see tools/serve_web.py)
#   tools/build-web.sh --publish  and put it on my site at /play/snapracers
#                                 (then commit and push the site)
set -euo pipefail

cd "$(dirname "$0")/.."
VERSION=4.7.2
GODOT="tools/godot/Godot_v${VERSION}-stable_linux.x86_64"
ENGINE=tools/godot/custom/web/web_nothreads_release.zip
OUT=/tmp/snapracers-build/web
SITE="$HOME/Projects/fdroid"

if [ ! -f "$ENGINE" ]; then
	tools/build-engine.sh web
fi

# Emptied rather than deleted, so a server already serving it (--serve, or
# one running from before) keeps working.
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -delete
"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Web" "$OUT/index.html"

# Squeezed copies of the big files, which a host that knows to (GitLab Pages
# does) sends instead, for a much smaller download.
for file in "$OUT"/*.wasm "$OUT"/*.pck "$OUT"/*.js; do
	[ -f "$file" ] && gzip -9 -k -f "$file"
done
ls -l "$OUT"

case "${1:-}" in
	--serve)
		tools/serve_web.py 8060
		;;
	--publish)
		"$SITE/publish_play.sh" snapracers "$OUT"
		;;
esac
