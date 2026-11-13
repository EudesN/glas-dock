import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_city: city.text
    property alias cfg_fahrenheit: fahrenheit.checked
    property alias cfg_showCity: showCity.checked
    property alias cfg_pillBackground: pillBackground.checked
    property alias cfg_popupStyle: popupStyle.currentIndex
    property alias cfg_popupOpacity: popupOpacity.value
    property alias cfg_popupRadius: popupRadius.value
    property alias cfg_popupAnimation: popupAnimation.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Weather" }

        QQC2.TextField {
            id: city
            Kirigami.FormData.label: "City:"
            placeholderText: "e.g. Teresina"
        }
        QQC2.CheckBox { id: fahrenheit; text: "Use Fahrenheit" }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "The city name is sent to Open-Meteo.com to find the forecast."
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Panel" }

        QQC2.CheckBox { id: showCity; Kirigami.FormData.label: "Show:"; text: "City name next to the temperature" }
        QQC2.CheckBox { id: pillBackground; text: "Glass pill background" }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Glass panel" }

        QQC2.ComboBox {
            id: popupStyle
            Kirigami.FormData.label: "Style:"
            model: ["Glass", "Frosted", "Clear", "Solid"]
        }
        RowLayout {
            Kirigami.FormData.label: "Opacity:"
            QQC2.Slider { id: popupOpacity; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(popupOpacity.value * 100) + "%" }
        }
        QQC2.SpinBox {
            id: popupRadius
            Kirigami.FormData.label: "Corner radius:"
            from: 0; to: 48
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox { id: popupAnimation; text: "Animate opening and closing" }
    }
}
