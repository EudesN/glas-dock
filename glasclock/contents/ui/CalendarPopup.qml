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
import "shared" as Shared

Item {
    id: popup

    property date now: new Date()
    property color accent: Kirigami.Theme.highlightColor
    property bool isDark: true
    property var eventPluginsManager: null
    property var timeText: d => Qt.formatTime(d, Qt.locale().timeFormat(Locale.ShortFormat))

    readonly property int dayStamp: now.getFullYear() * 10000 + now.getMonth() * 100 + now.getDate()
    readonly property date todayDate: {
        dayStamp;
        return new Date(now.getFullYear(), now.getMonth(), now.getDate());
    }
    property date selected: todayDate
    onTodayDateChanged: selected = todayDate
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
        today: popup.todayDate
        property int lastMonthKey: year * 12 + month
        property int monthDir: 1
        function handleMonthChange() {
            const key = year * 12 + month;
            if (key === lastMonthKey)
                return;
            monthDir = key > lastMonthKey ? 1 : -1;
            lastMonthKey = key;
            monthTransition.restart();
        }
        onMonthChanged: handleMonthChange()
        onYearChanged: handleMonthChange()
        Component.onCompleted: {
            displayedDate = popup.todayDate;
            lastMonthKey = year * 12 + month;
            if (popup.eventPluginsManager)
                daysModel.setPluginsManager(popup.eventPluginsManager);
        }
    }

    ParallelAnimation {
        id: monthTransition
        NumberAnimation { target: monthSlide; property: "x"; from: calendar.monthDir * 14; to: 0; duration: 190; easing.type: Easing.OutCubic }
        NumberAnimation { target: daysGrid; property: "opacity"; from: 0.25; to: 1; duration: 190; easing.type: Easing.OutCubic }
        NumberAnimation { target: monthLabelSlide; property: "x"; from: calendar.monthDir * 8; to: 0; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: monthLabel; property: "opacity"; from: 0.35; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }
    ParallelAnimation {
        id: agendaTransition
        NumberAnimation { target: agendaSlide; property: "y"; from: 4; to: 0; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: agendaCol; property: "opacity"; from: 0.35; to: 1; duration: 160; easing.type: Easing.OutCubic }
    }
    onSelectedChanged: if (visible) agendaTransition.restart()
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
            spacing: Kirigami.Units.largeSpacing

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                PC3.Label {
                    Layout.fillWidth: true
                    text: popup.now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
                    color: popup.accent
                    font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.12)
                    font.weight: Font.Bold
                    elide: Text.ElideRight
                }

                RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        implicitWidth: weekLbl.implicitWidth + Kirigami.Units.smallSpacing * 2
                        implicitHeight: weekLbl.implicitHeight + 2
                        radius: height / 2
                        color: Qt.rgba(popup.accent.r, popup.accent.g, popup.accent.b, popup.isDark ? 0.16 : 0.14)
                        PC3.Label {
                            id: weekLbl
                            anchors.centerIn: parent
                            text: "Week " + popup.weekOf(popup.now)
                            color: popup.accent
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            font.weight: Font.DemiBold
                        }
                    }

                    PC3.Label {
                        text: "·"
                        opacity: 0.45
                        font: Kirigami.Theme.smallFont
                    }

                    PC3.Label {
                        text: popup.timeText(popup.now)
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        font.features: { "tnum": 1 }
                        opacity: 0.72
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Kirigami.Units.smallSpacing

                Shared.GlassButton {
                    visible: calendar.month !== popup.now.getMonth() + 1 || calendar.year !== popup.now.getFullYear()
                    text: "Today"
                    iconSize: Kirigami.Units.iconSizes.small
                    isDark: popup.isDark
                    accent: popup.accent
                    onClicked: {
                        calendar.resetToToday();
                        popup.selected = new Date(popup.now.getFullYear(), popup.now.getMonth(), popup.now.getDate());
                    }
                }
                Shared.GlassButton {
                    iconName: "go-previous"
                    iconSize: Kirigami.Units.iconSizes.small
                    isDark: popup.isDark
                    onClicked: calendar.previousMonth()
                }
                PC3.Label {
                    id: monthLabel
                    text: (calendar.monthName + (calendar.year !== popup.now.getFullYear() ? " " + calendar.year : "")).toUpperCase()
                    color: popup.accent
                    font.weight: Font.Bold
                    transform: Translate { id: monthLabelSlide }
                }
                Shared.GlassButton {
                    iconName: "go-next"
                    iconSize: Kirigami.Units.iconSizes.small
                    isDark: popup.isDark
                    onClicked: calendar.nextMonth()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: popup.isDark ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(0, 0, 0, 0.08)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing * 2

            // -------------------------------------------------------- agenda
            ColumnLayout {
                id: agendaCol
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                Layout.maximumWidth: Kirigami.Units.gridUnit * 15
                Layout.alignment: Qt.AlignTop
                spacing: Kirigami.Units.smallSpacing
                transform: Translate { id: agendaSlide }

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
                clip: true

                Row {
                    Repeater {
                        model: 7
                        delegate: PC3.Label {
                            required property int index
                            width: popup.cell
                            horizontalAlignment: Text.AlignHCenter
                            readonly property int dow: (calendar.firstDayOfWeek + index - 1) % 7 + 1
                            text: Qt.locale().dayName(dow % 7, Locale.NarrowFormat)
                            opacity: 0.75
                            font.weight: Font.DemiBold
                        }
                    }
                }

                Grid {
                    id: daysGrid
                    columns: 7
                    transform: Translate { id: monthSlide }
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
                                color: day.isToday ? Qt.rgba(popup.accent.r, popup.accent.g, popup.accent.b, popup.isDark ? 0.34 : 0.28)
                                     : day.isSelected ? Qt.rgba(popup.accent.r, popup.accent.g, popup.accent.b, popup.isDark ? 0.18 : 0.22)
                                     : dayArea.containsMouse ? (popup.isDark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.08)) : "transparent"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: popup.cell * 0.82
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: 1.5
                                border.color: popup.accent
                                opacity: day.isSelected && !day.isToday ? 1 : 0
                                scale: day.isSelected && !day.isToday ? 1 : 0.82
                                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }
                            PC3.Label {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: day.model.dayNumber
                                color: Kirigami.Theme.textColor
                                opacity: day.inMonth ? 1 : 0.32
                                font.weight: day.isToday ? Font.Bold : Font.Normal
                            }
                            // has events (hidden while selected or today so it never overlaps the circle)
                            Rectangle {
                                readonly property bool showDot: (day.model.eventCount || 0) > 0 && !day.isSelected && !day.isToday
                                width: 4
                                height: 4
                                radius: 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                                color: popup.accent
                                opacity: showDot ? (day.inMonth ? 1 : 0.4) : 0
                                scale: showDot ? 1 : 0.4
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
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
