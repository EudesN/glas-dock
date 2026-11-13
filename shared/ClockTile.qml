/*
 * Glasdock — clock tile: time and date.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Tile {
    id: tile

    property date now: new Date()

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 0
        PC3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatTime(tile.now, Qt.locale().timeFormat(Locale.ShortFormat))
            font.pixelSize: Math.round(tile.height * 0.36)
            font.weight: Font.DemiBold
        }
        PC3.Label {
            Layout.alignment: Qt.AlignHCenter
            text: tile.now.toLocaleDateString(Qt.locale(), "ddd, d MMM")
            font: Kirigami.Theme.smallFont
            opacity: 0.6
        }
    }
}
