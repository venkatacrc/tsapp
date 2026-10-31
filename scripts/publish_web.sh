#!/usr/bin/env bash
# Copies the web app and the course into the bhakti repo as sopanam/, which GitHub Pages
# serves at https://venkatacrc.github.io/bhakti/sopanam/.
# Usage: scripts/publish_web.sh [path/to/bhakti]   (default ~/code/bhakti)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BHAKTI="${1:-$HOME/code/bhakti}"
DEST="$BHAKTI/sopanam"

[ -d "$BHAKTI/.git" ] || { echo "Not a git repo: $BHAKTI" >&2; exit 1; }

python3 "$ROOT/tools/build_course.py"

if [ ! -f "$ROOT/web/icons/maskable-512.png" ]; then
    swift "$ROOT/scripts/make_icon.swift" --web "$ROOT/web/icons"
fi

rm -rf "$DEST"
mkdir -p "$DEST/icons"
cp "$ROOT"/web/{index.html,app.css,app.js,lipi.js,course.json,manifest.webmanifest} "$DEST/"
cp "$ROOT"/web/icons/*.png "$DEST/icons/"

# A new cache name makes installed copies drop the old files.
VERSION="$(cat "$DEST"/*.* "$ROOT/web/sw.js" | shasum | cut -c1-10)"
sed "s/sopanam-dev/sopanam-$VERSION/" "$ROOT/web/sw.js" > "$DEST/sw.js"

echo "Published to $DEST (version $VERSION)"
echo "Commit and push bhakti to put it online."
