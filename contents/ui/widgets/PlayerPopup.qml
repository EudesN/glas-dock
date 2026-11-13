/*
 * Glasdock — expanded media player: cover, track info, progress and controls.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.private.mpris as Mpris

Item {
    id: popup

    property var player: null
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing

    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: layout.implicitHeight

    function fmt(us) {
        const s = Math.max(0, Math.floor(us / 1000000));
        const m = Math.floor(s / 60);
        return m + ":" + String(s % 60).padStart(2, "0");
    }

    // MPRIS does not push position updates; poll while visible
    Timer {
        interval: 1000
        repeat: true
        running: popup.visible && popup.playing
        onTriggered: popup.player.updatePosition()
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            spacing: Kirigami.Units.largeSpacing * 1.5

            Cover {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 7
                Layout.preferredHeight: Kirigami.Units.gridUnit * 7
                player: popup.player
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PC3.Label {
                    Layout.fillWidth: true
                    text: popup.hasPlayer ? (popup.player.track || popup.player.identity) : "Nothing playing"
                    font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.35)
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: popup.hasPlayer ? (popup.player.artist || "") : ""
                    opacity: 0.7
                    elide: Text.ElideRight
                }
                PC3.Label {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: popup.hasPlayer ? (popup.player.album || "") : ""
                    opacity: 0.5
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideRight
                }

                // controls
                RowLayout {
                    Layout.topMargin: Kirigami.Units.smallSpacing
                    spacing: Kirigami.Units.largeSpacing
                    enabled: popup.hasPlayer

                    PC3.ToolButton {
                        icon.name: "media-skip-backward"
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        enabled: popup.hasPlayer && popup.player.canGoPrevious
                        onClicked: popup.player.Previous()
                    }
                    PC3.ToolButton {
                        icon.name: popup.playing ? "media-playback-pause" : "media-playback-start"
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        onClicked: popup.player.PlayPause()
                    }
                    PC3.ToolButton {
                        icon.name: "media-skip-forward"
                        icon.width: Kirigami.Units.iconSizes.medium
                        icon.height: Kirigami.Units.iconSizes.medium
                        enabled: popup.hasPlayer && popup.player.canGoNext
                        onClicked: popup.player.Next()
                    }
                }
            }
        }

        // progress
        ColumnLayout {
            Layout.fillWidth: true
            visible: popup.hasPlayer && popup.player.length > 0
            spacing: 2

            PC3.Slider {
                Layout.fillWidth: true
                from: 0
                to: popup.hasPlayer ? popup.player.length : 1
                value: popup.hasPlayer ? popup.player.position : 0
                enabled: popup.hasPlayer && popup.player.canSeek
                onMoved: popup.player.position = value
            }
            RowLayout {
                PC3.Label { text: popup.hasPlayer ? popup.fmt(popup.player.position) : ""; font: Kirigami.Theme.smallFont; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                PC3.Label { text: popup.hasPlayer ? popup.fmt(popup.player.length) : ""; font: Kirigami.Theme.smallFont; opacity: 0.6 }
            }
        }

        PC3.Button {
            Layout.alignment: Qt.AlignRight
            visible: popup.hasPlayer && popup.player.canRaise
            text: popup.hasPlayer ? "Open " + popup.player.identity : ""
            icon.name: popup.hasPlayer ? popup.player.iconName : ""
            onClicked: popup.player.Raise()
        }
    }
}
