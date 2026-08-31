import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ------------------------------------------------------------------
    // OAuth constants (same ones Claude Code uses)
    // ------------------------------------------------------------------
    readonly property string clientId: "9d1c250a-e61b-44d9-88ed-5944d1962f5e"
    readonly property string tokenUrl: "https://platform.claude.com/v1/oauth/token"
    readonly property string usageUrl: "https://api.anthropic.com/api/oauth/usage"

    // ------------------------------------------------------------------
    // State
    // ------------------------------------------------------------------
    property var usageData: null
    property var extraUsage: null
    property string subType: ""
    property string status: "init"          // init | loading | ok | error
    property string errorMessage: ""
    property double lastUpdatedMs: 0
    property string homeDir: ""
    property bool credSourceIsFile: true
    property int _seq: 0
    property int _tick: 0                    // forces the countdown texts to recompute

    readonly property date lastUpdated: new Date(lastUpdatedMs)

    // Custom title if set, otherwise the default (localized) name.
    readonly property string effectiveTitle: {
        var t = (plasmoid.configuration.customTitle || "").trim()
        return t.length > 0 ? t : i18n("Claude Usage")
    }

    readonly property string subscriptionLabel: {
        if (subType.length > 0)
            return i18n("Account: %1", subType.charAt(0).toUpperCase() + subType.slice(1))
        if (status === "loading")
            return i18n("Connecting…")
        return ""
    }

    // Metrics already resolved for the view (array of {label, percent, resetText})
    readonly property var visibleMetrics: {
        root._tick // dependency: refresh the countdown every 30 s
        var data = usageData
        var out = []
        if (!data)
            return out
        var defs = [
            { key: "five_hour",        on: plasmoid.configuration.showFiveHour,       label: i18n("Session (5 hours)") },
            { key: "seven_day",        on: plasmoid.configuration.showSevenDay,       label: i18n("Week (7 days)") },
            { key: "seven_day_opus",   on: plasmoid.configuration.showSevenDayOpus,   label: i18n("Week · Opus") },
            { key: "seven_day_sonnet", on: plasmoid.configuration.showSevenDaySonnet, label: i18n("Week · Sonnet") }
        ]
        for (var i = 0; i < defs.length; ++i) {
            if (!defs[i].on)
                continue
            var m = data[defs[i].key]
            if (!m)
                continue
            out.push({
                label: defs[i].label,
                percent: m.utilization || 0,
                resetText: root.formatReset(m.resets_at)
            })
        }
        return out
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function shq(s) {
        // Safe single-quoting for POSIX sh
        return "'" + String(s).replace(/'/g, "'\\''") + "'"
    }

    function resolvedCredPath() {
        var p = plasmoid.configuration.credentialsPath
        if (!p || p.length === 0)
            return root.homeDir + "/.claude/.credentials.json"
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
            var src = cmd + " #" + (++root._seq)   // unique source per invocation
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
        loadCredentials()
    }

    // Obtains the credentials according to the chosen mode: file OR custom command.
    function loadCredentials() {
        var mode = plasmoid.configuration.credentialsSource
        if (mode === "command") {
            var cmd = (plasmoid.configuration.credentialsCommand || "").trim()
            if (cmd.length === 0) {
                root.fail(i18n("No command configured to obtain the credentials."))
                return
            }
            root.credSourceIsFile = false
            sh.run(cmd, function (out, err, code) {
                if (code !== 0) {
                    root.fail(i18n("The credentials command failed (exit code %1). %2",
                                   code, err.split("\n")[0]))
                    return
                }
                onCredentialsText(out, i18n("The command did not return valid credentials JSON."))
            })
        } else {
            var path = resolvedCredPath()
            root.credSourceIsFile = true
            sh.run("cat " + shq(path), function (out, err, code) {
                if (code !== 0 || out.length === 0) {
                    root.fail(i18n("Could not read %1", path))
                    return
                }
                onCredentialsText(out, i18n("The credentials file does not contain valid JSON."))
            })
        }
    }

    function onCredentialsText(out, parseErrMsg) {
        var full
        try {
            full = JSON.parse(out)
        } catch (e) {
            root.fail(parseErrMsg)
            return
        }
        var creds = full && full.claudeAiOauth
        if (!creds || !creds.accessToken) {
            root.fail(i18n("No accessToken found in the obtained credentials."))
            return
        }
        root.subType = creds.subscriptionType || ""

        var expired = creds.expiresAt && (creds.expiresAt - 60000) < Date.now()
        if (!expired) {
            fetchUsage(creds.accessToken)
            return
        }
        // Token expired. Automatic refresh only happens when the user has
        // explicitly enabled it AND the credentials come from a writable file.
        if (plasmoid.configuration.autoRefreshToken && root.credSourceIsFile && creds.refreshToken) {
            refreshToken(full)
        } else {
            root.fail(i18n("Token expired. Refresh your Claude session (open Claude Code or re-run your command) and the widget will pick it up on the next cycle."))
        }
    }

    function refreshToken(full) {
        var creds = full.claudeAiOauth
        var body = JSON.stringify({
            grant_type: "refresh_token",
            refresh_token: creds.refreshToken,
            client_id: root.clientId,
            scope: (creds.scopes || []).join(" ")
        })
        var cmd = "curl -sS -m 30 -X POST " + shq(root.tokenUrl)
                + " -H 'Content-Type: application/json'"
                + " -H 'User-Agent: claude-usage-widget/1.0'"
                + " --data-raw " + shq(body)
                + " -w '\\n%{http_code}'"
        sh.run(cmd, function (out, err, code) {
            if (code !== 0) {
                root.fail(i18n("Could not reach the OAuth server: %1", err))
                return
            }
            var nl = out.lastIndexOf("\n")
            var http = out.substring(nl + 1).trim()
            var payload = out.substring(0, nl)
            if (http !== "200") {
                root.fail(i18n("Token refresh failed (HTTP %1)", http))
                return
            }
            var tok
            try {
                tok = JSON.parse(payload)
            } catch (e) {
                root.fail(i18n("Invalid token refresh response"))
                return
            }
            // Keep any unknown field present in the original file.
            creds.accessToken = tok.access_token
            creds.refreshToken = tok.refresh_token || creds.refreshToken
            creds.expiresAt = Date.now() + ((tok.expires_in || 3600) * 1000)
            if (tok.scope)
                creds.scopes = tok.scope.split(" ")
            if (tok.subscription_type)
                creds.subscriptionType = tok.subscription_type

            writeCredentials(full, function () {
                root.subType = creds.subscriptionType || ""
                fetchUsage(creds.accessToken)
            })
        })
    }

    function writeCredentials(obj, done) {
        var path = resolvedCredPath()
        var tmp = path + ".widget-tmp"
        var b64 = Qt.btoa(JSON.stringify(obj, null, 2))
        var cmd = "printf %s " + shq(b64) + " | base64 -d > " + shq(tmp)
                + " && chmod 600 " + shq(tmp)
                + " && mv -f " + shq(tmp) + " " + shq(path)
        sh.run(cmd, function (out, err, code) {
            if (code !== 0) {
                root.fail(i18n("Could not write the refreshed token to %1. The widget needs write access for automatic refresh.", path))
                return
            }
            done()
        })
    }

    function fetchUsage(token) {
        var cmd = "curl -sS -m 20 " + shq(root.usageUrl)
                + " -H " + shq("Authorization: Bearer " + token)
                + " -H 'Content-Type: application/json'"
                + " -H 'anthropic-beta: oauth-2025-04-20'"
                + " -H 'anthropic-version: 2023-06-01'"
                + " -H 'User-Agent: claude-usage-widget/1.0'"
                + " -w '\\n%{http_code}'"
        sh.run(cmd, function (out, err, code) {
            if (code !== 0) {
                root.fail(i18n("Network error while fetching usage: %1", err))
                return
            }
            var nl = out.lastIndexOf("\n")
            var http = out.substring(nl + 1).trim()
            var payload = out.substring(0, nl)
            if (http === "401") {
                root.fail(i18n("Unauthorized (401). The token is not valid; open Claude Code to sign in."))
                return
            }
            if (http !== "200") {
                root.fail(i18n("The usage server responded HTTP %1", http))
                return
            }
            var parsed
            try {
                parsed = JSON.parse(payload)
            } catch (e) {
                root.fail(i18n("Invalid usage response"))
                return
            }
            root.usageData = parsed
            root.extraUsage = parsed.extra_usage || null
            root.status = "ok"
            root.errorMessage = ""
            root.lastUpdatedMs = Date.now()
        })
    }

    // ------------------------------------------------------------------
    // Startup and timers
    // ------------------------------------------------------------------
    Component.onCompleted: {
        sh.run("printf %s \"$HOME\"", function (out) {
            root.homeDir = out.trim() || "/root"
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
        // Keeps the "resets in …" texts up to date
        interval: 30000
        repeat: true
        running: true
        onTriggered: root._tick++
    }

    Connections {
        target: plasmoid.configuration
        function onCredentialsSourceChanged() { root.refresh() }
        function onCredentialsPathChanged() { root.refresh() }
        function onCredentialsCommandChanged() { root.refresh() }
        function onAutoRefreshTokenChanged() { root.refresh() }
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
        if (root.usageData.five_hour)
            parts.push(i18n("5h: %1%", Math.round(root.usageData.five_hour.utilization)))
        if (root.usageData.seven_day)
            parts.push(i18n("7d: %1%", Math.round(root.usageData.seven_day.utilization)))
        return parts.join("    ")
    }

    // ------------------------------------------------------------------
    // Compact representation (when placed in a panel)
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
                    var a = root.usageData.five_hour ? Math.round(root.usageData.five_hour.utilization) + "%" : "—"
                    var b = root.usageData.seven_day ? Math.round(root.usageData.seven_day.utilization) + "%" : "—"
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
                    text: root.subscriptionLabel
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
                warnThreshold: plasmoid.configuration.warnThreshold
                critThreshold: plasmoid.configuration.critThreshold
            }
        }

        UsageBar {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            visible: plasmoid.configuration.showExtraUsage
                     && root.extraUsage && root.extraUsage.is_enabled === true
            label: i18n("Extra credits")
            percent: (root.extraUsage && root.extraUsage.utilization) ? root.extraUsage.utilization : 0
            resetText: ""
            warnThreshold: plasmoid.configuration.warnThreshold
            critThreshold: plasmoid.configuration.critThreshold
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
