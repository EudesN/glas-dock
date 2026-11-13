import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.plasma.plasma5support as P5Support

KCM.SimpleKCM {
    property alias cfg_timeFormat: timeFormat.currentIndex
    property alias cfg_showDate: showDate.checked
    property alias cfg_showSeconds: showSeconds.checked
    property alias cfg_twoLines: twoLines.checked
    property var cfg_calendarPlugins: []
    property alias cfg_pillBackground: pillBackground.checked
    // style 4 (the old "Blur" style) shows as Glass with blur on
    property int cfg_popupStyle
    property bool cfg_popupBlur
    property alias cfg_popupFrost: blurFrost.value
    property alias cfg_popupOpacity: popupOpacity.value
    property alias cfg_popupRadius: popupRadius.value
    property alias cfg_popupAnimation: popupAnimation.checked
    property alias cfg_popupGap: popupGap.value
    property alias cfg_popupMorph: popupMorph.checked

    Kirigami.FormLayout {
        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Clock" }

        QQC2.ComboBox {
            id: timeFormat
            Kirigami.FormData.label: "Time format:"
            model: ["Follow the locale", "12-hour", "24-hour"]
        }
        QQC2.CheckBox { id: showSeconds; text: "Show seconds" }
        QQC2.CheckBox { id: showDate; Kirigami.FormData.label: "Date:"; text: "Show the date next to the time" }
        QQC2.CheckBox { id: twoLines; text: "Date below the time"; enabled: showDate.checked }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Events" }

        // event sources: the same plugins as Plasma's digital clock
        Repeater {
            model: pluginsManager.model
            delegate: QQC2.CheckBox {
                required property var model
                required property int index
                Kirigami.FormData.label: index === 0 ? "Show:" : ""
                text: model.display
                icon.name: model.decoration
                checked: cfg_calendarPlugins.indexOf(model.pluginId) !== -1
                onToggled: {
                    const list = cfg_calendarPlugins.slice();
                    const i = list.indexOf(model.pluginId);
                    if (checked && i === -1) list.push(model.pluginId);
                    if (!checked && i !== -1) list.splice(i, 1);
                    cfg_calendarPlugins = list;
                }
            }
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: "Holidays and their region are configured in the Digital Clock settings. Personal calendars (KOrganizer / Merkuro) appear here when the KDE PIM events plugin (kdepim-addons) is installed."
        }
        PlasmaCalendar.EventPluginsManager { id: pluginsManager }

        Kirigami.Separator { Kirigami.FormData.isSection: true; Kirigami.FormData.label: "Panel" }

        QQC2.CheckBox { id: pillBackground; Kirigami.FormData.label: "Background:"; text: "Glass pill background" }

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
