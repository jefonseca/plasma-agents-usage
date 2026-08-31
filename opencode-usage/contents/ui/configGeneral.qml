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
    property alias cfg_authPath: pathField.text
    property alias cfg_authCommand: commandField.text
    property alias cfg_providerId: providerField.text
    property alias cfg_apiKey: keyField.text
    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_showRolling: rolling.checked
    property alias cfg_showWeekly: weekly.checked
    property alias cfg_showMonthly: monthly.checked
    property alias cfg_warnThreshold: warnSpin.value
    property alias cfg_critThreshold: critSpin.value

    readonly property bool useFile: cfg_credentialsSource === "file"
    readonly property bool useCommand: cfg_credentialsSource === "command"
    readonly property bool useApiKey: cfg_credentialsSource === "apikey"

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
            placeholderText: i18n("OpenCode Usage")
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
            Kirigami.FormData.label: i18n("API key source:")
            text: i18n("Read from opencode auth.json")
            checked: page.useFile
            onToggled: if (checked) page.cfg_credentialsSource = "file"
        }
        QQC2.RadioButton {
            id: srcCommand
            text: i18n("Run a custom command")
            checked: page.useCommand
            onToggled: if (checked) page.cfg_credentialsSource = "command"
        }
        QQC2.RadioButton {
            id: srcKey
            text: i18n("Enter the key directly")
            checked: page.useApiKey
            onToggled: if (checked) page.cfg_credentialsSource = "apikey"
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.TextField {
            id: pathField
            Kirigami.FormData.label: i18n("auth.json path:")
            enabled: page.useFile
            placeholderText: "~/.local/share/opencode/auth.json"
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            enabled: page.useFile
            text: i18n("Empty = $XDG_DATA_HOME/opencode/auth.json (falls back to ~/.local/share). A leading ~ or $HOME is expanded.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.TextField {
            id: commandField
            Kirigami.FormData.label: i18n("Command:")
            enabled: page.useCommand
            placeholderText: "incus exec dev -- cat /root/.local/share/opencode/auth.json"
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            enabled: page.useCommand
            text: i18n("Runs with /bin/sh -c on every update, with your user privileges. Its output may be the auth.json contents or just the raw API key.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.TextField {
            id: providerField
            Kirigami.FormData.label: i18n("Provider key:")
            enabled: page.useFile || page.useCommand
            placeholderText: "opencode-go"
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            enabled: page.useFile || page.useCommand
            text: i18n("Which entry in auth.json holds the key. If not found, the first \"type\": \"api\" entry is used.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.TextField {
            id: keyField
            Kirigami.FormData.label: i18n("API key:")
            enabled: page.useApiKey
            echoMode: TextInput.PasswordEchoOnEdit
            placeholderText: i18n("paste your OpenCode API key")
            Layout.fillWidth: true
            Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        }
        QQC2.Label {
            Layout.fillWidth: true
            Layout.maximumWidth: Kirigami.Units.gridUnit * 24
            enabled: page.useApiKey
            text: i18n("Stored in plain text in the widget configuration. Prefer reading from auth.json when possible.")
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
            id: rolling
            Kirigami.FormData.label: i18n("Metrics to show:")
            text: i18n("Session (5 hours)")
        }
        QQC2.CheckBox {
            id: weekly
            text: i18n("Week")
        }
        QQC2.CheckBox {
            id: monthly
            text: i18n("Month")
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
    }
}
