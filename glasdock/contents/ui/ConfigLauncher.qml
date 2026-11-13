import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

// Glasdock settings — Launcher
KCM.SimpleKCM {
    property alias cfg_showAppsButton: showAppsButton.checked
    property alias cfg_appsButtonZoom: appsButtonZoom.checked
    // 4 = the old "Blur" style: shown as Glass (the launcher keeps its blur)
    property int cfg_launcherStyle
    property alias cfg_launcherBlur: launcherBlur.currentIndex
    property alias cfg_launcherFrost: launcherFrost.value
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
            text: "Same look as the dock."
        }

        // ---- blur behind the launcher (org.glasdock.blur helper plugin)
        QQC2.ComboBox {
            id: launcherBlur
            Kirigami.FormData.label: "Blur behind:"
            model: ["Same as the dock", "On", "Off"]
        }
        RowLayout {
            Kirigami.FormData.label: "Frost:"
            enabled: launcherBlur.currentIndex === 1
            QQC2.Slider { id: launcherFrost; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(launcherFrost.value * 100) + "%" }
        }
        RowLayout {
            Kirigami.FormData.label: "Blur strength:"
            enabled: launcherBlur.currentIndex !== 2
            QQC2.Button {
                text: "Desktop Effects…"
                icon.name: "preferences-desktop-effects"
                onClicked: runner.connectSource("systemsettings kcm_kwin_effects")
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: blurProbe.status === Loader.Error
                ? "The blur helper is not installed: run ./install.sh from the Glasdock folder, then log out and back in once."
                : "\"Same as the dock\" uses the dock's blur and frost (Appearance → Blur). Lower the launcher opacity to see more of the blur."
        }
        Loader { id: blurProbe; visible: false; source: Qt.resolvedUrl("shared/BlurLayer.qml") }
        P5Support.DataSource {
            id: runner
            engine: "executable"
            connectedSources: []
            onNewData: sourceName => disconnectSource(sourceName)
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
