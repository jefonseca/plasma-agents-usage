# KDE Plasma usage widgets

Monorepo of KDE Plasma 6 widgets that show the usage limits of AI coding agents.
Each folder is an independent project, with its own `metadata.json`, `.plasmoid`
package, translations and scripts.

| Project | Widget | Data source |
| --- | --- | --- |
| [`claude-usage/`](claude-usage/) | **Claude Usage** — 5-hour session and weekly limits of your Claude account | `GET api.anthropic.com/api/oauth/usage` with the Claude Code OAuth token |
| [`opencode-usage/`](opencode-usage/) | **OpenCode Usage** — 5-hour, weekly and monthly limits of OpenCode Go | `GET opencode.ai/zen/go/v1/usage` with your OpenCode API key |

## Common layout of each project

```
<project>/
  metadata.json
  package.sh              # builds dist/<project>-<version>.plasmoid
  build-translations.sh   # compiles po/*.po -> contents/locale/
  install.sh              # installs/updates from the source tree
  dist/*.plasmoid         # installable package (GUI or kpackagetool6)
  po/                     # .pot + translations (es)
  contents/
    config/               # main.xml (KConfigXT) + config.qml
    locale/               # compiled translations
    ui/                   # main.qml, UsageBar.qml, configGeneral.qml
```

## Installing a widget

From `<project>/`:

```sh
./build-translations.sh          # needs gettext (msgfmt)
./package.sh                     # -> dist/<project>-1.0.0.plasmoid
```

Then, in Plasma: right-click the desktop -> *Add Widgets...* -> *Get New...* ->
**Install Widget From Local File...** -> pick the `.plasmoid`.

Or via CLI: `kpackagetool6 --type Plasma/Applet --install dist/<project>-1.0.0.plasmoid`.

## Contributing context

See [`AGENTS.md`](AGENTS.md) for the accumulated working context: environment,
per-endpoint details, conventions, and project history.

## License

MIT. See [`LICENSE`](LICENSE).
