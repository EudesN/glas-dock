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
        // Single-shot, re-armed from the real time on every tick so it lands just
        // after each second/minute boundary. Qt timers stop counting during
        // suspend, so in minute mode it also wakes at least every 5 s: after a
        // resume the clock is right within 5 s instead of up to a minute late.
        id: clockTimer
        repeat: false
        triggeredOnStart: true
        running: true
        onTriggered: {
            const d = new Date();
            const sec = root.cfg.showSeconds;
            // only touch `now` when the shown text can change (no needless rebinds)
            if (sec || d.getMinutes() !== root.now.getMinutes() || d.getHours() !== root.now.getHours()
                    || d.getDate() !== root.now.getDate())
                root.now = d;
            const toNextSecond = 1000 - d.getMilliseconds() + 20;
            interval = sec ? toNextSecond
                : Math.min(5000, (59 - d.getSeconds()) * 1000 + toNextSecond);
            restart();
        }
    }
    Connections {
        target: root.cfg
        function onShowSecondsChanged() { clockTimer.interval = 1; clockTimer.restart(); }
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
        const script = decodeURIComponent(Qt.resolvedUrl("../code/country.sh").toString().replace("file://", ""));
        shell.run("country", "sh '" + script + "'");
        shell.run("read", "kreadconfig6 --file plasma_calendar_holiday_regions --group General --key selectedRegions");
    }

    Shared.ThemeScope { id: themeScope; target: null; themeMode: root.cfg.themeMode }
    readonly property bool isDark: themeScope.isDark
    readonly property color accent: themeScope.accent

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: root.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
    toolTipSubText: ""

    fullRepresentation: Item {
        id: compact

        Shared.ThemeScope { target: compact; themeMode: root.cfg.themeMode }
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        readonly property real pad: Math.round((vertical ? width : height) * 0.12)
        readonly property bool stacked: root.cfg.showDate && (vertical || root.cfg.twoLines || height >= 44)

        activeFocusOnTab: true
        Accessible.role: Accessible.Button
        Accessible.name: root.timeText(root.now) + ", " + root.toolTipMainText
        Keys.onReturnPressed: popup.toggle()
        Keys.onSpacePressed: popup.toggle()

        Layout.preferredWidth: vertical ? -1 : Math.ceil(content.implicitWidth) + pad * (root.cfg.pillBackground ? 4 : 2) + 4
        Layout.minimumWidth: vertical ? 0 : Layout.preferredWidth
        Layout.preferredHeight: vertical ? Math.ceil(content.implicitHeight) + pad * 2 + 4 : -1
        Layout.minimumHeight: vertical ? Layout.preferredHeight : 0
        Layout.fillWidth: vertical
        Layout.fillHeight: !vertical

        Rectangle {
            visible: root.cfg.pillBackground
            anchors.fill: parent
            anchors.topMargin: compact.pad / 2
            anchors.bottomMargin: compact.pad / 2
            radius: Math.min(width, height) / 2
            color: root.isDark ? Qt.rgba(1, 1, 1, area.containsMouse ? 0.14 : 0.08)
                               : Qt.rgba(1, 1, 1, area.containsMouse ? 0.6 : 0.4)
            border.width: (popup.visible && !popup.closing) || compact.activeFocus ? 1 : 0
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.6)
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
            width: compact.vertical ? Math.max(0, compact.width - compact.pad * 2) : implicitWidth
            columns: compact.stacked ? 1 : 2
            rowSpacing: 0
            columnSpacing: Math.round(compact.height * 0.25)

            PC3.Label {
                visible: root.cfg.showDate
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: compact.vertical
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.now.toLocaleDateString(Qt.locale(), i18n("ddd, d MMM"))
                opacity: 0.65
                font: compact.stacked ? Kirigami.Theme.smallFont : Kirigami.Theme.defaultFont
            }
            PC3.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: compact.vertical
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.timeText(root.now)
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }      // digits don't jump around
            }
        }

        Shared.GlassPopup {
            id: popup
            anchorItem: compact
            edge: Plasmoid.location
            gap: root.cfg.popupGap
            morph: root.cfg.popupMorph
            morphDistance: root.cfg.popupMorphGap
            screenGeometry: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 0, 0)
            style: root.cfg.popupStyle
            backgroundOpacity: root.cfg.popupOpacity
            radius: root.cfg.popupRadius
            themeMode: root.cfg.themeMode
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
