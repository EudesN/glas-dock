/*
 * Glasdeskclock — resizable glass clock widget for the Plasma desktop.
 * Supports Digital, Editorial (stacked), and Analog faces, optional glass card
 * backdrop, and Follow-system / Dark / Light themes from Glasdock's shared system.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import "shared" as Shared

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    property date now: new Date()
    Timer {
        interval: root.cfg.showSeconds
            ? 1000 : Math.max(1000, (60 - root.now.getSeconds()) * 1000 - root.now.getMilliseconds() + 50)
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Shared.ThemeScope { id: themeScope; target: null; themeMode: root.cfg.themeMode }
    readonly property bool isDark: themeScope.isDark
    readonly property color accent: themeScope.accent

    function use12Hour() {
        if (cfg.timeFormat === 1)
            return true;
        if (cfg.timeFormat === 2)
            return false;
        const fmt = Qt.locale().timeFormat(Locale.ShortFormat);
        return fmt.indexOf("AP") !== -1 || fmt.indexOf("ap") !== -1;
    }

    function formattedHours(d) {
        return Qt.formatTime(d, use12Hour() ? "hh" : "HH");
    }

    function formattedMinutes(d) {
        return String(d.getMinutes()).padStart(2, "0");
    }

    function formattedHm(d) {
        return Qt.formatTime(d, use12Hour() ? "h:mm" : "HH:mm");
    }

    function formattedSeconds(d) {
        return String(d.getSeconds()).padStart(2, "0");
    }

    function formattedAmPm(d) {
        return use12Hour() ? Qt.formatTime(d, "AP") : "";
    }

    function formattedWeekdayPrefix(d) {
        if (!cfg.showWeekday)
            return "";
        return d.toLocaleDateString(Qt.locale(), "ddd").toUpperCase().replace(/\.$/, "") + ",";
    }

    function formattedShortDate(d) {
        const s = d.toLocaleDateString(Qt.locale(), "MMM d");
        return s.toUpperCase().replace(/\./g, "");
    }

    function formattedDate(d) {
        if (cfg.showWeekday) {
            const s = d.toLocaleDateString(Qt.locale(), "dddd, d MMM");
            return s.length > 0 ? s.charAt(0).toUpperCase() + s.slice(1) : "";
        }
        return d.toLocaleDateString(Qt.locale(), Locale.LongFormat);
    }

    preferredRepresentation: fullRepresentation
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    toolTipMainText: formattedHm(now)
    toolTipSubText: now.toLocaleDateString(Qt.locale(), Locale.LongFormat)

    fullRepresentation: Item {
        id: desk

        Shared.ThemeScope { target: desk; themeMode: root.cfg.themeMode }

        readonly property int mode: root.cfg.clockStyle
        readonly property int hAlign: root.cfg.alignment === 0 ? Qt.AlignLeft
                                    : root.cfg.alignment === 2 ? Qt.AlignRight : Qt.AlignHCenter
        readonly property int textAlign: root.cfg.alignment === 0 ? Text.AlignLeft
                                       : root.cfg.alignment === 2 ? Text.AlignRight : Text.AlignHCenter
        readonly property real dayProgress: (root.now.getHours() * 3600
                                          + root.now.getMinutes() * 60
                                          + root.now.getSeconds()) / 86400
        readonly property int pad: Math.round(Math.max(Kirigami.Units.largeSpacing, Math.min(width, height) * 0.08))
        readonly property color dropTint: root.isDark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(1, 1, 1, 0.65)
        readonly property color solidNumeralColor: root.cfg.solidColorMode === 1 ? "#ffffff"
                                                 : root.cfg.solidColorMode === 2 ? root.accent
                                                 : Kirigami.Theme.textColor

        implicitWidth: Kirigami.Units.gridUnit * (mode === 2 ? 14 : mode === 1 ? 15 : 17)
        implicitHeight: Kirigami.Units.gridUnit * (mode === 2 ? 14 : mode === 1 ? 13 : 9.5)
        Layout.minimumWidth: Kirigami.Units.gridUnit * 8
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6

        Shared.GlassSurface {
            anchors.fill: parent
            visible: root.cfg.showCard
            style: root.cfg.cardStyle
            backgroundOpacity: root.cfg.cardOpacity
            radius: root.cfg.cardRadius
            isDark: root.isDark
            accent: root.accent
            showBorder: root.cfg.showBorder
            showShadow: root.cfg.showShadow
            blurBehind: root.cfg.blurBehind
            frost: root.cfg.blurFrost
        }

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: desk.pad

            readonly property real baseDigitPx: desk.mode === 1
                ? Math.max(26, Math.min(width * 0.44, height * (root.cfg.showDate ? 0.35 : 0.43)))
                : Math.max(28, Math.min(width / (root.cfg.showSeconds ? 4.3 : 3.1),
                                        height * (root.cfg.showDate ? 0.58 : 0.76)))

            // ---- Mode 0: Digital (accent weekday + bold date above 3D glass/solid numeral)
            ColumnLayout {
                visible: desk.mode === 0
                anchors.fill: parent
                spacing: Math.max(0, Math.round(inner.baseDigitPx * 0.02))

                Item { Layout.fillHeight: true }

                RowLayout {
                    visible: root.cfg.showDate
                    Layout.alignment: desk.hAlign
                    spacing: Math.max(4, Math.round(inner.baseDigitPx * 0.08))

                    PC3.Label {
                        visible: root.cfg.showWeekday
                        text: root.formattedWeekdayPrefix(root.now)
                        color: root.accent
                        font.pixelSize: Math.max(12, Math.round(inner.baseDigitPx * 0.24))
                        font.weight: Font.Bold
                        font.letterSpacing: 0.6
                        style: root.cfg.showCard ? Text.Normal : Text.Raised
                        styleColor: desk.dropTint
                    }
                    PC3.Label {
                        text: root.formattedShortDate(root.now)
                        font.pixelSize: Math.max(12, Math.round(inner.baseDigitPx * 0.24))
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.4
                        opacity: 0.90
                        elide: Text.ElideRight
                        style: root.cfg.showCard ? Text.Normal : Text.Raised
                        styleColor: desk.dropTint
                    }
                }

                RowLayout {
                    Layout.alignment: desk.hAlign
                    spacing: Math.max(4, Math.round(inner.baseDigitPx * 0.08))

                    GlassNumeral {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        text: root.formattedHm(root.now)
                        pixelSize: Math.round(inner.baseDigitPx)
                        fontWeight: Font.Bold
                        isDark: root.isDark
                        glassEffect: root.cfg.glassNumerals
                        solidColor: desk.solidNumeralColor
                        dropShadow: true
                        shadowColor: desk.dropTint
                    }

                    ColumnLayout {
                        visible: root.cfg.showSeconds || root.formattedAmPm(root.now).length > 0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        PC3.Label {
                            visible: root.formattedAmPm(root.now).length > 0
                            text: root.formattedAmPm(root.now)
                            color: desk.solidNumeralColor
                            font.pixelSize: Math.max(10, Math.round(inner.baseDigitPx * 0.20))
                            font.weight: Font.DemiBold
                            opacity: 0.78
                            style: root.cfg.showCard ? Text.Normal : Text.Raised
                            styleColor: desk.dropTint
                        }
                        PC3.Label {
                            visible: root.cfg.showSeconds
                            text: ":" + root.formattedSeconds(root.now)
                            font.pixelSize: Math.max(12, Math.round(inner.baseDigitPx * 0.32))
                            font.weight: Font.Medium
                            font.features: { "tnum": 1 }
                            color: root.cfg.accentSeconds ? root.accent : desk.solidNumeralColor
                            opacity: root.cfg.accentSeconds ? 0.95 : 0.72
                            style: root.cfg.showCard ? Text.Normal : Text.Raised
                            styleColor: desk.dropTint
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // ---- Mode 1: Editorial (stacked hours / minutes)
            ColumnLayout {
                visible: desk.mode === 1
                anchors.fill: parent
                spacing: -Math.round(inner.baseDigitPx * 0.10)

                Item { Layout.fillHeight: true }

                GlassNumeral {
                    Layout.alignment: desk.hAlign
                    Layout.preferredWidth: implicitWidth
                    Layout.preferredHeight: implicitHeight
                    text: root.formattedHours(root.now)
                    pixelSize: Math.round(inner.baseDigitPx)
                    fontWeight: Font.Bold
                    isDark: root.isDark
                    glassEffect: root.cfg.glassNumerals
                    solidColor: desk.solidNumeralColor
                    dropShadow: true
                    shadowColor: desk.dropTint
                }

                RowLayout {
                    Layout.alignment: desk.hAlign
                    spacing: Math.max(4, Math.round(inner.baseDigitPx * 0.08))

                    GlassNumeral {
                        Layout.preferredWidth: implicitWidth
                        Layout.preferredHeight: implicitHeight
                        text: root.formattedMinutes(root.now)
                        pixelSize: Math.round(inner.baseDigitPx)
                        fontWeight: Font.DemiBold
                        isDark: root.isDark
                        glassEffect: root.cfg.glassNumerals
                        solidColor: desk.solidNumeralColor
                        dropShadow: true
                        shadowColor: desk.dropTint
                    }
                    ColumnLayout {
                        visible: root.cfg.showSeconds || root.formattedAmPm(root.now).length > 0
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 2

                        PC3.Label {
                            visible: root.formattedAmPm(root.now).length > 0
                            text: root.formattedAmPm(root.now)
                            color: desk.solidNumeralColor
                            font.pixelSize: Math.max(10, Math.round(inner.baseDigitPx * 0.22))
                            font.weight: Font.DemiBold
                            opacity: 0.76
                            style: root.cfg.showCard ? Text.Normal : Text.Raised
                            styleColor: desk.dropTint
                        }
                        PC3.Label {
                            visible: root.cfg.showSeconds
                            text: root.formattedSeconds(root.now)
                            font.pixelSize: Math.max(12, Math.round(inner.baseDigitPx * 0.28))
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            color: root.cfg.accentSeconds ? root.accent : desk.solidNumeralColor
                            opacity: root.cfg.accentSeconds ? 0.95 : 0.72
                            style: root.cfg.showCard ? Text.Normal : Text.Raised
                            styleColor: desk.dropTint
                        }
                    }
                }

                PC3.Label {
                    visible: root.cfg.showDate
                    Layout.alignment: desk.hAlign
                    Layout.topMargin: Math.max(4, Math.round(inner.baseDigitPx * 0.14))
                    horizontalAlignment: desk.textAlign
                    text: root.formattedDate(root.now)
                    font.pixelSize: Math.max(11, Math.round(inner.baseDigitPx * 0.22))
                    font.weight: Font.DemiBold
                    opacity: 0.85
                    elide: Text.ElideRight
                    style: root.cfg.showCard ? Text.Normal : Text.Raised
                    styleColor: desk.dropTint
                }

                Item { Layout.fillHeight: true }
            }

            // ---- Mode 2: Analog
            ColumnLayout {
                visible: desk.mode === 2
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                AnalogDial {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    now: root.now
                    isDark: root.isDark
                    accentColor: root.accent
                    showSeconds: root.cfg.showSeconds
                    accentSeconds: root.cfg.accentSeconds
                    textColor: Kirigami.Theme.textColor
                }

                PC3.Label {
                    visible: root.cfg.showDate
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.formattedDate(root.now)
                    font.pixelSize: Math.max(11, Math.round(Math.min(inner.width, inner.height) * 0.075))
                    opacity: 0.75
                    elide: Text.ElideRight
                    style: root.cfg.showCard ? Text.Normal : Text.Raised
                    styleColor: desk.dropTint
                }
            }

            // optional subtle day-progress strip at the bottom of the inner padding
            Rectangle {
                visible: root.cfg.showDayProgress
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 3
                radius: 1.5
                color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.14)

                Rectangle {
                    width: parent.width * desk.dayProgress
                    height: parent.height
                    radius: parent.radius
                    color: root.accent
                }
            }
        }
    }
}
