import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    property alias cfg_showLaptop: showLaptop.checked
    property alias cfg_showPeripherals: showPeripherals.checked
    property alias cfg_showBluetooth: showBluetooth.checked
    property alias cfg_showDeviceNames: showDeviceNames.checked
    property alias cfg_showPercentSymbol: showPercentSymbol.checked
    property alias cfg_useAccentColor: useAccentColor.checked
    property alias cfg_ringSize: ringSize.value

    property alias cfg_showCard: showCard.checked
    property alias cfg_cardStyle: cardStyle.currentIndex
    property alias cfg_themeMode: themeMode.currentIndex
    property alias cfg_cardOpacity: cardOpacity.value
    property alias cfg_cardRadius: cardRadius.value
    property bool cfg_blurBehind
    property alias cfg_blurFrost: blurFrost.value
    property alias cfg_showBorder: showBorder.checked
    property alias cfg_showShadow: showShadow.checked
    property alias cfg_pillBackground: pillBackground.checked
    property alias cfg_panelCompact: panelCompact.checked
    property alias cfg_popupGap: popupGap.value
    property alias cfg_popupRadius: popupRadius.value
    property alias cfg_popupAnimation: popupAnimation.checked
    property alias cfg_popupMorph: popupMorph.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Devices" }

        QQC2.CheckBox { id: showLaptop; Kirigami.FormData.label: "Show:"; text: "Laptop battery" }
        QQC2.CheckBox { id: showPeripherals; text: "Wireless peripherals (mouse, keyboard, controller)" }
        QQC2.CheckBox {
            id: showBluetooth
            enabled: showPeripherals.checked
            text: "Bluetooth audio devices (headphones, earbuds)"
        }
        QQC2.CheckBox { id: showDeviceNames; text: "Device names under percentages" }
        QQC2.CheckBox { id: showPercentSymbol; text: "Show % symbol next to numbers" }
        QQC2.CheckBox { id: useAccentColor; Kirigami.FormData.label: "Ring color:"; text: "Use the system accent color instead of battery green" }

        QQC2.SpinBox {
            id: ringSize
            Kirigami.FormData.label: "Ring size:"
            from: 42; to: 110; stepSize: 2
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Glass surface" }

        QQC2.CheckBox { id: showCard; Kirigami.FormData.label: "Backdrop:"; text: "Show glass card on desktop" }
        QQC2.ComboBox {
            id: cardStyle
            Kirigami.FormData.label: "Style:"
            model: ["Glass", "Frosted", "Clear", "Solid"]
        }
        QQC2.ComboBox {
            id: themeMode
            Kirigami.FormData.label: "Theme:"
            model: ["Follow system", "Dark", "Light"]
        }
        RowLayout {
            Kirigami.FormData.label: "Opacity:"
            enabled: cardStyle.currentIndex === 0 || cardStyle.currentIndex === 1
            QQC2.Slider { id: cardOpacity; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(cardOpacity.value * 100) + "%" }
        }
        QQC2.SpinBox {
            id: cardRadius
            Kirigami.FormData.label: "Corner radius:"
            from: 0; to: 48
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox { id: showBorder; Kirigami.FormData.label: "Details:"; text: "Border" }
        QQC2.CheckBox { id: showShadow; enabled: cardStyle.currentIndex !== 2; text: "Shadow" }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Blur" }

        QQC2.ComboBox {
            id: blurBehind
            Kirigami.FormData.label: "Blur behind:"
            enabled: cardStyle.currentIndex !== 3
            model: ["On", "Off"]
            currentIndex: cfg_blurBehind ? 0 : 1
            onActivated: index => cfg_blurBehind = (index === 0)
        }
        RowLayout {
            Kirigami.FormData.label: "Frost:"
            enabled: cardStyle.currentIndex !== 3 && blurBehind.currentIndex === 0
            QQC2.Slider { id: blurFrost; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(blurFrost.value * 100) + "%" }
        }
        RowLayout {
            Kirigami.FormData.label: "Blur strength:"
            enabled: cardStyle.currentIndex !== 3 && blurBehind.currentIndex === 0
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
                : "Frost adds a milky, grainy layer over the blur. Lower the opacity to see more of the blur."
        }
        P5Support.DataSource {
            id: runner
            engine: "executable"
            connectedSources: []
            onNewData: sourceName => disconnectSource(sourceName)
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Status bar & popup" }

        QQC2.CheckBox { id: pillBackground; Kirigami.FormData.label: "Status bar:"; text: "Glass pill background" }
        QQC2.CheckBox { id: panelCompact; text: "Compact mode (primary device + count badge)" }
        QQC2.SpinBox {
            id: popupRadius
            Kirigami.FormData.label: "Popup corner radius:"
            from: 0; to: 48
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: popupGap
            Kirigami.FormData.label: "Distance from the widget:"
            from: -8; to: 60
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox { id: popupAnimation; text: "Animate opening and closing" }
        QQC2.CheckBox {
            id: popupMorph
            enabled: popupAnimation.checked
            text: "Grow out of the widget (experimental)"
        }
    }
}
