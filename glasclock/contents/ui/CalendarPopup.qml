/*
 * Glasclock — calendar panel: header with today's weekday/day/week, the events
 * of the selected day (and the next days that have events) on the left, the
 * month on the right. Clicking a day selects it; arrows change the month.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PC3
import org.kde.kirigami as Kirigami
import org.kde.plasma.workspace.calendar as PlasmaCalendar

Item {
    id: popup

    property date now: new Date()
    property color accent: Kirigami.Theme.highlightColor
    property bool isDark: true
    property var eventPluginsManager: null
    property var timeText: d => Qt.formatTime(d, Qt.locale().timeFormat(Locale.ShortFormat))

    property date selected: new Date(now.getFullYear(), now.getMonth(), now.getDate())
    property int revision: 0          // bumped when the agenda changes

    readonly property color dim: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.45)
    readonly property real cell: Kirigami.Units.gridUnit * 2.1

    implicitWidth: Kirigami.Units.gridUnit * 15 + Kirigami.Units.largeSpacing * 2 + monthGrid.width
    implicitHeight: layout.implicitHeight

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }
    // ISO 8601 week number
    function weekOf(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const y = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y) / 86400000 + 1) / 7);
    }

    PlasmaCalendar.Calendar {
        id: calendar
        days: 7
        weeks: 6
        firstDayOfWeek: Qt.locale().firstDayOfWeek
        today: popup.now
        Component.onCompleted: {
            displayedDate = popup.now;
            if (popup.eventPluginsManager)
                daysModel.setPluginsManager(popup.eventPluginsManager);
        }
    }
    Connections {
        target: calendar.daysModel
        function onAgendaUpdated() { popup.revision++; }
        function onModelReset() { popup.revision++; }
    }

    // events of the selected day + the next 6 days (only days that have some)
    readonly property var agenda: {
        revision;
        const days = [];
        for (let i = 0; i < 7; i++) {
            const d = new Date(selected.getFullYear(), selected.getMonth(), selected.getDate() + i);
            const evs = calendar.daysModel.eventsForDate(d) || [];
            if (evs.length > 0 || i === 0)
                days.push({ date: d, events: evs });
        }
        return days;
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        // ------------------------------------------------------------ header
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            PC3.Label {
                text: popup.now.toLocaleDateString(Qt.locale(), "ddd").toUpperCase()
                color: popup.accent
                font.weight: Font.Bold
            }
            PC3.Label {
                text: popup.now.getDate()
                font.weight: Font.Bold
            }
            PC3.Label {
                text: "W" + popup.weekOf(popup.now)
                color: Qt.rgba(popup.accent.r, popup.accent.g, popup.accent.b, 0.55)
                font.weight: Font.Bold
            }
            PC3.Label {
                Layout.leftMargin: Kirigami.Units.largeSpacing
                text: popup.timeText(popup.now)
                opacity: 0.6
            }
            Item { Layout.fillWidth: true }
            PC3.ToolButton {
                visible: calendar.month !== popup.now.getMonth() + 1 || calendar.year !== popup.now.getFullYear()
                text: "Today"
                onClicked: {
                    calendar.resetToToday();
                    popup.selected = new Date(popup.now.getFullYear(), popup.now.getMonth(), popup.now.getDate());
                }
            }
            PC3.ToolButton {
                icon.name: "go-previous"
                onClicked: calendar.previousMonth()
            }
            PC3.Label {
                text: (calendar.monthName + (calendar.year !== popup.now.getFullYear() ? " " + calendar.year : "")).toUpperCase()
                color: popup.accent
                font.weight: Font.Bold
            }
            PC3.ToolButton {
                icon.name: "go-next"
                onClicked: calendar.nextMonth()
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing * 2

            // -------------------------------------------------------- agenda
            ColumnLayout {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                Layout.maximumWidth: Kirigami.Units.gridUnit * 15
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: popup.agenda
                    delegate: ColumnLayout {
                        id: dayBlock
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        // day title (not for the first block when it is today)
                        PC3.Label {
                            visible: dayBlock.index > 0 || !popup.sameDay(dayBlock.modelData.date, popup.now)
                            Layout.topMargin: dayBlock.index > 0 ? Kirigami.Units.smallSpacing : 0
                            text: dayBlock.modelData.date.toLocaleDateString(Qt.locale(), "ddd, MMM d").toUpperCase()
                            color: popup.dim
                            font: Kirigami.Theme.smallFont
                        }

                        PC3.Label {
                            visible: dayBlock.modelData.events.length === 0
                            text: "No events"
                            color: popup.dim
                        }

                        Repeater {
                            model: dayBlock.modelData.events
                            delegate: Rectangle {
                                id: card
                                required property var modelData
                                readonly property color tone: modelData.eventColor && modelData.eventColor.toString() !== "" && modelData.eventColor.a > 0
                                    ? modelData.eventColor : popup.accent
                                Layout.fillWidth: true
                                implicitHeight: cardCol.implicitHeight + Kirigami.Units.smallSpacing * 2
                                radius: Kirigami.Units.cornerRadius
                                color: Qt.rgba(tone.r, tone.g, tone.b, 0.18)

                                Rectangle {
                                    width: 3
                                    radius: 1.5
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    anchors.margins: Kirigami.Units.smallSpacing
                                    color: card.tone
                                }
                                ColumnLayout {
                                    id: cardCol
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Kirigami.Units.largeSpacing + 3
                                    anchors.rightMargin: Kirigami.Units.smallSpacing
                                    spacing: 0
                                    PC3.Label {
                                        Layout.fillWidth: true
                                        text: card.modelData.title
                                        color: Qt.lighter(card.tone, popup.isDark ? 1.25 : 0.8)
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                    }
                                    PC3.Label {
                                        Layout.fillWidth: true
                                        text: card.modelData.isAllDay ? "All day"
                                            : popup.timeText(card.modelData.startDateTime) + " – " + popup.timeText(card.modelData.endDateTime)
                                        color: Qt.rgba(card.tone.r, card.tone.g, card.tone.b, 0.85)
                                        font: Kirigami.Theme.smallFont
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            // --------------------------------------------------------- month
            Column {
                id: monthGrid
                Layout.alignment: Qt.AlignTop
                spacing: 0

                Row {
                    Repeater {
                        model: 7
                        delegate: PC3.Label {
                            required property int index
                            width: popup.cell
                            horizontalAlignment: Text.AlignHCenter
                            readonly property int dow: (calendar.firstDayOfWeek + index - 1) % 7 + 1
                            text: Qt.locale().dayName(dow % 7, Locale.NarrowFormat)
                            opacity: dow === 6 || dow === 7 ? 0.45 : 0.75
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Grid {
                    columns: 7
                    Repeater {
                        model: calendar.daysModel
                        delegate: Item {
                            id: day
                            required property var model
                            required property int index
                            readonly property date date: new Date(model.yearNumber, model.monthNumber - 1, model.dayNumber)
                            readonly property bool inMonth: model.monthNumber === calendar.month
                            readonly property bool isToday: popup.sameDay(date, popup.now)
                            readonly property bool isSelected: popup.sameDay(date, popup.selected)
                            readonly property bool weekend: date.getDay() === 0 || date.getDay() === 6
                            width: popup.cell
                            height: popup.cell

                            Rectangle {
                                anchors.centerIn: parent
                                width: popup.cell * 0.82
                                height: width
                                radius: width / 2
                                color: day.isToday ? popup.accent
                                     : dayArea.containsMouse ? Qt.rgba(1, 1, 1, popup.isDark ? 0.10 : 0.4) : "transparent"
                                border.width: day.isSelected && !day.isToday ? 1.5 : 0
                                border.color: popup.accent
                            }
                            PC3.Label {
                                anchors.centerIn: parent
                                text: day.model.dayNumber
                                color: day.isToday
                                    ? (Kirigami.ColorUtils.brightnessForColor(popup.accent) === Kirigami.ColorUtils.Light ? "#1d1d1f" : "white")
                                    : Kirigami.Theme.textColor
                                opacity: day.isToday ? 1 : !day.inMonth ? 0.3 : day.weekend ? 0.55 : 1
                                font.weight: day.isToday ? Font.Bold : Font.Normal
                            }
                            // has events
                            Rectangle {
                                visible: (day.model.eventCount || 0) > 0 && !day.isToday
                                width: 4
                                height: 4
                                radius: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: popup.cell * 0.08
                                color: popup.accent
                                opacity: day.inMonth ? 1 : 0.4
                            }
                            MouseArea {
                                id: dayArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: popup.selected = day.date
                            }
                        }
                    }
                }
            }
        }
    }
}
