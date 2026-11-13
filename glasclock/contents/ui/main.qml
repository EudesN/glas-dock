/*
 * Glasclock — clock and calendar for a Plasma panel (Glasdock project).
 * Time and date in the panel; click for a glass panel with the day's events
 * (from Plasma's calendar event plugins) and the month.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar
import org.kde.plasma.plasma5support as P5Support
import org.kde.kholidays as KHolidays
import "shared" as Shared

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    property date now: new Date()
    Timer {
        // every second when seconds are shown, otherwise on the minute
        interval: root.cfg.showSeconds ? 1000 : (60 - root.now.getSeconds()) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // 0 = follow the locale, 1 = 12-hour, 2 = 24-hour
    function timeText(d) {
        const sec = cfg.showSeconds;
        if (cfg.timeFormat === 1)
            return Qt.formatTime(d, sec ? "h:mm:ss AP" : "h:mm AP");
        if (cfg.timeFormat === 2)
            return Qt.formatTime(d, sec ? "HH:mm:ss" : "HH:mm");
        let f = Qt.locale().timeFormat(Locale.ShortFormat);
        if (sec && f.indexOf("ss") === -1)
            f = f.replace("mm", "mm:ss");
        return Qt.formatTime(d, f);
    }

    // event sources (holidays, moon phases, KDE PIM agenda when installed…)
    // (enabledPlugins loads them; populateEnabledPluginsList only fills the
    // settings list)
    PlasmaCalendar.EventPluginsManager {
        id: eventPlugins
        Component.onCompleted: enabledPlugins = root.cfg.calendarPlugins
    }
    function reloadEventPlugins() {
        eventPlugins.enabledPlugins = [];
        Qt.callLater(() => eventPlugins.enabledPlugins = root.cfg.calendarPlugins);
    }
    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key, value) {
            if (key === "calendarPlugins")
                root.reloadEventPlugins();
            if (key === "holidayRegion")
                root.applyHolidayRegion();
        }
    }

    // ---- holidays of the user's country
    // Plasma's holidays plugin uses the region stored in
    // plasma_calendar_holiday_regions [General] selectedRegions (shared with
    // the Digital Clock). "auto": detect the country from the system time
    // zone and set its region only when none is configured yet; a region
    // chosen in the settings always replaces it.
    property string countryCode: ""          // e.g. "BR"
    property string pluginRegions: "?"       // current selectedRegions ("?" = not read yet)
    property var regionCodes: []             // all KHolidays region codes
    readonly property string autoRegion: regionForCountry(countryCode)

    KHolidays.HolidayRegionsModel { id: holidayRegions }
    Instantiator {
        id: regionInst
        model: holidayRegions
        delegate: QtObject { required property string region }
        onObjectAdded: (i, obj) => regionTimer.restart()
    }
    Timer {
        id: regionTimer
        interval: 50
        onTriggered: {
            const codes = [];
            for (let i = 0; i < regionInst.count; i++) {
                const o = regionInst.objectAt(i);
                if (o && o.region)
                    codes.push(o.region);
            }
            root.regionCodes = codes;
            root.applyHolidayRegion();
        }
    }

    // national region of a country: "br" -> "br_pt-br"; prefers the
    // locale's language when a country has several (e.g. "ca_en"/"ca_fr")
    function regionForCountry(cc) {
        if (!cc)
            return "";
        const lang = Qt.locale().name.split("_")[0];
        const national = regionCodes.filter(c => c.split("_")[0] === cc.toLowerCase());
        return national.find(c => c.split("_")[1] && c.split("_")[1].indexOf(lang) === 0) || national[0] || "";
    }

    function applyHolidayRegion() {
        if (pluginRegions === "?")
            return;
        const manual = cfg.holidayRegion && cfg.holidayRegion !== "auto";
        const wanted = manual ? cfg.holidayRegion : autoRegion;
        if (!wanted)
            return;
        if (manual ? pluginRegions === wanted : pluginRegions !== "")
            return;
        shell.run("write", "kwriteconfig6 --file plasma_calendar_holiday_regions --group General --key selectedRegions " + wanted);
        pluginRegions = wanted;
    }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        property var tags: ({})
        function run(tag, cmd) {
            tags[cmd] = tag;
            connectSource(cmd);
        }
        onNewData: (source, data) => {
            const out = (data["stdout"] || "").trim();
            const tag = tags[source];
            disconnectSource(source);
            if (tag === "country") {
                root.countryCode = out;
                root.applyHolidayRegion();
            } else if (tag === "read") {
                root.pluginRegions = out;
                root.applyHolidayRegion();
            } else if (tag === "write") {
                root.reloadEventPlugins();
            }
        }
    }
    Component.onCompleted: {
        // time zone (also old aliases like Brazil/East) -> canonical zone -> ISO country
        const script = Qt.resolvedUrl("../code/country.sh").toString().replace("file://", "");
        shell.run("country", "sh '" + script + "'");
        shell.run("read", "kreadconfig6 --file plasma_calendar_holiday_regions --group General --key selectedRegions");
    }

    readonly property bool isDark: Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.backgroundColor) === Kirigami.ColorUtils.Dark
    readonly property color accent: isDark
        && Kirigami.ColorUtils.brightnessForColor(Kirigami.Theme.highlightColor) === Kirigami.ColorUtils.Dark
        ? Qt.lighter(Kirigami.Theme.highlightColor, 1.5) : Kirigami.Theme.highlightColor

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: root.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
    toolTipSubText: ""

    fullRepresentation: Item {
        id: compact

        readonly property real pad: Math.round(height * 0.12)
        readonly property bool stacked: root.cfg.showDate && (root.cfg.twoLines || height >= 44)

        Layout.preferredWidth: Math.ceil(content.implicitWidth) + pad * (root.cfg.pillBackground ? 4 : 2) + 4
        Layout.minimumWidth: Layout.preferredWidth
        Layout.fillHeight: true

        Rectangle {
            visible: root.cfg.pillBackground
            anchors.fill: parent
            anchors.topMargin: compact.pad / 2
            anchors.bottomMargin: compact.pad / 2
            radius: height / 2
            color: root.isDark ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.14 : 0.08)
                               : Qt.rgba(1, 1, 1, area.containsMouse ? 0.6 : 0.4)
            border.width: 1
            border.color: popup.visible && !popup.closing
                ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
                : Qt.rgba(1, 1, 1, root.isDark ? 0.10 : 0.45)
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: popup.toggle()
        }

        GridLayout {
            id: content
            anchors.centerIn: parent
            columns: compact.stacked ? 1 : 2
            rowSpacing: 0
            columnSpacing: Math.round(compact.height * 0.25)

            PC3.Label {
                Layout.alignment: Qt.AlignHCenter
                text: root.timeText(root.now)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }      // digits don't jump around
            }
            PC3.Label {
                visible: root.cfg.showDate
                Layout.alignment: Qt.AlignHCenter
                text: root.now.toLocaleDateString(Qt.locale(), "ddd, d MMM")
                opacity: 0.65
                font: compact.stacked ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont
            }
        }

        Shared.GlassPopup {
            id: popup
            anchorItem: compact
            edge: Plasmoid.location
            gap: root.cfg.popupGap
            morph: root.cfg.popupMorph
            screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
            style: root.cfg.popupStyle
            backgroundOpacity: root.cfg.popupOpacity
            radius: root.cfg.popupRadius
            isDark: root.isDark
            accent: root.accent
            animated: root.cfg.popupAnimation
            blurBehind: root.cfg.popupBlur || root.cfg.popupStyle === 4
            frost: root.cfg.popupFrost
            sourceComponent: CalendarPopup {
                now: root.now
                accent: root.accent
                isDark: root.isDark
                eventPluginsManager: eventPlugins
                timeText: root.timeText
            }
        }
    }
}
