# OpenCode Usage — KDE Plasma 6 widget

Shows your **OpenCode Go** usage limits on the desktop:

- **Session (5 hours)**, **Week** and **Month** (the three limits the API exposes).
- Each metric: percentage, bar coloured by thresholds, and a countdown to the reset.
- If a limit is exhausted (`rate-limited`), the bar turns red and shows
  "limit reached".
- The API key is read from a **file** (opencode's `auth.json` by default), from a
  custom **command**, or **entered directly**.

## Where the data comes from

`GET https://opencode.ai/zen/go/v1/usage` with `Authorization: Bearer <API_KEY>`.
Response:

```json
{
  "usage": {
    "rolling": { "status": "ok", "percent": 12, "resetsAt": "2026-08-31T21:00:00.000Z" },
    "weekly":  { "status": "ok", "percent": 40, "resetsAt": "..." },
    "monthly": { "status": "rate-limited", "percent": 100, "resetsAt": "..." }
  }
}
```

- `rolling` = rolling 5-hour window · `weekly` = calendar week · `monthly` = month
  since the subscription date.
- `401` -> invalid API key. `403` -> no OpenCode Go subscription.

> This endpoint is **OpenCode Go**. OpenCode Zen (pay-as-you-go) has no public
> balance/usage endpoint yet, so the widget does not show it.

## Requirements

- KDE Plasma 6 (Qt 6 / KF6).
- `curl` on `PATH`.
- An OpenCode Go API key, reachable through one of the three modes (file / command
  / direct).

## Installation

Same as `claude-usage`: the `dist/opencode-usage-<version>.plasmoid` package.

- **GUI:** right-click the desktop -> *Add Widgets...* -> *Get New...* ->
  **Install Widget From Local File...** -> pick the `.plasmoid`.
- **CLI:**
  ```sh
  kpackagetool6 --type Plasma/Applet --install dist/opencode-usage-1.0.0.plasmoid
  kpackagetool6 --type Plasma/Applet --upgrade dist/opencode-usage-1.0.0.plasmoid
  kpackagetool6 --type Plasma/Applet --remove com.github.jefonseca.opencodeusage
  ```

Rebuild the package: `./package.sh`. Reload the shell:
`kquitapp6 plasmashell && (kstart plasmashell &)`.

## Settings

| Setting | Description |
| --- | --- |
| **Title** | Show/hide and customize the title (empty = default). |
| **API key source** | *Read from opencode auth.json* · *Run a custom command* · *Enter the key directly*. |
| **auth.json path** | (file mode) Empty = `$XDG_DATA_HOME/opencode/auth.json` (falls back to `~/.local/share/...`). A leading `~` or `$HOME` is expanded. |
| **Command** | (command mode) `/bin/sh -c` on every update. Its output may be the full `auth.json` or just the key. |
| **Provider key** | (file/command mode) Which entry in `auth.json` holds the key (default `opencode-go`). If missing, an entry with `"type":"api"` whose name contains "opencode" is preferred; otherwise the first `"type":"api"`. |
| **API key** | (direct mode) Stored **in plain text** in the widget config; use file mode when you can. |
| **Update every (seconds)** | Minimum **300 s** (default 300). |
| **Metrics to show** | Session (5 h), Week, Month. All three by default. |
| **Warning / critical threshold (%)** | When the bar turns yellow / red. |

## Security

- The OpenCode API key is **static** (no refresh). The widget **only reads it**;
  it never rewrites it.
- It is only sent to `opencode.ai`.
- The **custom command** runs with `/bin/sh -c` and your privileges on every
  cycle: only put there what you would type in a terminal.
- **Direct mode** stores the key in plain text in the applet's config file
  (`~/.config/plasma-org.kde.plasma.desktop-appletsrc`). File mode exposes nothing
  new: it reads the `auth.json` opencode already manages.

## Translations

English (source) + Spanish. Sources in `po/`, compiled with `./build-translations.sh`
into `contents/locale/<lang>/LC_MESSAGES/plasma_applet_com.github.jefonseca.opencodeusage.mo`.

## License

MIT. See `../LICENSE`.
