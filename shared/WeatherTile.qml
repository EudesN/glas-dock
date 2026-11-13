/*
 * Glasdock — weather tile: condition icon, temperature and place.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Tile {
    id: tile

    property var weather: null
    readonly property bool ready: weather !== null && weather.ready

    RowLayout {
        anchors.centerIn: parent
        spacing: Math.round(tile.height * 0.12)

        Kirigami.Icon {
            Layout.preferredWidth: tile.height * 0.6
            Layout.preferredHeight: tile.height * 0.6
            source: tile.ready ? tile.weather.iconFor(tile.weather.current.code, tile.weather.current.isDay)
                               : "weather-none-available"
        }

        ColumnLayout {
            spacing: 0
            PC3.Label {
                text: tile.ready ? tile.weather.current.temp + "°" : "--°"
                font.pixelSize: Math.round(tile.height * 0.36)
                font.weight: Font.DemiBold
            }
            PC3.Label {
                Layout.maximumWidth: tile.width * 0.55
                text: tile.ready ? tile.weather.place
                                 : (tile.weather && tile.weather.error ? tile.weather.error : "Loading…")
                font: Kirigami.Theme.smallFont
                opacity: 0.6
                elide: Text.ElideRight
            }
        }
    }
}
