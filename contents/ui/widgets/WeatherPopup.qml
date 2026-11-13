/*
 * Glasdock — expanded weather: current conditions and a 5-day forecast.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: popup

    property var weather: null
    property color accent: Kirigami.Theme.highlightColor
    property bool isDark: true
    readonly property bool ready: weather !== null && weather.ready

    implicitWidth: Kirigami.Units.gridUnit * 22
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Kirigami.Units.largeSpacing

        PC3.Label {
            visible: !popup.ready
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: popup.weather && popup.weather.error ? popup.weather.error : "Loading…"
            opacity: 0.7
        }

        // current conditions
        RowLayout {
            visible: popup.ready
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                source: popup.ready ? popup.weather.iconFor(popup.weather.current.code, popup.weather.current.isDay) : ""
            }
            ColumnLayout {
                spacing: 0
                PC3.Label {
                    text: popup.ready ? popup.weather.current.temp + "°" : ""
                    font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 3)
                    font.weight: Font.Light
                }
                PC3.Label {
                    text: popup.ready ? popup.weather.place + " · " + popup.weather.describe(popup.weather.current.code) : ""
                    opacity: 0.8
                }
            }
            Item { Layout.fillWidth: true }
        }

        // details as glass chips
        RowLayout {
            visible: popup.ready
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: popup.ready ? [
                    { icon: "temperature-normal", text: "Feels " + popup.weather.current.feels + "°" },
                    { icon: "raindrop", text: popup.weather.current.humidity + "%" },
                    { icon: "speedometer", text: popup.weather.current.wind + " " + popup.weather.current.windUnit }
                ] : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: chipRow.implicitHeight + Kirigami.Units.smallSpacing * 2
                    radius: height / 2
                    color: popup.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.4)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, popup.isDark ? 0.10 : 0.45)
                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: Kirigami.Units.smallSpacing
                        Kirigami.Icon {
                            Layout.preferredWidth: Kirigami.Units.iconSizes.small
                            Layout.preferredHeight: Kirigami.Units.iconSizes.small
                            source: modelData.icon
                        }
                        PC3.Label { text: modelData.text; font: Kirigami.Theme.smallFont }
                    }
                }
            }
        }

        // forecast
        RowLayout {
            visible: popup.ready
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing
            Repeater {
                model: popup.ready ? popup.weather.daily.slice(1, 6) : []
                delegate: Rectangle {
                    id: dayCard
                    required property var modelData
                    Layout.fillWidth: true
                    implicitHeight: dayCol.implicitHeight + Kirigami.Units.largeSpacing * 2
                    radius: Kirigami.Units.cornerRadius * 2
                    color: popup.isDark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.4)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, popup.isDark ? 0.10 : 0.45)

                ColumnLayout {
                    id: dayCol
                    readonly property var modelData: dayCard.modelData
                    anchors.centerIn: parent
                    spacing: Kirigami.Units.smallSpacing
                    PC3.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: new Date(modelData.date + "T12:00:00").toLocaleDateString(Qt.locale(), "ddd")
                        opacity: 0.7
                    }
                    Kirigami.Icon {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: Kirigami.Units.iconSizes.medium
                        Layout.preferredHeight: Kirigami.Units.iconSizes.medium
                        source: popup.weather.iconFor(modelData.code, true)
                    }
                    PC3.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.max + "°"
                        font.weight: Font.DemiBold
                    }
                    PC3.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: modelData.min + "°"
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }
                }
                }
            }
        }

        PC3.Label {
            Layout.alignment: Qt.AlignRight
            text: "Weather data by Open-Meteo.com"
            font: Kirigami.Theme.smallFont
            opacity: 0.4
        }
    }
}
