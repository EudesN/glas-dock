import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Glasdock settings — Launcher
KCM.SimpleKCM {
    property alias cfg_showAppsButton: showAppsButton.checked
    property alias cfg_appsButtonZoom: appsButtonZoom.checked
    // 4 = the old "Blur" style: shown as Glass (the launcher keeps its blur)
    property int cfg_launcherStyle
    property alias cfg_launcherOpacity: launcherOpacity.value
    property alias cfg_launcherIconSize: launcherIconSize.value
    property alias cfg_launcherWidth: launcherWidth.value
    property alias cfg_launcherHeight: launcherHeight.value
    property alias cfg_launcherGap: launcherGap.value
    property alias cfg_launcherAnimation: launcherAnimation.checked
    property alias cfg_launcherAnimationDuration: launcherAnimationDuration.value

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Apps button"
        }
        QQC2.CheckBox {
            id: showAppsButton
            Kirigami.FormData.label: "Button:"
            text: "Show at the start of the dock"
        }
        QQC2.CheckBox {
            id: appsButtonZoom
            enabled: showAppsButton.checked
            text: "Zoom it with the other icons"
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Look"
        }
        QQC2.ComboBox {
            id: launcherStyle
            Kirigami.FormData.label: "Style:"
            model: ["Glass", "Frosted", "Clear", "Solid"]
            currentIndex: cfg_launcherStyle === 4 ? 0 : cfg_launcherStyle
            onActivated: index => cfg_launcherStyle = index
        }
        RowLayout {
            Kirigami.FormData.label: "Opacity:"
            QQC2.Slider { id: launcherOpacity; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(launcherOpacity.value * 100) + "%"  }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Same look as the dock. Blur and frost follow the dock setting (Appearance → Blur)."
        }
        QQC2.SpinBox {
            id: launcherIconSize
            Kirigami.FormData.label: "Icon size:"
            from: 16; to: 128; stepSize: 4
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Size and position"
        }
        QQC2.SpinBox {
            id: launcherWidth
            Kirigami.FormData.label: "Width:"
            from: 400; to: 1600; stepSize: 10
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: launcherHeight
            Kirigami.FormData.label: "Height:"
            from: 300; to: 1200; stepSize: 10
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: launcherGap
            Kirigami.FormData.label: "Distance above the dock:"
            from: -40; to: 200; stepSize: 1
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Animation"
        }
        QQC2.CheckBox {
            id: launcherAnimation
            Kirigami.FormData.label: "Animation:"
            text: "Animate opening and closing (launcher and panels)"
        }
        QQC2.SpinBox {
            id: launcherAnimationDuration
            Kirigami.FormData.label: "Duration:"
            enabled: launcherAnimation.checked
            from: 80; to: 800; stepSize: 20
            textFromValue: v => v + " ms"
            valueFromText: t => parseInt(t)
        }
    }
}
