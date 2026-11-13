/*
 * Glasdock — macOS-style dock for Plasma 6
 * Parabolic icon zoom, glass background, launch bounce and its own app launcher.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import org.kde.plasma.plasma5support as P5Support
import org.kde.notificationmanager as NotificationManager
import org.kde.plasma.private.mpris as Mpris
import "widgets" as Widgets

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea

    // ---------------------------------------------------------------- model
    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }
    TaskManager.ActivityInfo { id: activityInfo }

    TaskManager.TasksModel {
        id: tasksModel

        virtualDesktop: virtualDesktopInfo.currentDesktop
        screenGeometry: Plasmoid.containment.screenGeometry
        activity: activityInfo.currentActivity

        filterByVirtualDesktop: Plasmoid.configuration.onlyCurrentDesktop
        filterByScreen: false
        filterByActivity: true
        filterNotMinimized: false

        groupMode: TaskManager.TasksModel.GroupApplications
        groupInline: false
        separateLaunchers: false
        launchInPlace: true
        hideActivatedLaunchers: true
        sortMode: TaskManager.TasksModel.SortManual

        launcherList: Plasmoid.configuration.launchers
        onLauncherListChanged: Plasmoid.configuration.launchers = launcherList
    }

    // Removes the background of the panel holding the dock (the glass is drawn here).
    // Not persisted: removing the widget brings the panel background back.
    Binding {
        target: Plasmoid.containment
        property: "backgroundHints"
        value: PlasmaCore.Types.NoBackground
        when: Plasmoid.configuration.transparentPanel
              && Plasmoid.formFactor === PlasmaCore.Types.Horizontal
        restoreMode: Binding.RestoreBindingOrValue
    }

    // ------------------------------------------------------- notification badges
    // Count of unread notifications in Plasma's notification history, per app
    // (desktop entry). Cleared when the notifications are read in the history.
    property var notifCounts: ({})

    // "applications:org.telegram.desktop.desktop", "file:///…/x.desktop",
    // "/usr/share/applications/x.desktop", "firefox" -> lowercase id without .desktop
    function appKey(s) {
        if (!s)
            return "";
        s = s.toString().replace(/^application:\/\//, "").replace(/^applications:/, "");
        s = s.substring(s.lastIndexOf("/") + 1).replace(/\.desktop$/, "");
        return s.toLowerCase();
    }

    function badgeFor(appId, launcherUrl) {
        const a = appKey(appId), b = appKey(launcherUrl);
        return Math.max(notifCounts[a] || 0, notifCounts[b] || 0);
    }

    NotificationManager.Notifications {
        id: notifModel
        showNotifications: true
        showJobs: false
        showExpired: true
        showDismissed: false
        groupMode: NotificationManager.Notifications.GroupDisabled
    }
    Connections {
        target: notifModel
        function onCountChanged() { recountTimer.restart(); }
        function onDataChanged() { recountTimer.restart(); }
        function onModelReset() { recountTimer.restart(); }
    }
    Timer {
        id: recountTimer
        interval: 150
        onTriggered: {
            const counts = {};
            for (let i = 0; i < notifModel.count; i++) {
                const idx = notifModel.index(i, 0);
                if (notifModel.data(idx, NotificationManager.Notifications.ReadRole))
                    continue;
                const k = root.appKey(notifModel.data(idx, NotificationManager.Notifications.DesktopEntryRole));
                if (k)
                    counts[k] = (counts[k] || 0) + 1;
            }
            root.notifCounts = counts;
        }
    }
    Component.onCompleted: recountTimer.start()

    // ------------------------------------------------------ dock widgets data
    Mpris.Mpris2Model { id: mpris2Model }

    Widgets.WeatherData {
        id: weatherData
        city: Plasmoid.configuration.showWeather ? Plasmoid.configuration.weatherCity : ""
        fahrenheit: Plasmoid.configuration.weatherFahrenheit
    }

    property date now: new Date()
    Timer {
        interval: 1000
        repeat: true
        running: Plasmoid.configuration.showClock
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Runs shell commands (power actions)
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: sourceName => disconnectSource(sourceName)
        function run(cmd) { connectSource(cmd); }
    }

    // Meta key / Alt+F1 (this widget provides org.kde.plasma.launchermenu)
    property Item dockItem: null
    Connections {
        target: Plasmoid
        function onActivated() {
            if (root.dockItem)
                root.dockItem.toggleLauncher();
        }
    }

    // ---------------------------------------------------------------- visual
    fullRepresentation: Item {
        id: dock

        readonly property var cfg: Plasmoid.configuration
        // Counted from the Repeater: TasksModel.count can lag behind row inserts,
        // which left newly opened apps outside the glass bar.
        readonly property int count: taskRepeater.count
        readonly property int offset: cfg.showAppsButton ? 1 : 0
        readonly property int slots: count + offset
        readonly property real maxZoom: Math.max(1, cfg.maxZoom)
        readonly property real pad: Math.round(cfg.iconSize * 0.18)
        readonly property real labelSpace: cfg.showLabels ? Kirigami.Units.gridUnit * 2 : 0

        // Resting icon size: the configured one, reduced if the panel is not tall
        // enough for the zoomed icon to fit.
        readonly property real baseIcon: Math.max(16, Math.min(cfg.iconSize,
            Math.floor((height - cfg.bottomMargin - pad - labelSpace) / maxZoom)))
        readonly property real spacing: Math.max(0, cfg.iconSpacing)
        readonly property real iconMax: Math.ceil(baseIcon * maxZoom)

        readonly property real barHeight: baseIcon + pad * 2
        readonly property real barY: height - cfg.bottomMargin - barHeight
        // --- widgets (player, weather, clock) after the app icons
        readonly property real sepGap: Math.max(spacing, 6) * 2 + 1
        readonly property var widgetWidths: {
            const w = [];
            if (cfg.showPlayer) w.push(Math.round(baseIcon * 3.8));
            if (cfg.showWeather) w.push(Math.round(baseIcon * 2.4));
            if (cfg.showClock) w.push(Math.round(baseIcon * 2.4));
            return w;
        }
        readonly property real widgetsWidth: widgetWidths.length === 0 ? 0
            : sepGap + widgetWidths.reduce((a, b) => a + b, 0) + spacing * (widgetWidths.length - 1)

        readonly property real restWidth: slots * baseIcon + Math.max(0, slots - 1) * spacing + widgetsWidth
        readonly property real zoomSlack: (maxZoom - 1) * baseIcon * cfg.zoomRange * 1.15

        // Fixed width (with room for the zoom) so the panel does not resize on
        // every mouse move.
        Layout.minimumWidth: restWidth + pad * 2 + zoomSlack + 8
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        // Panel thickness needed for the configured icon size at full zoom.
        // With "autoPanelHeight" the panel is resized to it, so the icon size
        // setting is not capped by the current panel height.
        readonly property int neededHeight: Math.ceil(cfg.bottomMargin + pad
            + cfg.iconSize * maxZoom + labelSpace + 4)
        onNeededHeightChanged: panelResizeTimer.restart()
        onHeightChanged: panelResizeTimer.restart()
        Timer {
            id: panelResizeTimer
            interval: 500
            onTriggered: {
                if (!dock.cfg.autoPanelHeight || Plasmoid.formFactor !== PlasmaCore.Types.Horizontal
                        || !Plasmoid.containment || dock.height <= 0
                        || Math.abs(dock.height - dock.neededHeight) < 2)
                    return;
                executable.run("qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
                    + "'var p = panelById(" + Plasmoid.containment.id + "); if (p) p.height = "
                    + dock.neededHeight + ";'");
            }
        }

        // --- system accent color for the dock details (dots, labels, tint)
        // on dark glass, dark accents (e.g. picked from the wallpaper) are lifted
        // a bit so the details stay visible
        readonly property color accent: isDark
            && Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.highlightColor) === Kirigami.ColorUtils.Dark
            ? Qt.lighter(Kirigami.Theme.highlightColor, 1.5) : Kirigami.Theme.highlightColor
        readonly property color detailColor: cfg.useAccentColor ? accent
            : (isDark ? "white" : Qt.rgba(0, 0, 0, 0.75))

        // --- drag to reorder
        property Item dragItem: null    // delegate being dragged (identity survives moves)
        property Item droppedItem: null // just released: animates into its slot
        property real dragX: 0          // pointer x (dock coordinates)
        readonly property bool dragging: dragItem !== null

        function reorderTo(from, px) {
            const b = baseIcon, sp = spacing;
            const left0 = (width - restWidth) / 2;
            const slotAt = Math.round((px - left0 - b / 2) / (b + sp));
            const to = Math.max(0, Math.min(count - 1, slotAt - offset));
            if (to !== from)
                tasksModel.move(from, to);
        }

        // keeps a dragged icon (width w) inside the glass bar, after the apps
        // button; returns the clamped pointer x
        function clampDragX(px, w) {
            const lo = (offset === 1 ? layout.xs[0] + layout.sizes[0] + spacing : layout.x0) + w / 2;
            const hi = layout.iconsEnd - w / 2;
            return Math.max(lo, Math.min(hi, px));
        }

        function endDrag() {
            droppedItem = dragItem;
            dragItem = null;
            dropTimer.restart();
            tasksModel.syncLaunchers(); // saves the new order of pinned apps
        }

        Timer {
            id: dropTimer
            interval: 220
            onTriggered: dock.droppedItem = null
        }

        readonly property bool isDark: Kirigami.ColorUtils.brightnessForColor(
            Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark

        // --- mouse tracking and zoom amount (0..1, animated)
        property real mouseX: -100000
        property real zoom: hover.hovered && !contextMenuOpen ? 1 : 0
        property bool contextMenuOpen: false
        Behavior on zoom {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        HoverHandler {
            id: hover
            readonly property real px: point.position.x
            // while dragging, mouseX is driven by the (clamped) drag position
            onPxChanged: if (hovered && !dock.dragging) dock.mouseX = px
        }

        // --- layout: size and position of each icon
        // centeredZoom: the bar grows evenly from the screen center, so it does
        // not slide sideways while the mouse moves over it. Otherwise the point
        // under the cursor stays put (the bar shifts to follow it).
        readonly property var layout: {
            const n = slots, b = baseIcon, sp = spacing;
            const R = b * cfg.zoomRange;
            const z = (maxZoom - 1) * zoom;
            const left0 = (width - restWidth) / 2;
            let sizes = [], total = 0, leftExtra = 0;
            for (let i = 0; i < n; i++) {
                const restX = left0 + i * (b + sp);
                const d = Math.abs(mouseX - (restX + b / 2));
                const g = d < R ? (Math.cos(Math.PI * d / R) + 1) / 2 : 0;
                const fixed = i === 0 && offset === 1 && !cfg.appsButtonZoom;
                const s = fixed ? b : b * (1 + z * g);
                const t = Math.max(0, Math.min(1, (mouseX - restX) / b));
                leftExtra += (s - b) * t;
                sizes.push(s);
                total += s;
            }
            total += sp * Math.max(0, n - 1);
            const iconsTotal = total;
            total += widgetsWidth;
            const x0 = cfg.centeredZoom ? (width - total) / 2 : left0 - leftExtra;
            let xs = [], x = x0;
            for (let i = 0; i < n; i++) {
                xs.push(x);
                x += sizes[i] + sp;
            }
            const iconsEnd = x0 + iconsTotal;
            return { sizes: sizes, xs: xs, total: total, x0: x0,
                     iconsEnd: iconsEnd, widgetsX: iconsEnd + sepGap };
        }

        // ------------------------------------------------------- glass bar
        Item {
            id: glass
            x: Math.round(dock.layout.x0 - dock.pad)
            y: dock.barY
            width: Math.round(Math.max(dock.layout.total, dock.baseIcon) + dock.pad * 2)
            height: dock.barHeight

            GlassSurface {
                anchors.fill: parent
                style: dock.cfg.dockStyle
                backgroundOpacity: dock.cfg.glassOpacity
                radius: dock.cfg.cornerRadius
                isDark: dock.isDark
                accent: dock.accent
                accentTint: dock.cfg.glassAccentTint
                showBorder: dock.cfg.showBorder
                showShadow: dock.cfg.showShadow
            }
        }

        // ---------------------------------------------------- apps button
        Item {
            id: appsButton
            visible: dock.cfg.showAppsButton
            readonly property real size: dock.layout.sizes[0] ?? dock.baseIcon
            x: dock.layout.xs[0] ?? 0
            y: dock.barY + dock.pad + dock.baseIcon - size
            width: size
            height: size
            z: appsMouse.containsMouse ? 10 : 1

            Kirigami.Icon {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: dock.iconMax
                height: dock.iconMax
                scale: appsButton.size / dock.iconMax
                transformOrigin: Item.Bottom
                source: dock.cfg.appsButtonIcon
                opacity: appsMouse.pressed ? 0.65 : 1
            }

            Rectangle {
                opacity: dock.cfg.showLabels && appsMouse.containsMouse ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 140 } }
                width: appsLabel.implicitWidth + Kirigami.Units.largeSpacing * 2
                height: appsLabel.implicitHeight + Kirigami.Units.smallSpacing * 2
                radius: height / 2
                x: (appsButton.width - width) / 2
                y: Math.max(-appsButton.y, -height - Kirigami.Units.smallSpacing * 2)
                color: dock.isDark ? Qt.rgba(0.12, 0.12, 0.14, 0.85) : Qt.rgba(1, 1, 1, 0.85)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, dock.isDark ? 0.15 : 0.6)
                Text {
                    id: appsLabel
                    anchors.centerIn: parent
                    text: "Applications"
                    color: dock.isDark ? "white" : "#1d1d1f"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    renderType: Text.NativeRendering
                }
            }

            MouseArea {
                id: appsMouse
                // same hit area rules as the app icons
                anchors.fill: parent
                anchors.leftMargin: -dock.pad
                anchors.rightMargin: -(dock.slots === 1 ? dock.pad : dock.spacing / 2)
                anchors.topMargin: Math.min(0, dock.barY - appsButton.y)
                anchors.bottomMargin: -(dock.barY + dock.barHeight - appsButton.y - appsButton.height)
                hoverEnabled: true
                onClicked: dock.toggleLauncher()
            }
        }

        // ------------------------------------------------------- launcher
        Component.onCompleted: root.dockItem = dock

        property double launcherHiddenAt: 0
        function toggleLauncher() {
            // a click on the button first deactivates (hides) the popup;
            // don't reopen it right away
            // a click on the button first deactivates the popup (which starts
            // closing it); don't reopen it right away
            if (launcherView.closing || Date.now() - launcherHiddenAt < 250)
                return;
            if (launcher.visible) {
                launcherView.playClose();
                return;
            }
            launcherView.reset();
            launcher.reposition();
            launcher.visible = true;
            launcher.reposition();
            launcher.requestActivate();
            launcherView.reset();
            launcherView.playOpen();
        }

        PlasmaCore.Dialog {
            id: launcher
            type: PlasmaCore.Dialog.AppletPopup
            flags: Qt.WindowStaysOnTopHint
            // With the theme background, BottomEdge lets KWin's "Sliding popups"
            // effect slide the whole window (frame + blur) up from the dock. The
            // custom glass background is animated entirely by Launcher.qml.
            readonly property bool kwinSlides: dock.cfg.launcherAnimation && !dock.cfg.launcherCustomBackground
            location: kwinSlides ? PlasmaCore.Types.BottomEdge : PlasmaCore.Types.Floating
            // closing on deactivation is animated (onActiveChanged) instead
            hideOnWindowDeactivate: !dock.cfg.launcherAnimation
            onActiveChanged: if (!active && visible) launcherView.playClose()
            backgroundHints: dock.cfg.launcherCustomBackground ? PlasmaCore.Dialog.NoBackground
                                                               : PlasmaCore.Dialog.StandardBackground
            visible: false

            onVisibleChanged: {
                if (!visible)
                    dock.launcherHiddenAt = Date.now();
                Plasmoid.status = visible ? PlasmaCore.Types.RequiresAttentionStatus
                                          : PlasmaCore.Types.ActiveStatus;
            }
            onWidthChanged: if (visible) reposition()
            onHeightChanged: if (visible) reposition()

            // centered over the glass bar, cfg.launcherGap px above it
            function reposition() {
                const p = dock.mapToGlobal(glass.x + glass.width / 2, glass.y);
                const w = launcherView.width + margins.left + margins.right;
                const h = launcherView.height + margins.top + margins.bottom;
                x = Math.round(p.x - w / 2);
                y = Math.round(p.y - dock.cfg.launcherGap - h);
            }

            mainItem: Launcher {
                id: launcherView
                width: dock.cfg.launcherWidth
                height: dock.cfg.launcherHeight
                appletInterface: root
                iconSize: dock.cfg.launcherIconSize
                customBackground: dock.cfg.launcherCustomBackground
                backgroundOpacity: dock.cfg.launcherOpacity
                isDark: dock.isDark
                frameMargins: launcher.margins
                animated: dock.cfg.launcherAnimation
                animationDuration: dock.cfg.launcherAnimationDuration
                windowSlides: launcher.kwinSlides
                onCloseRequested: playClose()
                onCloseFinished: launcher.visible = false
                onRunCommand: cmd => executable.run(cmd)
                onPinRequested: url => tasksModel.requestAddLauncher(url)
            }
        }

        // ------------------------------------------------------------ widgets
        Rectangle {
            // separator between apps and widgets
            visible: dock.widgetsWidth > 0
            x: Math.round(dock.layout.iconsEnd + dock.sepGap / 2)
            y: dock.barY + dock.barHeight * 0.2
            width: 1
            height: dock.barHeight * 0.6
            color: Qt.rgba(1, 1, 1, dock.isDark ? 0.18 : 0.5)
        }

        Row {
            id: widgetsRow
            visible: dock.widgetsWidth > 0
            x: dock.layout.widgetsX
            y: dock.barY + dock.pad
            height: dock.baseIcon
            spacing: dock.spacing

            Widgets.PlayerTile {
                id: playerTile
                visible: dock.cfg.showPlayer
                width: Math.round(dock.baseIcon * 3.8)
                height: parent.height
                isDark: dock.isDark
                player: mpris2Model.currentPlayer
                active: dock.popupOpenFor(playerTile)
                onClicked: dock.toggleWidgetPopup(playerTile, playerPopupComponent)
            }
            Widgets.WeatherTile {
                id: weatherTile
                visible: dock.cfg.showWeather
                width: Math.round(dock.baseIcon * 2.4)
                height: parent.height
                isDark: dock.isDark
                weather: weatherData
                active: dock.popupOpenFor(weatherTile)
                onClicked: dock.toggleWidgetPopup(weatherTile, weatherPopupComponent)
            }
            Widgets.ClockTile {
                id: clockTile
                visible: dock.cfg.showClock
                width: Math.round(dock.baseIcon * 2.4)
                height: parent.height
                isDark: dock.isDark
                now: root.now
                active: dock.popupOpenFor(clockTile)
                onClicked: dock.toggleWidgetPopup(clockTile, clockPopupComponent)
            }
        }

        Component { id: playerPopupComponent; Widgets.PlayerPopup { player: mpris2Model.currentPlayer; accent: dock.accent; isDark: dock.isDark } }
        Component { id: weatherPopupComponent; Widgets.WeatherPopup { weather: weatherData; accent: dock.accent; isDark: dock.isDark } }
        Component { id: clockPopupComponent; Widgets.ClockPopup { now: root.now; accent: dock.accent; isDark: dock.isDark } }

        property double widgetPopupHiddenAt: 0
        // the tile whose panel is open stays highlighted
        function popupOpenFor(tile) {
            return widgetPopup.visible && widgetPopupAnchor === tile && !popupFrame.closing;
        }
        property Item widgetPopupAnchor: null
        function toggleWidgetPopup(anchorItem, component) {
            const same = widgetPopupAnchor === anchorItem;
            // clicking the dock deactivates the panel first, which starts closing it
            if (same && (popupFrame.closing || Date.now() - widgetPopupHiddenAt < 250))
                return;
            if (widgetPopup.visible) {
                if (same) {
                    popupFrame.playClose();
                    return;
                }
                // another tile: swap the content in place instead of closing/reopening
                popupFrame.cancelClose();
                widgetPopupAnchor = anchorItem;
                widgetPopupLoader.sourceComponent = component;
                widgetPopup.reposition();
                popupFrame.playSwitch();
                widgetPopup.requestActivate();
                return;
            }
            if (launcher.visible)
                launcherView.playClose();
            widgetPopupAnchor = anchorItem;
            widgetPopupLoader.sourceComponent = component;
            widgetPopup.reposition();
            widgetPopup.visible = true;
            widgetPopup.reposition();
            widgetPopup.requestActivate();
        }

        PlasmaCore.Dialog {
            id: widgetPopup
            type: PlasmaCore.Dialog.AppletPopup
            flags: Qt.WindowStaysOnTopHint
            location: PlasmaCore.Types.Floating   // animated by popupFrame instead of KWin
            // closing on deactivation is animated (onActiveChanged) instead
            hideOnWindowDeactivate: !dock.cfg.launcherAnimation
            onActiveChanged: if (!active && visible) popupFrame.playClose()
            // drawn by GlassSurface so the panels match the dock
            backgroundHints: PlasmaCore.Dialog.NoBackground
            visible: false

            onVisibleChanged: {
                if (!visible)
                    dock.widgetPopupHiddenAt = Date.now();
                else
                    popupFrame.playOpen();
                Plasmoid.status = visible || launcher.visible ? PlasmaCore.Types.RequiresAttentionStatus
                                                              : PlasmaCore.Types.ActiveStatus;
            }
            onWidthChanged: if (visible) reposition()
            onHeightChanged: if (visible) reposition()

            // centered over its tile, launcherGap px above the bar
            function reposition() {
                if (!dock.widgetPopupAnchor)
                    return;
                const a = dock.widgetPopupAnchor;
                const p = a.mapToGlobal(a.width / 2, 0);
                const top = dock.mapToGlobal(0, glass.y).y;
                // the frame has a transparent margin for the shadow
                x = Math.round(p.x - popupFrame.width / 2);
                y = Math.round(top - dock.cfg.launcherGap - popupFrame.height + popupFrame.shadowMargin);
            }

            mainItem: Item {
                id: popupFrame
                readonly property int shadowMargin: 28
                readonly property int padding: Kirigami.Units.gridUnit
                width: widgetPopupLoader.width + (padding + shadowMargin) * 2
                height: widgetPopupLoader.height + (padding + shadowMargin) * 2

                // Open: the glass grows out of its tile, the content follows a
                // moment later. Switch: content cross-fades with a small pop.
                // Close: quick fade/shrink, then the window is hidden.
                // Durations follow Plasma's global animation speed.
                readonly property int dur: Math.round(dock.cfg.launcherAnimationDuration * Kirigami.Units.longDuration / 200)
                readonly property bool animated: dock.cfg.launcherAnimation && dur >= 10
                readonly property bool closing: closeAnim.running
                property real reveal: 1

                function playOpen() {
                    closeAnim.stop();
                    if (!animated) {
                        panel.opacity = 1; panel.scale = 1; rise.y = 0; reveal = 1;
                        return;
                    }
                    panel.opacity = 0; panel.scale = 0.92; rise.y = 14; reveal = 0;
                    openAnim.restart();
                }
                function playSwitch() {
                    if (!animated)
                        return;
                    panel.opacity = 1; rise.y = 0;
                    panel.scale = 0.97; reveal = 0;
                    switchAnim.restart();
                }
                function playClose() {
                    if (closeAnim.running)
                        return;
                    openAnim.stop();
                    switchAnim.stop();
                    if (!animated) {
                        widgetPopup.visible = false;
                        return;
                    }
                    closeAnim.restart();
                }
                function cancelClose() {
                    if (!closeAnim.running)
                        return;
                    closeAnim.stop();
                    panel.opacity = 1; panel.scale = 1; rise.y = 0; reveal = 1;
                }

                ParallelAnimation {
                    id: openAnim
                    NumberAnimation { target: panel; property: "opacity"; to: 1; duration: popupFrame.dur * 0.8; easing.type: Easing.OutCubic }
                    NumberAnimation { target: panel; property: "scale"; to: 1; duration: popupFrame.dur; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
                    NumberAnimation { target: rise; property: "y"; to: 0; duration: popupFrame.dur; easing.type: Easing.OutQuint }
                    SequentialAnimation {
                        PauseAnimation { duration: popupFrame.dur * 0.3 }
                        NumberAnimation { target: popupFrame; property: "reveal"; to: 1; duration: popupFrame.dur; easing.type: Easing.OutCubic }
                    }
                }
                ParallelAnimation {
                    id: switchAnim
                    NumberAnimation { target: panel; property: "scale"; to: 1; duration: popupFrame.dur; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
                    NumberAnimation { target: popupFrame; property: "reveal"; to: 1; duration: popupFrame.dur * 0.9; easing.type: Easing.OutCubic }
                }
                SequentialAnimation {
                    id: closeAnim
                    ParallelAnimation {
                        NumberAnimation { target: panel; property: "opacity"; to: 0; duration: popupFrame.dur * 0.55; easing.type: Easing.InCubic }
                        NumberAnimation { target: panel; property: "scale"; to: 0.95; duration: popupFrame.dur * 0.55; easing.type: Easing.InCubic }
                        NumberAnimation { target: rise; property: "y"; to: 8; duration: popupFrame.dur * 0.55; easing.type: Easing.InCubic }
                    }
                    ScriptAction { script: widgetPopup.visible = false }
                }

                Item {
                    id: panel
                    anchors.fill: parent
                    anchors.margins: popupFrame.shadowMargin
                    transformOrigin: Item.Bottom
                    transform: Translate { id: rise }

                    GlassSurface {
                        anchors.fill: parent
                        style: dock.cfg.dockStyle
                        backgroundOpacity: dock.cfg.glassOpacity
                        radius: dock.cfg.cornerRadius + 4
                        isDark: dock.isDark
                        accent: dock.accent
                        accentTint: dock.cfg.glassAccentTint
                        showBorder: dock.cfg.showBorder
                        showShadow: dock.cfg.showShadow
                        forceBody: true
                    }

                    Loader {
                        id: widgetPopupLoader
                        x: popupFrame.padding
                        y: popupFrame.padding
                        width: item ? item.implicitWidth : 1
                        height: item ? item.implicitHeight : 1
                        focus: true
                        Keys.onEscapePressed: popupFrame.playClose()
                        // staggered reveal of the content
                        opacity: popupFrame.reveal
                        transform: Translate { y: (1 - popupFrame.reveal) * 8 }
                    }
                }
            }
        }

        // ------------------------------------------------------------- icons
        Repeater {
            id: taskRepeater
            model: tasksModel

            delegate: Item {
                id: task

                required property int index
                required property var model

                readonly property int slot: index + dock.offset
                // hidden until the layout knows about this slot (avoids a frame
                // where a new icon is drawn full size outside the bar)
                readonly property bool laidOut: slot < dock.layout.sizes.length
                visible: laidOut
                readonly property real size: dock.layout.sizes[slot] ?? dock.baseIcon
                readonly property bool isLauncher: model.IsLauncher === true
                readonly property int badgeCount: root.badgeFor(model.AppId, model.LauncherUrlWithoutIcon)
                property real bounce: 0
                property bool launching: false

                readonly property bool dragged: dock.dragItem === task
                x: dragged ? dock.dragX - width / 2 : (dock.layout.xs[slot] ?? 0)
                Behavior on x {
                    // the other icons slide into their new places while dragging
                    enabled: (dock.dragging && !task.dragged) || dock.droppedItem === task
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
                y: dock.barY + dock.pad + dock.baseIcon - size - bounce
                width: size
                height: size
                z: dragged ? 20 : (mouse.containsMouse ? 10 : 1)
                opacity: dragged ? 0.85 : 1

                onIsLauncherChanged: if (!isLauncher) launching = false

                function modelIndex(child) {
                    return tasksModel.makeModelIndex(index, child === undefined ? -1 : child);
                }

                function publishGeometry() {
                    // resting position, used by KWin's minimize animation
                    if (!dock || !task || index < 0)
                        return; // delegate already destroyed (model changed)
                    const restX = (dock.width - dock.restWidth) / 2 + slot * (dock.baseIcon + dock.spacing);
                    const p = dock.mapToGlobal(restX, dock.barY + dock.pad);
                    tasksModel.requestPublishDelegateGeometry(modelIndex(),
                        Qt.rect(p.x, p.y, dock.baseIcon, dock.baseIcon), task);
                }

                function startLaunchBounce() {
                    launching = true;
                    launchTimer.restart();
                }

                function activate() {
                    if (isLauncher) {
                        startLaunchBounce();
                        tasksModel.requestActivate(modelIndex());
                        return;
                    }
                    publishGeometry();
                    if (model.IsGroupParent && model.ChildCount > 1) {
                        // several windows of the same app: cycle through them
                        const n = model.ChildCount;
                        let active = -1;
                        for (let c = 0; c < n; c++) {
                            if (tasksModel.data(modelIndex(c), TaskManager.AbstractTasksModel.IsActive)) {
                                active = c;
                                break;
                            }
                        }
                        tasksModel.requestActivate(modelIndex((active + 1) % n));
                        return;
                    }
                    if (model.IsActive && !model.IsMinimized)
                        tasksModel.requestToggleMinimized(modelIndex());
                    else
                        tasksModel.requestActivate(modelIndex());
                }

                Component.onCompleted: Qt.callLater(publishGeometry)

                Timer {
                    id: launchTimer
                    interval: 2400
                    onTriggered: task.launching = false
                }

                // bounce (app launching or demanding attention)
                SequentialAnimation {
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    running: task.launching || task.model.IsStartup === true
                             || task.model.IsDemandingAttention === true
                    NumberAnimation {
                        target: task; property: "bounce"
                        to: dock.baseIcon * 0.5; duration: 280
                        easing.type: Easing.OutQuad
                    }
                    NumberAnimation {
                        target: task; property: "bounce"
                        to: 0; duration: 420
                        easing.type: Easing.OutBounce
                    }
                }

                Kirigami.Icon {
                    id: icon
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    // rendered at max size and scaled down: sharp and cheap
                    width: dock.iconMax
                    height: dock.iconMax
                    scale: task.size / dock.iconMax
                    transformOrigin: Item.Bottom
                    source: task.model.decoration
                    opacity: mouse.pressed ? 0.65 : 1
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                }

                // notification badge (top-right of the icon):
                // a plain dot for a single notification, the number when there are more
                Rectangle {
                    id: badge
                    readonly property bool shown: dock.cfg.showBadges && task.badgeCount > 0 && !task.dragged
                    readonly property bool numeric: task.badgeCount > 1
                    readonly property real h: Math.max(14, Math.round(task.size * 0.34))
                    readonly property real dotSize: Math.max(8, Math.round(h * 0.55))
                    height: numeric ? h : dotSize
                    width: numeric ? Math.max(h, badgeText.implicitWidth + h * 0.55) : dotSize
                    radius: height / 2
                    x: numeric ? task.width - width * 0.8 : task.width - width * 0.9
                    y: numeric ? -h * 0.15 : -dotSize * 0.1
                    z: 5
                    // system accent color by default (red is the alternative)
                    color: dock.cfg.badgeUseAccent ? dock.accent : "#ff3b30"
                    border.width: 1
                    border.color: Qt.rgba(0, 0, 0, 0.18)
                    scale: shown ? 1 : 0
                    visible: scale > 0
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

                    Text {
                        id: badgeText
                        visible: badge.numeric
                        anchors.centerIn: parent
                        text: task.badgeCount > 99 ? "99+" : task.badgeCount
                        // dark text on light accents, white otherwise
                        color: Kirigami.ColorUtils.brightnessForColor(badge.color) === Kirigami.ColorUtils.Light
                               ? "#1d1d1f" : "white"
                        font.pixelSize: Math.round(badge.h * 0.62)
                        font.bold: true
                    }
                }

                // running indicator
                // (active app: a wider pill with a soft glow in the accent color)
                Rectangle {
                    id: dot
                    visible: !task.isLauncher && !task.dragged
                    readonly property bool active: task.model.IsActive === true
                    width: active ? 12 : 5
                    height: 5
                    radius: 2.5
                    x: (task.width - width) / 2
                    y: dock.barY + dock.barHeight - dock.pad / 2 - height / 2 - task.y
                    color: dock.detailColor
                    opacity: active ? 1 : 0.6
                    Behavior on width { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: height / 2
                        color: dock.detailColor
                        opacity: dot.active && dock.cfg.useAccentColor ? 0.25 : 0
                        z: -1
                    }
                }

                // app name on hover
                Rectangle {
                    id: label
                    readonly property bool shown: dock.cfg.showLabels && mouse.containsMouse
                                                  && !dock.contextMenuOpen && !dock.dragging
                    opacity: shown ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 140 } }

                    width: labelText.implicitWidth + Kirigami.Units.largeSpacing * 2
                    height: labelText.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: height / 2
                    x: (task.width - width) / 2
                    y: Math.max(-task.y, -height - Kirigami.Units.smallSpacing * 2)
                    color: dock.isDark ? Qt.rgba(0.12, 0.12, 0.14, 0.85) : Qt.rgba(1, 1, 1, 0.85)
                    border.width: 1
                    border.color: dock.cfg.useAccentColor
                        ? Qt.rgba(dock.accent.r, dock.accent.g, dock.accent.b, 0.7)
                        : Qt.rgba(1, 1, 1, dock.isDark ? 0.15 : 0.6)

                    Text {
                        id: labelText
                        anchors.centerIn: parent
                        text: task.model.AppName || task.model.display || ""
                        color: dock.isDark ? "white" : "#1d1d1f"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: mouse
                    // hit area: up to the middle of the gap to each neighbour and
                    // the full height of the bar (no dead zones between icons or
                    // over the running-indicator strip)
                    anchors.fill: parent
                    anchors.leftMargin: -(task.slot === 0 ? dock.pad : dock.spacing / 2)
                    anchors.rightMargin: -(task.slot === dock.slots - 1 && dock.widgetsWidth === 0
                                           ? dock.pad : dock.spacing / 2)
                    anchors.topMargin: Math.min(0, dock.barY - task.y)
                    anchors.bottomMargin: -(dock.barY + dock.barHeight - task.y - task.height)
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    preventStealing: true

                    property point pressPos
                    property bool dragActive: false
                    property bool suppressClick: false

                    onPressed: m => {
                        pressPos = Qt.point(m.x, m.y);
                        dragActive = false;
                        suppressClick = false;
                    }
                    onPositionChanged: m => {
                        if (!(pressedButtons & Qt.LeftButton) || !dock.cfg.allowReorder)
                            return;
                        if (!dragActive && Math.abs(m.x - pressPos.x) > Qt.styleHints.startDragDistance) {
                            dragActive = true;
                            dock.dragItem = task;
                        }
                        if (dragActive) {
                            const p = mapToItem(dock, m.x, m.y);
                            const x = dock.clampDragX(p.x, task.width);
                            dock.dragX = x;
                            dock.mouseX = x;
                            dock.reorderTo(task.index, x);
                        }
                    }
                    onReleased: {
                        if (dragActive) {
                            dragActive = false;
                            suppressClick = true;
                            dock.endDrag();
                        }
                    }
                    onCanceled: {
                        if (dragActive) {
                            dragActive = false;
                            dock.endDrag();
                        }
                    }
                    onClicked: mouseEvent => {
                        if (suppressClick) {
                            suppressClick = false;
                            return;
                        }
                        if (mouseEvent.button === Qt.LeftButton) {
                            task.activate();
                        } else if (mouseEvent.button === Qt.MiddleButton) {
                            task.startLaunchBounce();
                            tasksModel.requestNewInstance(task.modelIndex());
                        } else {
                            menu.openRelative();
                            dock.contextMenuOpen = true;
                        }
                    }
                }

                PlasmaExtras.Menu {
                    id: menu
                    visualParent: task
                    placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
                    onStatusChanged: if (status === PlasmaExtras.Menu.Closed) dock.contextMenuOpen = false

                    readonly property string launcherUrl: task.model.LauncherUrlWithoutIcon ?? ""
                    readonly property bool pinned: launcherUrl !== ""
                        && tasksModel.launcherList.indexOf(launcherUrl.toString()) !== -1

                    PlasmaExtras.MenuItem {
                        text: "New Window"
                        icon: "window-new"
                        visible: task.model.CanLaunchNewInstance === true && !task.isLauncher
                        onClicked: {
                            task.startLaunchBounce();
                            tasksModel.requestNewInstance(task.modelIndex());
                        }
                    }
                    PlasmaExtras.MenuItem {
                        text: menu.pinned ? "Remove from Dock" : "Keep in Dock"
                        icon: menu.pinned ? "window-unpin" : "window-pin"
                        visible: menu.launcherUrl !== ""
                        onClicked: {
                            if (menu.pinned)
                                tasksModel.requestRemoveLauncher(menu.launcherUrl);
                            else
                                tasksModel.requestAddLauncher(menu.launcherUrl);
                        }
                    }
                    PlasmaExtras.MenuItem { separator: true }
                    PlasmaExtras.MenuItem {
                        text: task.model.IsMinimized ? "Restore" : "Minimize"
                        icon: "window-minimize"
                        visible: task.model.IsWindow === true || task.model.IsGroupParent === true
                        onClicked: {
                            task.publishGeometry();
                            tasksModel.requestToggleMinimized(task.modelIndex());
                        }
                    }
                    PlasmaExtras.MenuItem {
                        text: task.model.IsGroupParent ? "Close All Windows" : "Close"
                        icon: "window-close"
                        visible: !task.isLauncher
                        onClicked: tasksModel.requestClose(task.modelIndex())
                    }
                    PlasmaExtras.MenuItem { separator: true }
                    PlasmaExtras.MenuItem {
                        text: "Configure Glasdock…"
                        icon: "configure"
                        onClicked: Plasmoid.internalAction("configure").trigger()
                    }
                }
            }
        }
    }
}
