/*
 * Glasdock — expanded clock: large time with seconds, full date and how much
 * of the day has passed.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: popup

    property date now: new Date()
    readonly property real dayProgress: (now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()) / 86400
    readonly property var startOfYear: new Date(now.getFullYear(), 0, 1)
    readonly property int dayOfYear: Math.floor((now - startOfYear) / 86400000) + 1

    implicitWidth: Kirigami.Units.gridUnit * 20
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                text: Qt.formatTime(popup.now, Qt.locale().timeFormat(Locale.ShortFormat))
                font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 3.4)
                font.weight: Font.DemiBold
            }
            PC3.Label {
                Layout.alignment: Qt.AlignBottom
                Layout.bottomMargin: Kirigami.Units.smallSpacing * 2
                text: ":" + String(popup.now.getSeconds()).padStart(2, "0")
                opacity: 0.5
                font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.3)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            PC3.Label {
                text: popup.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                opacity: 0.7
            }
            Item { Layout.fillWidth: true }
            PC3.Label {
                text: Math.round(popup.dayProgress * 100) + "% of the day"
                opacity: 0.5
                font: Kirigami.Theme.smallFont
            }
        }

        // day progress
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Kirigami.Units.smallSpacing
            height: 4
            radius: 2
            color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
            Rectangle {
                width: parent.width * popup.dayProgress
                height: parent.height
                radius: 2
                color: Kirigami.Theme.highlightColor
            }
        }

        PC3.Label {
            Layout.topMargin: Kirigami.Units.smallSpacing
            text: "Day " + popup.dayOfYear + " of the year"
            font: Kirigami.Theme.smallFont
            opacity: 0.5
        }
    }
}
