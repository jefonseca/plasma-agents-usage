import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_showTitle: showTitle.checked
    property alias cfg_customTitle: customTitle.text
    property string cfg_credentialsSource: "file"
    property alias cfg_credentialsPath: pathField.text
    property alias cfg_credentialsCommand: commandField.text
    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_showFiveHour: fiveHour.checked
    property alias cfg_showSevenDay: sevenDay.checked
    property alias cfg_showSevenDayOpus: opus.checked
    property alias cfg_showSevenDaySonnet: sonnet.checked
    property alias cfg_showExtraUsage: extra.checked
    property alias cfg_autoRefreshToken: autoRefresh.checked
    property alias cfg_warnThreshold: warnSpin.value
    property alias cfg_critThreshold: critSpin.value

    readonly property bool useCommand: cfg_credentialsSource === "command"

    Kirigami.FormLayout {

        QQC2.CheckBox {
            id: showTitle
            Kirigami.FormData.label: i18n("Title:")
            text: i18n("Show the title")
        }
        QQC2.TextField {
            id: customTitle
            Kirigami.FormData.label: i18n("Custom title:")
            enabled: showTitle.checked
            placeholderText: i18n("Claude Usage")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            enabled: showTitle.checked
            text: i18n("Leave empty to use the default title.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.RadioButton {
            id: srcFile
            Kirigami.FormData.label: i18n("Credentials source:")
            text: i18n("Read from a file")
            checked: !page.useCommand
            onToggled: if (checked) page.cfg_credentialsSource = "file"
        }
        QQC2.RadioButton {
            id: srcCommand
            text: i18n("Run a custom command")
            checked: page.useCommand
            onToggled: if (checked) page.cfg_credentialsSource = "command"
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextField {
            id: pathField
            Kirigami.FormData.label: i18n("File path:")
            enabled: !page.useCommand
            placeholderText: "~/.claude/.credentials.json"
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            enabled: !page.useCommand
            text: i18n("Empty = ~/.claude/.credentials.json. A leading ~ or $HOME is expanded.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextField {
            id: commandField
            Kirigami.FormData.label: i18n("Command:")
            enabled: page.useCommand
            placeholderText: "incus exec claude -- cat /home/user/.claude/.credentials.json"
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            enabled: page.useCommand
            text: i18n("Runs with /bin/sh -c on every update, with your user privileges. Its standard output must be the credentials JSON (with the claudeAiOauth key). If the command fails or does not return that JSON, the widget shows a warning.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Update every (seconds):")
            from: 300
            to: 3600
            stepSize: 60
            editable: true
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: fiveHour
            Kirigami.FormData.label: i18n("Metrics to show:")
            text: i18n("Session (5 hours)")
        }
        QQC2.CheckBox {
            id: sevenDay
            text: i18n("Week (7 days)")
        }
        QQC2.CheckBox {
            id: opus
            text: i18n("Week · Opus")
        }
        QQC2.CheckBox {
            id: sonnet
            text: i18n("Week · Sonnet")
        }
        QQC2.CheckBox {
            id: extra
            text: i18n("Extra credits (if enabled)")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: warnSpin
            Kirigami.FormData.label: i18n("Warning threshold (%):")
            from: 1
            to: 100
            editable: true
        }
        QQC2.SpinBox {
            id: critSpin
            Kirigami.FormData.label: i18n("Critical threshold (%):")
            from: 1
            to: 100
            editable: true
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: autoRefresh
            Kirigami.FormData.label: i18n("Token refresh:")
            text: i18n("Automatically refresh the expired OAuth token")
            enabled: !page.useCommand
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            text: page.useCommand
                ? i18n("Not available with a custom command: the widget cannot rewrite an arbitrary source. With an expired token you will see a warning until you refresh your Claude session.")
                : i18n("DISABLED by default. If enabled, the widget periodically sends your refresh_token to platform.claude.com and REWRITES the credentials file (atomic write, permissions 600). It can conflict with Claude Code if both refresh the token, forcing a new sign-in. Enable it only if you understand the implications.")
            color: (!page.useCommand && autoRefresh.checked) ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
            font: Kirigami.Theme.smallFont
            opacity: 0.8
            wrapMode: Text.WordWrap
        }
    }
}
