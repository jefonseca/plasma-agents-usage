import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: bar

    property string label: ""
    property real percent: 0
    property string resetText: ""
    property int warnThreshold: 75
    property int critThreshold: 90

    // Bar fill: theme highlight normally, semantic theme roles past the thresholds.
    readonly property color fillColor:
        percent >= critThreshold ? Kirigami.Theme.negativeTextColor :
        percent >= warnThreshold ? Kirigami.Theme.neutralTextColor :
        Kirigami.Theme.highlightColor

    spacing: Kirigami.Units.smallSpacing

    RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: bar.label
            elide: Text.ElideRight
        }
        PlasmaComponents.Label {
            text: Math.round(bar.percent) + "%"
            font.weight: Font.Bold
            color: Kirigami.Theme.textColor
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.round(Kirigami.Units.gridUnit * 0.55)
        radius: height / 2
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Kirigami.Theme.disabledTextColor

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                margins: 1
            }
            width: Math.max(0, Math.min(1, bar.percent / 100)) * (parent.width - 2)
            radius: parent.radius
            color: bar.fillColor

            Behavior on width {
                NumberAnimation { duration: Kirigami.Units.longDuration }
            }
        }
    }

    PlasmaComponents.Label {
        visible: bar.resetText.length > 0
        text: bar.resetText
        opacity: 0.7
        font: Kirigami.Theme.smallFont
    }
}
