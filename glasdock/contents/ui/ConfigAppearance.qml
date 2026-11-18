import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as P5Support

// Glasdock settings — Appearance
KCM.SimpleKCM {
    // style 4 (the old "Blur" style) shows as Glass with blur on
    property int cfg_dockStyle
    property alias cfg_themeMode: themeMode.currentIndex
    property bool cfg_blurBehind
    property alias cfg_blurFrost: blurFrost.value
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
            Kirigami.FormData.label: i18n("Background")
        }
        QQC2.ComboBox {
            id: dockStyle
            Kirigami.FormData.label: i18n("Style:")
            model: [i18n("Glass"), i18n("Frosted"), i18n("Clear (no background)"), i18n("Solid")]
            currentIndex: cfg_dockStyle === 4 ? 0 : cfg_dockStyle
            onActivated: index => {
                if (cfg_dockStyle === 4)
                    cfg_blurBehind = true;
                cfg_dockStyle = index;
            }
        }
        QQC2.ComboBox {
            id: themeMode
            Kirigami.FormData.label: i18n("Theme:")
            model: [i18n("Follow system"), i18n("Dark"), i18n("Light")]
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Opacity:")
            enabled: dockStyle.currentIndex === 0 || dockStyle.currentIndex === 1
            QQC2.Slider { id: glassOpacity; from: 0.0; to: 0.8; stepSize: 0.01 }
            QQC2.Label { text: Math.round(glassOpacity.value * 100) + "%" }
        }
        QQC2.SpinBox {
            id: cornerRadius
            Kirigami.FormData.label: i18n("Corner radius:")
            from: 0; to: 64; stepSize: 1; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.CheckBox {
            id: showBorder
            Kirigami.FormData.label: i18n("Details:")
            text: i18n("Border")
        }
        QQC2.CheckBox {
            id: showShadow
            enabled: dockStyle.currentIndex !== 2
            text: i18n("Shadow")
        }
        // ---- real blur (org.glasdock.blur helper plugin)
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Blur")
        }
        QQC2.ComboBox {
            id: blurBehind
            Kirigami.FormData.label: i18n("Blur behind:")
            enabled: dockStyle.currentIndex !== 3
            model: [i18n("On"), i18n("Off")]
            currentIndex: (cfg_blurBehind || cfg_dockStyle === 4) ? 0 : 1
            onActivated: index => {
                cfg_blurBehind = (index === 0);
                if (cfg_dockStyle === 4)
                    cfg_dockStyle = 0;
            }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Frost:")
            enabled: dockStyle.currentIndex !== 3 && blurBehind.currentIndex === 0
            QQC2.Slider { id: blurFrost; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label { text: Math.round(blurFrost.value * 100) + "%" }
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Blur strength:")
            enabled: dockStyle.currentIndex !== 3 && blurBehind.currentIndex === 0
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
                : i18n("Frost adds a milky, grainy layer over the blur. How strongly KWin blurs is a system-wide setting: Desktop Effects → Blur. Lower the opacity to see more of the blur.")
        }
        P5Support.DataSource {
            id: runner
            engine: "executable"
            connectedSources: []
            onNewData: sourceName => disconnectSource(sourceName)
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Colors")
        }
        QQC2.CheckBox {
            id: useAccentColor
            Kirigami.FormData.label: i18n("Accent color:")
            text: i18n("Use the system accent color for dots, labels and highlights")
        }
        RowLayout {
            Kirigami.FormData.label: i18n("Accent tint on glass:")
            QQC2.Slider { id: glassAccentTint; from: 0.0; to: 0.5; stepSize: 0.01 }
            QQC2.Label { text: Math.round(glassAccentTint.value * 100) + "%" }
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Size and position")
        }
        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: i18n("Icon size:")
            from: 24; to: 128; stepSize: 1; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: iconSpacing
            Kirigami.FormData.label: i18n("Icon spacing:")
            from: 0; to: 48; stepSize: 1; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        QQC2.SpinBox {
            id: bottomMargin
            Kirigami.FormData.label: i18n("Distance from screen edge:")
            from: 0; to: 48; stepSize: 1; editable: true
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel")
        }
        QQC2.CheckBox {
            id: transparentPanel
            Kirigami.FormData.label: i18n("Panel:")
            text: i18n("Make the panel transparent (only the glass is visible)")
        }
        QQC2.CheckBox {
            id: autoPanelHeight
            text: i18n("Resize the panel to fit the icon size and zoom")
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: i18n("The Meta key and Alt+F1 open the launcher. Window previews, badges and zoom are in the Behavior tab.")
        }
    }
}
