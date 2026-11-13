/*
 * Glasdock — glass panel that opens from a panel widget.
 *
 * Opens below the anchor when the panel is at the top of the screen and above
 * it when the panel is at the bottom, centered on the anchor and kept on
 * screen. Same glass, open/close animation and click-outside behaviour as the
 * dock's panels. The content (sourceComponent) only exists while it is open.
 */
import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmaCore.Dialog {
    id: popup

    property Item anchorItem: null
    property int edge: PlasmaCore.Types.TopEdge   // screen edge of the panel
    property int gap: 2
    // global geometry of the screen the panel is on (Plasmoid.containment.screenGeometry);
    // used to keep the panel fully on screen when the widget sits near an edge
    property rect screenGeometry: Qt.rect(0, 0, 0, 0)
    property alias sourceComponent: loader.sourceComponent
    readonly property Item loadedItem: loader.item

    // look
    property int style: 0
    property real backgroundOpacity: 0.8
    property real radius: 22
    property bool isDark: true
    property color accent: Kirigami.Theme.highlightColor
    property bool animated: true
    property int animationDuration: 220

    readonly property bool closing: closeAnim.running
    property bool blurBehind: false     // real blur behind the glass (plugin)
    property real frost: 0
    property double hiddenAt: 0
    readonly property bool fromTop: edge !== PlasmaCore.Types.BottomEdge

    type: PlasmaCore.Dialog.AppletPopup
    flags: Qt.WindowStaysOnTopHint
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    hideOnWindowDeactivate: !animated
    visible: false

    function toggle() {
        // a click on the widget first deactivates the panel (which starts closing it)
        if (closing || Date.now() - hiddenAt < 250)
            return;
        if (visible) {
            close();
            return;
        }
        visible = true;
        reposition();
        requestActivate();
    }

    function close() {
        if (closeAnim.running || !visible)
            return;
        openAnim.stop();
        if (!frame.animatedNow) {
            visible = false;
            return;
        }
        closeAnim.restart();
    }

    onActiveChanged: if (!active && visible) close()
    onVisibleChanged: {
        if (visible) {
            frame.playOpen();
        } else {
            hiddenAt = Date.now();
        }
    }
    onWidthChanged: if (visible) reposition()
    onHeightChanged: if (visible) reposition()

    function reposition() {
        if (!anchorItem)
            return;
        const p = anchorItem.mapToGlobal(0, 0);
        const w = frame.width, h = frame.height;
        const m = frame.shadowMargin;
        let nx = Math.round(p.x + anchorItem.width / 2 - w / 2);
        const g = screenGeometry;
        if (g.width > 0) {
            // the frame has a transparent shadow margin m on each side
            const margin = Kirigami.Units.smallSpacing * 2;
            const left = g.x + margin - m, right = g.x + g.width - margin + m;
            nx = Math.max(left, Math.min(right - w, nx));
        }
        x = nx;
        y = fromTop ? Math.round(p.y + anchorItem.height + gap - m)
                    : Math.round(p.y - gap - h + m);
    }

    mainItem: Item {
        id: frame
        readonly property int shadowMargin: 28
        readonly property int padding: Kirigami.Units.gridUnit
        readonly property int dur: Math.round(popup.animationDuration * Kirigami.Units.longDuration / 200)
        readonly property bool animatedNow: popup.animated && dur >= 10
        property real reveal: 1

        width: Math.max(1, loader.width) + (padding + shadowMargin) * 2
        height: Math.max(1, loader.height) + (padding + shadowMargin) * 2

        function playOpen() {
            closeAnim.stop();
            if (!animatedNow) {
                panel.opacity = 1; panel.scale = 1; shift.y = 0; reveal = 1;
                return;
            }
            panel.opacity = 0; panel.scale = 0.92;
            shift.y = popup.fromTop ? -14 : 14;
            reveal = 0;
            openAnim.restart();
        }

        // (animations live here: a Dialog takes any direct child as its mainItem)
        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: panel; property: "opacity"; to: 1; duration: frame.dur * 0.8; easing.type: Easing.OutCubic }
            NumberAnimation { target: panel; property: "scale"; to: 1; duration: frame.dur; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
            NumberAnimation { target: shift; property: "y"; to: 0; duration: frame.dur; easing.type: Easing.OutQuint }
            SequentialAnimation {
                PauseAnimation { duration: frame.dur * 0.3 }
                NumberAnimation { target: frame; property: "reveal"; to: 1; duration: frame.dur; easing.type: Easing.OutCubic }
            }
        }

        SequentialAnimation {
            id: closeAnim
            ParallelAnimation {
                NumberAnimation { target: panel; property: "opacity"; to: 0; duration: frame.dur * 0.55; easing.type: Easing.InCubic }
                NumberAnimation { target: panel; property: "scale"; to: 0.95; duration: frame.dur * 0.55; easing.type: Easing.InCubic }
                NumberAnimation { target: shift; property: "y"; to: popup.fromTop ? -8 : 8; duration: frame.dur * 0.55; easing.type: Easing.InCubic }
            }
            ScriptAction { script: popup.visible = false }
        }

        Item {
            id: panel
            anchors.fill: parent
            anchors.margins: frame.shadowMargin
            // grows out of the panel the widget sits on
            transformOrigin: popup.fromTop ? Item.Top : Item.Bottom
            transform: Translate { id: shift }

            GlassSurface {
                anchors.fill: parent
                style: popup.style
                backgroundOpacity: popup.backgroundOpacity
                radius: popup.radius
                isDark: popup.isDark
                accent: popup.accent
                forceBody: true
                blurBehind: popup.blurBehind
                frost: popup.frost
            }

            Loader {
                id: loader
                x: frame.padding
                y: frame.padding
                active: popup.visible
                width: item ? item.implicitWidth : 0
                height: item ? item.implicitHeight : 0
                focus: true
                Keys.onEscapePressed: popup.close()
                opacity: frame.reveal
                transform: Translate { y: (1 - frame.reveal) * (popup.fromTop ? -8 : 8) }
            }
        }
    }
}
