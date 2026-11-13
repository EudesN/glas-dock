import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    property alias cfg_city: city.text
    property alias cfg_fahrenheit: fahrenheit.checked
    property alias cfg_showCity: showCity.checked
    property alias cfg_pillBackground: pillBackground.checked
    // style 4 (the old "Blur" style) shows as Glass with blur on
    property int cfg_popupStyle
    property bool cfg_popupBlur
    property alias cfg_popupFrost: blurFrost.value
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
            currentIndex: cfg_popupStyle === 4 ? 0 : cfg_popupStyle
            onActivated: index => {
                if (cfg_popupStyle === 4)
                    cfg_popupBlur = true;
                cfg_popupStyle = index;
            }
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

        // ---- real blur (org.glasdock.blur helper plugin)
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Blur"
        }
        QQC2.CheckBox {
            id: blurBehind
            Kirigami.FormData.label: "Blur:"
            text: "Blur the desktop behind the glass"
            checked: cfg_popupBlur || cfg_popupStyle === 4
            onToggled: {
                cfg_popupBlur = checked;
                if (cfg_popupStyle === 4)
                    cfg_popupStyle = 0;
            }
        }
        RowLayout {
            Kirigami.FormData.label: "Frost:"
            enabled: blurBehind.checked
            QQC2.Slider { id: blurFrost; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(blurFrost.value * 100) + "%" }
        }
        RowLayout {
            Kirigami.FormData.label: "Blur strength:"
            enabled: blurBehind.checked
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
                : "Frost adds a milky, grainy layer over the blur. How strongly KWin blurs is a system-wide setting: Desktop Effects → Blur. Lower the opacity to see more of the blur."
        }
        // probes whether the helper plugin can be loaded
        Loader { id: blurProbe; visible: false; source: Qt.resolvedUrl("shared/BlurLayer.qml") }
        P5Support.DataSource {
            id: runner
            engine: "executable"
            connectedSources: []
            onNewData: sourceName => disconnectSource(sourceName)
        }

    }
}
