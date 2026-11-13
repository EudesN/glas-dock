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
    property color accent: Kirigami.Theme.highlightColor
    property bool isDark: true
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property real progress: hasPlayer && player.length > 0 ? Math.min(1, player.position / player.length) : 0

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
                    spacing: Kirigami.Units.mediumSpacing

                    GlassButton {
                        iconName: "media-skip-backward"
                        isDark: popup.isDark
                        enabled: popup.hasPlayer && popup.player.canGoPrevious
                        onClicked: popup.player.Previous()
                    }
                    GlassButton {
                        iconName: popup.playing ? "media-playback-pause" : "media-playback-start"
                        iconSize: Kirigami.Units.iconSizes.medium
                        filled: true
                        accent: popup.accent
                        isDark: popup.isDark
                        enabled: popup.hasPlayer
                        onClicked: popup.player.PlayPause()
                    }
                    GlassButton {
                        iconName: "media-skip-forward"
                        isDark: popup.isDark
                        enabled: popup.hasPlayer && popup.player.canGoNext
                        onClicked: popup.player.Next()
                    }
                }
            }
        }

        // progress: slim track in the accent color, click/drag to seek
        ColumnLayout {
            Layout.fillWidth: true
            visible: popup.hasPlayer && popup.player.length > 0
            spacing: Kirigami.Units.smallSpacing

            Item {
                Layout.fillWidth: true
                implicitHeight: 14

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekArea.containsMouse || seekArea.pressed ? 6 : 4
                    radius: height / 2
                    color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.15)
                    Behavior on height { NumberAnimation { duration: 100 } }

                    Rectangle {
                        width: parent.width * popup.progress
                        height: parent.height
                        radius: parent.radius
                        color: popup.accent
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: popup.hasPlayer && popup.player.canSeek
                    function seek(mx) {
                        popup.player.position = Math.max(0, Math.min(1, mx / width)) * popup.player.length;
                    }
                    onPressed: mouse => seek(mouse.x)
                    onPositionChanged: mouse => { if (pressed) seek(mouse.x); }
                }
            }
            RowLayout {
                PC3.Label { text: popup.hasPlayer ? popup.fmt(popup.player.position) : ""; font: Kirigami.Theme.smallFont; opacity: 0.6 }
                Item { Layout.fillWidth: true }
                PC3.Label { text: popup.hasPlayer ? popup.fmt(popup.player.length) : ""; font: Kirigami.Theme.smallFont; opacity: 0.6 }
            }
        }

        GlassButton {
            Layout.alignment: Qt.AlignRight
            visible: popup.hasPlayer && popup.player.canRaise
            iconName: popup.hasPlayer ? popup.player.iconName : ""
            text: popup.hasPlayer ? "Open " + popup.player.identity : ""
            iconSize: Kirigami.Units.iconSizes.small
            isDark: popup.isDark
            onClicked: popup.player.Raise()
        }
    }
}
