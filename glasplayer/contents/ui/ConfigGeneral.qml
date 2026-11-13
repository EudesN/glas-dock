import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_maxWidth: maxWidth.value
    property alias cfg_showArtist: showArtist.checked
    property alias cfg_showSkipButtons: showSkipButtons.checked
    property alias cfg_hideWhenIdle: hideWhenIdle.checked
    property alias cfg_pillBackground: pillBackground.checked
    property alias cfg_popupStyle: popupStyle.currentIndex
    property alias cfg_popupOpacity: popupOpacity.value
    property alias cfg_popupRadius: popupRadius.value
    property alias cfg_popupAnimation: popupAnimation.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Panel" }

        QQC2.SpinBox {
            id: maxWidth
            Kirigami.FormData.label: "Maximum width:"
            from: 120; to: 800; stepSize: 10
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox { id: showArtist; Kirigami.FormData.label: "Show:"; text: "Artist next to the title" }
        QQC2.CheckBox { id: showSkipButtons; text: "Previous / next buttons" }
        QQC2.CheckBox { id: pillBackground; text: "Glass pill background" }
        QQC2.CheckBox { id: hideWhenIdle; Kirigami.FormData.label: "Behavior:"; text: "Hide when nothing is playing" }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Glass panel" }

        QQC2.ComboBox {
            id: popupStyle
            Kirigami.FormData.label: "Style:"
            model: ["Glass", "Frosted", "Clear", "Solid", "Blur (real blur)"]
        }

        QQC2.Label {
            visible: popupStyle.currentIndex === 4
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Blur uses Plasma's own background: the desktop behind is really blurred and the corner shape follows the Plasma theme."
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

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Tip: middle-click to play/pause, scroll over the widget to skip tracks."
        }
    }
}
