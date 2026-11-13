/*
 * Glasdock — media player tile: cover, title/artist and play/pause.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.private.mpris as Mpris

Tile {
    id: tile

    property var player: null
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing

    RowLayout {
        anchors.fill: parent
        anchors.margins: Math.round(tile.height * 0.12)
        spacing: Math.round(tile.height * 0.16)

        Cover {
            Layout.preferredWidth: parent.height
            Layout.preferredHeight: parent.height
            player: tile.player
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            PC3.Label {
                Layout.fillWidth: true
                text: tile.hasPlayer ? (tile.player.track || tile.player.identity) : "Nothing playing"
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            PC3.Label {
                Layout.fillWidth: true
                visible: text.length > 0
                text: tile.hasPlayer ? (tile.player.artist || "") : ""
                opacity: 0.6
                font: Kirigami.Theme.smallFont
                elide: Text.ElideRight
            }
        }

        // play / pause
        Item {
            Layout.preferredWidth: tile.height * 0.5
            Layout.preferredHeight: tile.height * 0.5
            visible: tile.hasPlayer
            Kirigami.Icon {
                anchors.fill: parent
                source: tile.playing ? "media-playback-pause" : "media-playback-start"
                opacity: playArea.containsMouse ? 1 : 0.85
            }
            MouseArea {
                id: playArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                onClicked: tile.player.PlayPause()
            }
        }
    }
}
