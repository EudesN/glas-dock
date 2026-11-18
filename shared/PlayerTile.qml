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
    accessibleName: tile.hasPlayer
        ? ((tile.player.track || tile.player.identity) + (tile.player.artist ? " — " + tile.player.artist : ""))
        : i18n("Media player")

    onMiddleClicked: if (hasPlayer) player.playPause()

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
                text: tile.hasPlayer ? (tile.player.track || tile.player.identity) : ""
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
            Layout.preferredWidth: Math.round(tile.height * 0.62)
            Layout.preferredHeight: Layout.preferredWidth
            visible: tile.hasPlayer
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Kirigami.Theme.textColor
                opacity: playArea.pressed ? 0.18 : playArea.containsMouse ? 0.10 : 0
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }
            Kirigami.Icon {
                anchors.centerIn: parent
                width: Math.round(tile.height * 0.46)
                height: width
                source: tile.playing ? "media-playback-pause" : "media-playback-start"
                opacity: playArea.containsMouse ? 1 : 0.85
            }
            MouseArea {
                id: playArea
                anchors.fill: parent
                anchors.margins: -2
                hoverEnabled: true
                onClicked: tile.player.playPause()
            }
        }
    }

    WheelSkipper { id: wheelSkipper; player: tile.hasPlayer ? tile.player : null }
    WheelHandler {
        onWheel: event => wheelSkipper.handle(event.angleDelta.y)
    }
}
