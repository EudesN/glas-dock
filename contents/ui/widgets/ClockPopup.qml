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
    property color accent: Kirigami.Theme.highlightColor
    property bool isDark: true
    readonly property real dayProgress: (now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()) / 86400
    readonly property var startOfYear: new Date(now.getFullYear(), 0, 1)
    readonly property int dayOfYear: Math.floor((now - startOfYear) / 86400000) + 1
    // ISO 8601 week number
    readonly property int weekNumber: {
        const d = new Date(Date.UTC(now.getFullYear(), now.getMonth(), now.getDate()));
        const day = d.getUTCDay() || 7;
        d.setUTCDate(d.getUTCDate() + 4 - day);
        const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
        return Math.ceil(((d - yearStart) / 86400000 + 1) / 7);
    }

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
                color: popup.accent
            }
        }

        // glass chips
        RowLayout {
            Layout.topMargin: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: [
                    "Day " + popup.dayOfYear,
                    "Week " + popup.weekNumber,
                    Qt.formatDate(popup.now, "yyyy")
                ]
                delegate: Rectangle {
                    required property string modelData
                    implicitWidth: chip.implicitWidth + Kirigami.Units.largeSpacing * 2
                    implicitHeight: chip.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: height / 2
                    color: popup.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.4)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, popup.isDark ? 0.10 : 0.45)
                    PC3.Label { id: chip; anchors.centerIn: parent; text: modelData; font: Kirigami.Theme.smallFont }
                }
            }
        }
    }
}
