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
    property bool isDark: true
    property var frameMargins: null

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
    // follows Plasma's global animation speed (0 when animations are off)
    readonly property int dur: Math.round(animationDuration * Kirigami.Units.longDuration / 200)
    readonly property bool closing: closeAnim.running
    property real reveal: 1   // 0..1, content below the search field

    transformOrigin: Item.Bottom
    transform: Translate { id: rise; y: 0 }

    function playOpen() {
        closeAnim.stop();
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
        if (closeAnim.running)
            return;
        openAnim.stop();
        if (!animated || dur < 10 || opacity === 0) {
            closeFinished();
            return;
        }
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
    readonly property bool searching: search.text.length > 0

    readonly property var gridModel: {
        if (searching)
            return runnerModel.count > 0 ? runnerModel.modelForRow(0) : null;
        if (currentCategory < 0)
            return rootModel.favoritesModel;
        return rootModel.modelForRow(currentCategory);
    }

    function reset() {
        search.text = "";
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
        query: search.text
    }

    // ------------------------------------------------------------- background
    Widgets.GlassSurface {
        z: -1
        anchors.fill: parent
        style: view.style
        backgroundOpacity: view.backgroundOpacity
        radius: view.radius
        isDark: view.isDark
        accent: view.accent
        accentTint: view.accentTint
        showBorder: view.showBorder
        showShadow: false        // the window has no room for it
        forceBody: true
        blurBehind: view.blurBehind
        frost: view.frost
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing * 1.5
        spacing: Kirigami.Units.largeSpacing

        // ------------------------------------------------------------ search
        PlasmaExtras.SearchField {
            id: search
            Layout.fillWidth: true
            focus: true
            onTextChanged: grid.currentIndex = 0
            Keys.onEscapePressed: view.closeRequested()
            Keys.onReturnPressed: view.launch(grid.currentIndex)
            Keys.onEnterPressed: view.launch(grid.currentIndex)
            Keys.onDownPressed: { grid.forceActiveFocus(); }
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
                Layout.preferredWidth: Kirigami.Units.gridUnit * 11
                Layout.fillHeight: true
                visible: !view.searching
                PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

                ListView {
                    id: categories
                    clip: true
                    model: rootModel
                    spacing: 2
                    header: CategoryButton {
                        width: categories.width
                        text: "Favorites"
                        iconSource: "bookmarks"
                        checked: view.currentCategory === -1
                        onClicked: view.currentCategory = -1
                    }
                    delegate: CategoryButton {
                        required property int index
                        required property var model
                        width: categories.width
                        text: model.display
                        iconSource: model.decoration
                        checked: view.currentCategory === index
                        onClicked: view.currentCategory = index
                    }
                }
            }

            Kirigami.Separator {
                Layout.fillHeight: true
                visible: !view.searching
            }

            // ----------------------------------------------------------- apps
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                // a little room after the category separator
                Layout.leftMargin: view.searching ? 0 : Kirigami.Units.smallSpacing
                clip: true
                model: view.gridModel
                keyNavigationWraps: true
                readonly property int columns: Math.max(1, Math.floor(width / (view.iconSize * 2.2)))
                cellWidth: Math.floor(width / columns)
                cellHeight: view.iconSize + Kirigami.Units.gridUnit * 3
                highlightMoveDuration: 0
                highlight: PlasmaExtras.Highlight {}
                // the scrollbar sits beside the grid (not over the last column)
                QQC2.ScrollBar.vertical: gridScroll

                Keys.onReturnPressed: view.launch(currentIndex)
                Keys.onEnterPressed: view.launch(currentIndex)
                Keys.onEscapePressed: view.closeRequested()
                Keys.onPressed: event => {
                    // typing while the grid has focus goes to the search box
                    if (event.text.length > 0 && event.text.trim().length > 0
                            && !(event.modifiers & Qt.ControlModifier)) {
                        search.text += event.text;
                        search.forceActiveFocus();
                        event.accepted = true;
                    }
                }

                delegate: Item {
                    id: cell
                    required property int index
                    required property var model
                    width: grid.cellWidth
                    height: grid.cellHeight

                    readonly property string favoriteId: model.favoriteId ?? ""

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.topMargin: Kirigami.Units.smallSpacing
                        anchors.bottomMargin: Kirigami.Units.smallSpacing
                        anchors.leftMargin: Kirigami.Units.smallSpacing
                        anchors.rightMargin: Kirigami.Units.smallSpacing
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: view.iconSize
                            Layout.preferredHeight: view.iconSize
                            source: cell.model.decoration
                            active: cellMouse.containsMouse
                        }
                        PC3.Label {
                            id: cellLabel
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: cell.model.display ?? ""
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
                            text: appMenu.isFav ? "Remove from Favorites" : "Add to Favorites"
                            icon: appMenu.isFav ? "bookmark-remove" : "bookmark-new"
                            onClicked: {
                                if (appMenu.isFav)
                                    rootModel.favoritesModel.removeFavorite(cell.favoriteId);
                                else
                                    rootModel.favoritesModel.addFavorite(cell.favoriteId);
                            }
                        }
                        PlasmaExtras.MenuItem {
                            text: "Keep in Dock"
                            icon: "window-pin"
                            onClicked: view.pinRequested(cell.favoriteId)
                        }
                    }
                }

                PlasmaExtras.PlaceholderMessage {
                    anchors.centerIn: parent
                    width: parent.width - Kirigami.Units.gridUnit * 4
                    visible: grid.count === 0
                    iconName: view.searching ? "edit-none" : "bookmarks"
                    text: view.searching ? "No results" : "No favorites yet"
                    explanation: view.searching ? ""
                        : "Right-click an app and choose “Add to Favorites”."
                }
            }

            PC3.ScrollBar {
                id: gridScroll
                Layout.fillHeight: true
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

            PC3.ToolButton {
                text: "Sleep"
                icon.name: "system-suspend"
                onClicked: { view.closeRequested(); view.runCommand("systemctl suspend"); }
            }
            PC3.ToolButton {
                text: "Restart"
                icon.name: "system-reboot"
                onClicked: { view.closeRequested(); view.runCommand("qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptReboot"); }
            }
            PC3.ToolButton {
                text: "Shut Down"
                icon.name: "system-shutdown"
                onClicked: { view.closeRequested(); view.runCommand("qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptShutDown"); }
            }
            PC3.ToolButton {
                text: "Log Out"
                icon.name: "system-log-out"
                onClicked: { view.closeRequested(); view.runCommand("qdbus6 org.kde.LogoutPrompt /LogoutPrompt org.kde.LogoutPrompt.promptLogout"); }
            }
        }
    }

    component CategoryButton: PC3.ItemDelegate {
        property var iconSource
        checkable: false
        highlighted: checked
        icon.width: Kirigami.Units.iconSizes.smallMedium
        icon.height: Kirigami.Units.iconSizes.smallMedium
        contentItem: RowLayout {
            spacing: Kirigami.Units.mediumSpacing
            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                source: parent.parent.iconSource
            }
            PC3.Label {
                Layout.fillWidth: true
                text: parent.parent.text
                elide: Text.ElideRight
            }
        }
    }
}
