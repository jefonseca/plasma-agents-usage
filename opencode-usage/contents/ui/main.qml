import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property string usageUrl: "https://opencode.ai/zen/go/v1/usage"

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    property var usageData: null            // { rolling, weekly, monthly }
    property string status: "init"          // init | loading | ok | error
    property string errorMessage: ""
    property double lastUpdatedMs: 0
    property string homeDir: ""
    property string dataDir: ""             // $XDG_DATA_HOME or $HOME/.local/share
    property int _seq: 0
    property int _tick: 0

    readonly property date lastUpdated: new Date(lastUpdatedMs)

    readonly property string effectiveTitle: {
        var t = (plasmoid.configuration.customTitle || "").trim()
        return t.length > 0 ? t : i18n("OpenCode Usage")
    }

    // Metrics resolved for the view: [{label, percent, resetText, rateLimited}]
    readonly property var visibleMetrics: {
        root._tick
        var data = usageData
        var out = []
        if (!data)
            return out
        var defs = [
            { key: "rolling", on: plasmoid.configuration.showRolling, label: i18n("Session (5 hours)") },
            { key: "weekly",  on: plasmoid.configuration.showWeekly,  label: i18n("Week") },
            { key: "monthly", on: plasmoid.configuration.showMonthly, label: i18n("Month") }
        ]
        for (var i = 0; i < defs.length; ++i) {
            if (!defs[i].on)
                continue
            var m = data[defs[i].key]
            if (!m)
                continue
            out.push({
                label: defs[i].label,
                percent: m.percent || 0,
                resetText: root.formatReset(m.resetsAt),
                rateLimited: m.status === "rate-limited"
            })
        }
        return out
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function shq(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function resolvedAuthPath() {
        var p = plasmoid.configuration.authPath
        if (!p || p.length === 0)
            return root.dataDir + "/opencode/auth.json"
        if (p.charAt(0) === "~")
            return root.homeDir + p.substring(1)
        if (p.indexOf("$HOME") === 0)
            return root.homeDir + p.substring(5)
        return p
    }

    function formatReset(iso) {
        if (!iso)
            return ""
        var s = String(iso).replace(/(\.\d{3})\d+/, "$1")
        var d = new Date(s)
        if (isNaN(d.getTime()))
            return ""
        var ms = d.getTime() - Date.now()
        if (ms <= 0)
            return i18n("resetting…")
        var mins = Math.round(ms / 60000)
        var h = Math.floor(mins / 60)
        var m = mins % 60
        if (h >= 24) {
            var days = Math.floor(h / 24)
            return i18n("resets in %1d %2h", days, h % 24)
        }
        if (h > 0)
            return i18n("resets in %1h %2m", h, m)
        return i18n("resets in %1m", m)
    }

    function fail(msg) {
        root.status = "error"
        root.errorMessage = msg
    }

    // ------------------------------------------------------------------
    // Command runner (plasma5support "executable" engine)
    // ------------------------------------------------------------------
    P5Support.DataSource {
        id: sh
        engine: "executable"
        interval: 0
        connectedSources: []

        property var _cb: ({})

        onNewData: (source, data) => {
            var cb = _cb[source]
            disconnectSource(source)
            delete _cb[source]
            if (cb)
                cb(String(data["stdout"] || ""), String(data["stderr"] || ""), data["exit code"] || 0)
        }

        function run(cmd, cb) {
            var src = cmd + " #" + (++root._seq)
            _cb[src] = cb
            connectSource(src)
        }
    }

    // ------------------------------------------------------------------
    // Main flow
    // ------------------------------------------------------------------
    function refresh() {
        if (root.homeDir.length === 0)
            return
        if (root.status === "loading")
            return
        root.status = "loading"
        loadApiKey()
    }

    // Extract the API key from an opencode auth.json text, or accept a bare key.
    function extractKey(text, allowRawFallback) {
        var parsed
        try {
            parsed = JSON.parse(text)
        } catch (e) {
            if (allowRawFallback) {
                var raw = String(text).trim()
                return raw.length > 0 ? raw : null
            }
            return null
        }
        if (!parsed || typeof parsed !== "object")
            return null
        var pid = (plasmoid.configuration.providerId || "opencode-go").trim()
        var entry = parsed[pid]
        if (entry && typeof entry === "object" && entry.key
                && (!entry.type || entry.type === "api"))
            return entry.key
        // Fallback 1: an "api" entry whose name mentions opencode (auth.json can also
        // hold keys for other providers, e.g. "google").
        var k, e
        for (k in parsed) {
            e = parsed[k]
            if (e && typeof e === "object" && e.type === "api" && e.key
                    && k.toLowerCase().indexOf("opencode") !== -1)
                return e.key
        }
        // Fallback 2: the first "api" entry.
        for (k in parsed) {
            e = parsed[k]
            if (e && typeof e === "object" && e.type === "api" && e.key)
                return e.key
        }
        return null
    }

    function loadApiKey() {
        var mode = plasmoid.configuration.credentialsSource

        if (mode === "apikey") {
            var k = (plasmoid.configuration.apiKey || "").trim()
            if (k.length === 0) {
                root.fail(i18n("No API key set. Paste your OpenCode API key in the settings."))
                return
            }
            fetchUsage(k)
            return
        }

        if (mode === "command") {
            var cmd = (plasmoid.configuration.authCommand || "").trim()
            if (cmd.length === 0) {
                root.fail(i18n("No command configured to obtain the API key."))
                return
            }
            sh.run(cmd, function (out, err, code) {
                if (code !== 0) {
                    root.fail(i18n("The API key command failed (exit code %1). %2",
                                   code, err.split("\n")[0]))
                    return
                }
                var key = root.extractKey(out, true)
                if (!key) {
                    root.fail(i18n("The command output did not contain an OpenCode API key."))
                    return
                }
                fetchUsage(key)
            })
            return
        }

        // mode === "file"
        var path = resolvedAuthPath()
        sh.run("cat " + shq(path), function (out, err, code) {
            if (code !== 0 || out.length === 0) {
                root.fail(i18n("Could not read %1", path))
                return
            }
            var key = root.extractKey(out, false)
            if (!key) {
                root.fail(i18n("No API key for provider \"%1\" found in %2",
                               plasmoid.configuration.providerId || "opencode", path))
                return
            }
            fetchUsage(key)
        })
    }

    function fetchUsage(key) {
        var cmd = "curl -sS -m 20 " + shq(root.usageUrl)
                + " -H " + shq("Authorization: Bearer " + key)
                + " -H 'Content-Type: application/json'"
                + " -w '\\n%{http_code}'"
        sh.run(cmd, function (out, err, code) {
            if (code !== 0) {
                root.fail(i18n("Network error while fetching usage: %1", err))
                return
            }
            var nl = out.lastIndexOf("\n")
            var http = out.substring(nl + 1).trim()
            var payload = out.substring(0, nl)
            var body = null
            try { body = JSON.parse(payload) } catch (e) { body = null }

            if (http === "401") {
                root.fail(i18n("Unauthorized (401). Check your OpenCode API key."))
                return
            }
            if (http === "403") {
                root.fail((body && body.error && body.error.message)
                          ? body.error.message
                          : i18n("OpenCode Go subscription required."))
                return
            }
            if (http !== "200") {
                root.fail(i18n("The usage server responded HTTP %1", http))
                return
            }
            if (!body || !body.usage) {
                root.fail(i18n("Invalid usage response"))
                return
            }
            root.usageData = body.usage
            root.status = "ok"
            root.errorMessage = ""
            root.lastUpdatedMs = Date.now()
        })
    }

    // ------------------------------------------------------------------
    // Startup and timers
    // ------------------------------------------------------------------
    Component.onCompleted: {
        sh.run("printf '%s\\n%s' \"$HOME\" \"${XDG_DATA_HOME:-}\"", function (out) {
            var lines = out.split("\n")
            root.homeDir = (lines[0] || "").trim() || "/root"
            var xdg = (lines[1] || "").trim()
            root.dataDir = xdg.length > 0 ? xdg : root.homeDir + "/.local/share"
            root.refresh()
        })
    }

    Timer {
        interval: Math.max(300, plasmoid.configuration.refreshInterval) * 1000
        repeat: true
        running: root.homeDir.length > 0
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root._tick++
    }

    Connections {
        target: plasmoid.configuration
        function onCredentialsSourceChanged() { root.refresh() }
        function onAuthPathChanged() { root.refresh() }
        function onAuthCommandChanged() { root.refresh() }
        function onProviderIdChanged() { root.refresh() }
        function onApiKeyChanged() { root.refresh() }
    }

    // ------------------------------------------------------------------
    // Panel tooltip
    // ------------------------------------------------------------------
    toolTipMainText: root.effectiveTitle
    toolTipSubText: {
        if (root.status === "error")
            return root.errorMessage
        if (!root.usageData)
            return i18n("No data yet")
        var parts = []
        if (root.usageData.rolling)
            parts.push(i18n("5h: %1%", Math.round(root.usageData.rolling.percent)))
        if (root.usageData.weekly)
            parts.push(i18n("7d: %1%", Math.round(root.usageData.weekly.percent)))
        if (root.usageData.monthly)
            parts.push(i18n("30d: %1%", Math.round(root.usageData.monthly.percent)))
        return parts.join("    ")
    }

    // ------------------------------------------------------------------
    // Compact representation (panel)
    // ------------------------------------------------------------------
    compactRepresentation: MouseArea {
        onClicked: root.expanded = !root.expanded

        RowLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "utilities-system-monitor"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents.Label {
                text: {
                    if (root.status === "error")
                        return "!"
                    if (!root.usageData)
                        return "—"
                    var a = root.usageData.rolling ? Math.round(root.usageData.rolling.percent) + "%" : "—"
                    var b = root.usageData.weekly ? Math.round(root.usageData.weekly.percent) + "%" : "—"
                    return a + " / " + b
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Full representation (desktop)
    // ------------------------------------------------------------------
    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 16
        Layout.minimumWidth: Kirigami.Units.gridUnit * 15
        Layout.minimumHeight: Kirigami.Units.gridUnit * 11
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "utilities-system-monitor"
                Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                Kirigami.Heading {
                    level: 3
                    visible: plasmoid.configuration.showTitle
                    text: root.effectiveTitle
                }
                PlasmaComponents.Label {
                    visible: text.length > 0
                    text: i18n("OpenCode Go")
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                }
            }
            QQC2.BusyIndicator {
                running: root.status === "loading"
                visible: running
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            QQC2.ToolButton {
                icon.name: "view-refresh"
                enabled: root.status !== "loading"
                onClicked: root.refresh()
                QQC2.ToolTip.text: i18n("Refresh now")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            visible: root.status === "error"
            type: Kirigami.MessageType.Error
            text: root.errorMessage
        }

        Repeater {
            model: root.visibleMetrics
            delegate: UsageBar {
                required property var modelData
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                label: modelData.label
                percent: modelData.percent
                resetText: modelData.resetText
                rateLimited: modelData.rateLimited
                warnThreshold: plasmoid.configuration.warnThreshold
                critThreshold: plasmoid.configuration.critThreshold
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            opacity: 0.7
            wrapMode: Text.WordWrap
            visible: root.visibleMetrics.length === 0 && root.status !== "error"
            text: root.status === "loading" ? i18n("Loading…")
                : root.status === "ok" ? i18n("Enable a metric in the widget settings")
                : i18n("No data yet")
        }

        Item { Layout.fillHeight: true }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            opacity: 0.6
            font: Kirigami.Theme.smallFont
            visible: root.lastUpdatedMs > 0
            text: i18n("Updated at %1", Qt.formatTime(root.lastUpdated, "hh:mm:ss"))
        }
    }
}
