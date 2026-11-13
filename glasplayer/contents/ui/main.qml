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

            // (the cover is only shown in the glass panel)
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

            // controls: previous / play-pause / next
            Row {
                visible: root.hasPlayer
                spacing: 0
                Layout.alignment: Qt.AlignVCenter

                Repeater {
                    model: root.cfg.showSkipButtons ? ["prev", "play", "next"] : ["play"]
                    delegate: Item {
                        id: ctl
                        required property string modelData
                        readonly property bool enabledNow: !root.hasPlayer ? false
                            : modelData === "prev" ? root.player.canGoPrevious
                            : modelData === "next" ? root.player.canGoNext
                            : (root.player.canPlay || root.player.canPause)
                        width: Math.round(compact.height * 0.9)
                        height: width

                        // round hover highlight
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            color: Kirigami.Theme.textColor
                            opacity: ctlArea.pressed ? 0.18 : ctlArea.containsMouse && ctl.enabledNow ? 0.10 : 0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }
                        Kirigami.Icon {
                            anchors.centerIn: parent
                            width: Math.round(compact.height * (ctl.modelData === "play" ? 0.66 : 0.56))
                            height: width
                            source: ctl.modelData === "prev" ? "media-skip-backward"
                                  : ctl.modelData === "next" ? "media-skip-forward"
                                  : root.playing ? "media-playback-pause" : "media-playback-start"
                            opacity: ctl.enabledNow ? (ctlArea.containsMouse ? 1 : 0.85) : 0.3
                        }
                        MouseArea {
                            id: ctlArea
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: ctl.enabledNow
                            onClicked: {
                                if (ctl.modelData === "prev") root.player.Previous();
                                else if (ctl.modelData === "next") root.player.Next();
                                else root.player.PlayPause();
                            }
                        }
                    }
                }
            }
        }

        Shared.GlassPopup {
            id: popup
            anchorItem: compact
            edge: Plasmoid.location
            gap: root.cfg.popupGap
            screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
            style: root.cfg.popupStyle
            backgroundOpacity: root.cfg.popupOpacity
            radius: root.cfg.popupRadius
            isDark: root.isDark
            accent: root.accent
            animated: root.cfg.popupAnimation
            blurBehind: root.cfg.popupBlur || root.cfg.popupStyle === 4
            frost: root.cfg.popupFrost
            sourceComponent: Shared.PlayerPopup {
                player: root.player
                accent: root.accent
                isDark: root.isDark
            }
        }
    }
}
