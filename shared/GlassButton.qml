/*
 * Glasdock — round (or pill) glass button used inside the widget panels.
 * "filled" paints it with the accent color (main action).
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Rectangle {
    id: button

    property string iconName: ""
    property string text: ""
    property bool filled: false
    property bool isDark: true
    property color accent: Kirigami.Theme.highlightColor
    property real iconSize: Kirigami.Units.iconSizes.smallMedium

    signal clicked()

    implicitHeight: Math.round(iconSize * 2)
    implicitWidth: text.length > 0 ? row.implicitWidth + implicitHeight : implicitHeight
    radius: height / 2
    opacity: enabled ? 1 : 0.4

    readonly property color fg: filled
        ? (Kirigami.ColorUtils.brightnessForColor(accent) === Kirigami.ColorUtils.Light ? "#1d1d1f" : "white")
        : Kirigami.Theme.textColor

    color: filled ? (area.containsMouse ? Qt.lighter(accent, 1.12) : accent)
        : isDark ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.16 : 0.08)
        : Qt.rgba(1, 1, 1, area.containsMouse ? 0.6 : 0.4)
    border.width: filled ? 0 : 1
    border.color: Qt.rgba(1, 1, 1, isDark ? 0.10 : 0.45)
    Behavior on color { ColorAnimation { duration: 120 } }

    scale: area.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            visible: button.iconName.length > 0
            Layout.preferredWidth: button.iconSize
            Layout.preferredHeight: button.iconSize
            source: button.iconName
            color: button.fg
            isMask: button.filled
        }
        PC3.Label {
            visible: button.text.length > 0
            text: button.text
            color: button.fg
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        enabled: button.enabled
        onClicked: button.clicked()
    }
}
