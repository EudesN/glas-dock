/*
 * Glasbattery — single device battery ring (circular gauge, centered device
 * icon, optional charging bolt, percentage and optional device name).
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.core as PlasmaCore

Item {
    id: cell

    property var device: null
    property real ringSize: 62
    property bool showDeviceName: false
    property bool useAccentColor: false
    property bool isDark: true
    property color accent: Kirigami.Theme.highlightColor

    readonly property int targetPercent: device ? Math.max(0, Math.min(100, device.percent)) : 0
    property real animatedPercent: targetPercent
    Behavior on animatedPercent {
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }

    readonly property bool charging: device && device.charging === true
    readonly property color ringColor: {
        if (useAccentColor)
            return accent;
        if (targetPercent <= 10 && !charging)
            return "#ff453a";
        if (targetPercent <= 20 && !charging)
            return "#ff9f0a";
        return "#30d158";
    }
    readonly property color fgColor: isDark ? "#f2f2f7" : "#1d1d1f"
    readonly property color trackColor: isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
    readonly property real strokePx: Math.max(4, Math.round(ringSize * 0.115))
    readonly property real radiusPx: Math.max(8, ringSize / 2 - strokePx / 2)

    implicitWidth: Math.max(ringSize + 10, col.implicitWidth)
    implicitHeight: col.implicitHeight

    opacity: 0
    scale: 0.92
    Component.onCompleted: {
        opacity = 1;
        scale = 1;
    }
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    ColumnLayout {
        id: col
        anchors.centerIn: parent
        spacing: Math.max(4, Math.round(cell.ringSize * 0.10))

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: cell.ringSize
            Layout.preferredHeight: cell.ringSize

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: hoverArea.containsMouse
                    ? (cell.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05))
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: cell.strokePx
                    strokeColor: cell.trackColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: cell.ringSize / 2
                        centerY: cell.ringSize / 2
                        radiusX: cell.radiusPx
                        radiusY: cell.radiusPx
                        startAngle: -90
                        sweepAngle: 360
                    }
                }

                ShapePath {
                    strokeWidth: cell.strokePx
                    strokeColor: cell.ringColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: cell.ringSize / 2
                        centerY: cell.ringSize / 2
                        radiusX: cell.radiusPx
                        radiusY: cell.radiusPx
                        startAngle: -90
                        sweepAngle: (cell.animatedPercent / 100) * 360
                    }
                }
            }

            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(cell.ringSize * 0.42)
                height: width
                source: cell.device ? cell.device.iconSource : ""
                isMask: true
                color: cell.fgColor
                opacity: 0.86
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 2

            Kirigami.Icon {
                visible: cell.charging
                Layout.preferredWidth: Math.max(10, Math.round(pctLabel.font.pixelSize * 0.85))
                Layout.preferredHeight: Layout.preferredWidth
                source: Qt.resolvedUrl("icons/bolt.svg")
                isMask: true
                color: cell.fgColor
            }

            PC3.Label {
                id: pctLabel
                text: cell.targetPercent + " %"
                color: cell.fgColor
                font.pixelSize: Math.max(11, Math.round(cell.ringSize * 0.21))
                font.weight: Font.Medium
                font.features: { "tnum": 1 }
            }
        }

        PC3.Label {
            visible: cell.showDeviceName
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: cell.ringSize + 18
            text: cell.device ? cell.device.name : ""
            color: cell.fgColor
            font: Kirigami.Theme.smallFont
            opacity: 0.72
            elide: Text.ElideRight
        }
    }

    PlasmaCore.ToolTipArea {
        id: hoverArea
        anchors.fill: parent
        mainText: cell.device ? cell.device.name : ""
        subText: {
            if (!cell.device)
                return "";
            let text = cell.targetPercent + "%" + (cell.charging ? " · Charging" : "");
            const ms = cell.device.remainingMsec || 0;
            if (ms > 60000) {
                const mins = Math.round(ms / 60000);
                const h = Math.floor(mins / 60);
                const m = mins % 60;
                text += (h > 0 ? " · " + h + "h " + m + "m" : " · " + m + "m");
            }
            return text;
        }
    }
}
