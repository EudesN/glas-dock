/*
 * Glasdock — glass panel that opens from a panel widget.
 *
 * Opens below the anchor when the panel is at the top of the screen and above
 * it when the panel is at the bottom, centered on the anchor and kept on
 * screen. Same glass, open/close animation and click-outside behaviour as the
 * dock's panels. The content (sourceComponent) only exists while it is open.
 */
import QtQuick
import QtQuick.Window
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
    property bool preload: false
    property int contentPadding: Kirigami.Units.gridUnit

    // look
    property int style: 0
    property real backgroundOpacity: 0.8
    property real radius: 22
    property int themeMode: 0
    property bool isDark: true
    property color accent: Kirigami.Theme.highlightColor
    property bool animated: true
    property int animationDuration: 220

    readonly property bool closing: closeAnim.running || morphClose.running
    // EXPERIMENTAL: the panel grows out of the widget's own rectangle (and
    // shrinks back into it when closing) instead of fading in next to it
    property bool morph: false
    property int morphDistance: 0
    property bool blurBehind: false     // real blur behind the glass (plugin)
    property real frost: 0
    property double hiddenAt: 0
    property bool _preparing: false
    readonly property bool isSide: edge === PlasmaCore.Types.LeftEdge || edge === PlasmaCore.Types.RightEdge
    readonly property bool fromLeft: edge === PlasmaCore.Types.LeftEdge
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
        if (visible || _preparing) {
            _preparing = false;
            close();
            return;
        }
        _preparing = true;
        frame.prepareClosedState();
        if (loader.status === Loader.Ready && loader.width > 0 && loader.height > 0)
            _completeOpen();
    }

    function _completeOpen() {
        if (!_preparing || visible)
            return;
        if (loader.status !== Loader.Ready || loader.width <= 0 || loader.height <= 0)
            return;
        _preparing = false;
        reposition();
        frame.prepareClosedState();
        visible = true;
        reposition();
        requestActivate();
    }

    function close() {
        _preparing = false;
        if (closeAnim.running || morphClose.running || !visible)
            return;
        openAnim.stop();
        morphOpen.stop();
        if (morph && frame.animatedNow) {
            morphClose.restart();
            return;
        }
        if (!frame.animatedNow) {
            visible = false;
            return;
        }
        closeAnim.restart();
    }

    onActiveChanged: if (!active && visible) close()
    onVisibleChanged: {
        if (visible) {
            _preparing = false;
            frame.playOpen();
        } else {
            hiddenAt = Date.now();
        }
    }
    onWidthChanged: if (visible) reposition()
    onHeightChanged: if (visible) reposition()
    onGapChanged: if (visible) reposition()
    onMorphDistanceChanged: if (visible) reposition()

    function reposition() {
        if (!anchorItem)
            return;
        const p = anchorItem.mapToGlobal(0, 0);
        const m = frame.shadowMargin;
        const innerW = Math.max(1, loader.width) + frame.padding * 2;
        const innerH = Math.max(1, loader.height) + frame.padding * 2;
        const w = innerW + m * 2;
        let topM = m;
        let botM = m;
        let nx = isSide
            ? (fromLeft ? Math.round(p.x + anchorItem.width + gap - m)
                        : Math.round(p.x - gap - innerW - m))
            : Math.round(p.x + anchorItem.width / 2 - w / 2);
        let ny = isSide
            ? Math.round(p.y + anchorItem.height / 2 - (topM + innerH + botM) / 2)
            : (fromTop ? Math.round(p.y + anchorItem.height + gap - m)
                       : Math.round(p.y - gap - innerH - m));
        const g = screenGeometry;
        if (g.width > 0) {
            // the frame has a transparent shadow margin on each side
            const margin = Kirigami.Units.smallSpacing * 2;
            const left = g.x + margin - m, right = g.x + g.width - margin + m;
            nx = Math.max(left, Math.min(right - w, nx));
            // KWin/Wayland keeps Floating dialogs out of panel struts (and screen bounds).
            // Clamp the window to the panel edge and trim the bar-facing shadow margin
            // so small gaps (0..28 px) actually sit right next to the status bar.
            const win = anchorItem.Window ? anchorItem.Window.window : null;
            if (!isSide) {
                const isPanelWin = win && g.height > 0 && win.height > 0 && win.height < g.height * 0.35;
                const minTopY = isPanelWin ? Math.max(g.y, win.y + win.height) : g.y;
                const maxBotY = isPanelWin ? Math.min(g.y + g.height, win.y) : (g.y + g.height);
                if (fromTop && ny < minTopY) {
                    const desiredTop = Math.round(p.y + anchorItem.height + gap);
                    ny = minTopY;
                    topM = Math.max(0, Math.min(m, desiredTop - ny));
                } else if (!fromTop && ny + m + innerH + m > maxBotY) {
                    const desiredBottom = Math.round(p.y - gap);
                    botM = Math.max(0, Math.min(m, Math.round(maxBotY - desiredBottom)));
                    ny = Math.max(g.y, Math.min(maxBotY, desiredBottom) - m - innerH);
                }
            }
            const totalH = topM + innerH + botM;
            ny = Math.max(g.y, Math.min(g.y + g.height - totalH, ny));
        }
        frame.topMargin = topM;
        frame.bottomMargin = botM;
        x = nx;
        y = ny;
        // Widget's horizontal span in window coordinates, clamped to the panel box
        const sw = Math.min(innerW, Math.max(24, anchorItem.width));
        const sx = Math.max(m, Math.min(m + innerW - sw, p.x - nx));
        const sh = Math.min(innerH, Math.max(10, Math.round(anchorItem.height * 0.42)));
        const widgetEdgeY = fromTop ? (p.y + anchorItem.height - ny) : (p.y - ny);
        const syRaw = fromTop ? (widgetEdgeY + morphDistance) : (widgetEdgeY - sh - morphDistance);
        const frameH = innerH + topM + botM;
        const sy = Math.max(2, Math.min(Math.max(2, frameH - sh - 2), syRaw));
        frame.morphStartX = sx;
        frame.morphStartY = sy;
        frame.morphStartW = sw;
    }

    mainItem: Item {
        id: frame
        ThemeScope { target: frame; themeMode: popup.themeMode }
        readonly property int shadowMargin: 28
        property int topMargin: shadowMargin
        property int bottomMargin: shadowMargin
        readonly property int padding: popup.contentPadding
        readonly property int dur: Math.round(popup.animationDuration * Kirigami.Units.longDuration / 200)
        readonly property bool animatedNow: popup.animated && dur >= 10
        property real reveal: 1

        property real morphStartX: shadowMargin
        property real morphStartY: shadowMargin
        property real morphStartW: 60
        readonly property real morphStartH: Math.min(fh, Math.max(10, popup.anchorItem ? Math.round(popup.anchorItem.height * 0.42) : 12))
        property real t: 1        // 0 = widget edge pill, 1 = full panel
        // full panel rectangle
        readonly property real fx: shadowMargin
        readonly property real fy: topMargin
        readonly property real fw: Math.max(1, width - shadowMargin * 2)
        readonly property real fh: Math.max(1, height - topMargin - bottomMargin)

        width: Math.max(1, loader.width) + (padding + shadowMargin) * 2
        height: Math.max(1, loader.height) + padding * 2 + topMargin + bottomMargin

        function prepareClosedState() {
            if (!animatedNow)
                return;
            if (popup.morph) {
                panel.opacity = 0; panel.scale = 1; shift.y = 0;
                reveal = 0;
                t = 0;
            } else {
                t = 1;
                panel.opacity = 0; panel.scale = 0.92;
                shift.y = popup.fromTop ? -14 : 14;
                reveal = 0;
            }
        }

        function playOpen() {
            closeAnim.stop();
            morphClose.stop();
            if (popup.morph && animatedNow) {
                popup.reposition();
                panel.opacity = 0; panel.scale = 1; shift.y = 0;
                reveal = 0;
                t = 0;
                morphOpen.restart();
                return;
            }
            t = 1;
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

        // morph open: the glass emerges from the widget's edge and expands into
        // the full panel while the content reveals cleanly
        ParallelAnimation {
            id: morphOpen
            NumberAnimation { target: panel; property: "opacity"; to: 1; duration: Math.max(25, frame.dur * 0.14); easing.type: Easing.OutCubic }
            NumberAnimation { target: frame; property: "t"; to: 1; duration: frame.dur * 1.35; easing.type: Easing.OutQuart }
            SequentialAnimation {
                PauseAnimation { duration: frame.dur * 0.42 }
                NumberAnimation { target: frame; property: "reveal"; to: 1; duration: frame.dur * 0.85; easing.type: Easing.OutCubic }
            }
        }
        // morph close: content out, glass shrinks back toward the widget edge
        SequentialAnimation {
            id: morphClose
            NumberAnimation { target: frame; property: "reveal"; to: 0; duration: frame.dur * 0.30; easing.type: Easing.InCubic }
            ParallelAnimation {
                NumberAnimation { target: frame; property: "t"; to: 0; duration: frame.dur * 0.95; easing.type: Easing.InOutCubic }
                SequentialAnimation {
                    PauseAnimation { duration: frame.dur * 0.55 }
                    NumberAnimation { target: panel; property: "opacity"; to: 0; duration: frame.dur * 0.40; easing.type: Easing.InCubic }
                }
            }
            ScriptAction { script: popup.visible = false }
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
            // between the widget's edge (t = 0) and the full panel (t = 1)
            x: popup.morph ? frame.morphStartX + (frame.fx - frame.morphStartX) * frame.t : frame.fx
            y: popup.morph ? frame.morphStartY + (frame.fy - frame.morphStartY) * frame.t : frame.fy
            width: popup.morph ? frame.morphStartW + (frame.fw - frame.morphStartW) * frame.t : frame.fw
            height: popup.morph ? frame.morphStartH + (frame.fh - frame.morphStartH) * frame.t : frame.fh
            // grows out of the panel the widget sits on
            transformOrigin: popup.fromTop ? Item.Top : Item.Bottom
            transform: Translate { id: shift }

            GlassSurface {
                anchors.fill: parent
                style: popup.style
                backgroundOpacity: popup.backgroundOpacity
                // pill-shaped while emerging from the widget
                radius: popup.morph && frame.t < 1
                    ? Math.min(popup.radius, height / 2) + (popup.radius - Math.min(popup.radius, height / 2)) * frame.t
                    : popup.radius
                isDark: popup.isDark
                accent: popup.accent
                forceBody: true
                blurBehind: popup.blurBehind
                    && !(morphClose.running && (panel.opacity < 0.95 || frame.t < 0.65))
                    && !closeAnim.running
                frost: popup.frost
            }

            // Clip only the inner content during morph so GlassSurface's outer shadow
            // is never chopped into a square bounding box.
            Item {
                id: contentClip
                anchors.fill: parent
                clip: popup.morph && frame.t < 1

                Loader {
                    id: loader
                    // stays locked in its final position while the glass expands around it
                    x: frame.padding + frame.fx - panel.x
                    y: frame.padding + frame.fy - panel.y
                    active: popup.visible || popup.preload || popup._preparing
                    onLoaded: if (popup._preparing) Qt.callLater(popup._completeOpen)
                    onWidthChanged: if (popup._preparing && width > 0) Qt.callLater(popup._completeOpen)
                    onHeightChanged: if (popup._preparing && height > 0) Qt.callLater(popup._completeOpen)
                    width: item ? item.implicitWidth : 0
                    height: item ? item.implicitHeight : 0
                    focus: true
                    Keys.onEscapePressed: popup.close()
                    opacity: frame.reveal
                    transform: Translate { y: popup.morph ? 0 : (1 - frame.reveal) * (popup.fromTop ? -8 : 8) }
                }
            }
        }
    }
}
