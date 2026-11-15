import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Glasdock settings — Widgets
KCM.SimpleKCM {
    property alias cfg_showPlayer: showPlayer.checked
    property alias cfg_showWeather: showWeather.checked
    property alias cfg_showClock: showClock.checked
    property alias cfg_weatherCity: weatherCity.text
    property alias cfg_weatherFahrenheit: weatherFahrenheit.checked
    property alias cfg_weatherBadges: weatherBadges.checked

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Widgets after the apps (experimental)"
        }
        QQC2.CheckBox {
            id: showPlayer
            Kirigami.FormData.label: "Show:"
            text: "Media player"
        }
        QQC2.CheckBox {
            id: showWeather
            text: "Weather"
        }
        QQC2.CheckBox {
            id: showClock
            text: "Clock"
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Weather"
        }
        QQC2.TextField {
            id: weatherCity
            Kirigami.FormData.label: "City:"
            enabled: showWeather.checked
            placeholderText: "e.g. Teresina"
        }
        QQC2.CheckBox {
            id: weatherFahrenheit
            enabled: showWeather.checked
            text: "Use Fahrenheit"
        }
        QQC2.CheckBox {
            id: weatherBadges
            enabled: showWeather.checked
            text: "Glasdock badge icons (otherwise the icon theme's)"
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "The city name is sent to Open-Meteo.com to find the forecast. For the top bar, use the separate Glasplayer and Glasweather widgets."
        }
    }
}
