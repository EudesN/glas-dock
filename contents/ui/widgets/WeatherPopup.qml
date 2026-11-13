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
            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing
                PC3.Label { text: popup.ready ? "Feels like " + popup.weather.current.feels + "°" : ""; font: Kirigami.Theme.smallFont; opacity: 0.7 }
                PC3.Label { text: popup.ready ? "Humidity " + popup.weather.current.humidity + "%" : ""; font: Kirigami.Theme.smallFont; opacity: 0.7 }
                PC3.Label { text: popup.ready ? "Wind " + popup.weather.current.wind + " " + popup.weather.current.windUnit : ""; font: Kirigami.Theme.smallFont; opacity: 0.7 }
            }
        }

        Kirigami.Separator { Layout.fillWidth: true; visible: popup.ready }

        // forecast
        RowLayout {
            visible: popup.ready
            Layout.fillWidth: true
            spacing: 0
            Repeater {
                model: popup.ready ? popup.weather.daily.slice(1, 6) : []
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
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
                        text: modelData.max + "° / " + modelData.min + "°"
                        font: Kirigami.Theme.smallFont
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
