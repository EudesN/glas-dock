/*
 * Glasdock — application launcher shown above the dock.
 * Uses the same models as Kickoff/Kicker (favorites, categories, search).
 */
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami
import org.kde.plasma.private.kicker as Kicker
import "shared" as Widgets

Item {
    id: view

    property var appletInterface
    property int iconSize: Kirigami.Units.iconSizes.large

    // Background: the dock's glass (style 0 Glass, 1 Frosted, 2 Clear, 3 Solid;
    // 4, the old "Blur", = Glass with blur), optionally with real blur behind.
    property int style: 0
    property bool blurBehind: false
    property real frost: 0
    property real backgroundOpacity: 0
    property real radius: 22
    property color accent: Kirigami.Theme.highlightColor
    property real accentTint: 0
    property bool showBorder: true
    property int themeMode: 0
    property bool isDark: true
    property var frameMargins: null

    Widgets.ThemeScope {
        target: view
        themeMode: view.themeMode
    }

    signal closeRequested()
    signal closeFinished()

    // ---------------------------------------------------------------- animation
    // Open: fade in and grow out of the dock, then the content below the search
    // field follows a moment later (staggered). When KWin already slides the
    // window (theme background), the content only fades/grows a little, so the
    // two motions do not add up.
    // Close: quick fade/shrink, then closeFinished() hides the window.
    property bool animated: true
    property int animationDuration: 220
    property bool windowSlides: false
    property bool morph: false
    property real contentHeight: height
    property real morphStartX: 0
    property real morphStartY: contentHeight - 36
    property real morphStartW: 48
    property real morphStartH: 36
    // follows Plasma's global animation speed (0 when animations are off)
    readonly property int dur: Math.round(animationDuration * Kirigami.Units.longDuration / 200)
    readonly property bool closing: closeAnim.running || morphClose.running
    property real reveal: 1   // 0..1, content below the search field
    property real t: 1        // 0 = dock-edge pill, 1 = full launcher
    property real morphReveal: 1

    transformOrigin: Item.Bottom
    transform: Translate { id: rise; y: 0 }

    function prepareClosedState() {
        if (!animated || dur < 10)
            return;
        if (morph) {
            opacity = 1; scale = 1; rise.y = 0; reveal = 1;
            morphPanel.opacity = 0;
            morphReveal = 0;
            t = 0;
        } else {
            t = 1;
            morphPanel.opacity = 1;
            morphReveal = 1;
            opacity = 0;
            scale = windowSlides ? 0.98 : 0.94;
            rise.y = windowSlides ? 0 : 16;
            reveal = 0;
        }
    }

    function playOpen() {
        closeAnim.stop();
        morphClose.stop();
        if (morph && animated && dur >= 10) {
            opacity = 1; scale = 1; rise.y = 0; reveal = 1;
            morphPanel.opacity = 0;
            morphReveal = 0;
            t = 0;
            morphOpen.restart();
            return;
        }
        t = 1;
        morphPanel.opacity = 1;
        morphReveal = 1;
        if (!animated || dur < 10) {
            opacity = 1; scale = 1; rise.y = 0; reveal = 1;
            return;
        }
        opacity = 0;
        scale = windowSlides ? 0.98 : 0.94;
        rise.y = windowSlides ? 0 : 16;
        reveal = 0;
        openAnim.restart();
    }

    function playClose() {
        if (closeAnim.running || morphClose.running)
            return;
        openAnim.stop();
        morphOpen.stop();
        if (!animated || dur < 10 || opacity === 0 || (morph && morphPanel.opacity === 0)) {
            closeFinished();
            return;
        }
        if (morph)
            morphClose.restart();
        else
            closeAnim.restart();
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: view; property: "opacity"; to: 1; duration: view.dur * 0.8; easing.type: Easing.OutCubic }
        NumberAnimation { target: view; property: "scale"; to: 1; duration: view.dur; easing.type: Easing.OutBack; easing.overshoot: 1.05 }
        NumberAnimation { target: rise; property: "y"; to: 0; duration: view.dur; easing.type: Easing.OutQuint }
        SequentialAnimation {
            PauseAnimation { duration: view.dur * 0.3 }
            NumberAnimation { target: view; property: "reveal"; to: 1; duration: view.dur; easing.type: Easing.OutCubic }
        }
    }

    ParallelAnimation {
        id: morphOpen
        NumberAnimation { target: morphPanel; property: "opacity"; to: 1; duration: Math.max(25, view.dur * 0.14); easing.type: Easing.OutCubic }
        NumberAnimation { target: view; property: "t"; to: 1; duration: view.dur * 1.35; easing.type: Easing.OutQuart }
        SequentialAnimation {
            PauseAnimation { duration: view.dur * 0.42 }
            NumberAnimation { target: view; property: "morphReveal"; to: 1; duration: view.dur * 0.85; easing.type: Easing.OutCubic }
        }
    }

    SequentialAnimation {
        id: morphClose
        NumberAnimation { target: view; property: "morphReveal"; to: 0; duration: view.dur * 0.30; easing.type: Easing.InCubic }
        ParallelAnimation {
            NumberAnimation { target: view; property: "t"; to: 0; duration: view.dur * 0.95; easing.type: Easing.InOutCubic }
            SequentialAnimation {
                PauseAnimation { duration: view.dur * 0.55 }
                NumberAnimation { target: morphPanel; property: "opacity"; to: 0; duration: view.dur * 0.40; easing.type: Easing.InCubic }
            }
        }
        ScriptAction { script: view.closeFinished() }
    }

    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: view; property: "opacity"; to: 0; duration: view.dur * 0.55; easing.type: Easing.InCubic }
            NumberAnimation { target: view; property: "scale"; to: 0.97; duration: view.dur * 0.55; easing.type: Easing.InCubic }
            NumberAnimation { target: rise; property: "y"; to: view.windowSlides ? 0 : 8; duration: view.dur * 0.55; easing.type: Easing.InCubic }
        }
        ScriptAction { script: view.closeFinished() }
    }

    signal runCommand(string cmd)
    signal pinRequested(string launcherUrl)

    // -1 = Favorites, otherwise a row of rootModel (All Applications, categories…)
    property int currentCategory: -1
    readonly property bool searching: search.text.trim().length > 0
    // the query reaches the runners ~80 ms after the last keystroke
    property string query: ""
    // typed but results not in yet: no "No results" flash, Enter waits for them
    readonly property bool searchPending: searching && (queryTimer.running || runnerModel.querying)
    property bool launchWhenReady: false

    Timer {
        id: queryTimer
        interval: 80
        onTriggered: view.query = search.text.trim()
    }

    // Enter: launch now, or as soon as the pending search delivers results
    function launchCurrent() {
        if (searchPending) {
            launchWhenReady = true;
            if (queryTimer.running) {
                queryTimer.stop();
                view.query = search.text.trim();
            }
            return;
        }
        launch(grid.currentIndex);
    }
    onSearchPendingChanged: {
        if (!searchPending && launchWhenReady) {
            launchWhenReady = false;
            launch(grid.currentIndex);
        }
    }

    // Esc and type-to-search from any focused child (keys bubble up to here)
    focus: true
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            if (search.text.length > 0) {
                search.text = "";
                search.forceActiveFocus();
            } else {
                view.closeRequested();
            }
            event.accepted = true;
            return;
        }
        if (search.activeFocus || (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            return;
        if (event.key === Qt.Key_Backspace) {
            search.text = search.text.slice(0, -1);
            search.forceActiveFocus();
            event.accepted = true;
            return;
        }
        // printable characters only (no control chars like \b, DEL, tab, return)
        const t = event.text;
        if (t.length > 0 && /^[^\x00-\x1f\x7f]+$/.test(t) && t.trim().length > 0) {
            search.text += t;
            search.forceActiveFocus();
            event.accepted = true;
        }
    }

    readonly property var gridModel: {
        if (searching)
            return runnerModel.count > 0 ? runnerModel.modelForRow(0) : null;
        if (currentCategory < 0)
            return rootModel.favoritesModel;
        return rootModel.modelForRow(currentCategory);
    }

    function reset() {
        search.text = "";
        queryTimer.stop();
        query = "";
        launchWhenReady = false;
        currentCategory = -1;
        grid.currentIndex = 0;
        search.forceActiveFocus();
    }

    function launch(i) {
        const m = grid.model;
        if (!m || i < 0 || i >= grid.count)
            return;
        m.trigger(i, "", null);
        closeRequested();
    }

    Kicker.RootModel {
        id: rootModel
        autoPopulate: false
        appletInterface: view.appletInterface
        flat: true
        sorted: true
        showSeparators: false
        showAllApps: true
        showAllAppsCategorized: false
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false
        showFavoritesPlaceholder: false
        showRootSeparator: false
        Component.onCompleted: {
            favoritesModel.initForClient("com.github.eudesn.glasdock.favorites");
            refresh();
        }
    }

    Kicker.RunnerModel {
        id: runnerModel
        appletInterface: view.appletInterface
        favoritesModel: rootModel.favoritesModel
        mergeResults: true
        runners: ["krunner_services", "krunner_systemsettings", "calculator",
                  "unitconverter", "krunner_sessions", "krunner_powerdevil"]
        query: view.query
    }

    // ------------------------------------------------------------- background
    Item {
        id: morphPanel
        x: view.morph ? view.morphStartX + (0 - view.morphStartX) * view.t : 0
        y: view.morph ? view.morphStartY + (0 - view.morphStartY) * view.t : 0
        width: view.morph ? view.morphStartW + (view.width - view.morphStartW) * view.t : view.width
        height: view.morph ? view.morphStartH + (view.contentHeight - view.morphStartH) * view.t : view.contentHeight
        clip: view.morph && view.t < 1

        Widgets.GlassSurface {
            z: -1
            anchors.fill: parent
            style: view.style
            backgroundOpacity: view.backgroundOpacity
            radius: view.morph && view.t < 1
                ? Math.min(view.radius, height / 2) + (view.radius - Math.min(view.radius, height / 2)) * view.t
                : view.radius
            isDark: view.isDark
            accent: view.accent
            accentTint: view.accentTint
            showBorder: view.showBorder
            showShadow: false        // the window has no room for it
            forceBody: true
            blurBehind: view.blurBehind
                && !(morphClose.running && (morphPanel.opacity < 0.95 || view.t < 0.65))
                && !closeAnim.running
            frost: view.frost
        }

        Item {
            id: contentBox
            x: -morphPanel.x
            y: -morphPanel.y
            width: view.width
            height: view.contentHeight
            opacity: view.morph ? view.morphReveal : 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing * 1.5
                spacing: Kirigami.Units.largeSpacing

        // ------------------------------------------------------------ search
        PlasmaExtras.SearchField {
            id: search
            Layout.fillWidth: true
            focus: true
            topPadding: 7
            bottomPadding: 7
            Binding {
                target: search
                property: "Kirigami.Theme.inherit"
                value: false
                when: view.themeMode !== 0
                restoreMode: Binding.RestoreBindingOrValue
            }
            Binding {
                target: search
                property: "Kirigami.Theme.textColor"
                value: view.isDark ? "#f2f2f7" : "#1d1d1f"
                when: view.themeMode !== 0
                restoreMode: Binding.RestoreBindingOrValue
            }
            Binding {
                target: search
                property: "color"
                value: view.isDark ? "#f2f2f7" : "#1d1d1f"
                when: view.themeMode !== 0
                restoreMode: Binding.RestoreBindingOrValue
            }
            Binding {
                target: search
                property: "placeholderTextColor"
                value: view.isDark ? "#98989d" : "#6e6e73"
                when: view.themeMode !== 0
                restoreMode: Binding.RestoreBindingOrValue
            }
            Binding {
                target: search.background
                property: "opacity"
                value: 0
                when: search.background !== null
                restoreMode: Binding.RestoreBindingOrValue
            }
            Rectangle {
                z: -1
                anchors.fill: parent
                radius: height / 2
                color: search.activeFocus
                    ? (view.isDark ? Qt.rgba(1, 1, 1, 0.11) : Qt.rgba(1, 1, 1, 0.78))
                    : (view.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.62))
                border.width: 1
                border.color: search.activeFocus
                    ? Qt.rgba(view.accent.r, view.accent.g, view.accent.b, 0.75)
                    : (view.isDark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.14))
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }
            onTextChanged: {
                grid.currentIndex = 0;
                if (text.trim().length === 0) {
                    queryTimer.stop();
                    view.query = "";
                    view.launchWhenReady = false;
                } else {
                    queryTimer.restart();
                }
            }
            Keys.onReturnPressed: view.launchCurrent()
            Keys.onEnterPressed: view.launchCurrent()
            Keys.onDownPressed: { grid.forceActiveFocus(); }
            Keys.onEscapePressed: event => {
                if (search.text.length > 0) {
                    search.text = "";
                } else {
                    view.closeRequested();
                }
                event.accepted = true;
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Kirigami.Units.largeSpacing
            // staggered reveal
            opacity: view.reveal
            transform: Translate { y: (1 - view.reveal) * 10 }

            // ---------------------------------------------------- categories
            QQC2.ScrollView {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 12
                Layout.fillHeight: true
                visible: !view.searching
                QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

                ListView {
                    id: categories
                    clip: true
                    model: rootModel
                    spacing: 6
                    header: Item {
                        width: categories.width
                        height: favBtn.implicitHeight + categories.spacing
                        CategoryButton {
                            id: favBtn
                            width: parent.width
                            text: i18n("Favorites")
                            iconSource: "bookmarks"
                            checked: view.currentCategory === -1
                            onClicked: view.currentCategory = -1
                        }
                    }
                    delegate: Item {
                        required property int index
                        required property var model
                        readonly property bool hasDividerAfter: index === 0 && categories.count > 1
                        width: categories.width
                        height: catItem.implicitHeight + (hasDividerAfter ? 11 : 0)

                        CategoryButton {
                            id: catItem
                            width: parent.width
                            text: model.display
                            iconSource: model.decoration
                            checked: view.currentCategory === index
                            onClicked: view.currentCategory = index
                        }
                        Rectangle {
                            visible: hasDividerAfter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: Kirigami.Units.largeSpacing + 2
                            anchors.rightMargin: Kirigami.Units.largeSpacing + 2
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            height: 1
                            color: view.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                width: 1
                visible: !view.searching
                color: view.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.12)
            }

            FontMetrics {
                id: cellFontMetrics
                font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 0.92)
            }

            // ----------------------------------------------------------- apps
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                // a little room after the category separator
                Layout.leftMargin: view.searching ? 0 : Kirigami.Units.smallSpacing
                topMargin: 2
                bottomMargin: 2
                clip: true
                model: view.gridModel
                keyNavigationWraps: false

                readonly property int boxMargin: 3
                readonly property int hoverHeadroom: Math.ceil(view.iconSize * 0.04)
                readonly property int cardTopPad: Kirigami.Units.smallSpacing + 4 + hoverHeadroom
                readonly property int cardBottomPad: Kirigami.Units.smallSpacing + 2
                readonly property int cardSidePad: Kirigami.Units.smallSpacing * 2
                readonly property int iconLabelGap: Kirigami.Units.smallSpacing + 1
                readonly property int labelHeight: Math.ceil(cellFontMetrics.lineSpacing * 2)

                readonly property real minCellWidth: Math.max(view.iconSize * 2.2, Kirigami.Units.gridUnit * 5.2)
                readonly property int columns: Math.max(1, Math.floor(width / minCellWidth))
                cellWidth: Math.floor(width / columns)
                cellHeight: boxMargin * 2 + cardTopPad + view.iconSize + iconLabelGap + labelHeight + cardBottomPad
                highlightMoveDuration: 0
                highlight: Item {
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: grid.boxMargin
                        radius: Math.round(Kirigami.Units.cornerRadius * 2.0)
                        color: view.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.52)
                        border.width: 1
                        border.color: Qt.rgba(view.accent.r, view.accent.g, view.accent.b, 0.55)
                    }
                }
                // the scrollbar sits beside the grid (not over the last column)
                QQC2.ScrollBar.vertical: gridScroll

                Keys.onReturnPressed: view.launchCurrent()
                Keys.onEnterPressed: view.launchCurrent()
                Keys.onUpPressed: event => {
                    if (grid.currentIndex < grid.columns) {
                        search.forceActiveFocus();
                        event.accepted = true;
                    } else {
                        event.accepted = false;
                    }
                }
                // Esc and typing bubble up to the launcher root

                delegate: Item {
                    id: cell
                    required property int index
                    required property var model
                    width: grid.cellWidth
                    height: grid.cellHeight

                    readonly property string favoriteId: model.favoriteId ?? ""

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: grid.boxMargin + grid.cardTopPad
                        anchors.bottomMargin: grid.boxMargin + grid.cardBottomPad
                        anchors.leftMargin: grid.boxMargin + grid.cardSidePad
                        anchors.rightMargin: grid.boxMargin + grid.cardSidePad
                        spacing: grid.iconLabelGap

                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: view.iconSize
                            Layout.preferredHeight: view.iconSize
                            source: cell.model.decoration
                            scale: cellMouse.pressed ? 0.92 : (cellMouse.containsMouse ? 1.06 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutCubic } }
                        }
                        PC3.Label {
                            id: cellLabel
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: cell.model.display ?? ""
                            font.pixelSize: cellFontMetrics.font.pixelSize
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignTop
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }

                    // full name when it does not fit in two lines
                    PC3.ToolTip {
                        text: cellLabel.text
                        visible: cellMouse.containsMouse && cellLabel.truncated
                        delay: Kirigami.Units.toolTipDelay
                    }

                    MouseArea {
                        id: cellMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onEntered: grid.currentIndex = cell.index
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) {
                                view.launch(cell.index);
                            } else if (cell.favoriteId.startsWith("applications:")) {
                                appMenu.openRelative();
                            }
                        }
                    }

                    PlasmaExtras.Menu {
                        id: appMenu
                        visualParent: cell
                        placement: PlasmaExtras.Menu.BottomPosedLeftAlignedPopup
                        readonly property bool isFav: cell.favoriteId !== ""
                            && rootModel.favoritesModel.isFavorite(cell.favoriteId)

                        PlasmaExtras.MenuItem {
                            text: appMenu.isFav ? i18n("Remove from Favorites") : i18n("Add to Favorites")
                            icon: appMenu.isFav ? "bookmark-remove" : "bookmark-new"
                            onClicked: {
                                if (appMenu.isFav)
                                    rootModel.favoritesModel.removeFavorite(cell.favoriteId);
                                else
                                    rootModel.favoritesModel.addFavorite(cell.favoriteId);
                            }
                        }
                        PlasmaExtras.MenuItem {
                            text: i18n("Keep in Dock")
                            icon: "window-pin"
                            onClicked: view.pinRequested(cell.favoriteId)
                        }
                    }
                }

                // a GridView child scrolls with the content, so center on the
                // view's own size via x/y instead of anchoring to the flickable
                PlasmaExtras.PlaceholderMessage {
                    parent: grid
                    x: (grid.width - width) / 2
                    y: (grid.height - height) / 2
                    z: 1
                    width: grid.width - Kirigami.Units.gridUnit * 4
                    visible: grid.count === 0 && !view.searchPending
                    iconName: view.searching ? "edit-none" : "bookmarks"
                    text: view.searching ? i18n("No results") : i18n("No favorites yet")
                    explanation: view.searching ? ""
                        : i18n("Right-click an app and choose “Add to Favorites”.")
                }
            }

            QQC2.ScrollBar {
                id: gridScroll
                Layout.fillHeight: true
                policy: QQC2.ScrollBar.AlwaysOn
                enabled: grid.contentHeight > grid.height
                // keep the space reserved so the grid does not reflow when it appears
                opacity: grid.contentHeight > grid.height ? 1 : 0
            }
        }

        // ------------------------------------------------------------ footer
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            opacity: view.reveal

            Item { Layout.fillWidth: true }

            Widgets.GlassButton {
                text: i18n("Sleep")
                iconName: "system-suspend"
                iconSize: Kirigami.Units.iconSizes.small
                isDark: view.isDark
                accent: view.accent
                onClicked: { view.closeRequested(); view.runCommand("systemctl suspend"); }
            }
            Widgets.GlassButton {
                text: i18n("Restart")
                iconName: "system-reboot"
                iconSize: Kirigami.Units.iconSizes.small
                isDark: view.isDark
                accent: view.accent
                onClicked: { view.closeRequested(); view.runCommand("dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptReboot"); }
            }
            Widgets.GlassButton {
                text: i18n("Shut Down")
                iconName: "system-shutdown"
                iconSize: Kirigami.Units.iconSizes.small
                isDark: view.isDark
                accent: view.accent
                onClicked: { view.closeRequested(); view.runCommand("dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptShutDown"); }
            }
            Widgets.GlassButton {
                text: i18n("Log Out")
                iconName: "system-log-out"
                iconSize: Kirigami.Units.iconSizes.small
                isDark: view.isDark
                accent: view.accent
                onClicked: { view.closeRequested(); view.runCommand("dbus-send --session --type=method_call --dest=org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptLogout"); }
            }
        }
    }
    }
    }

    component CategoryButton: PC3.ItemDelegate {
        id: catBtn
        property var iconSource
        readonly property int iconPx: Kirigami.Units.iconSizes.smallMedium + 2
        checkable: false
        highlighted: checked
        // keep the keyboard in the search box (type-to-search, Enter, arrows)
        focusPolicy: Qt.NoFocus
        onReleased: search.forceActiveFocus()
        topPadding: 7
        bottomPadding: 7
        leftPadding: Kirigami.Units.largeSpacing + 2
        rightPadding: Kirigami.Units.largeSpacing + 2
        implicitHeight: Math.max(contentItem.implicitHeight + topPadding + bottomPadding,
                                 Math.round(Kirigami.Units.gridUnit * 2.0))
        background: Rectangle {
            radius: height / 2
            color: catBtn.checked
                ? Qt.rgba(view.accent.r, view.accent.g, view.accent.b, view.isDark ? 0.22 : 0.26)
                : catBtn.hovered ? (view.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.06)) : "transparent"
            border.width: catBtn.checked ? 1 : 0
            border.color: Qt.rgba(view.accent.r, view.accent.g, view.accent.b, 0.55)
            Behavior on color { ColorAnimation { duration: 100 } }
        }
        contentItem: RowLayout {
            spacing: Kirigami.Units.largeSpacing
            Kirigami.Icon {
                Layout.preferredWidth: catBtn.iconPx
                Layout.preferredHeight: catBtn.iconPx
                source: catBtn.iconSource
            }
            PC3.Label {
                Layout.fillWidth: true
                text: catBtn.text
                font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.08)
                font.weight: catBtn.checked ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
        }
    }
}
