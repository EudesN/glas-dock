/*
 * Glasdock — the glass look shared by the dock, its panels and the panel widgets.
 * style: 0 = Glass, 1 = Frosted, 2 = Clear (no background), 3 = Solid
 *        (4, the old "Blur" style, is treated as Glass with blurBehind on)
 * blurBehind: real KWin blur of the desktop behind the surface, in its exact
 *        shape, through the org.glasdock.blur helper plugin (if installed)
 * frost: 0..1 milky veil + grain on top, to make the blur look softer/heavier
 */
import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: surface

    property int style: 0
    property bool blurBehind: false
    property real frost: 0
    // true once the blur helper plugin is loaded (false when not installed)
    readonly property bool blurAvailable: blurLoader.status === Loader.Ready
    property real backgroundOpacity: 0.22
    property real radius: 20
    property bool isDark: true
    property color accent: Kirigami.Theme.highlightColor
    property real accentTint: 0
    property bool showBorder: true
    property bool showShadow: true
    // panels keep a minimum body so their text stays readable in "Clear"
    property bool forceBody: false

    readonly property int st: style === 4 ? 0 : style
    readonly property bool blurOn: blurBehind || style === 4
    readonly property bool isGlass: st === 0
    readonly property bool isFrosted: st === 1
    readonly property bool hasBody: st !== 2 || forceBody
    readonly property real bodyAlpha: st === 3 ? 1
        : st === 1 ? Math.max(0.45, backgroundOpacity)
        : st === 2 ? (blurOn ? 0.25 : 0.55)
        : backgroundOpacity

    // real blur behind (first, so everything else is drawn over it)
    Loader {
        id: blurLoader
        anchors.fill: parent
        active: surface.blurOn
        source: Qt.resolvedUrl("BlurLayer.qml")
        onLoaded: item.radius = Qt.binding(() => surface.r)
    }
    readonly property real r: Math.min(radius, height / 2)

    // Grain texture, tiled to the surface size (a stretched image showed up as
    // vertical streaks on large surfaces such as the launcher)
    Item {
        id: grainTile
        width: Math.max(1, surface.width)
        height: Math.max(1, surface.height)
        visible: false
        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("images/noise.png")
            fillMode: Image.Tile
            smooth: false
        }
    }
    ShaderEffectSource {
        id: grainSource
        sourceItem: grainTile
        hideSource: true
        live: false
        visible: false
        // re-render when the size changes
        onWidthChanged: scheduleUpdate()
        onHeightChanged: scheduleUpdate()
        width: grainTile.width
        height: grainTile.height
    }

    // frost only makes sense on top of the real blur
    readonly property real frostNow: blurOn ? frost : 0

    // body + border + shadow
    Kirigami.ShadowedRectangle {
        anchors.fill: parent
        radius: surface.r
        color: !surface.hasBody ? "transparent"
            : surface.st === 3 ? Kirigami.Theme.backgroundColor
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
        source: grainSource
    }

    // frost veil (blur look): milky layer + grain, amount = frost
    Rectangle {
        visible: surface.frostNow > 0
        anchors.fill: parent
        anchors.margins: 1
        radius: surface.r - 1
        color: surface.isDark ? Qt.rgba(0.85, 0.85, 0.9, surface.frostNow * 0.14)
                              : Qt.rgba(1, 1, 1, surface.frostNow * 0.45)
    }
    Kirigami.ShadowedTexture {
        visible: surface.frostNow > 0
        anchors.fill: parent
        anchors.margins: 1
        radius: surface.r - 1
        color: "transparent"
        opacity: surface.frostNow * (surface.isDark ? 0.5 : 0.7)
        source: grainSource
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
