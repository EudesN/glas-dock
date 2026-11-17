/*
 * Glasbattery — glass battery widget for desktop or status bar / panel (GlasDo project).
 * Shows horseshoe battery gauges on the desktop (and panel popup), and a compact
 * status-bar pill with connected laptop and wireless/USB peripherals (mouse,
 * keyboard, Bluetooth headphones/earbuds, controllers).
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "shared" as Shared

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration
    readonly property bool inPanel: Plasmoid.formFactor === PlasmaCore.Types.Horizontal
                                 || Plasmoid.formFactor === PlasmaCore.Types.Vertical

    BatterySource {
        id: batSource
        showLaptop: root.cfg.showLaptop
        showPeripherals: root.cfg.showPeripherals
        showBluetooth: root.cfg.showBluetooth
    }

    Shared.ThemeScope { id: themeScope; target: null; themeMode: root.cfg.themeMode }
    readonly property bool isDark: themeScope.isDark
    readonly property color accent: themeScope.accent
    readonly property bool editing: Plasmoid.containment && Plasmoid.containment.corona
                                    ? Plasmoid.containment.corona.editMode === true : false
    readonly property bool hidden: !batSource.hasDevices && root.cfg.hideWhenEmpty && !editing

    function formatRemaining(ms) {
        if (!ms || ms <= 60000)
            return "";
        const mins = Math.round(ms / 60000);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        return h > 0 ? (h + "h " + m + "m") : (m + "m");
    }

    function levelColor(dev) {
        if (!dev)
            return Kirigami.Theme.textColor;
        const charging = dev.charging === true;
        if (dev.percent <= 10 && !charging)
            return "#ff453a";
        if (dev.percent <= 20 && !charging)
            return "#ff9f0a";
        return Kirigami.Theme.textColor;
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    Plasmoid.status: hidden ? PlasmaCore.Types.PassiveStatus : PlasmaCore.Types.ActiveStatus
    toolTipMainText: {
        if (!batSource.hasDevices)
            return "No battery devices";
        return batSource.devices.slice(0, 3)
            .map(d => d.name + " · " + d.percent + "%" + (d.charging ? " ⚡" : ""))
            .join("   |   ");
    }
    toolTipSubText: {
        if (!batSource.primaryDevice)
            return "";
        if (batSource.primaryDevice.charging)
            return "Charging";
        const rem = formatRemaining(batSource.primaryDevice.remainingMsec);
        if (rem)
            return rem + " remaining";
        return batSource.count > 1 ? (batSource.count + " devices connected") : "";
    }

    fullRepresentation: Item {
        id: view

        Shared.ThemeScope { target: view; themeMode: root.cfg.themeMode }

        readonly property real padV: Math.max(12, Math.round(root.cfg.ringSize * 0.22))
        readonly property real padH: Math.max(18, Math.round(root.cfg.ringSize * 0.30))
        readonly property real cellGap: Math.max(12, Math.round(root.cfg.ringSize * 0.22))
        readonly property real barH: height > 0 ? height : 32
        readonly property real panelPad: Math.max(3, Math.round(barH * 0.12))
        readonly property int visibleCount: Math.max(1, batSource.count)
        readonly property int nameExtraH: root.cfg.showDeviceNames ? 18 : 0
        readonly property real cardIdealW: visibleCount * root.cfg.ringSize
            + Math.max(0, visibleCount - 1) * cellGap + padH * 2
        readonly property real cardIdealH: root.cfg.ringSize + nameExtraH + padV * 2

        // If Plasma's desktop container is narrower/shorter than cardIdealW/H,
        // scale gauges down smoothly so they never overflow outside the glass pill.
        readonly property real desktopAvailW: Math.max(40, width - padH * 2)
        readonly property real desktopAvailH: Math.max(40, height - padV * 2 - nameExtraH)
        readonly property real fitScale: (!root.inPanel && width > 0 && height > 0)
            ? Math.min(1.0,
                       desktopAvailW / Math.max(1, visibleCount * root.cfg.ringSize + Math.max(0, visibleCount - 1) * cellGap),
                       desktopAvailH / Math.max(1, root.cfg.ringSize))
            : 1.0
        readonly property real effectiveRingSize: Math.max(36, Math.floor(root.cfg.ringSize * fitScale))
        readonly property real effectiveCellGap: Math.max(8, Math.round(effectiveRingSize * 0.22))

        readonly property int panelMaxShown: root.cfg.panelCompact ? 1 : 3
        readonly property var panelDevices: batSource.devices.slice(0, panelMaxShown)
        readonly property int panelOverflow: Math.max(0, batSource.count - panelDevices.length)

        implicitWidth: root.inPanel
            ? (root.hidden ? 0 : Math.ceil(panelRow.implicitWidth) + panelPad * (root.cfg.pillBackground ? 4 : 2) + 4)
            : cardIdealW
        implicitHeight: root.inPanel ? 32 : cardIdealH

        Layout.preferredWidth: implicitWidth
        Layout.minimumWidth: root.inPanel ? Layout.preferredWidth : cardIdealW
        Layout.maximumWidth: root.inPanel ? Layout.preferredWidth : Number.POSITIVE_INFINITY
        Layout.minimumHeight: root.inPanel ? 0 : cardIdealH
        Layout.fillHeight: root.inPanel

        // ============================================================ DESKTOP
        Item {
            visible: !root.inPanel && !root.hidden
            anchors.fill: parent

            Shared.GlassSurface {
                anchors.fill: parent
                visible: root.cfg.showCard
                style: root.cfg.cardStyle
                backgroundOpacity: root.cfg.cardOpacity
                radius: Math.min(height, width) / 2
                isDark: root.isDark
                accent: root.accent
                showBorder: root.cfg.showBorder
                showShadow: root.cfg.showShadow
                blurBehind: root.cfg.blurBehind
                frost: root.cfg.blurFrost
            }

            Row {
                id: desktopRow
                anchors.centerIn: parent
                spacing: view.effectiveCellGap

                Repeater {
                    model: batSource.devices
                    delegate: BatteryRing {
                        required property var modelData
                        device: modelData
                        ringSize: view.effectiveRingSize
                        showDeviceName: root.cfg.showDeviceNames
                        showPercentSymbol: root.cfg.showPercentSymbol
                        useAccentColor: root.cfg.useAccentColor
                        isDark: root.isDark
                        accent: root.accent
                    }
                }
            }

            PC3.Label {
                anchors.centerIn: parent
                visible: !batSource.hasDevices
                text: "No battery devices"
                opacity: 0.55
            }
        }

        // =================================================== STATUS BAR / PANEL
        Item {
            visible: root.inPanel && !root.hidden
            anchors.fill: parent

            Connections {
                target: root
                function onHiddenChanged() {
                    if (root.hidden && popup.visible)
                        popup.close();
                }
            }

            // Glass pill matching Glasclock / Glasweather / Glasplayer
            Rectangle {
                visible: root.cfg.pillBackground
                anchors.fill: parent
                anchors.topMargin: view.panelPad / 2
                anchors.bottomMargin: view.panelPad / 2
                radius: height / 2
                color: root.isDark ? Qt.rgba(1, 1, 1, panelArea.containsMouse ? 0.14 : 0.08)
                                   : Qt.rgba(1, 1, 1, panelArea.containsMouse ? 0.6 : 0.4)
                border.width: popup.visible && !popup.closing ? 1 : 0
                border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
            }

            MouseArea {
                id: panelArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: popup.toggle()
            }

            RowLayout {
                id: panelRow
                anchors.centerIn: parent
                spacing: Math.max(6, Math.round(view.barH * 0.22))

                Repeater {
                    model: view.panelDevices
                    delegate: RowLayout {
                        id: chip
                        required property int index
                        required property var modelData
                        readonly property color stateColor: root.levelColor(modelData)
                        spacing: 4

                        Rectangle {
                            visible: chip.index > 0
                            Layout.preferredWidth: 1
                            Layout.preferredHeight: Math.max(10, Math.round(view.barH * 0.36))
                            Layout.rightMargin: Math.max(2, Math.round(view.barH * 0.08))
                            color: Kirigami.Theme.textColor
                            opacity: 0.18
                        }

                        Kirigami.Icon {
                            Layout.preferredWidth: Math.max(14, Math.round(view.barH * 0.56))
                            Layout.preferredHeight: Layout.preferredWidth
                            source: chip.modelData.iconSource
                            isMask: true
                            color: chip.stateColor
                        }

                        Kirigami.Icon {
                            visible: chip.modelData.charging === true
                            Layout.preferredWidth: Math.max(9, Math.round(view.barH * 0.34))
                            Layout.preferredHeight: Layout.preferredWidth
                            source: Qt.resolvedUrl("icons/bolt.svg")
                            isMask: true
                            color: root.cfg.useAccentColor ? root.accent : "#30d158"
                        }

                        PC3.Label {
                            text: chip.modelData.percent + "%"
                            color: chip.stateColor
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }

                PC3.Label {
                    visible: view.panelOverflow > 0
                    text: "+" + view.panelOverflow
                    font: Kirigami.Theme.smallFont
                    opacity: 0.68
                }

                PC3.Label {
                    visible: !batSource.hasDevices
                    text: "--%"
                    opacity: 0.6
                }
            }

            Shared.GlassPopup {
                id: popup
                anchorItem: view
                edge: Plasmoid.location
                gap: root.cfg.popupGap
                morph: root.cfg.popupMorph
                screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
                style: root.cfg.cardStyle
                backgroundOpacity: root.cfg.cardOpacity
                radius: root.cfg.popupRadius
                themeMode: root.cfg.themeMode
                isDark: root.isDark
                accent: root.accent
                animated: root.cfg.popupAnimation
                blurBehind: root.cfg.blurBehind
                frost: root.cfg.blurFrost
                sourceComponent: Item {
                    readonly property var primary: batSource.primaryDevice
                    readonly property string statusSummary: {
                        if (!primary)
                            return "";
                        if (primary.charging)
                            return "Charging";
                        const rem = root.formatRemaining(primary.remainingMsec);
                        if (rem)
                            return rem + " left";
                        return primary.percent >= 99 ? "Full" : "";
                    }
                    implicitWidth: Math.max(Kirigami.Units.gridUnit * 12, popupCol.implicitWidth)
                    implicitHeight: popupCol.implicitHeight

                    ColumnLayout {
                        id: popupCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: Kirigami.Units.largeSpacing

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Kirigami.Units.largeSpacing

                            PC3.Label {
                                text: "Battery"
                                font.weight: Font.DemiBold
                            }
                            Item { Layout.fillWidth: true }
                            PC3.Label {
                                visible: statusSummary.length > 0
                                text: statusSummary
                                font: Kirigami.Theme.smallFont
                                opacity: 0.65
                            }
                        }

                        Row {
                            id: popupRow
                            visible: batSource.hasDevices
                            Layout.alignment: Qt.AlignHCenter
                            spacing: view.cellGap
                            Repeater {
                                model: batSource.devices
                                delegate: BatteryRing {
                                    required property var modelData
                                    device: modelData
                                    ringSize: root.cfg.ringSize
                                    showDeviceName: true
                                    showPercentSymbol: root.cfg.showPercentSymbol
                                    useAccentColor: root.cfg.useAccentColor
                                    isDark: root.isDark
                                    accent: root.accent
                                }
                            }
                        }

                        PC3.Label {
                            Layout.alignment: Qt.AlignHCenter
                            visible: !batSource.hasDevices
                            text: "No battery devices connected"
                            opacity: 0.6
                        }
                    }
                }
            }
        }
    }
}
