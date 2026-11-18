import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    property alias cfg_maxWidth: maxWidth.value
    property alias cfg_showArtist: showArtist.checked
    property alias cfg_showSkipButtons: showSkipButtons.checked
    property alias cfg_hideWhenIdle: hideWhenIdle.checked
    property alias cfg_pillBackground: pillBackground.checked
    // style 4 (the old "Blur" style) shows as Glass with blur on
    property int cfg_popupStyle
    property alias cfg_themeMode: themeMode.currentIndex
    property bool cfg_popupBlur
    property alias cfg_popupFrost: blurFrost.value
    property alias cfg_popupOpacity: popupOpacity.value
    property alias cfg_popupRadius: popupRadius.value
    property alias cfg_popupAnimation: popupAnimation.checked
    property alias cfg_popupGap: popupGap.value
    property alias cfg_popupMorph: popupMorph.checked
    property alias cfg_popupMorphGap: popupMorphGap.value

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Panel" }

        QQC2.SpinBox {
            id: maxWidth
            Kirigami.FormData.label: i18n("Maximum width:")
            from: 120; to: 800; stepSize: 10; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox { id: showArtist; Kirigami.FormData.label: "Show:"; text: "Artist next to the title" }
        QQC2.CheckBox { id: showSkipButtons; text: "Previous / next buttons" }
        QQC2.CheckBox { id: pillBackground; text: "Glass pill background" }
        QQC2.CheckBox { id: hideWhenIdle; Kirigami.FormData.label: "Behavior:"; text: "Only show when media is playing or queued" }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Glass panel" }

        QQC2.ComboBox {
            id: popupStyle
            Kirigami.FormData.label: "Style:"
            model: ["Glass", "Frosted", "Clear", "Solid"]
            currentIndex: cfg_popupStyle === 4 ? 0 : cfg_popupStyle
            onActivated: index => {
                if (cfg_popupStyle === 4)
                    cfg_popupBlur = true;
                cfg_popupStyle = index;
            }
        }
        QQC2.ComboBox {
            id: themeMode
            Kirigami.FormData.label: "Theme:"
            model: ["Follow system", "Dark", "Light"]
        }
        RowLayout {
            Kirigami.FormData.label: "Opacity:"
            QQC2.Slider { id: popupOpacity; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(popupOpacity.value * 100) + "%" }
        }
        QQC2.SpinBox {
            id: popupRadius
            Kirigami.FormData.label: i18n("Corner radius:")
            from: 0; to: 48; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: popupGap
            Kirigami.FormData.label: "Distance from the widget:"
            from: -8; to: 60; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox { id: popupAnimation; text: "Animate opening and closing" }
        QQC2.CheckBox {
            id: popupMorph
            enabled: popupAnimation.checked
            text: "Grow out of the widget (experimental)"
        }
        QQC2.SpinBox {
            id: popupMorphGap
            Kirigami.FormData.label: "Grow origin distance:"
            enabled: popupAnimation.checked && popupMorph.checked
            from: -24; to: 60; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        // ---- real blur (org.glasdock.blur helper plugin)
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Blur"
        }
        QQC2.ComboBox {
            id: blurBehind
            Kirigami.FormData.label: "Blur behind:"
            enabled: popupStyle.currentIndex !== 3
            model: ["On", "Off"]
            currentIndex: (cfg_popupBlur || cfg_popupStyle === 4) ? 0 : 1
            onActivated: index => {
                cfg_popupBlur = (index === 0);
                if (cfg_popupStyle === 4)
                    cfg_popupStyle = 0;
            }
        }
        RowLayout {
            Kirigami.FormData.label: "Frost:"
            enabled: popupStyle.currentIndex !== 3 && blurBehind.currentIndex === 0
            QQC2.Slider { id: blurFrost; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(blurFrost.value * 100) + "%" }
        }
        RowLayout {
            Kirigami.FormData.label: "Blur strength:"
            enabled: popupStyle.currentIndex !== 3 && blurBehind.currentIndex === 0
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
            readonly property bool blurInstalled: Qt.createComponent(Qt.resolvedUrl("shared/BlurLayer.qml")).status === Component.Ready
            text: !blurInstalled
                ? "The blur helper is not installed: run ./install.sh from the Glasdock folder, then log out and back in once."
                : "Frost adds a milky, grainy layer over the blur. How strongly KWin blurs is a system-wide setting: Desktop Effects → Blur. Lower the opacity to see more of the blur."
        }
        P5Support.DataSource {
            id: runner
            engine: "executable"
            connectedSources: []
            onNewData: sourceName => disconnectSource(sourceName)
        }


        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Tip: middle-click to play/pause, scroll over the widget to skip tracks."
        }
    }
}
