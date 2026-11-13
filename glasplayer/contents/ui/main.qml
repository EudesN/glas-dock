/*
 * Glasplayer — media player for a Plasma panel (Glasdock project).
 * Cover, title/artist and play/pause in the panel; click for the glass panel
 * with progress and controls. The title only scrolls on hover.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.mpris as Mpris
import "shared" as Shared

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    Shared.MprisSource { id: mpris }
    readonly property var player: mpris.player
    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property bool idle: !hasPlayer || player.playbackStatus === Mpris.PlaybackStatus.Stopped
    // while the panel is being edited the widget is always shown, so it can be
    // found, moved and configured even with "hide when idle" on
    readonly property bool editing: Plasmoid.containment && Plasmoid.containment.corona
                                    ? Plasmoid.containment.corona.editMode === true : false
    readonly property bool hidden: idle && cfg.hideWhenIdle && !editing

    // on dark themes, dark accent colors are lifted a bit (same rule as the dock)
    readonly property bool isDark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    readonly property color accent: isDark
        && Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.highlightColor) === Kirigami.ColorUtils.Dark
        ? Qt.lighter(Kirigami.Theme.highlightColor, 1.5) : Kirigami.Theme.highlightColor

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: hidden ? PlasmaCore.Types.PassiveStatus : PlasmaCore.Types.ActiveStatus
    toolTipMainText: hasPlayer ? (player.track || player.identity) : "Nothing playing"
    toolTipSubText: hasPlayer ? (player.artist || "") : ""

    fullRepresentation: Item {
        id: compact

        readonly property bool collapsed: root.hidden
        readonly property real pad: Math.round(height * 0.12)

        // (+ a few px so sub-pixel rounding doesn't elide text that fits)
        Layout.preferredWidth: collapsed ? 0 : Math.min(root.cfg.maxWidth,
            Math.ceil(row.implicitWidth) + row.anchors.leftMargin + row.anchors.rightMargin + 4)
        Layout.minimumWidth: Layout.preferredWidth
        Layout.maximumWidth: Layout.preferredWidth
        Layout.fillHeight: true
        visible: !collapsed

        // optional glass pill behind the widget
        Rectangle {
            visible: root.cfg.pillBackground
            anchors.fill: parent
            anchors.topMargin: compact.pad / 2
            anchors.bottomMargin: compact.pad / 2
            radius: height / 2
            color: root.isDark ? Qt.rgba(1, 1, 1, hover.hovered ? 0.14 : 0.08)
                               : Qt.rgba(1, 1, 1, hover.hovered ? 0.6 : 0.4)
            border.width: 1
            border.color: popup.visible && !popup.closing
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                : Qt.rgba(1, 1, 1, root.isDark ? 0.10 : 0.45)
        }

        HoverHandler { id: hover }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton && root.hasPlayer)
                    root.player.PlayPause();
                else
                    popup.toggle();
            }
            onWheel: wheel => {
                // scroll to skip tracks
                if (!root.hasPlayer)
                    return;
                if (wheel.angleDelta.y > 0 && root.player.canGoPrevious) root.player.Previous();
                else if (wheel.angleDelta.y < 0 && root.player.canGoNext) root.player.Next();
            }
        }

        RowLayout {
            id: row
            anchors.fill: parent
            anchors.leftMargin: compact.pad * (root.cfg.pillBackground ? 2 : 1)
            anchors.rightMargin: compact.pad * (root.cfg.pillBackground ? 2 : 1)
            spacing: Math.round(compact.height * 0.22)

            Shared.Cover {
                Layout.preferredWidth: compact.height - compact.pad * 2
                Layout.preferredHeight: compact.height - compact.pad * 2
                player: root.player
            }

            Shared.MarqueeText {
                opacity: root.hasPlayer ? 1 : 0.6
                Layout.fillWidth: true
                Layout.preferredWidth: implicitWidth
                Layout.fillHeight: true
                scrolling: hover.hovered
                text: !root.hasPlayer ? "Nothing playing"
                    : (root.player.track || root.player.identity)
                      + (root.cfg.showArtist && root.player.artist ? "  ·  " + root.player.artist : "")
            }

            Repeater {
                model: root.cfg.showSkipButtons && root.hasPlayer
                       ? ["media-skip-backward", "PLAY", "media-skip-forward"] : (root.hasPlayer ? ["PLAY"] : [])
                delegate: Item {
                    required property string modelData
                    readonly property bool isPlay: modelData === "PLAY"
                    Layout.preferredWidth: compact.height * 0.62
                    Layout.preferredHeight: compact.height * 0.62
                    Kirigami.Icon {
                        anchors.fill: parent
                        source: parent.isPlay ? (root.playing ? "media-playback-pause" : "media-playback-start")
                                              : parent.modelData
                        opacity: btn.containsMouse ? 1 : 0.8
                    }
                    MouseArea {
                        id: btn
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (parent.isPlay) root.player.PlayPause();
                            else if (parent.modelData === "media-skip-backward") root.player.Previous();
                            else root.player.Next();
                        }
                    }
                }
            }
        }

        Shared.GlassPopup {
            id: popup
            anchorItem: compact
            edge: Plasmoid.location
            style: root.cfg.popupStyle
            backgroundOpacity: root.cfg.popupOpacity
            radius: root.cfg.popupRadius
            isDark: root.isDark
            accent: root.accent
            animated: root.cfg.popupAnimation
            sourceComponent: Shared.PlayerPopup {
                player: root.player
                accent: root.accent
                isDark: root.isDark
            }
        }
    }
}
