/*
 * Glasdock — custom glass dock for KDE Plasma 6 (GlasDo project)
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
import "shared" as Widgets

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.constraintHints: Plasmoid.CanFillArea
    Plasmoid.status: dockItem && dockItem.keepPanelOpen ? PlasmaCore.Types.RequiresAttentionStatus
                                                        : PlasmaCore.Types.ActiveStatus

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
        enabled: Plasmoid.configuration.showBadges
        function onCountChanged() { recountTimer.restart(); }
        function onDataChanged(topLeft, bottomRight, roles) {
            if (!roles || roles.length === 0
                    || roles.indexOf(NotificationManager.Notifications.ReadRole) !== -1
                    || roles.indexOf(NotificationManager.Notifications.DesktopEntryRole) !== -1)
                recountTimer.restart();
        }
        function onModelReset() { recountTimer.restart(); }
    }
    Timer {
        id: recountTimer
        interval: 150
        onTriggered: {
            const counts = {};
            if (!Plasmoid.configuration.showBadges) {
                root.notifCounts = counts;
                return;
            }
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
    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key, value) {
            if (key === "showBadges")
                recountTimer.restart();
        }
    }

    // ------------------------------------------------------ dock widgets data
    // Only created while the matching widget is enabled.
    Loader {
        id: mprisLoader
        active: Plasmoid.configuration.showPlayer
        sourceComponent: Widgets.MprisSource {}
    }
    readonly property var activePlayer: mprisLoader.item ? mprisLoader.item.player : null
    readonly property bool playerHasMedia: mprisLoader.item ? mprisLoader.item.hasMedia : false

    Loader {
        id: weatherLoader
        active: Plasmoid.configuration.showWeather
        sourceComponent: Widgets.WeatherData {
            city: Plasmoid.configuration.weatherCity
            fahrenheit: Plasmoid.configuration.weatherFahrenheit
            useBadges: Plasmoid.configuration.weatherBadges
        }
    }
    readonly property var weatherData: weatherLoader.item

    property date now: new Date()
    Timer {
        // every second only while the clock panel is open; otherwise on the minute
        interval: (root.dockItem && root.dockItem.clockPopupOpen)
            ? 1000 : Math.max(1000, (60 - root.now.getSeconds()) * 1000 - root.now.getMilliseconds() + 50)
        repeat: true
        running: Plasmoid.configuration.showClock
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // Runs shell commands (power actions and .desktop action parser)
    property var appActions: ({})
    property var _pendingActions: ({})
    readonly property string actionsScript: decodeURIComponent(Qt.resolvedUrl("../code/desktop-actions.sh").toString().replace("file://", ""))

    function ensureAppActions(appId, launcherUrl) {
        const key = appKey(launcherUrl || appId);
        if (!key || appActions[key] !== undefined || _pendingActions[key])
            return;
        const ref = (launcherUrl || appId || "").toString();
        if (!ref)
            return;
        _pendingActions[key] = true;
        const safeRef = ref.replace(/'/g, "'\\''");
        const cmd = "sh '" + actionsScript + "' '" + safeRef + "' '" + Qt.locale().name + "'";
        executable.actionKeyForCmd[cmd] = key;
        executable.run(cmd);
    }

    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        property var actionKeyForCmd: ({})
        onNewData: (sourceName, data) => {
            const key = actionKeyForCmd[sourceName];
            disconnectSource(sourceName);
            if (!key)
                return;
            delete actionKeyForCmd[sourceName];
            const out = (data["stdout"] || "").trim();
            const list = [];
            if (out.length > 0) {
                const lines = out.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const p = lines[i].split("\t");
                    if (p.length >= 4)
                        list.push({ id: p[0], name: p[1], icon: p[2], exec: p[3] });
                }
            }
            const next = Object.assign({}, root.appActions);
            next[key] = list;
            root.appActions = next;
        }
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
        // real blur behind the glass (blur helper plugin); the old "Blur" style
        // (4) means Glass with blur
        readonly property bool blurOn: cfg.blurBehind || cfg.dockStyle === 4
        readonly property real maxZoom: Math.max(1, cfg.maxZoom)
        readonly property int bottomGap: cfg.bottomMargin
        readonly property real pad: Math.round(cfg.iconSize * 0.18)
        readonly property real labelSpace: cfg.showLabels ? Kirigami.Units.gridUnit * 2 : 0

        // Resting icon size: the configured one, reduced if the panel is not tall
        // enough for the zoomed icon to fit.
        readonly property real baseIcon: Math.max(16, Math.min(cfg.iconSize, fitWidthIcon,
            Math.floor((height - bottomGap - pad - labelSpace) / maxZoom)))
        // With many apps the icons shrink (like macOS) so the dock never gets
        // wider than the screen. The widget width is linear in the icon size b:
        //   b * (slots + widget tiles + zoom room + spare) + fixed parts
        readonly property real fitWidthIcon: {
            const g = Plasmoid.containment ? Plasmoid.containment.screenGeometry : null;
            if (!g || g.width <= 0)
                return cfg.iconSize;
            const sp = Math.max(0, cfg.iconSpacing);
            const tiles = (cfg.showPlayer ? 3.8 : 0) + (cfg.showWeather ? 2.4 : 0) + (cfg.showClock ? 2.4 : 0);
            const tileCount = (cfg.showPlayer ? 1 : 0) + (cfg.showWeather ? 1 : 0) + (cfg.showClock ? 1 : 0);
            const zoomRoom = (Math.max(1, cfg.maxZoom) - 1) * cfg.zoomRange * 1.15;
            const perIcon = slots + tiles + zoomRoom + 1;
            const fixed = Math.max(0, slots - 1) * sp + gapsTotal
                + (tileCount > 0 ? sepGap + sp * (tileCount - 1) : 0) + pad * 2 + 8 + sp;
            return Math.floor((g.width - Kirigami.Units.gridUnit * 2 - fixed) / perIcon);
        }
        readonly property real spacing: Math.max(0, cfg.iconSpacing)
        readonly property real iconMax: Math.ceil(baseIcon * maxZoom)

        readonly property real barHeight: baseIcon + pad * 2
        readonly property real barY: height - bottomGap - barHeight
        // --- widgets (player, weather, clock) after the app icons
        readonly property bool showPlayerTile: cfg.showPlayer && root.playerHasMedia
        onShowPlayerTileChanged: {
            if (!showPlayerTile && widgetPopup.visible && widgetPopupAnchor === playerTile)
                popupFrame.playClose();
        }
        readonly property real sepGap: Math.max(spacing, 6) * 2 + 1
        readonly property var widgetWidths: {
            const w = [];
            if (showPlayerTile) w.push(Math.round(baseIcon * 3.8));
            if (cfg.showWeather) w.push(Math.round(baseIcon * 2.4));
            if (cfg.showClock) w.push(Math.round(baseIcon * 2.4));
            return w;
        }
        readonly property real widgetsWidth: widgetWidths.length === 0 ? 0
            : sepGap + widgetWidths.reduce((a, b) => a + b, 0) + spacing * (widgetWidths.length - 1)
        // The player tile comes and goes with the music. The panel keeps room
        // for it whenever it is enabled (so Plasma doesn't resize and re-centre
        // the whole panel), and the glass bar animates to the new width.
        readonly property real reservedWidgetsWidth: {
            const w = [];
            if (cfg.showPlayer) w.push(Math.round(baseIcon * 3.8));
            if (cfg.showWeather) w.push(Math.round(baseIcon * 2.4));
            if (cfg.showClock) w.push(Math.round(baseIcon * 2.4));
            return w.length === 0 ? 0 : sepGap + w.reduce((a, b) => a + b, 0) + spacing * (w.length - 1);
        }
        property real widgetsWidthAnimated: widgetsWidth
        Behavior on widgetsWidthAnimated {
            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
        }

        // --- separators: a vertical line after chosen icons (right-click an icon →
        // "Add Separator After"). Stored as the launcher URLs of the icons they
        // follow ("@apps" = after the apps button), so they move with the icons.
        readonly property real separatorGap: Math.max(spacing, 6) * 2 + 1
        property int modelRevision: 0      // bumped when tasks move/insert/remove
        property int activeRevision: 0     // bumped when active window or group child count changes
        Connections {
            target: tasksModel
            function onRowsMoved() { dock.modelRevision++; dock.activeRevision++; }
            function onRowsInserted() { dock.modelRevision++; dock.activeRevision++; }
            function onRowsRemoved() { dock.modelRevision++; dock.activeRevision++; }
            function onModelReset() {
                dock.modelRevision++;
                dock.activeRevision++;
                dock.bouncingCount = 0;
            }
            function onDataChanged(topLeft, bottomRight, roles) {
                if (!roles || roles.length === 0) {
                    dock.modelRevision++;
                    dock.activeRevision++;
                    return;
                }
                if (roles.indexOf(TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon) !== -1)
                    dock.modelRevision++;
                if (roles.indexOf(TaskManager.AbstractTasksModel.IsActive) !== -1
                        || roles.indexOf(TaskManager.AbstractTasksModel.ChildCount) !== -1)
                    dock.activeRevision++;
            }
        }
        function launcherKeyOf(row) {
            const url = tasksModel.data(tasksModel.makeModelIndex(row), TaskManager.AbstractTasksModel.LauncherUrlWithoutIcon);
            return url ? url.toString() : "";
        }
        // gap after each slot (0 or separatorGap)
        readonly property var gapAfter: {
            modelRevision;   // dependency
            const seps = cfg.separators || [];
            const gaps = [];
            for (let i = 0; i < slots; i++) {
                const key = (offset === 1 && i === 0) ? "@apps" : launcherKeyOf(i - offset);
                gaps.push(i < slots - 1 && key !== "" && seps.indexOf(key) !== -1 ? separatorGap : 0);
            }
            return gaps;
        }
        // resting x of each slot's left edge, relative to the first one
        readonly property var restOffsets: {
            const r = [];
            let x = 0;
            for (let i = 0; i < slots; i++) {
                r.push(x);
                x += baseIcon + spacing + (gapAfter[i] || 0);
            }
            return r;
        }
        readonly property real gapsTotal: gapAfter.reduce((a, g) => a + g, 0)

        function hasSeparatorAfter(key) {
            return (cfg.separators || []).indexOf(key) !== -1;
        }
        function toggleSeparatorAfter(key) {
            const seps = (cfg.separators || []).slice();
            const i = seps.indexOf(key);
            if (i === -1)
                seps.push(key);
            else
                seps.splice(i, 1);
            cfg.separators = seps;
        }

        readonly property real restIconsWidth: slots * baseIcon + Math.max(0, slots - 1) * spacing + gapsTotal
        readonly property real restWidth: restIconsWidth + widgetsWidthAnimated
        readonly property real zoomSlack: (maxZoom - 1) * baseIcon * cfg.zoomRange * 1.15

        // Fixed width (with room for the zoom) so the panel does not resize on
        // every mouse move.
        // + room for one more icon: a newly opened app fits even before Plasma
        // has resized the panel (it was cut at the edge for a moment)
        readonly property real spareRoom: baseIcon + spacing
        Layout.minimumWidth: Math.ceil(restIconsWidth + reservedWidgetsWidth + pad * 2 + zoomSlack + 8 + spareRoom)
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        Layout.fillHeight: true

        // Panel thickness needed for the configured icon size at full zoom.
        // With "autoPanelHeight" the panel is resized to it, so the icon size
        // setting is not capped by the current panel height.
        readonly property int neededHeight: Math.ceil(cfg.bottomMargin + pad + cfg.iconSize * maxZoom + labelSpace + 4)
        onNeededHeightChanged: panelResizeTimer.restart()
        // Each needed height is requested once. Re-requesting after every height
        // change fought users who resize the panel by hand, and looped when
        // Plasma clamps the height (floating panels, margins).
        property int lastRequestedHeight: -1
        Connections {
            target: Plasmoid.configuration
            function onValueChanged(key, value) {
                if (key === "autoPanelHeight") {
                    dock.lastRequestedHeight = -1;
                    panelResizeTimer.restart();
                }
            }
        }
        Timer {
            id: panelResizeTimer
            interval: 500
            onTriggered: {
                if (!dock.cfg.autoPanelHeight || Plasmoid.formFactor !== PlasmaCore.Types.Horizontal
                        || !Plasmoid.containment || dock.height <= 0)
                    return;
                if (Math.abs(dock.height - dock.neededHeight) < 2 || dock.lastRequestedHeight === dock.neededHeight)
                    return;
                dock.lastRequestedHeight = dock.neededHeight;
                // dbus-send ships with D-Bus itself (qdbus6 is missing or renamed on some distros)
                executable.run("dbus-send --session --type=method_call --dest=org.kde.plasmashell /PlasmaShell "
                    + "org.kde.PlasmaShell.evaluateScript string:'var p = panelById(" + Plasmoid.containment.id
                    + "); if (p) p.height = " + dock.neededHeight + ";'");
            }
        }

        // KWin's minimize animation flies to the geometry each icon published;
        // republish it when icons move (apps added/removed, widths changed),
        // not only when an icon is created
        onRestWidthChanged: geometryTimer.restart()
        onRestOffsetsChanged: geometryTimer.restart()
        onWidthChanged: geometryTimer.restart()
        Timer {
            id: geometryTimer
            interval: 400
            onTriggered: {
                for (let i = 0; i < taskRepeater.count; i++) {
                    const t = taskRepeater.itemAt(i);
                    if (t && !t.isLauncher)
                        t.publishGeometry();
                }
            }
        }

        // --- system accent color and Light/Dark theme for the dock and panels
        Widgets.ThemeScope {
            id: themeScope
            target: dock
            themeMode: dock.cfg.themeMode
        }
        readonly property color accent: themeScope.accent
        readonly property color detailColor: cfg.useAccentColor ? accent
            : (isDark ? "white" : Qt.rgba(0, 0, 0, 0.75))

        // --- drag to reorder
        // --- window previews on hover
        property Item previewTask: null   // task whose previews are shown / pending
        readonly property bool previewOpen: windowPreview.visible
        property int bouncingCount: 0
        readonly property bool keepPanelOpen: windowPreview.visible || launcher.visible || widgetPopup.visible || contextMenuOpen || bouncingCount > 0

        // windows of a task: one entry per window (children of a group)
        function windowsOf(task) {
            const list = [];
            const add = (idx, row, child) => {
                const ids = tasksModel.data(idx, TaskManager.AbstractTasksModel.WinIdList) || [];
                if (ids.length === 0)
                    return;
                list.push({
                    uuid: String(ids[0]),
                    title: tasksModel.data(idx, Qt.DisplayRole) || "",
                    icon: tasksModel.data(idx, Qt.DecorationRole),
                    active: tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive) === true,
                    row: row, child: child
                });
            };
            if (task.model.IsGroupParent) {
                for (let c = 0; c < task.model.ChildCount; c++)
                    add(tasksModel.makeModelIndex(task.index, c), task.index, c);
            } else {
                add(tasksModel.makeModelIndex(task.index), task.index, -1);
            }
            return list;
        }

        property Item shownPreviewTask: null

        function previewAnchorTop(task) {
            const zoomedTop = dock.barY + dock.pad + dock.baseIcon - dock.iconMax;
            const iconTop = task ? Math.min(zoomedTop, task.y) : zoomedTop;
            return dock.mapToGlobal(0, Math.min(glass.y, iconTop)).y;
        }

        function showPreviewFor(task) {
            const wins = windowsOf(task);
            if (wins.length === 0) {
                hidePreview();
                return;
            }
            previewTask = task;
            shownPreviewTask = task;
            const ids = wins.map(w => w.uuid + "|" + w.title + "|" + w.active).join(",");
            const oldIds = windowPreview.windows.map(w => w.uuid + "|" + w.title + "|" + w.active).join(",");
            if (ids !== oldIds)
                windowPreview.windows = wins;
            const p = task.mapToGlobal(task.width / 2, 0);
            windowPreview.anchorX = p.x;
            windowPreview.anchorTop = previewAnchorTop(task);
            if (windowPreview.visible) {
                windowPreview.reposition();
            } else {
                // let the cards get their size first, so the window appears in
                // its final place instead of jumping there
                previewRevealTimer.restart();
            }
        }
        function hidePreview() {
            previewShowTimer.stop();
            previewSwitchTimer.stop();
            previewHideTimer.stop();
            previewRevealTimer.stop();
            windowPreview.visible = false;
            // drop the cards: their window screencasts stop with them
            windowPreview.windows = [];
            previewTask = null;
            shownPreviewTask = null;
        }
        Timer {
            id: previewRevealTimer
            interval: 30
            onTriggered: {
                if (!dock.previewTask)
                    return;
                windowPreview.anchorX = dock.previewTask.mapToGlobal(dock.previewTask.width / 2, 0).x;
                windowPreview.anchorTop = dock.previewAnchorTop(dock.previewTask);
                windowPreview.reposition();
                windowPreview.visible = true;
                windowPreview.reposition();
            }
        }
        // called by the task icons
        function previewEnter(task) {
            if (!cfg.showPreviews || dragging || contextMenuOpen)
                return;
            if (task.isLauncher) {
                previewLeave(null);
                return;
            }
            previewHideTimer.stop();
            previewTask = task;
            if (windowPreview.visible) {
                if (shownPreviewTask === task)
                    showPreviewFor(task);
                else
                    previewSwitchTimer.restart();
            } else {
                previewShowTimer.restart();
            }
        }
        function previewLeave(task) {
            if (task && previewTask !== task)
                return;
            previewShowTimer.stop();
            previewSwitchTimer.stop();
            if (previewRevealTimer.running)
                hidePreview();
            else if (windowPreview.visible)
                previewHideTimer.restart();
        }

        Timer {
            id: previewShowTimer
            interval: 450
            onTriggered: if (dock.previewTask) dock.showPreviewFor(dock.previewTask)
        }
        Timer {
            id: previewSwitchTimer
            interval: 120
            onTriggered: if (dock.previewTask) dock.showPreviewFor(dock.previewTask)
        }
        Timer {
            id: previewHideTimer
            interval: 280
            onTriggered: {
                if (windowPreview.hovered || (dock.previewTask && dock.previewTask.hovered))
                    return;
                dock.hidePreview();
            }
        }

        WindowPreview {
            id: windowPreview
            screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
            thumbWidth: dock.cfg.previewWidth
            style: dock.cfg.dockStyle
            backgroundOpacity: dock.cfg.glassOpacity
            radius: dock.cfg.cornerRadius
            themeMode: dock.cfg.themeMode
            isDark: dock.isDark
            accent: dock.accent
            accentTint: dock.cfg.glassAccentTint
            showBorder: dock.cfg.showBorder
            showShadow: dock.cfg.showShadow
            blurBehind: dock.blurOn
            frost: dock.cfg.blurFrost
            onHoveredChanged: hovered ? previewHideTimer.stop() : dock.previewLeave(null)
            onActivateRequested: uuid => {
                const idx = dock.indexOfWindow(uuid);
                if (idx)
                    tasksModel.requestActivate(idx);
                dock.hidePreview();
            }
            onCloseRequested: uuid => {
                const idx = dock.indexOfWindow(uuid);
                if (idx)
                    tasksModel.requestClose(idx);
                // the card goes away when the window leaves the model (see the
                // refresh below); hide the card right away so it doesn't linger
                windowPreview.windows = windowPreview.windows.filter(w => w.uuid !== uuid);
                if (windowPreview.windows.length === 0)
                    dock.hidePreview();
            }
        }

        // model index of a window, found by its uuid at the moment it is needed
        // (rows shift when other apps open or close while the previews are open)
        function indexOfWindow(uuid) {
            const has = idx => {
                const ids = tasksModel.data(idx, TaskManager.AbstractTasksModel.WinIdList) || [];
                for (let k = 0; k < ids.length; k++)
                    if (String(ids[k]) === uuid)
                        return true;
                return false;
            };
            for (let r = 0; r < tasksModel.count; r++) {
                const idx = tasksModel.makeModelIndex(r);
                const children = tasksModel.data(idx, TaskManager.AbstractTasksModel.ChildCount) || 0;
                if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsGroupParent) && children > 0) {
                    for (let c = 0; c < children; c++) {
                        const cidx = tasksModel.makeModelIndex(r, c);
                        if (has(cidx))
                            return cidx;
                    }
                } else if (has(idx)) {
                    return idx;
                }
            }
            return null;
        }

        // keep open previews in sync with the model (windows opened/closed,
        // apps moved, active window changed)
        onModelRevisionChanged: previewSyncTimer.restart()
        onActiveRevisionChanged: previewSyncTimer.restart()
        Timer {
            id: previewSyncTimer
            interval: 120
            onTriggered: {
                if (!windowPreview.visible)
                    return;
                if (!dock.previewTask) {
                    dock.hidePreview();
                    return;
                }
                dock.showPreviewFor(dock.previewTask);
            }
        }

        property Item dragItem: null    // delegate being dragged (identity survives moves)
        property Item droppedItem: null // just released: animates into its slot
        property real dragX: 0          // pointer x (dock coordinates)
        property real dragY: 0          // pointer y (dock coordinates)
        property bool dragOutToUnpin: false
        readonly property bool dragging: dragItem !== null

        function reorderTo(from, px) {
            const b = baseIcon, sp = spacing;
            const left0 = (width - restWidth) / 2;
            // nearest resting slot (separators make the steps uneven)
            let slotAt = 0, best = Infinity;
            for (let i = 0; i < slots; i++) {
                const d = Math.abs(px - (left0 + restOffsets[i] + b / 2));
                if (d < best) { best = d; slotAt = i; }
            }
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
            dragOutToUnpin = false;
            dropTimer.restart();
            tasksModel.syncLaunchers(); // saves the new order of pinned apps
        }

        Timer {
            id: dropTimer
            interval: 220
            onTriggered: dock.droppedItem = null
        }

        readonly property bool isDark: themeScope.isDark

        // --- mouse tracking and zoom amount (0..1, animated)
        property real mouseX: -100000
        property bool pointerOverBar: false
        property real zoom: (pointerOverBar || dragging) && !contextMenuOpen ? 1 : 0
        property bool contextMenuOpen: false
        Behavior on zoom {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        function updatePointerOverBar() {
            if (!hover.hovered) {
                pointerOverBar = false;
                return;
            }
            const p = hover.point.position;
            const top = zoom > 0.01 ? dock.barY - (dock.iconMax - dock.baseIcon) - 2 : dock.barY - 2;
            const inside = p.x >= glass.x && p.x <= glass.x + glass.width
                && p.y >= top && p.y <= dock.height;
            pointerOverBar = inside;
            if (inside && !dock.dragging) {
                const qx = Math.round(p.x * 2) / 2;
                if (Math.abs(qx - dock.mouseX) >= 0.5)
                    dock.mouseX = qx;
            }
        }

        HoverHandler {
            id: hover
            // while dragging, mouseX is driven by the (clamped) drag position;
            // onPointChanged fires once per pointer event instead of twice (x + y)
            onPointChanged: dock.updatePointerOverBar()
            onHoveredChanged: dock.updatePointerOverBar()
        }

        // External drag-and-drop: drop a .desktop file to pin it, or drop
        // files/URLs onto an app icon to open them with that app.
        DropArea {
            anchors.fill: parent
            onEntered: drag => {
                if (drag.hasUrls) {
                    dock.pointerOverBar = true;
                    dock.mouseX = Math.round(drag.x * 2) / 2;
                }
            }
            onPositionChanged: drag => {
                if (drag.hasUrls) {
                    dock.pointerOverBar = true;
                    dock.mouseX = Math.round(drag.x * 2) / 2;
                }
            }
            onExited: dock.updatePointerOverBar()
            onDropped: drop => {
                dock.updatePointerOverBar();
                if (!drop.hasUrls || !drop.urls || drop.urls.length === 0)
                    return;
                const launchers = [];
                const files = [];
                for (let i = 0; i < drop.urls.length; i++) {
                    const u = drop.urls[i];
                    const s = u.toString();
                    if (/\.desktop(\?.*)?$/i.test(s) || s.startsWith("applications:"))
                        launchers.push(u);
                    else
                        files.push(u);
                }
                if (launchers.length > 0 && files.length === 0) {
                    for (let i = 0; i < launchers.length; i++)
                        tasksModel.requestAddLauncher(launchers[i]);
                    drop.acceptProposedAction();
                    return;
                }
                // Find the task icon under drop.x
                let bestTask = null;
                let bestDist = Infinity;
                for (let i = 0; i < taskRepeater.count; i++) {
                    const item = taskRepeater.itemAt(i);
                    if (!item || !item.visible)
                        continue;
                    const cx = item.x + item.width / 2;
                    const d = Math.abs(drop.x - cx);
                    if (d <= item.width / 2 + dock.spacing / 2 + dock.pad && d < bestDist) {
                        bestDist = d;
                        bestTask = item;
                    }
                }
                if (bestTask) {
                    bestTask.startLaunchBounce();
                    tasksModel.requestOpenUrls(bestTask.modelIndex(), drop.urls);
                    drop.acceptProposedAction();
                }
            }
        }

        // --- layout: size and position of each icon
        // centeredZoom: the bar grows evenly from the screen center, so it does
        // not slide sideways while the mouse moves over it. Otherwise the point
        // under the cursor stays put (the bar shifts to follow it).
        readonly property var layout: {
            const n = slots, b = baseIcon, sp = spacing;
            const R = b * cfg.zoomRange;
            const z = (maxZoom - 1) * zoom;          // 0..maxZoom-1, animated
            const mx = z > 0 ? mouseX : 0;
            const left0 = (width - restWidth) / 2;
            const center = i => left0 + (restOffsets[i] || 0) + b / 2;
            const g = d => d < R ? (Math.cos(Math.PI * d / R) + 1) / 2 : 0;
            const zoomable = i => !(i === 0 && offset === 1 && !cfg.appsButtonZoom);

            // Pointer position used for the zoom, kept within the icons that can
            // zoom: over the (non-zooming) apps button or past the last icon the
            // dock behaves as if the pointer were on the nearest app, so the bar
            // does not shrink and grow again when moving between them.
            const firstZ = zoomable(0) ? 0 : Math.min(1, n - 1);
            const zx = n > 0 && cfg.centeredZoom
                ? Math.max(center(firstZ), Math.min(center(n - 1), mx)) : mx;

            // extra width of each icon for the current pointer position
            let extras = [], sumE = 0;
            for (let i = 0; i < n; i++) {
                const rawE = zoomable(i) ? b * z * g(Math.abs(zx - center(i))) : 0;
                const e = rawE < 0.05 ? 0 : rawE;
                extras.push(e);
                sumE += e;
            }

            // Centered zoom: keep the total extra (= the bar width) the same as
            // with the pointer in the middle of the icons, so the bar edges don't
            // "breathe" while the pointer moves along it. Near the ends, where
            // fewer neighbours are magnified, the magnified ones grow a bit more
            // to make up the difference ("water-filling"), never beyond the
            // maximum zoom. (Simulated: width varies < 0.1 px end to end.)
            if (cfg.centeredZoom && sumE > 0 && n > 1) {
                const first = zoomable(0) ? 0 : 1;
                const mid = (center(first) + center(n - 1)) / 2;
                let target = 0;
                for (let i = 0; i < n; i++)
                    if (zoomable(i))
                        target += b * z * g(Math.abs(mid - center(i)));
                const cap = b * z;
                for (let pass = 0; pass < 16; pass++) {
                    let capped = 0, free = 0;
                    for (let i = 0; i < n; i++) {
                        if (extras[i] >= cap - 1e-6) capped += extras[i];
                        else free += extras[i];
                    }
                    if (free <= 1e-9 || Math.abs(target - capped - free) < 0.0005)
                        break;
                    const k = (target - capped) / free;
                    for (let i = 0; i < n; i++)
                        if (extras[i] < cap - 1e-6)
                            extras[i] = Math.min(cap, extras[i] * k);
                }
                sumE = 0;
                for (let i = 0; i < n; i++)
                    sumE += extras[i];
            }

            let sizes = [], leftExtra = 0;
            for (let i = 0; i < n; i++) {
                const s = b + extras[i];
                const restX = center(i) - b / 2;
                if (extras[i] > 0)
                    leftExtra += extras[i] * Math.max(0, Math.min(1, (mx - restX) / b));
                sizes.push(s);
            }
            const iconsTotal = n * b + sumE + sp * Math.max(0, n - 1) + gapsTotal;
            const total = iconsTotal + widgetsWidthAnimated;
            const x0 = cfg.centeredZoom ? (width - total) / 2 : left0 - leftExtra;
            let xs = [], x = x0;
            let seps = [];       // x of each separator line
            for (let i = 0; i < n; i++) {
                xs.push(x);
                x += sizes[i] + sp;
                const gap = gapAfter[i] || 0;
                if (gap > 0) {
                    seps.push(x - sp / 2 + gap / 2);
                    x += gap;
                }
            }
            const iconsEnd = x0 + iconsTotal;
            // real extent of the icons (the bar is drawn around it)
            const first = n > 0 ? xs[0] : x0;
            const last = n > 0 ? xs[n - 1] + sizes[n - 1] : x0;
            return { sizes: sizes, xs: xs, total: total, x0: x0, separators: seps,
                     firstX: Math.min(x0, first), lastX: Math.max(x0 + total, last + widgetsWidthAnimated),
                     iconsEnd: iconsEnd, widgetsX: iconsEnd + sepGap };
        }

        // Watchdog: if an icon ever ends up outside the bar or the widget, log the
        // numbers (journalctl --user | grep Glasdock) so the cause can be found.
        onSlotsChanged: if (dock.visible && taskRepeater.count > 0) watchdogTimer.restart()
        Timer {
            id: watchdogTimer
            interval: 300
            onTriggered: {
                const li = taskRepeater.itemAt(taskRepeater.count - 1);
                if (!li || !li.visible || dock.dragging)
                    return;
                const right = li.x + li.width;
                if (right > glass.x + glass.width + 1 || right > dock.width + 1)
                    console.warn("Glasdock: icon outside the bar: icon " + li.x.toFixed(0) + ".." + right.toFixed(0)
                        + " bar " + glass.x + ".." + (glass.x + glass.width) + " widget " + dock.width.toFixed(0)
                        + " needed " + dock.Layout.minimumWidth.toFixed(0) + " slots " + dock.slots
                        + " sizes " + dock.layout.sizes.length);
            }
        }

        // ------------------------------------------------------- glass bar
        Item {
            id: glass
            // both edges rounded from the same positions (rounding x and width
            // separately made the right edge flicker by a pixel)
            // always around every icon, from the icons' actual positions
            readonly property real leftEdge: Math.round(dock.layout.firstX - dock.pad)
            readonly property real rightEdge: Math.round(Math.max(dock.layout.lastX, dock.layout.firstX + dock.baseIcon) + dock.pad)
            x: leftEdge
            y: dock.barY
            width: rightEdge - leftEdge
            height: dock.barHeight

            Widgets.GlassSurface {
                anchors.fill: parent
                blurBehind: dock.blurOn
                frost: dock.cfg.blurFrost
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

        // ----------------------------------------------------- separators
        Repeater {
            // a count, not the positions array: the array is new on every pointer
            // move, which made the Repeater destroy and recreate every line
            model: dock.layout.separators.length
            delegate: Rectangle {
                required property int index
                x: Math.round(dock.layout.separators[index] || 0)
                y: dock.barY + dock.barHeight * 0.16
                width: 1
                height: dock.barHeight * 0.68
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.25; color: dock.isDark ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(0, 0, 0, 0.22) }
                    GradientStop { position: 0.75; color: dock.isDark ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(0, 0, 0, 0.22) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
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
            activeFocusOnTab: visible
            Accessible.role: Accessible.Button
            Accessible.name: i18n("Applications")
            Keys.onReturnPressed: dock.toggleLauncher()
            Keys.onSpacePressed: dock.toggleLauncher()

            Kirigami.Icon {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: dock.iconMax
                height: dock.iconMax
                property real pressScale: appsMouse.pressed ? 0.90 : 1.0
                Behavior on pressScale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                scale: (appsButton.size / dock.iconMax) * pressScale
                transformOrigin: Item.Bottom
                source: dock.cfg.appsButtonIcon
                opacity: appsMouse.pressed ? 0.85 : 1
                Behavior on opacity { NumberAnimation { duration: 90 } }
            }

            MouseArea {
                id: appsMouse
                // same hit area rules as the app icons
                anchors.fill: parent
                anchors.leftMargin: -dock.pad
                anchors.rightMargin: -(dock.slots === 1 ? dock.pad : dock.spacing / 2)
                anchors.topMargin: Math.min(0, dock.barY - appsButton.y)
                anchors.bottomMargin: -dock.pad
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        dock.hidePreview();
                        appsMenu.openRelative();
                        dock.contextMenuOpen = true;
                    } else {
                        dock.toggleLauncher();
                    }
                }
            }

            PlasmaExtras.Menu {
                id: appsMenu
                visualParent: appsButton
                placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
                onStatusChanged: if (status === PlasmaExtras.Menu.Closed) dock.contextMenuOpen = false
                PlasmaExtras.MenuItem {
                    readonly property bool has: dock.hasSeparatorAfter("@apps")
                    text: has ? i18n("Remove Separator After") : i18n("Add Separator After")
                    icon: has ? "edit-delete-remove" : "distribute-horizontal-x"
                    onClicked: dock.toggleSeparatorAfter("@apps")
                }
                PlasmaExtras.MenuItem {
                    text: i18n("Configure Glasdock…")
                    icon: "configure"
                    onClicked: Plasmoid.internalAction("configure").trigger()
                }
            }
        }

        // ------------------------------------------------------- launcher
        Component.onCompleted: {
            root.dockItem = dock;
            panelResizeTimer.restart();
        }

        property double launcherHiddenAt: 0
        // The launcher (and its app/search models) is created on first use, not at
        // Plasma startup.
        readonly property Item launcherView: launcherLoader.item

        function toggleLauncher() {
            if (!launcherLoader.active)
                launcherLoader.active = true;
            if (!launcherView)
                return;
            // a click on the button first deactivates the popup (which starts
            // closing it); don't reopen it right away
            if (launcherView.closing || Date.now() - launcherHiddenAt < 250)
                return;
            if (launcher.visible) {
                launcherView.playClose();
                return;
            }
            hidePreview();
            launcherView.reset();
            launcherView.prepareClosedState();
            launcher.visible = true;
            launcher.reposition();
            launcher.requestActivate();
            launcherView.playOpen();
        }

        PlasmaCore.Dialog {
            id: launcher
            type: PlasmaCore.Dialog.AppletPopup
            flags: Qt.WindowStaysOnTopHint
            // With the theme background, BottomEdge lets KWin's "Sliding popups"
            // effect slide the whole window (frame + blur) up from the dock. The
            // custom glass background is animated entirely by Launcher.qml.
            readonly property bool kwinSlides: false   // animated by Launcher.qml
            location: PlasmaCore.Types.Floating
            // closing on deactivation is animated (onActiveChanged) instead
            hideOnWindowDeactivate: !dock.cfg.launcherAnimation
            onActiveChanged: if (!active && visible && dock.launcherView) dock.launcherView.playClose()
            backgroundHints: PlasmaCore.Dialog.NoBackground
            visible: false

            onVisibleChanged: {
                if (!visible)
                    dock.launcherHiddenAt = Date.now();
            }
            onWidthChanged: if (visible) reposition()
            onHeightChanged: if (visible) reposition()

            property int morphBottomSlack: 0

            // centered over the glass bar, cfg.launcherGap px above it
            function reposition() {
                const p = dock.mapToGlobal(glass.x + glass.width / 2, glass.y);
                const contentW = dock.cfg.launcherWidth;
                const contentH = dock.cfg.launcherHeight;
                const w = contentW + margins.left + margins.right;
                const baseH = contentH + margins.top + margins.bottom;
                let nx = Math.round(p.x - w / 2);
                const g = Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0);
                if (g.width > 0) {
                    const margin = Kirigami.Units.smallSpacing * 2;
                    nx = Math.max(g.x + margin, Math.min(g.x + g.width - margin - w, nx));
                }
                const ny = Math.round(p.y - dock.cfg.launcherGap - baseH);
                const availBelow = g.width > 0 ? Math.max(0, (g.y + g.height) - (ny + baseH)) : 48;
                morphBottomSlack = dock.cfg.launcherMorph
                    ? Math.min(availBelow, Math.max(0, dock.cfg.launcherGap + 28))
                    : 0;
                x = nx;
                y = ny;

                if (dock.launcherView) {
                    const startW = Math.min(contentW, Math.max(24, Math.round(dock.baseIcon)));
                    const startH = Math.min(contentH, Math.min(40, Math.max(24, Math.round(dock.baseIcon * 0.72))));
                    const localOriginX = p.x - nx - margins.left;
                    const localDockTopY = p.y - ny - margins.top;
                    dock.launcherView.morphStartX = Math.max(2, Math.min(contentW - startW - 2, localOriginX - startW / 2));
                    const maxStartY = Math.max(2, (contentH + morphBottomSlack) - startH - 2);
                    dock.launcherView.morphStartY = Math.max(2, Math.min(maxStartY, localDockTopY - startH - dock.cfg.launcherMorphGap));
                    dock.launcherView.morphStartW = startW;
                    dock.launcherView.morphStartH = startH;
                }
            }

            mainItem: Loader {
                id: launcherLoader
                active: false
                width: dock.cfg.launcherWidth
                height: dock.cfg.launcherHeight + launcher.morphBottomSlack
                sourceComponent: Launcher {
                width: launcherLoader.width
                height: launcherLoader.height
                contentHeight: dock.cfg.launcherHeight
                appletInterface: root
                iconSize: dock.cfg.launcherIconSize
                style: dock.cfg.launcherStyle === 4 ? 0 : dock.cfg.launcherStyle
                // launcherBlur: 0 = same as the dock, 1 = on, 2 = off
                blurBehind: dock.cfg.launcherBlur === 1 ? true
                          : dock.cfg.launcherBlur === 2 ? false
                          : (dock.blurOn || dock.cfg.launcherStyle === 4)
                frost: dock.cfg.launcherBlur === 0 ? dock.cfg.blurFrost : dock.cfg.launcherFrost
                radius: dock.cfg.cornerRadius + 4
                accent: dock.accent
                accentTint: dock.cfg.glassAccentTint
                showBorder: dock.cfg.showBorder
                backgroundOpacity: dock.cfg.launcherOpacity
                themeMode: dock.cfg.themeMode
                isDark: dock.isDark
                frameMargins: launcher.margins
                animated: dock.cfg.launcherAnimation
                animationDuration: dock.cfg.launcherAnimationDuration
                morph: dock.cfg.launcherMorph
                windowSlides: launcher.kwinSlides
                onCloseRequested: playClose()
                onCloseFinished: launcher.visible = false
                onRunCommand: cmd => executable.run(cmd)
                onPinRequested: url => tasksModel.requestAddLauncher(url)
                }
            }
        }

        // ------------------------------------------------------------ widgets
        Rectangle {
            // separator between apps and widgets
            visible: dock.widgetsWidth > 0
            x: Math.round(dock.layout.iconsEnd + dock.sepGap / 2)
            y: dock.barY + dock.barHeight * 0.16
            width: 1
            height: dock.barHeight * 0.68
            gradient: Gradient {
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.25; color: dock.isDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.20) }
                GradientStop { position: 0.75; color: dock.isDark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.20) }
                GradientStop { position: 1.0; color: "transparent" }
            }
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
                visible: dock.showPlayerTile
                width: Math.round(dock.baseIcon * 3.8)
                height: parent.height
                isDark: dock.isDark
                player: root.activePlayer
                active: dock.popupOpenFor(playerTile)
                onHoveredChanged: {
                    if (hovered && root.activePlayer)
                        root.activePlayer.updatePosition();
                    if (hovered && !widgetPopup.visible)
                        widgetPopupLoader.sourceComponent = playerPopupComponent;
                }
                onClicked: {
                    if (root.activePlayer)
                        root.activePlayer.updatePosition();
                    dock.toggleWidgetPopup(playerTile, playerPopupComponent);
                }
            }
            Widgets.WeatherTile {
                id: weatherTile
                visible: dock.cfg.showWeather
                width: Math.round(dock.baseIcon * 2.4)
                height: parent.height
                isDark: dock.isDark
                weather: root.weatherData
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

        Component { id: playerPopupComponent; Widgets.PlayerPopup { player: root.activePlayer; accent: dock.accent; isDark: dock.isDark; cardRadius: dock.cfg.cornerRadius + 4; showWaves: dock.cfg.showPlayerWaves; onCloseRequested: popupFrame.playClose() } }
        Component { id: weatherPopupComponent; Widgets.WeatherPopup { weather: root.weatherData; accent: dock.accent; isDark: dock.isDark } }
        Component { id: clockPopupComponent; Widgets.ClockPopup { now: root.now; accent: dock.accent; isDark: dock.isDark } }

        property double widgetPopupHiddenAt: 0
        readonly property bool clockPopupOpen: popupOpenFor(clockTile)
        onClockPopupOpenChanged: if (clockPopupOpen) root.now = new Date()
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
            hidePreview();
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
            // drawn by GlassSurface so the panels match the dock; Blur style uses
            // Plasma's own (blurred) background instead
            backgroundHints: PlasmaCore.Dialog.NoBackground
            visible: false

            onVisibleChanged: {
                if (!visible) {
                    dock.widgetPopupHiddenAt = Date.now();
                    // destroy the panel content: no timers/bindings left running
                    // (e.g. the player's position polling) while it is closed
                    widgetPopupLoader.sourceComponent = undefined;
                } else
                    popupFrame.playOpen();
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
                const w = popupFrame.width, h = popupFrame.height;
                const m = popupFrame.shadowMargin;
                let nx = Math.round(p.x - w / 2);
                const g = Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0);
                if (g.width > 0) {
                    const margin = Kirigami.Units.smallSpacing * 2;
                    nx = Math.max(g.x + margin - m, Math.min(g.x + g.width - margin + m - w, nx));
                }
                x = nx;
                y = Math.round(top - dock.cfg.launcherGap - h + m);
            }

            mainItem: Item {
                id: popupFrame
                Widgets.ThemeScope { target: popupFrame; themeMode: dock.cfg.themeMode }
                readonly property int shadowMargin: 28
                readonly property int padding: dock.widgetPopupAnchor === playerTile ? 0 : Kirigami.Units.gridUnit
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

                    Widgets.GlassSurface {
                        anchors.fill: parent
                        blurBehind: dock.blurOn
                        frost: dock.cfg.blurFrost
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
                readonly property bool laidOut: slot < dock.slots
                visible: laidOut
                readonly property real size: dock.layout.sizes[slot] ?? dock.baseIcon
                readonly property bool isLauncher: model.IsLauncher === true
                readonly property int badgeCount: root.badgeFor(model.AppId, model.LauncherUrlWithoutIcon)
                readonly property var desktopActions: root.appActions[root.appKey(model.LauncherUrlWithoutIcon || model.AppId)] || []
                readonly property alias hovered: mouse.containsMouse

                activeFocusOnTab: visible
                Accessible.role: Accessible.Button
                Accessible.name: task.model.AppName || task.model.display || ""
                Keys.onReturnPressed: task.activate()
                Keys.onSpacePressed: task.activate()

                Component.onDestruction: {
                    if (dock.previewTask === task)
                        dock.hidePreview();
                    // the app quit (or was closed from this menu) while its menu
                    // was open: the menu's Closed status may never arrive, which
                    // left the dock without zoom and the panel unable to hide
                    if (menu.status !== PlasmaExtras.Menu.Closed)
                        dock.contextMenuOpen = false;
                    if (isBouncing)
                        dock.bouncingCount = Math.max(0, dock.bouncingCount - 1);
                }
                property real bounce: 0
                property bool launching: false
                readonly property bool isBouncing: bounceAnim.running
                onIsBouncingChanged: {
                    if (isBouncing)
                        dock.bouncingCount++;
                    else
                        dock.bouncingCount = Math.max(0, dock.bouncingCount - 1);
                }

                readonly property bool dragged: dock.dragItem === task
                x: dragged ? dock.dragX - width / 2 : (dock.layout.xs[slot] ?? 0)
                Behavior on x {
                    // the other icons slide into their new places while dragging
                    enabled: (dock.dragging && !task.dragged) || dock.droppedItem === task
                    NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
                }
                y: (dragged && dock.dragOutToUnpin)
                    ? Math.min(dock.barY + dock.pad + dock.baseIcon - size, dock.dragY - height / 2)
                    : (dock.barY + dock.pad + dock.baseIcon - size - bounce)
                width: size
                height: size
                z: dragged ? 20 : (mouse.containsMouse ? 10 : 1)
                opacity: dragged ? (dock.dragOutToUnpin ? 0.45 : 0.85) : 1

                onIsLauncherChanged: {
                    if (!isLauncher) {
                        launching = false;
                        launchTimer.stop();
                    }
                }

                function modelIndex(child) {
                    return tasksModel.makeModelIndex(index, child === undefined ? -1 : child);
                }

                function publishGeometry() {
                    // resting position, used by KWin's minimize animation
                    if (!dock || !task || index < 0)
                        return; // delegate already destroyed (model changed)
                    const restX = (dock.width - dock.restWidth) / 2 + (dock.restOffsets[slot] || 0);
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

                Component.onCompleted: {
                    Qt.callLater(publishGeometry);
                    root.ensureAppActions(model.AppId, model.LauncherUrlWithoutIcon);
                }

                Timer {
                    id: launchTimer
                    interval: 2400
                    onTriggered: task.launching = false
                }

                // bounce (app launching or demanding attention). Both are capped:
                // a launch bounces for at most ~2.4 s, an attention request three
                // times, so a stuck flag never keeps the dock repainting forever.
                readonly property bool startup: model.IsStartup === true
                readonly property bool attention: model.IsDemandingAttention === true
                property int attentionLeft: 0
                onStartupChanged: if (startup) startLaunchBounce()
                onAttentionChanged: attentionLeft = attention ? 3 : 0
                SequentialAnimation {
                    id: bounceAnim
                    loops: Animation.Infinite
                    alwaysRunToEnd: true
                    running: task.launching || task.attentionLeft > 0
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
                    ScriptAction {
                        script: if (task.attentionLeft > 0) task.attentionLeft--
                    }
                }

                Kirigami.Icon {
                    id: icon
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    // rendered at max size and scaled down: sharp and cheap
                    width: dock.iconMax
                    height: dock.iconMax
                    property real pressScale: mouse.pressed && !task.dragged ? 0.90 : (task.dragged ? 1.06 : 1.0)
                    Behavior on pressScale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    scale: (task.size / dock.iconMax) * pressScale
                    transformOrigin: Item.Bottom
                    source: task.model.decoration
                    opacity: mouse.pressed && !task.dragged ? 0.85 : 1
                    Behavior on opacity { NumberAnimation { duration: 90 } }
                }

                // notification badge (top-right of the icon):
                // a plain dot for a single notification, the number when there are more
                Kirigami.ShadowedRectangle {
                    id: badge
                    readonly property bool shown: dock.cfg.showBadges && task.badgeCount > 0 && !task.dragged
                    readonly property bool numeric: task.badgeCount > 1
                    readonly property real h: shown ? Math.max(14, Math.round(task.size * 0.34)) : 14
                    readonly property real dotSize: shown ? Math.max(8, Math.round(h * 0.55)) : 8
                    height: numeric ? h : dotSize
                    width: numeric && shown ? Math.max(h, badgeText.implicitWidth + h * 0.55) : dotSize
                    radius: height / 2
                    x: !shown ? 0 : (numeric ? task.width - width * 0.8 : task.width - width * 0.9)
                    y: !shown ? 0 : (numeric ? -h * 0.15 : -dotSize * 0.1)
                    z: 5
                    // system accent color by default (red is the alternative)
                    color: dock.cfg.badgeUseAccent ? dock.accent : "#ff3b30"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.32)
                    shadow.size: 8
                    shadow.yOffset: 2
                    shadow.color: Qt.rgba(0, 0, 0, 0.38)
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
                // (1 dot for 1 window, 2 for 2 windows, 3 for 3+ windows;
                //  the active window's dot expands into a glowing pill)
                Item {
                    id: indicator
                    visible: !task.isLauncher && !task.dragged
                    readonly property bool rawActive: task.model.IsActive === true
                    property bool active: rawActive
                    onRawActiveChanged: {
                        if (rawActive) {
                            deactivateTimer.stop();
                            active = true;
                        } else {
                            deactivateTimer.restart();
                        }
                    }
                    Timer {
                        id: deactivateTimer
                        interval: 60
                        onTriggered: indicator.active = indicator.rawActive
                    }

                    readonly property int winCount: {
                        const c = task.model.ChildCount || 0;
                        return c > 1 ? c : 1;
                    }
                    readonly property int dotCount: Math.min(winCount, 3)

                    property int activeSlot: 0
                    readonly property int currentChildSlot: {
                        const n = task.model.ChildCount || 0;
                        if (n <= 1)
                            return 0;
                        dock.activeRevision;
                        for (let c = 0; c < n; c++) {
                            if (tasksModel.data(task.modelIndex(c), TaskManager.AbstractTasksModel.IsActive))
                                return c % dotCount;
                        }
                        return -1;
                    }
                    onCurrentChildSlotChanged: {
                        if (currentChildSlot >= 0)
                            activeSlot = currentChildSlot;
                    }
                    onDotCountChanged: {
                        if (activeSlot >= dotCount)
                            activeSlot = Math.max(0, dotCount - 1);
                    }

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -(dock.pad / 2 + 2.5 + task.bounce)
                    width: dotsRow.width
                    height: 5

                    Row {
                        id: dotsRow
                        anchors.centerIn: parent
                        spacing: 4

                        Repeater {
                            model: indicator.dotCount
                            delegate: Rectangle {
                                required property int index
                                readonly property bool isCurrent: indicator.active && index === indicator.activeSlot
                                width: isCurrent ? (indicator.dotCount === 1 ? 14 : (indicator.dotCount === 2 ? 10 : 8)) : 4.5
                                height: 4.5
                                radius: 2.25
                                color: dock.detailColor
                                opacity: isCurrent ? 1.0 : 0.62
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: parent.width + 3
                                    height: parent.height + 3
                                    radius: height / 2
                                    color: dock.detailColor
                                    opacity: parent.isCurrent && dock.cfg.useAccentColor ? 0.24 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    z: -1
                                }
                            }
                        }
                    }
                }

                // app name on hover or keyboard focus
                Kirigami.ShadowedRectangle {
                    id: label
                    readonly property bool shown: ((dock.cfg.showLabels && mouse.containsMouse) || task.activeFocus)
                                                  && !(dock.previewOpen && dock.previewTask === task)
                                                  && !dock.contextMenuOpen && !dock.dragging
                    opacity: shown ? 1 : 0
                    visible: opacity > 0
                    scale: 0.92 + 0.08 * opacity
                    transformOrigin: Item.Bottom
                    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    width: labelText.implicitWidth + Kirigami.Units.largeSpacing * 2
                    height: labelText.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: height / 2
                    x: visible ? (task.width - width) / 2 : 0
                    y: visible ? Math.max(-task.y, -height - Kirigami.Units.smallSpacing * 2) : 0
                    color: dock.isDark ? Qt.rgba(0.10, 0.10, 0.13, 0.88) : Qt.rgba(1, 1, 1, 0.88)
                    border.width: dock.cfg.useAccentColor ? 1 : 0
                    border.color: Qt.rgba(dock.accent.r, dock.accent.g, dock.accent.b, 0.7)
                    shadow.size: 12
                    shadow.yOffset: 3
                    shadow.color: Qt.rgba(0, 0, 0, dock.isDark ? 0.45 : 0.20)

                    Text {
                        id: labelText
                        anchors.centerIn: parent
                        text: task.model.AppName || task.model.display || ""
                        color: dock.isDark ? "white" : "#1d1d1f"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize
                        font.weight: Font.Medium
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
                    anchors.bottomMargin: -(dock.pad + task.bounce)
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                    preventStealing: true

                    onContainsMouseChanged: containsMouse ? dock.previewEnter(task) : dock.previewLeave(task)

                    property point pressPos
                    property bool dragActive: false
                    property bool suppressClick: false

                    onPressed: m => {
                        pressPos = Qt.point(m.x, m.y);
                        dragActive = false;
                        suppressClick = false;
                    }
                    onPositionChanged: m => {
                        if (!(pressedButtons & Qt.LeftButton) || (!dock.cfg.allowReorder && !menu.pinned))
                            return;
                        if (!dragActive && Math.hypot(m.x - pressPos.x, m.y - pressPos.y) > Qt.styleHints.startDragDistance) {
                            dragActive = true;
                            dock.dragItem = task;
                            dock.hidePreview();
                        }
                        if (dragActive) {
                            const p = mapToItem(dock, m.x, m.y);
                            const outsideBar = p.y < glass.y - dock.baseIcon * 0.85
                                || p.x < glass.x - dock.baseIcon * 0.85
                                || p.x > glass.x + glass.width + dock.baseIcon * 0.85;
                            dock.dragOutToUnpin = menu.pinned && outsideBar;
                            dock.dragY = p.y;
                            const x = dock.clampDragX(p.x, task.width);
                            dock.dragX = x;
                            dock.mouseX = x;
                            if (dock.cfg.allowReorder && !dock.dragOutToUnpin)
                                dock.reorderTo(task.index, x);
                        }
                    }
                    onReleased: {
                        if (dragActive) {
                            const unpin = dock.dragOutToUnpin && menu.pinned && menu.launcherUrl !== "";
                            const url = menu.launcherUrl;
                            dragActive = false;
                            suppressClick = true;
                            dock.endDrag();
                            if (unpin)
                                tasksModel.requestRemoveLauncher(url);
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
                        dock.hidePreview();
                        if (mouseEvent.button === Qt.LeftButton) {
                            task.activate();
                        } else if (mouseEvent.button === Qt.MiddleButton) {
                            task.startLaunchBounce();
                            tasksModel.requestNewInstance(task.modelIndex());
                        } else {
                            root.ensureAppActions(task.model.AppId, task.model.LauncherUrlWithoutIcon);
                            menu.openRelative();
                            dock.contextMenuOpen = true;
                        }
                    }
                }

                // .desktop JumpList actions (e.g. "New Private Window")
                Instantiator {
                    model: task.desktopActions
                    delegate: PlasmaExtras.MenuItem {
                        required property var modelData
                        text: modelData.name
                        icon: modelData.icon || task.model.decoration
                        onClicked: {
                            task.startLaunchBounce();
                            executable.run(modelData.exec);
                        }
                    }
                    onObjectAdded: (index, object) => menu.addMenuItem(object, pinMenuItem)
                    onObjectRemoved: (index, object) => menu.removeMenuItem(object)
                }

                // Virtual desktop actions ("Move to Desktop …")
                Instantiator {
                    model: virtualDesktopInfo.numberOfDesktops > 1
                           && (task.model.IsWindow === true || task.model.IsGroupParent === true)
                           ? virtualDesktopInfo.desktopIds : []
                    delegate: PlasmaExtras.MenuItem {
                        required property var modelData
                        required property int index
                        text: i18n("Move to %1", virtualDesktopInfo.desktopNames[index] || (index + 1))
                        checkable: true
                        checked: task.model.IsOnAllVirtualDesktops !== true
                                 && (task.model.VirtualDesktops || []).indexOf(modelData) !== -1
                        onClicked: tasksModel.requestVirtualDesktops(task.modelIndex(), [modelData])
                    }
                    onObjectAdded: (index, object) => menu.addMenuItem(object, allDesktopsItem)
                    onObjectRemoved: (index, object) => menu.removeMenuItem(object)
                }

                PlasmaExtras.Menu {
                    id: menu
                    visualParent: task
                    placement: PlasmaExtras.Menu.TopPosedLeftAlignedPopup
                    onStatusChanged: if (status === PlasmaExtras.Menu.Closed) dock.contextMenuOpen = false

                    readonly property string launcherUrl: task.model.LauncherUrlWithoutIcon ?? ""
                    readonly property bool pinned: launcherUrl !== ""
                        && tasksModel.launcherList.indexOf(launcherUrl.toString()) !== -1
                    readonly property bool hasDesktopNewWindow: task.desktopActions.some(a => a.id === "new-window")

                    PlasmaExtras.MenuItem {
                        text: i18n("New Window")
                        icon: "window-new"
                        visible: task.model.CanLaunchNewInstance === true && !task.isLauncher && !menu.hasDesktopNewWindow
                        onClicked: {
                            task.startLaunchBounce();
                            tasksModel.requestNewInstance(task.modelIndex());
                        }
                    }
                    PlasmaExtras.MenuItem {
                        id: pinMenuItem
                        text: menu.pinned ? i18n("Remove from Dock") : i18n("Keep in Dock")
                        icon: menu.pinned ? "window-unpin" : "window-pin"
                        visible: menu.launcherUrl !== ""
                        onClicked: {
                            if (menu.pinned)
                                tasksModel.requestRemoveLauncher(menu.launcherUrl);
                            else
                                tasksModel.requestAddLauncher(menu.launcherUrl);
                        }
                    }
                    PlasmaExtras.MenuItem {
                        readonly property bool has: dock.hasSeparatorAfter(menu.launcherUrl.toString())
                        text: has ? i18n("Remove Separator After") : i18n("Add Separator After")
                        icon: has ? "edit-delete-remove" : "distribute-horizontal-x"
                        visible: menu.launcherUrl !== "" && task.slot < dock.slots - 1
                        onClicked: dock.toggleSeparatorAfter(menu.launcherUrl.toString())
                    }
                    PlasmaExtras.MenuItem { separator: true }
                    PlasmaExtras.MenuItem {
                        id: allDesktopsItem
                        text: i18n("Show on All Desktops")
                        icon: "virtual-desktops"
                        checkable: true
                        checked: task.model.IsOnAllVirtualDesktops === true
                        visible: virtualDesktopInfo.numberOfDesktops > 1
                                 && (task.model.IsWindow === true || task.model.IsGroupParent === true)
                        onClicked: {
                            if (task.model.IsOnAllVirtualDesktops === true)
                                tasksModel.requestVirtualDesktops(task.modelIndex(), [virtualDesktopInfo.currentDesktop]);
                            else
                                tasksModel.requestVirtualDesktops(task.modelIndex(), []);
                        }
                    }
                    PlasmaExtras.MenuItem {
                        text: task.model.IsMinimized ? i18n("Restore") : i18n("Minimize")
                        icon: "window-minimize"
                        visible: task.model.IsWindow === true || task.model.IsGroupParent === true
                        onClicked: {
                            task.publishGeometry();
                            tasksModel.requestToggleMinimized(task.modelIndex());
                        }
                    }
                    PlasmaExtras.MenuItem {
                        text: task.model.IsGroupParent ? i18n("Close All Windows") : i18n("Close")
                        icon: "window-close"
                        visible: !task.isLauncher
                        onClicked: tasksModel.requestClose(task.modelIndex())
                    }
                    PlasmaExtras.MenuItem { separator: true }
                    PlasmaExtras.MenuItem {
                        text: i18n("Configure Glasdock…")
                        icon: "configure"
                        onClicked: Plasmoid.internalAction("configure").trigger()
                    }
                }
            }
        }
    }
}
