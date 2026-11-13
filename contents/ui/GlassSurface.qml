/*
 * Glasdock — the dock's glass look, shared by the bar and the widget panels.
 * style: 0 = Glass, 1 = Frosted, 2 = Clear (no background), 3 = Solid
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: surface

    property int style: 0
    property real backgroundOpacity: 0.22
    property real radius: 20
    property bool isDark: true
    property color accent: Kirigami.Theme.highlightColor
    property real accentTint: 0
    property bool showBorder: true
    property bool showShadow: true
    // panels keep a minimum body so their text stays readable in "Clear"
    property bool forceBody: false

    readonly property bool isGlass: style === 0
    readonly property bool isFrosted: style === 1
    readonly property bool hasBody: style !== 2 || forceBody
    readonly property real bodyAlpha: style === 3 ? 1
        : style === 1 ? Math.max(0.45, backgroundOpacity)
        : style === 2 ? 0.55
        : backgroundOpacity
    readonly property real r: Math.min(radius, height / 2)

    // body + border + shadow
    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        radius: surface.r
        color: !surface.hasBody ? "transparent"
            : surface.style === 3 ? Kirigami.Theme.backgroundColor
            : surface.isDark ? Qt.rgba(0.10, 0.10, 0.12, Math.min(1, surface.bodyAlpha + (surface.isGlass ? 0.12 : 0)))
            : Qt.rgba(1, 1, 1, surface.bodyAlpha)
        border.width: surface.showBorder ? 1 : 0
        border.color: surface.isFrosted ? Qt.rgba(1, 1, 1, surface.isDark ? 0.12 : 0.35)
            : Qt.rgba(1, 1, 1, surface.isDark ? 0.18 : 0.45)
        shadow.size: surface.showShadow && surface.hasBody ? 22 : 0
        shadow.yOffset: 6
        shadow.color: Qt.rgba(0, 0, 0, surface.isDark ? 0.45 : 0.22)
    }

    // frosted: milky veil + fine grain
    Rectangle {
        visible: surface.isFrosted
        anchors.fill: parent
        anchors.margins: 1
        radius: surface.r - 1
        color: Qt.rgba(1, 1, 1, surface.isDark ? 0.06 : 0.20)
    }
    Kirigami.ShadowedTexture {
        visible: surface.isFrosted
        anchors.fill: parent
        anchors.margins: 1
        radius: surface.r - 1
        color: "transparent"
        opacity: surface.isDark ? 0.55 : 0.8
        source: Image {
            source: Qt.resolvedUrl("../images/noise.png")
            fillMode: Image.Stretch
            smooth: false
            visible: false
        }
    }

    // accent tint
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: surface.r - 1
        color: surface.accent
        opacity: surface.accentTint
        visible: opacity > 0 && surface.hasBody
    }

    // vertical sheen (light from above) — glass only
    Rectangle {
        visible: surface.isGlass
        anchors.fill: parent
        anchors.margins: 1
        radius: surface.r - 1
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, surface.isDark ? 0.16 : 0.38) }
            GradientStop { position: Math.min(0.45, 30 / Math.max(1, surface.height)); color: Qt.rgba(1, 1, 1, surface.isDark ? 0.04 : 0.08) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0) }
        }
    }

    // specular highlight on the top edge
    Rectangle {
        visible: surface.isGlass
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - surface.r * 1.4
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, surface.isDark ? 0.55 : 0.9) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    // faint refracted glow on the bottom edge
    Rectangle {
        visible: surface.isGlass
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - surface.r * 2
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.22) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }
}
