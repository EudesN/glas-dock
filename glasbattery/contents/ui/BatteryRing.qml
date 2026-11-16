/*
 * Glasbattery — single device horseshoe battery gauge (arch gauge opening
 * downwards, centered device icon, charging bolt and percentage).
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
    readonly property bool isEmpty: !device || device.empty === true
    property real ringSize: 68
    property bool showDeviceName: false
    property bool showPercentSymbol: false
    property bool useAccentColor: false
    property bool isDark: true
    property color accent: Kirigami.Theme.highlightColor

    readonly property int targetPercent: (!isEmpty && device.percent !== undefined)
        ? Math.max(0, Math.min(100, device.percent)) : 0
    property real animatedPercent: targetPercent
    Behavior on animatedPercent {
        NumberAnimation { duration: 420; easing.type: Easing.OutCubic }
    }

    readonly property bool charging: !isEmpty && device.charging === true
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
    readonly property color trackColor: isDark ? Qt.rgba(1, 1, 1, 0.20) : Qt.rgba(0, 0, 0, 0.14)
    readonly property real strokePx: Math.max(5, Math.round(ringSize * 0.125))
    readonly property real radiusPx: Math.max(8, (ringSize - strokePx) / 2)

    // Horseshoe arc geometry:
    // Sweeps 250° over the top, symmetrical with apex at 270° (top / 12 o'clock).
    // Start at 145° (bottom-left) to 35° (bottom-right).
    // At 50%, sweep is 125°, ending at exactly 270° (12 o'clock), matching reference.
    readonly property real startAngle: 145
    readonly property real totalSweep: 250
    readonly property real sweepAngle: isEmpty ? 0 : Math.max(0.001, (animatedPercent / 100) * totalSweep)

    implicitWidth: Math.max(ringSize, col.implicitWidth)
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
        spacing: Math.max(2, Math.round(cell.ringSize * 0.06))

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: cell.ringSize
            Layout.preferredHeight: cell.ringSize

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: hoverArea.containsMouse && !cell.isEmpty
                    ? (cell.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.05))
                    : "transparent"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                // Background track arc
                ShapePath {
                    strokeWidth: cell.strokePx
                    strokeColor: cell.trackColor
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: cell.ringSize / 2
                        centerY: cell.ringSize * 0.44
                        radiusX: cell.radiusPx
                        radiusY: cell.radiusPx
                        startAngle: cell.startAngle
                        sweepAngle: cell.totalSweep
                    }
                }

                // Active battery progress arc
                ShapePath {
                    strokeWidth: (!cell.isEmpty && cell.animatedPercent > 0) ? cell.strokePx : 0
                    strokeColor: (!cell.isEmpty && cell.animatedPercent > 0) ? cell.ringColor : "transparent"
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: cell.ringSize / 2
                        centerY: cell.ringSize * 0.44
                        radiusX: cell.radiusPx
                        radiusY: cell.radiusPx
                        startAngle: cell.startAngle
                        sweepAngle: cell.sweepAngle
                    }
                }
            }

            // Device icon centered in the upper bowl of the arc
            Kirigami.Icon {
                visible: !cell.isEmpty && cell.device && cell.device.iconSource
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(cell.ringSize * 0.44 - height * 0.5 - cell.ringSize * 0.05)
                width: Math.round(cell.ringSize * 0.35)
                height: width
                source: cell.device ? cell.device.iconSource : ""
                isMask: true
                color: cell.fgColor
                opacity: 0.95
            }

            // Charge bolt and percentage in the bottom opening between the tips
            RowLayout {
                visible: !cell.isEmpty
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.round(cell.ringSize * 0.44 + cell.radiusPx * 0.52)
                spacing: 2

                Kirigami.Icon {
                    visible: cell.charging
                    Layout.preferredWidth: Math.max(9, Math.round(pctLabel.font.pixelSize * 0.80))
                    Layout.preferredHeight: Layout.preferredWidth
                    source: Qt.resolvedUrl("icons/bolt.svg")
                    isMask: true
                    color: cell.fgColor
                }

                PC3.Label {
                    id: pctLabel
                    text: cell.showPercentSymbol ? (cell.targetPercent + "%") : cell.targetPercent
                    color: cell.fgColor
                    font.pixelSize: Math.max(11, Math.round(cell.ringSize * 0.20))
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }
        }

        PC3.Label {
            visible: !cell.isEmpty && cell.showDeviceName
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: cell.ringSize + 18
            text: (!cell.isEmpty && cell.device && cell.device.name) ? cell.device.name : ""
            color: cell.fgColor
            font: Kirigami.Theme.smallFont
            opacity: 0.72
            elide: Text.ElideRight
        }
    }

    PlasmaCore.ToolTipArea {
        id: hoverArea
        anchors.fill: parent
        enabled: !cell.isEmpty
        mainText: (!cell.isEmpty && cell.device && cell.device.name) ? cell.device.name : ""
        subText: {
            if (!cell.device || cell.isEmpty)
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
