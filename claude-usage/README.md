# Claude Usage — KDE Plasma 6 widget

Shows your Claude account usage limits on the desktop:

- **Session (5 hours)** and **Week (7 days)** by default.
- Optionally **Week · Opus**, **Week · Sonnet** and **Extra credits**.
- Progress bar coloured by warning / critical thresholds, with a countdown to each
  limit's reset.
- Credentials from a **file** (by default where Claude Code stores them) **or** from
  a **custom command** (e.g. `incus exec ...`, `ssh ...`).

The data comes from the same endpoint `claude` uses for its `/usage` command
(`GET https://api.anthropic.com/api/oauth/usage`), authenticating with the OAuth
token stored by Claude Code.

## Requirements

- KDE Plasma 6 (Qt 6 / KF6).
- `curl` on `PATH` (for the HTTP calls).
- `cat`, `base64`, `mv`, `chmod`, `printf` (coreutils; `base64`/`mv`/`chmod` are
  only used if you enable automatic token refresh).
- Claude credentials reachable, either:
  - a valid JSON file (default `~/.claude/.credentials.json`), **or**
  - a command that prints them to *stdout* (whatever it runs must be on `PATH`,
    e.g. `incus`, `ssh`, `podman`...).

## Installation

### Option A — `.plasmoid` package (recommended for testing)

`dist/` contains `claude-usage-<version>.plasmoid` (a ZIP with `metadata.json` +
`contents/`, translations already compiled inside).

- **GUI:** right-click the desktop -> *Add Widgets...* -> *Get New...* ->
  **Install Widget From Local File...** -> pick the `.plasmoid`. Then drag
  **Claude Usage** onto the desktop.
- **CLI equivalent:**
  ```sh
  kpackagetool6 --type Plasma/Applet --install dist/claude-usage-1.0.0.plasmoid
  kpackagetool6 --type Plasma/Applet --upgrade dist/claude-usage-1.0.0.plasmoid
  ```

Rebuild the `.plasmoid` after changes:

```sh
./package.sh          # writes the file into dist/
```

### Option B — install from the source tree

```sh
kpackagetool6 --type Plasma/Applet --install .
kpackagetool6 --type Plasma/Applet --upgrade .
```

### Uninstall

```sh
kpackagetool6 --type Plasma/Applet --remove com.github.jefonseca.claudeusage
```

### Reload after a reinstall

```sh
kquitapp6 plasmashell && (kstart plasmashell &)
```

## Settings

Right-click the widget -> *Configure Claude Usage...*

| Setting | Description |
| --- | --- |
| **Credentials source** | *Read from a file* **or** *Run a custom command*. Mutually exclusive. |
| **File path** | (file mode) Path to the JSON with the OAuth token. Empty = `~/.claude/.credentials.json`. A leading `~` or `$HOME` is expanded. |
| **Command** | (command mode) Runs with `/bin/sh -c` on every update. Its *stdout* must be the credentials JSON (with the `claudeAiOauth` key). E.g. `incus exec claude -- cat /home/user/.claude/.credentials.json`. |
| **Update every (seconds)** | Poll interval. Minimum **300 s** (default 300) to avoid hammering the API. |
| **Metrics to show** | Which limits are drawn. Default: 5-hour session and 7-day week. |
| **Warning / critical threshold (%)** | Percentage at which the bar turns yellow / red. |
| **Automatically refresh the expired token** | **Off by default.** See the security section. |

If the chosen source fails (command with a non-zero exit code, empty output,
invalid JSON, or no `accessToken`), the widget shows a warning and makes no API
request.

## Token refresh and security

The Claude Code access token expires every few hours. By default the widget
**does not touch your credentials**: it only reads them and makes a single request
per cycle, `GET https://api.anthropic.com/api/oauth/usage`. If the token is
expired it shows a warning and waits for you to refresh the Claude session
yourself (using `claude` refreshes it, and the widget picks it up on the next
cycle).

The **"Automatically refresh the expired token"** option is **off** and only takes
effect in file mode. If you enable it, the widget will, unattended and
periodically:

1. send your `refresh_token` to `POST https://platform.claude.com/v1/oauth/token`
   (official endpoint, but that is your long-lived credential going out on a
   schedule you might forget about);
2. **rewrite the credentials file** (temp file + `chmod 600` + atomic `mv`),
   preserving keys it does not recognize.

Risks to consider before enabling it:

- **Refresh-token rotation.** Anthropic issues a new `refresh_token` on every use.
  If Claude Code and the widget refresh separately, whichever uses the already
  rotated token is rejected and you have to sign in again. Two processes writing
  the same file is inherently race-prone.
- **File format.** If Anthropic changes the schema, the rewrite could corrupt it.
  This is mitigated with an atomic write and by preserving unknown keys, but it is
  still a write to a file another program manages.
- **Command mode.** No refresh is possible: an arbitrary source (e.g. inside a
  container) cannot be rewritten. You will see the expired-token warning until you
  refresh the session.

**Recommendation:** leave it off. Enable it only on a machine where you almost
never open `claude` and you accept the occasional forced sign-in.

The custom command runs with your user privileges on every cycle: only put there
what you would type in a terminal yourself.

The widget only contacts `api.anthropic.com` and (if you enable refresh)
`platform.claude.com`.

## Languages / translations

The source language is **English** (the `msgid`s in the code). The widget uses
your desktop language when a translation is available.

- Bundled translations: **English** (default) and **Spanish**.
- Sources in `po/` (`es.po` + the `.pot` template).
- Compile to `.mo` (`install.sh` does this too):

  ```sh
  sudo apt install gettext     # if you don't have it
  ./build-translations.sh
  ```

  Produces `contents/locale/<lang>/LC_MESSAGES/plasma_applet_com.github.jefonseca.claudeusage.mo`.

Force a language while testing:

```sh
LANGUAGE=es plasmoidviewer --applet "$PWD"
LANGUAGE=en plasmoidviewer --applet "$PWD"
```

### Add a language

```sh
msginit -i po/plasma_applet_com.github.jefonseca.claudeusage.pot -l fr -o po/fr.po
# translate po/fr.po, then:
./build-translations.sh
```

## Layout

```
metadata.json
package.sh               # builds dist/claude-usage-<version>.plasmoid
build-translations.sh    # compiles po/*.po -> contents/locale/
install.sh               # installs/updates from the source tree
dist/
  claude-usage-1.0.0.plasmoid   # installable package (GUI or kpackagetool6)
po/
  plasma_applet_com.github.jefonseca.claudeusage.pot   # template
  es.po                                                # Spanish
contents/
  config/
    main.xml           # configuration keys (KConfigXT)
    config.qml         # settings-dialog categories
  locale/<lang>/LC_MESSAGES/*.mo   # compiled translations
  ui/
    main.qml           # logic: obtains credentials, refreshes token, calls the API
    UsageBar.qml       # reusable progress bar (theme colors)
    configGeneral.qml  # settings form
```

## Note about `qmllint`

`qmllint` does not resolve the Plasma modules (`org.kde.plasma.plasmoid`,
`org.kde.plasma.configuration`) or the injected globals (`i18n`, `plasmoid`), so
it emits "not found" / "unqualified access" warnings about `PlasmoidItem`,
`toolTipMainText`, `ConfigCategory`, `DataSource`, `i18n(...)`, etc. These are
expected and do not indicate a real error; what matters are **syntax** failures
and broken **imports** of first-party Qt modules.

## License

MIT. See `../LICENSE`.
