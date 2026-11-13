/*
 * Glasdock — single line of text that is elided normally and scrolls only
 * while `scrolling` is true (e.g. on hover), so it costs nothing at rest.
 */
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: marquee

    property string text: ""
    property bool scrolling: false
    property alias font: measure.font
    property color color: Kirigami.Theme.textColor

    readonly property bool overflows: measure.implicitWidth > width
    implicitWidth: measure.implicitWidth
    implicitHeight: measure.implicitHeight
    clip: true

    // at rest: elided label
    PC3.Label {
        anchors.fill: parent
        visible: !moving.visible
        text: marquee.text
        font: measure.font
        color: marquee.color
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }

    // scrolling copy
    Text {
        id: moving
        visible: marquee.scrolling && marquee.overflows
        anchors.verticalCenter: parent.verticalCenter
        text: marquee.text
        font: measure.font
        color: marquee.color
        x: 0
        SequentialAnimation on x {
            running: moving.visible
            loops: Animation.Infinite
            onRunningChanged: if (!running) moving.x = 0
            PauseAnimation { duration: 600 }
            NumberAnimation {
                to: -(measure.implicitWidth - marquee.width)
                duration: Math.max(800, (measure.implicitWidth - marquee.width) * 25)
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 900 }
            NumberAnimation {
                to: 0
                duration: Math.max(800, (measure.implicitWidth - marquee.width) * 25)
                easing.type: Easing.InOutSine
            }
        }
    }

    Text {
        id: measure
        visible: false
        text: marquee.text
        font: Kirigami.Theme.defaultFont   // same font the label draws with
    }
}
