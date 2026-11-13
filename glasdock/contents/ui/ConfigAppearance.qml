import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Glasdock settings — Appearance
KCM.SimpleKCM {
    property alias cfg_dockStyle: dockStyle.currentIndex
    property alias cfg_glassOpacity: glassOpacity.value
    property alias cfg_showBorder: showBorder.checked
    property alias cfg_showShadow: showShadow.checked
    property alias cfg_cornerRadius: cornerRadius.value
    property alias cfg_useAccentColor: useAccentColor.checked
    property alias cfg_glassAccentTint: glassAccentTint.value
    property alias cfg_iconSize: iconSize.value
    property alias cfg_iconSpacing: iconSpacing.value
    property alias cfg_bottomMargin: bottomMargin.value
    property alias cfg_transparentPanel: transparentPanel.checked
    property alias cfg_autoPanelHeight: autoPanelHeight.checked

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Background"
        }
        QQC2.ComboBox {
            id: dockStyle
            Kirigami.FormData.label: "Style:"
            model: ["Glass", "Frosted", "Clear (no background)", "Solid", "Blur (real blur)"]
        }
        QQC2.Label {
            visible: dockStyle.currentIndex === 4
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Blur uses Plasma's own background, so the desktop behind is really blurred and the corner shape follows the Plasma theme. The panel becomes as tall as the bar (floating), so icon zoom and hover names are turned off."
        }
        RowLayout {
            Kirigami.FormData.label: "Opacity:"
            enabled: dockStyle.currentIndex === 0 || dockStyle.currentIndex === 1
            QQC2.Slider { id: glassOpacity; from: 0.0; to: 0.8; stepSize: 0.01 }
            QQC2.Label { text: Math.round(glassOpacity.value * 100) + "%" }
        }
        QQC2.SpinBox {
            id: cornerRadius
            Kirigami.FormData.label: "Corner radius:"
            from: 0; to: 64; stepSize: 1
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox {
            id: showBorder
            Kirigami.FormData.label: "Details:"
            text: "Border"
        }
        QQC2.CheckBox {
            id: showShadow
            enabled: dockStyle.currentIndex !== 2 && dockStyle.currentIndex !== 4
            text: "Shadow"
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Colors"
        }
        QQC2.CheckBox {
            id: useAccentColor
            Kirigami.FormData.label: "Accent color:"
            text: "Use the system accent color for dots, labels and highlights"
        }
        RowLayout {
            Kirigami.FormData.label: "Accent tint on glass:"
            QQC2.Slider { id: glassAccentTint; from: 0.0; to: 0.5; stepSize: 0.01 }
            QQC2.Label { text: Math.round(glassAccentTint.value * 100) + "%" }
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Size and position"
        }
        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: "Icon size:"
            from: 24; to: 128; stepSize: 1
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: iconSpacing
            Kirigami.FormData.label: "Icon spacing:"
            from: 0; to: 48; stepSize: 1
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: bottomMargin
            Kirigami.FormData.label: "Distance from screen edge:"
            enabled: dockStyle.currentIndex !== 4
            from: 0; to: 48; stepSize: 1
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Panel"
        }
        QQC2.CheckBox {
            id: transparentPanel
            Kirigami.FormData.label: "Panel:"
            text: "Make the panel transparent (only the glass is visible)"
        }
        QQC2.CheckBox {
            id: autoPanelHeight
            text: "Resize the panel to fit the icon size and zoom"
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "The Meta key and Alt+F1 open the launcher. Window previews, badges and zoom are in the Behavior tab."
        }
    }
}
