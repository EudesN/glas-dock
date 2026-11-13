/*
 * Glasdock — base look of a dock widget tile (rounded, slightly lighter than
 * the bar, highlights on hover).
 */
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: tile

    property bool isDark: true
    readonly property alias hovered: area.containsMouse
    readonly property alias pressed: area.pressed
    default property alias content: inner.data

    signal clicked()

    radius: Math.round(height * 0.24)
    color: isDark ? Qt.rgba(1, 1, 1, hovered ? 0.13 : 0.08)
                  : Qt.rgba(1, 1, 1, hovered ? 0.55 : 0.38)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, isDark ? 0.10 : 0.45)
    Behavior on color { ColorAnimation { duration: 120 } }

    scale: pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: tile.clicked()
    }

    // children go here, above the click area so buttons inside still work
    Item {
        id: inner
        anchors.fill: parent
    }
}
