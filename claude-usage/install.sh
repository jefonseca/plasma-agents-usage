#!/bin/sh
# Installs or updates the "Claude Usage" widget in the current user's Plasma.
set -e

DIR=$(cd "$(dirname "$0")" && pwd)
ID="com.github.jefonseca.claudeusage"

# Compile translations (if gettext is available).
if command -v msgfmt >/dev/null 2>&1; then
    "$DIR/build-translations.sh"
else
    echo "Warning: 'msgfmt' not available; installing without compiled translations." >&2
fi

if kpackagetool6 --type Plasma/Applet --show "$ID" >/dev/null 2>&1; then
    echo "Updating $ID ..."
    kpackagetool6 --type Plasma/Applet --upgrade "$DIR"
else
    echo "Installing $ID ..."
    kpackagetool6 --type Plasma/Applet --install "$DIR"
fi

echo "Done. Add it from \"Add Widgets\" -> \"Claude Usage\"."
echo "If it was already on the desktop, reload the shell:  kquitapp6 plasmashell && (kstart plasmashell &)"
