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
        readonly property real restWidth: slots * baseIcon + Math.max(0, slots - 1) * spacing
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
            const hi = layout.x0 + layout.total - w / 2;
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
            const x0 = cfg.centeredZoom ? (width - total) / 2 : left0 - leftExtra;
            let xs = [], x = x0;
            for (let i = 0; i < n; i++) {
                xs.push(x);
                x += sizes[i] + sp;
            }
            return { sizes: sizes, xs: xs, total: total, x0: x0 };
        }

        // ------------------------------------------------------- glass bar
        Item {
            id: glass
            x: Math.round(dock.layout.x0 - dock.pad)
            y: dock.barY
            width: Math.round(Math.max(dock.layout.total, dock.baseIcon) + dock.pad * 2)
            height: dock.barHeight
            readonly property real r: Math.min(dock.cfg.cornerRadius, height / 2)

            // translucent body + border + shadow
            Kirigami.ShadowedRectangle {
                anchors.fill: parent
                radius: glass.r
                color: dock.isDark ? Qt.rgba(0.10, 0.10, 0.12, dock.cfg.glassOpacity + 0.12)
                                   : Qt.rgba(1, 1, 1, dock.cfg.glassOpacity)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, dock.isDark ? 0.18 : 0.45)
                shadow.size: 22
                shadow.yOffset: 6
                shadow.color: Qt.rgba(0, 0, 0, dock.isDark ? 0.45 : 0.22)
            }

            // accent tint
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: glass.r - 1
                color: dock.accent
                opacity: dock.cfg.glassAccentTint
                visible: opacity > 0
            }

            // vertical sheen (light from above)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 1
                radius: glass.r - 1
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, dock.isDark ? 0.16 : 0.38) }
                    GradientStop { position: 0.45; color: Qt.rgba(1, 1, 1, dock.isDark ? 0.04 : 0.08) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
                }
            }

            // specular highlight on the top edge
            Rectangle {
                anchors.top: parent.top
                anchors.topMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - glass.r * 1.4
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, dock.isDark ? 0.55 : 0.9) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            // faint refracted glow on the bottom edge
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 1
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - glass.r * 2
                height: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.22) }
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
            if (launcher.visible || Date.now() - launcherHiddenAt < 250) {
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
            // BottomEdge makes KWin's "Sliding popups" effect slide the whole
            // window (frame + blur) up from the dock
            location: dock.cfg.launcherAnimation ? PlasmaCore.Types.BottomEdge
                                                 : PlasmaCore.Types.Floating
            hideOnWindowDeactivate: true
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
                onCloseRequested: playClose()
                onCloseFinished: launcher.visible = false
                onRunCommand: cmd => executable.run(cmd)
                onPinRequested: url => tasksModel.requestAddLauncher(url)
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
                    anchors.rightMargin: -(task.slot === dock.slots - 1 ? dock.pad : dock.spacing / 2)
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
