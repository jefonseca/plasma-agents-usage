#!/bin/sh
# Builds dist/claude-usage-<version>.plasmoid, ready for
# "Install Widget From Local File..." or `kpackagetool6 -i file.plasmoid`.
set -e

DIR=$(cd "$(dirname "$0")" && pwd)
cd "$DIR"

VERSION=$(python3 -c "import json;print(json.load(open('metadata.json'))['KPlugin']['Version'])")
OUT="dist/claude-usage-${VERSION}.plasmoid"

# Compile translations into the package.
if command -v msgfmt >/dev/null 2>&1; then
    ./build-translations.sh
else
    echo "Warning: 'msgfmt' not found; the package will ship without translations." >&2
fi

mkdir -p dist
rm -f "$OUT"

# A .plasmoid is a ZIP with metadata.json and contents/ at the archive root.
zip -r -q "$OUT" metadata.json contents \
    -x '*/.*' -x '*~' -x '*.tmp'

echo "Created: $OUT"
unzip -l "$OUT"
