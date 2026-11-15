import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property alias cfg_clockStyle: clockStyle.currentIndex
    property alias cfg_timeFormat: timeFormat.currentIndex
    property alias cfg_alignment: alignment.currentIndex
    property alias cfg_showSeconds: showSeconds.checked
    property alias cfg_showDate: showDate.checked
    property alias cfg_showWeekday: showWeekday.checked
    property alias cfg_showDayProgress: showDayProgress.checked
    property alias cfg_accentSeconds: accentSeconds.checked

    property alias cfg_showCard: showCard.checked
    property alias cfg_cardStyle: cardStyle.currentIndex
    property alias cfg_themeMode: themeMode.currentIndex
    property alias cfg_cardOpacity: cardOpacity.value
    property alias cfg_cardRadius: cardRadius.value
    property alias cfg_showBorder: showBorder.checked
    property alias cfg_showShadow: showShadow.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Clock" }

        QQC2.ComboBox {
            id: clockStyle
            Kirigami.FormData.label: "Face:"
            model: ["Digital", "Editorial (stacked)", "Analog"]
        }
        QQC2.ComboBox {
            id: timeFormat
            Kirigami.FormData.label: "Time format:"
            model: ["Follow the locale", "12-hour", "24-hour"]
        }
        QQC2.ComboBox {
            id: alignment
            Kirigami.FormData.label: "Alignment:"
            enabled: clockStyle.currentIndex !== 2
            model: ["Left", "Center", "Right"]
        }
        QQC2.CheckBox { id: showSeconds; text: "Show seconds" }
        QQC2.CheckBox { id: accentSeconds; text: "Highlight seconds with accent color"; enabled: showSeconds.checked }
        QQC2.CheckBox { id: showDate; Kirigami.FormData.label: "Details:"; text: "Show the date" }
        QQC2.CheckBox { id: showWeekday; text: "Include weekday name"; enabled: showDate.checked }
        QQC2.CheckBox { id: showDayProgress; text: "Show day progress bar" }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Appearance" }

        QQC2.ComboBox {
            id: themeMode
            Kirigami.FormData.label: "Theme:"
            model: ["Follow system", "Dark", "Light"]
        }
        QQC2.CheckBox { id: showCard; Kirigami.FormData.label: "Background:"; text: "Show glass card behind the clock" }
        QQC2.ComboBox {
            id: cardStyle
            Kirigami.FormData.label: "Card style:"
            enabled: showCard.checked
            model: ["Glass", "Frosted", "Clear", "Solid"]
        }
        RowLayout {
            Kirigami.FormData.label: "Opacity:"
            enabled: showCard.checked
            QQC2.Slider { id: cardOpacity; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(cardOpacity.value * 100) + "%" }
        }
        QQC2.SpinBox {
            id: cardRadius
            Kirigami.FormData.label: "Corner radius:"
            enabled: showCard.checked
            from: 0; to: 48
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox { id: showBorder; text: "Inner light border"; enabled: showCard.checked }
        QQC2.CheckBox { id: showShadow; text: "Drop shadow"; enabled: showCard.checked }
    }
}
