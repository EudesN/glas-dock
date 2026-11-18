/*
 * Glasweather — weather for a Plasma panel (Glasdock project).
 * Condition icon and temperature in the panel; click for the glass panel with
 * current conditions and a 5-day forecast. Data: Open-Meteo (no API key).
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

    Shared.WeatherData {
        id: weatherSource
        city: root.cfg.city
        fahrenheit: root.cfg.fahrenheit
        useBadges: root.cfg.iconBadges
    }
    readonly property bool ready: weatherSource.ready

    Shared.ThemeScope { id: themeScope; target: null; themeMode: root.cfg.themeMode }
    readonly property bool isDark: themeScope.isDark
    readonly property color accent: themeScope.accent

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: ready ? weatherSource.current.temp + "° · " + weatherSource.describe(weatherSource.current.code) : i18n("Weather")
    toolTipSubText: ready ? weatherSource.place : (weatherSource.error || i18n("Loading…"))

    fullRepresentation: Item {
        id: compact

        Shared.ThemeScope { target: compact; themeMode: root.cfg.themeMode }
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property real refSize: vertical ? width : height
        readonly property real pad: Math.round(refSize * 0.12)

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.toolTipMainText + (root.toolTipSubText ? ", " + root.toolTipSubText : "")
        Keys.onReturnPressed: popup.toggle()
        Keys.onSpacePressed: popup.toggle()

        Layout.preferredWidth: vertical ? -1 : row.implicitWidth + pad * (root.cfg.pillBackground ? 4 : 2)
        Layout.minimumWidth: vertical ? 0 : Layout.preferredWidth
        Layout.preferredHeight: vertical ? row.implicitHeight + pad * 2 : -1
        Layout.minimumHeight: vertical ? Layout.preferredHeight : 0
        Layout.fillWidth: vertical
        Layout.fillHeight: !vertical

        Rectangle {
            visible: root.cfg.pillBackground
            anchors.fill: parent
            anchors.topMargin: compact.pad / 2
            anchors.bottomMargin: compact.pad / 2
            radius: Math.min(width, height) / 2
            color: root.isDark ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.14 : 0.08)
                               : Qt.rgba(1, 1, 1, area.containsMouse ? 0.6 : 0.4)
            border.width: (popup.visible && !popup.closing) || compact.activeFocus ? 1 : 0
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: popup.toggle()
        }

        GridLayout {
            id: row
            anchors.centerIn: parent
            columns: compact.vertical ? 1 : 3
            rowSpacing: 2
            columnSpacing: Math.round(compact.refSize * 0.18)

            Kirigami.Icon {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: compact.refSize * (compact.vertical ? 0.56 : 0.68)
                Layout.preferredHeight: Layout.preferredWidth
                source: root.ready ? weatherSource.iconFor(weatherSource.current.code, weatherSource.current.isDay)
                                   : "weather-none-available"
            }
            PC3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.ready ? weatherSource.current.temp + "°" : (root.cfg.city ? "--°" : i18n("Set city"))
                font.weight: Font.DemiBold
            }
            PC3.Label {
                Layout.alignment: Qt.AlignHCenter
                visible: root.cfg.showCity && root.ready && !compact.vertical
                text: root.ready ? weatherSource.place : ""
                opacity: 0.65
            }
        }

        Shared.GlassPopup {
            id: popup
            anchorItem: compact
            edge: Plasmoid.location
            gap: root.cfg.popupGap
            morph: root.cfg.popupMorph
            morphDistance: root.cfg.popupMorphGap
            screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
            style: root.cfg.popupStyle
            backgroundOpacity: root.cfg.popupOpacity
            radius: root.cfg.popupRadius
            themeMode: root.cfg.themeMode
            isDark: root.isDark
            accent: root.accent
            animated: root.cfg.popupAnimation
            blurBehind: root.cfg.popupBlur || root.cfg.popupStyle === 4
            frost: root.cfg.popupFrost
            sourceComponent: Shared.WeatherPopup {
                weather: weatherSource
                accent: root.accent
                isDark: root.isDark
            }
        }
    }
}
