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

    readonly property bool isDark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    readonly property color accent: isDark
        && Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.highlightColor) === Kirigami.ColorUtils.Dark
        ? Qt.lighter(Kirigami.Theme.highlightColor, 1.5) : Kirigami.Theme.highlightColor

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: ready ? weatherSource.current.temp + "° · " + weatherSource.describe(weatherSource.current.code) : "Weather"
    toolTipSubText: ready ? weatherSource.place : (weatherSource.error || "Loading…")

    fullRepresentation: Item {
        id: compact

        readonly property real pad: Math.round(height * 0.12)

        Layout.preferredWidth: row.implicitWidth + pad * (root.cfg.pillBackground ? 4 : 2)
        Layout.minimumWidth: Layout.preferredWidth
        Layout.fillHeight: true

        Rectangle {
            visible: root.cfg.pillBackground
            anchors.fill: parent
            anchors.topMargin: compact.pad / 2
            anchors.bottomMargin: compact.pad / 2
            radius: height / 2
            color: root.isDark ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.14 : 0.08)
                               : Qt.rgba(1, 1, 1, area.containsMouse ? 0.6 : 0.4)
            border.width: 1
            border.color: popup.visible && !popup.closing
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                : Qt.rgba(1, 1, 1, root.isDark ? 0.10 : 0.45)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: popup.toggle()
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: Math.round(compact.height * 0.18)

            Kirigami.Icon {
                Layout.preferredWidth: compact.height * 0.68
                Layout.preferredHeight: compact.height * 0.68
                source: root.ready ? weatherSource.iconFor(weatherSource.current.code, weatherSource.current.isDay)
                                   : "weather-none-available"
            }
            PC3.Label {
                text: root.ready ? weatherSource.current.temp + "°" : (root.cfg.city ? "--°" : "Set city")
                font.weight: Font.DemiBold
            }
            PC3.Label {
                visible: root.cfg.showCity && root.ready
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
            screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
            style: root.cfg.popupStyle
            backgroundOpacity: root.cfg.popupOpacity
            radius: root.cfg.popupRadius
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
