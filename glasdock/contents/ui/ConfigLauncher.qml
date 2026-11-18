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
    property alias cfg_launcherMorph: launcherMorph.checked
    property alias cfg_launcherMorphGap: launcherMorphGap.value

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Apps button")
        }
        QQC2.CheckBox {
            id: showAppsButton
            Kirigami.FormData.label: i18n("Button:")
            text: i18n("Show at the start of the dock")
        }
        QQC2.CheckBox {
            id: appsButtonZoom
            enabled: showAppsButton.checked
            text: i18n("Zoom it with the other icons")
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Look")
        }
        QQC2.ComboBox {
            id: launcherStyle
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Glass"), i18n("Frosted"), i18n("Clear"), i18n("Solid")]
            currentIndex: cfg_launcherStyle === 4 ? 0 : cfg_launcherStyle
            onActivated: index => {
                // the legacy style 4 meant "Glass + blur": keep the blur when
                // leaving it, otherwise it would silently fall back to the dock's
                if (cfg_launcherStyle === 4 && launcherBlur.currentIndex === 0)
                    launcherBlur.currentIndex = 1;
                cfg_launcherStyle = index;
            }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Opacity:")
            enabled: launcherStyle.currentIndex === 0 || launcherStyle.currentIndex === 1
            QQC2.Slider { id: launcherOpacity; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(launcherOpacity.value * 100) + "%"  }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("Same look as the dock.")
        }

        // ---- blur behind the launcher (org.glasdock.blur helper plugin)
        QQC2.ComboBox {
            id: launcherBlur
            Kirigami.FormData.label: i18n("Blur behind:")
            enabled: launcherStyle.currentIndex !== 3
            model: [i18n("Same as the dock"), i18n("On"), i18n("Off")]
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Frost:")
            enabled: launcherStyle.currentIndex !== 3 && launcherBlur.currentIndex === 1
            QQC2.Slider { id: launcherFrost; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(launcherFrost.value * 100) + "%" }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Blur strength:")
            enabled: launcherStyle.currentIndex !== 3 && launcherBlur.currentIndex !== 2
            QQC2.Button {
                text: i18n("Desktop Effects…")
                icon.name: "preferences-desktop-effects"
                onClicked: runner.connectSource("systemsettings kcm_kwin_effects")
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            readonly property bool blurInstalled: Qt.createComponent(Qt.resolvedUrl("shared/BlurLayer.qml")).status === Component.Ready
            text: !blurInstalled
                ? i18n("The blur helper is not installed: run ./install.sh from the Glasdock folder, then log out and back in once.")
                : i18n("\"Same as the dock\" uses the dock's blur and frost (Appearance → Blur). Lower the launcher opacity to see more of the blur.")
        }
        P5Support.DataSource {
            id: runner
            engine: "executable"
            connectedSources: []
            onNewData: sourceName => disconnectSource(sourceName)
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Size and position")
        }
        QQC2.SpinBox {
            id: launcherIconSize
            Kirigami.FormData.label: i18n("Icon size:")
            from: 16; to: 128; stepSize: 4; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: launcherWidth
            Kirigami.FormData.label: i18n("Width:")
            from: 400; to: 1600; stepSize: 10; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: launcherHeight
            Kirigami.FormData.label: i18n("Height:")
            from: 300; to: 1200; stepSize: 10; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: launcherGap
            Kirigami.FormData.label: i18n("Distance above the dock:")
            from: -40; to: 200; stepSize: 1; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Animation")
        }
        QQC2.CheckBox {
            id: launcherAnimation
            Kirigami.FormData.label: i18n("Animation:")
            text: i18n("Animate opening and closing (launcher and panels)")
        }
        QQC2.SpinBox {
            id: launcherAnimationDuration
            Kirigami.FormData.label: i18n("Duration:")
            enabled: launcherAnimation.checked
            from: 80; to: 800; stepSize: 20; editable: true
            textFromValue: v => v + " ms"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox {
            id: launcherMorph
            Kirigami.FormData.label: i18n("Transition:")
            enabled: launcherAnimation.checked
            text: i18n("Grow out of the widget (experimental)")
        }
        QQC2.SpinBox {
            id: launcherMorphGap
            Kirigami.FormData.label: i18n("Grow origin distance:")
            enabled: launcherAnimation.checked && launcherMorph.checked
            from: -24; to: 60; stepSize: 2; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
    }
}
