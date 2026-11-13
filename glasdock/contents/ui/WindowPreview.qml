/*
 * Glasdock — live window previews shown above a dock icon on hover, like
 * Plasma's task manager (KWin screencast + PipeWire), on the dock's glass.
 * One card per window: title, close button and a live thumbnail; clicking a
 * card activates that window.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.pipewire as PipeWire
import "shared" as Widgets

PlasmaCore.Dialog {
    id: preview

    // [{ uuid, title, icon, row, child }]
    property var windows: []
    property real anchorX: 0          // global x of the icon center
    property real anchorTop: 0        // global y of the top of the dock bar
    property int gap: 10
    property rect screenGeometry: Qt.rect(0, 0, 0, 0)
    property int thumbWidth: 220

    // look (same settings as the dock)
    property int style: 0
    property real backgroundOpacity: 0.8
    property real radius: 22
    property bool isDark: true
    property color accent: Kirigami.Theme.highlightColor
    property real accentTint: 0
    property bool showBorder: true
    property bool showShadow: true

    readonly property bool hovered: frameHover.hovered

    signal activateRequested(int row, int child)
    signal closeRequested(int row, int child)

    type: PlasmaCore.Dialog.Tooltip
    flags: Qt.WindowDoesNotAcceptFocus | Qt.WindowStaysOnTopHint
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: false
    visible: false

    onVisibleChanged: if (visible) frame.fadeIn()
    onWidthChanged: if (visible) reposition()
    onHeightChanged: if (visible) reposition()

    function reposition() {
        const w = frame.width, h = frame.height, m = frame.shadowMargin;
        let nx = Math.round(anchorX - w / 2);
        const g = screenGeometry;
        if (g.width > 0) {
            const margin = Kirigami.Units.smallSpacing * 2;
            nx = Math.max(g.x + margin - m, Math.min(g.x + g.width - margin + m - w, nx));
        }
        x = nx;
        y = Math.round(anchorTop - gap - h + m);
    }

    mainItem: Item {
        id: frame
        readonly property int shadowMargin: 28
        readonly property int padding: Kirigami.Units.largeSpacing
        readonly property int columns: Math.min(Math.max(1, preview.windows.length), 4)

        width: cards.width + (padding + shadowMargin) * 2
        height: cards.height + (padding + shadowMargin) * 2

        function fadeIn() {
            panel.opacity = 0;
            panel.scale = 0.96;
            fade.restart();
        }
        ParallelAnimation {
            id: fade
            NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Kirigami.Units.shortDuration * 1.4; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale"; to: 1; duration: Kirigami.Units.shortDuration * 1.6; easing.type: Easing.OutCubic }
        }

        HoverHandler { id: frameHover }

        Item {
            id: panel
            anchors.fill: parent
            anchors.margins: frame.shadowMargin
            transformOrigin: Item.Bottom

            Widgets.GlassSurface {
                anchors.fill: parent
                style: preview.style
                backgroundOpacity: preview.backgroundOpacity
                radius: preview.radius
                isDark: preview.isDark
                accent: preview.accent
                accentTint: preview.accentTint
                showBorder: preview.showBorder
                showShadow: preview.showShadow
                forceBody: true
            }

            Grid {
                id: cards
                x: frame.padding
                y: frame.padding
                columns: frame.columns
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: preview.windows
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property real thumbHeight: Math.round(preview.thumbWidth * 0.62)

                        width: preview.thumbWidth + Kirigami.Units.smallSpacing * 2
                        height: header.height + thumbHeight + Kirigami.Units.smallSpacing * 3
                        radius: Math.round(preview.radius * 0.6)
                        color: cardArea.containsMouse
                            ? (preview.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.55))
                            : "transparent"
                        border.width: cardArea.containsMouse ? 1 : 0
                        border.color: Qt.rgba(preview.accent.r, preview.accent.g, preview.accent.b, 0.6)
                        Behavior on color { ColorAnimation { duration: 100 } }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton)
                                    preview.closeRequested(card.modelData.row, card.modelData.child);
                                else
                                    preview.activateRequested(card.modelData.row, card.modelData.child);
                            }
                        }

                        // title + close
                        RowLayout {
                            id: header
                            x: Kirigami.Units.smallSpacing
                            y: Kirigami.Units.smallSpacing
                            width: parent.width - Kirigami.Units.smallSpacing * 2
                            height: Kirigami.Units.iconSizes.small + Kirigami.Units.smallSpacing
                            spacing: Kirigami.Units.smallSpacing

                            Kirigami.Icon {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                                source: card.modelData.icon
                            }
                            PC3.Label {
                                Layout.fillWidth: true
                                text: card.modelData.title
                                elide: Text.ElideRight
                                font: Kirigami.Theme.smallFont
                            }
                            Rectangle {
                                Layout.preferredWidth: Kirigami.Units.iconSizes.small + 4
                                Layout.preferredHeight: Kirigami.Units.iconSizes.small + 4
                                radius: width / 2
                                visible: cardArea.containsMouse || closeArea.containsMouse
                                color: closeArea.containsMouse ? "#e5484d" : Qt.rgba(1, 1, 1, 0.12)
                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    width: Kirigami.Units.iconSizes.small - 4
                                    height: width
                                    source: "window-close"
                                }
                                MouseArea {
                                    id: closeArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: preview.closeRequested(card.modelData.row, card.modelData.child)
                                }
                            }
                        }

                        // live thumbnail (falls back to the app icon)
                        Item {
                            id: thumb
                            x: Kirigami.Units.smallSpacing
                            y: header.y + header.height + Kirigami.Units.smallSpacing
                            width: preview.thumbWidth
                            height: card.thumbHeight

                            TaskManager.ScreencastingRequest {
                                id: cast
                                uuid: card.modelData.uuid
                            }

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                width: Kirigami.Units.iconSizes.huge
                                height: width
                                visible: !stream.ready
                                source: card.modelData.icon
                            }

                            PipeWire.PipeWireSourceItem {
                                id: stream
                                anchors.fill: parent
                                // must stay visible to receive frames; transparent until the first one
                                visible: cast.nodeId > 0
                                opacity: ready ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 120 } }
                                nodeId: cast.nodeId
                                objectSerial: cast.objectSerial
                            }
                        }
                    }
                }
            }
        }
    }
}
