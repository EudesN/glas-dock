/*
 * Glasbattery — glass battery widget for desktop or panel (Glasdock project).
 * Shows circular battery rings for the laptop and connected peripherals
 * (Bluetooth headphones/earbuds, mice, keyboards, touchpads, controllers) and
 * adapts automatically as devices connect or disconnect.
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

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: batSource.primaryDevice
        ? batSource.primaryDevice.name + " · " + batSource.primaryDevice.percent + "%"
        : "No battery devices"
    toolTipSubText: batSource.count > 1 ? (batSource.count + " devices connected") : ""

    fullRepresentation: Item {
        id: view

        Shared.ThemeScope { target: view; themeMode: root.cfg.themeMode }

        readonly property var desktopDeviceList: {
            const list = batSource.devices.slice();
            if (list.length === 1 && root.cfg.showPlaceholder)
                list.push({ empty: true });
            return list;
        }

        readonly property real padH: Math.round(Kirigami.Units.gridUnit * 1.3)
        readonly property real padV: Math.round(Kirigami.Units.gridUnit * 0.75)
        readonly property real cellGap: Math.round(Kirigami.Units.gridUnit * 1.1)
        readonly property int visibleCount: Math.max(1, desktopDeviceList.length)
        readonly property real cardIdealW: visibleCount * root.cfg.ringSize
            + Math.max(0, visibleCount - 1) * cellGap + padH * 2
        readonly property real cardIdealH: (root.cfg.ringSize + (root.cfg.showDeviceNames ? 18 : 0)) + padV * 2

        implicitWidth: root.inPanel
            ? Math.ceil(panelRow.implicitWidth) + Math.round(height * 0.24) * 2
            : Math.max(160, cardIdealW)
        implicitHeight: root.inPanel ? 32 : Math.max(88, Math.max(cardIdealH, desktopFlow.implicitHeight + padV * 2))

        Layout.preferredWidth: implicitWidth
        Layout.minimumWidth: root.inPanel ? implicitWidth : 130
        Layout.minimumHeight: root.inPanel ? 0 : 80
        Layout.fillHeight: root.inPanel

        // ============================================================ DESKTOP
        Item {
            visible: !root.inPanel
            anchors.fill: parent

            Shared.GlassSurface {
                anchors.fill: parent
                visible: root.cfg.showCard
                style: root.cfg.cardStyle
                backgroundOpacity: root.cfg.cardOpacity
                radius: Math.min(height / 2, Math.max(root.cfg.cardRadius, height / 2))
                isDark: root.isDark
                accent: root.accent
                showBorder: root.cfg.showBorder
                showShadow: root.cfg.showShadow
                blurBehind: root.cfg.blurBehind
                frost: root.cfg.blurFrost
            }

            Flow {
                id: desktopFlow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, Math.max(1, parent.width - view.padH * 2))
                spacing: view.cellGap

                Repeater {
                    model: view.desktopDeviceList
                    delegate: BatteryRing {
                        required property var modelData
                        device: modelData
                        ringSize: root.cfg.ringSize
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

        // ============================================================== PANEL
        Item {
            visible: root.inPanel
            anchors.fill: parent

            MouseArea {
                id: panelArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: popup.toggle()
            }

            RowLayout {
                id: panelRow
                anchors.centerIn: parent
                spacing: Math.round(view.height * 0.22)

                Repeater {
                    model: batSource.devices.slice(0, 3)
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 4
                        Kirigami.Icon {
                            Layout.preferredWidth: Math.round(view.height * 0.56)
                            Layout.preferredHeight: Layout.preferredWidth
                            source: modelData.iconSource
                            isMask: true
                            color: Kirigami.Theme.textColor
                        }
                        PC3.Label {
                            text: modelData.percent + "%"
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                }
                PC3.Label {
                    visible: batSource.count > 3
                    text: "+" + (batSource.count - 3)
                    opacity: 0.65
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
                radius: root.cfg.cardRadius
                themeMode: root.cfg.themeMode
                isDark: root.isDark
                accent: root.accent
                animated: root.cfg.popupAnimation
                blurBehind: root.cfg.blurBehind
                frost: root.cfg.blurFrost
                sourceComponent: Item {
                    readonly property int count: Math.max(1, batSource.count)
                    readonly property int cols: Math.min(4, count)
                    implicitWidth: Math.max(140, cols * (root.cfg.ringSize + 10)
                        + Math.max(0, cols - 1) * view.cellGap)
                    implicitHeight: Math.max(90, popupFlow.implicitHeight)

                    Flow {
                        id: popupFlow
                        anchors.centerIn: parent
                        width: parent.width
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
                        anchors.centerIn: parent
                        visible: !batSource.hasDevices
                        text: "No battery devices connected"
                        opacity: 0.6
                    }
                }
            }
        }
    }
}
