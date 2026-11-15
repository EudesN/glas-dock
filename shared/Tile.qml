/*
 * Glasdock — base look of a dock widget tile (rounded, slightly lighter than
 * the bar, highlights on hover).
 */
import QtQuick
import org.kde.kirigami as Kirigami

Rectangle {
    id: tile

    property bool isDark: true
    property bool active: false   // its panel is open
    readonly property alias hovered: area.containsMouse
    readonly property alias pressed: area.pressed
    default property alias content: inner.data

    signal clicked()
    signal middleClicked()

    radius: Math.round(height * 0.24)
    color: isDark ? Qt.rgba(1, 1, 1, active ? 0.18 : hovered ? 0.13 : 0.08)
                  : Qt.rgba(1, 1, 1, active ? 0.72 : hovered ? 0.58 : 0.40)
    border.width: 1
    border.color: active ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g,
                                   Kirigami.Theme.highlightColor.b, 0.65)
                         : Qt.rgba(1, 1, 1, isDark ? (hovered ? 0.18 : 0.11) : 0.48)
    Behavior on border.color { ColorAnimation { duration: 120 } }
    Behavior on color { ColorAnimation { duration: 120 } }

    // subtle top sheen on the tile capsule
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - parent.radius * 1.6)
        height: 1
        color: Qt.rgba(1, 1, 1, tile.isDark ? 0.20 : 0.55)
    }

    scale: pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => mouse.button === Qt.MiddleButton ? tile.middleClicked() : tile.clicked()
    }

    // children go here, above the click area so buttons inside still work
    Item {
        id: inner
        anchors.fill: parent
    }
}
