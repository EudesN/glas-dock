import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_iconSize: iconSize.value
    property alias cfg_iconSpacing: iconSpacing.value
    property alias cfg_centeredZoom: centeredZoom.checked
    property alias cfg_allowReorder: allowReorder.checked
    property alias cfg_useAccentColor: useAccentColor.checked
    property alias cfg_glassAccentTint: glassAccentTint.value
    property alias cfg_dockStyle: dockStyle.currentIndex
    property alias cfg_showPlayer: showPlayer.checked
    property alias cfg_showWeather: showWeather.checked
    property alias cfg_showClock: showClock.checked
    property alias cfg_weatherCity: weatherCity.text
    property alias cfg_weatherFahrenheit: weatherFahrenheit.checked
    property alias cfg_showBorder: showBorder.checked
    property alias cfg_showShadow: showShadow.checked
    property alias cfg_showBadges: showBadges.checked
    property alias cfg_badgeUseAccent: badgeUseAccent.checked
    property alias cfg_launcherAnimation: launcherAnimation.checked
    property alias cfg_launcherAnimationDuration: launcherAnimationDuration.value
    property alias cfg_maxZoom: maxZoom.value
    property alias cfg_zoomRange: zoomRange.value
    property alias cfg_glassOpacity: glassOpacity.value
    property alias cfg_cornerRadius: cornerRadius.value
    property alias cfg_bottomMargin: bottomMargin.value
    property alias cfg_showLabels: showLabels.checked
    property alias cfg_onlyCurrentDesktop: onlyCurrentDesktop.checked
    property alias cfg_showAppsButton: showAppsButton.checked
    property alias cfg_appsButtonZoom: appsButtonZoom.checked
    property alias cfg_transparentPanel: transparentPanel.checked
    property alias cfg_launcherGap: launcherGap.value
    property alias cfg_launcherIconSize: launcherIconSize.value
    property alias cfg_launcherOpacity: launcherOpacity.value
    property alias cfg_launcherCustomBackground: launcherCustomBackground.checked
    property alias cfg_autoPanelHeight: autoPanelHeight.checked
    property alias cfg_launcherWidth: launcherWidth.value
    property alias cfg_launcherHeight: launcherHeight.value

    Kirigami.FormLayout {
        // ------------------------------------------------------------ dock
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Dock"
        }

        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: "Dock icon size:"
            from: 24; to: 128
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        QQC2.SpinBox {
            id: iconSpacing
            Kirigami.FormData.label: "Icon spacing:"
            from: 0; to: 48
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        RowLayout {
            Kirigami.FormData.label: "Maximum zoom:"
            QQC2.Slider { id: maxZoom; from: 1.0; to: 2.5; stepSize: 0.05 }
            QQC2.Label { text: maxZoom.value.toFixed(2) + "×" }
        }

        RowLayout {
            Kirigami.FormData.label: "Zoom reach:"
            QQC2.Slider { id: zoomRange; from: 1.0; to: 5.0; stepSize: 0.1 }
            QQC2.Label { text: zoomRange.value.toFixed(1) + " icons" }
        }

        QQC2.ComboBox {
            id: dockStyle
            Kirigami.FormData.label: "Style:"
            model: ["Glass", "Frosted", "Clear (no background)", "Solid"]
        }

        RowLayout {
            Kirigami.FormData.label: "Background opacity:"
            enabled: dockStyle.currentIndex === 0 || dockStyle.currentIndex === 1
            QQC2.Slider { id: glassOpacity; from: 0.0; to: 0.8; stepSize: 0.01 }
            QQC2.Label { text: Math.round(glassOpacity.value * 100) + "%" }
        }

        QQC2.CheckBox {
            id: showBorder
            Kirigami.FormData.label: "Details:"
            text: "Border"
        }

        QQC2.CheckBox {
            id: showShadow
            text: "Shadow"
            enabled: dockStyle.currentIndex !== 2
        }

        QQC2.CheckBox {
            id: useAccentColor
            Kirigami.FormData.label: "Accent color:"
            text: "Use the system accent color for the dock details"
        }

        RowLayout {
            Kirigami.FormData.label: "Accent tint on glass:"
            QQC2.Slider { id: glassAccentTint; from: 0.0; to: 0.5; stepSize: 0.01 }
            QQC2.Label { text: Math.round(glassAccentTint.value * 100) + "%" }
        }

        QQC2.SpinBox {
            id: cornerRadius
            Kirigami.FormData.label: "Corner radius:"
            from: 0; to: 64
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        QQC2.SpinBox {
            id: bottomMargin
            Kirigami.FormData.label: "Distance from screen edge:"
            from: 0; to: 48
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        QQC2.CheckBox {
            id: centeredZoom
            Kirigami.FormData.label: "Zoom:"
            text: "Keep the dock centered while zooming"
        }

        QQC2.CheckBox {
            id: showBadges
            Kirigami.FormData.label: "Notifications:"
            text: "Show a badge on apps with unread notifications"
        }

        QQC2.CheckBox {
            id: badgeUseAccent
            text: "Use the system accent color for badges (otherwise red)"
            enabled: showBadges.checked
        }

        QQC2.CheckBox {
            id: allowReorder
            Kirigami.FormData.label: "Behavior:"
            text: "Drag icons to reorder them"
        }

        QQC2.CheckBox {
            id: showLabels
            text: "Show app name on hover"
        }

        QQC2.CheckBox {
            id: onlyCurrentDesktop
            text: "Only show windows from the current desktop"
        }

        QQC2.CheckBox {
            id: autoPanelHeight
            text: "Resize the panel to fit the icon size and zoom"
        }

        QQC2.CheckBox {
            id: transparentPanel
            text: "Make the panel transparent (only the glass is visible)"
        }

        // --------------------------------------------------------- widgets
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Widgets (experimental)"
        }

        QQC2.CheckBox {
            id: showPlayer
            Kirigami.FormData.label: "Show:"
            text: "Media player"
        }

        QQC2.CheckBox {
            id: showWeather
            text: "Weather"
        }

        QQC2.CheckBox {
            id: showClock
            text: "Clock"
        }

        QQC2.TextField {
            id: weatherCity
            Kirigami.FormData.label: "Weather city:"
            enabled: showWeather.checked
            placeholderText: "e.g. São Paulo"
        }

        QQC2.CheckBox {
            id: weatherFahrenheit
            enabled: showWeather.checked
            text: "Use Fahrenheit"
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            visible: showWeather.checked
            text: "The city name is sent to Open-Meteo.com to find the forecast."
        }

        // -------------------------------------------------------- launcher
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Launcher"
        }

        QQC2.CheckBox {
            id: showAppsButton
            Kirigami.FormData.label: "Apps button:"
            text: "Show at the start of the dock"
        }

        QQC2.CheckBox {
            id: appsButtonZoom
            text: "Zoom the apps button too"
            enabled: showAppsButton.checked
        }

        QQC2.SpinBox {
            id: launcherGap
            Kirigami.FormData.label: "Distance above the dock:"
            from: -40; to: 200
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        QQC2.SpinBox {
            id: launcherIconSize
            Kirigami.FormData.label: "Launcher icon size:"
            from: 16; to: 128; stepSize: 4
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        QQC2.CheckBox {
            id: launcherCustomBackground
            Kirigami.FormData.label: "Launcher background:"
            text: "Custom glass (any transparency, no blur)"
        }

        RowLayout {
            Kirigami.FormData.label: "Launcher opacity:"
            QQC2.Slider { id: launcherOpacity; from: 0.0; to: 1.0; stepSize: 0.01 }
            QQC2.Label {
                text: Math.round(launcherOpacity.value * 100) + "%"
                      + (!launcherCustomBackground.checked && launcherOpacity.value === 0 ? " (theme default)" : "")
            }
        }

        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: launcherCustomBackground.checked
                  ? "Custom glass: 0% is fully transparent, 100% is solid. The desktop behind is not blurred."
                  : "Theme background keeps the blur. The slider adds tint on top: 0% looks like the theme, 100% is solid."
        }

        QQC2.CheckBox {
            id: launcherAnimation
            Kirigami.FormData.label: "Launcher animation:"
            text: "Animate opening and closing"
        }

        QQC2.SpinBox {
            id: launcherAnimationDuration
            Kirigami.FormData.label: "Animation duration:"
            enabled: launcherAnimation.checked
            from: 80; to: 800; stepSize: 20
            textFromValue: v => v + " ms"
            valueFromText: t => parseInt(t)
        }

        QQC2.SpinBox {
            id: launcherWidth
            Kirigami.FormData.label: "Launcher width:"
            from: 400; to: 1600; stepSize: 10
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        QQC2.SpinBox {
            id: launcherHeight
            Kirigami.FormData.label: "Launcher height:"
            from: 300; to: 1200; stepSize: 10
            textFromValue: v => v + " px"
            valueFromText: t => parseInt(t)
        }

        Kirigami.Separator { Kirigami.FormData.isSection: true }

        QQC2.Label {
            Kirigami.FormData.label: "Tip:"
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            text: (autoPanelHeight.checked ? "The panel will be resized to about " : "Keep the panel about ")
                  + Math.ceil(bottomMargin.value + iconSize.value * 0.18
                              + iconSize.value * maxZoom.value
                              + (showLabels.checked ? Kirigami.Units.gridUnit * 2 : 0))
                  + " px tall so the zoom has room to grow. The Meta key and Alt+F1 open the launcher."
        }
    }
}
