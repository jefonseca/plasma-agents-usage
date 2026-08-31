#!/bin/sh
# Compiles po/*.po into contents/locale/<lang>/LC_MESSAGES/<domain>.mo
# English is the source language (the msgids) and needs no .po.
set -e

DIR=$(cd "$(dirname "$0")" && pwd)
DOMAIN=plasma_applet_com.github.jefonseca.claudeusage

if ! command -v msgfmt >/dev/null 2>&1; then
    echo "Missing 'msgfmt'. Install:  sudo apt install gettext" >&2
    exit 1
fi

found=0
for po in "$DIR"/po/*.po; do
    [ -e "$po" ] || continue
    found=1
    lang=$(basename "$po" .po)
    dest="$DIR/contents/locale/$lang/LC_MESSAGES"
    mkdir -p "$dest"
    msgfmt --check --statistics "$po" -o "$dest/$DOMAIN.mo"
    echo "  -> contents/locale/$lang/LC_MESSAGES/$DOMAIN.mo"
done

[ "$found" = 1 ] || { echo "No po/*.po files found"; exit 1; }
echo "Translations compiled."
