/*
 * Glasdeskclock — static-cached 3D Liquid Glass / Solid numeral renderer.
 * Paints only when the displayed text, size, theme or style changes (once per
 * minute), keeping idle CPU/GPU usage near zero while rendering sculpted 3D
 * glass depth: grounded shadow, bottom-right thickness bevel, translucent
 * frosted core, inner refraction highlight, diagonal sheen and specular rim.
 */
import QtQuick
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3

Item {
    id: root

    property string text: ""
    property int pixelSize: 96
    property int fontWeight: Font.Bold
    property bool isDark: true
    property bool glassEffect: true
    property bool dropShadow: true
    property color solidColor: Kirigami.Theme.textColor
    property color shadowColor: Qt.rgba(0, 0, 0, 0.45)

    readonly property string fontFamily: Kirigami.Theme.defaultFont.family || "sans-serif"
    readonly property int pad: Math.max(4, Math.round(pixelSize * 0.08))
    property real measuredWidth: fallback.implicitWidth

    implicitWidth: glassEffect
        ? Math.ceil(Math.max(fallback.implicitWidth, measuredWidth)) + pad * 2
        : fallback.implicitWidth
    implicitHeight: glassEffect
        ? Math.ceil(Math.max(fallback.implicitHeight, pixelSize * 1.06)) + pad * 2
        : fallback.implicitHeight

    PC3.Label {
        id: fallback
        anchors.centerIn: parent
        visible: !root.glassEffect
        text: root.text
        color: root.solidColor
        font.pixelSize: root.pixelSize
        font.weight: root.fontWeight
        font.features: { "tnum": 1 }
        lineHeight: 0.9
        style: root.dropShadow ? Text.Raised : Text.Normal
        styleColor: root.shadowColor
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        visible: root.glassEffect
        renderStrategy: Canvas.Cooperative

        function repaint() {
            if (!root.glassEffect || width <= 0 || height <= 0)
                return;
            requestPaint();
        }

        Connections {
            target: root
            function onTextChanged() { canvas.repaint(); }
            function onPixelSizeChanged() { canvas.repaint(); }
            function onFontWeightChanged() { canvas.repaint(); }
            function onIsDarkChanged() { canvas.repaint(); }
            function onGlassEffectChanged() { canvas.repaint(); }
            function onDropShadowChanged() { canvas.repaint(); }
            function onFontFamilyChanged() { canvas.repaint(); }
        }
        onWidthChanged: repaint()
        onHeightChanged: repaint()
        Component.onCompleted: repaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!root.text || root.pixelSize <= 0)
                return;

            const weight = root.fontWeight >= Font.Bold ? "700"
                         : root.fontWeight >= Font.DemiBold ? "600"
                         : root.fontWeight <= Font.Light ? "300" : "500";
            const fam = root.fontFamily.replace(/"/g, "");
            ctx.font = weight + " " + root.pixelSize + "px \"" + fam + "\", sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";

            const m = ctx.measureText(root.text);
            if (m && m.width > 0 && Math.abs(root.measuredWidth - m.width) > 1)
                root.measuredWidth = m.width;

            const w = width;
            const h = height;
            const cx = w / 2;
            const cy = h / 2;
            const halfSpan = root.pixelSize * 0.42;

            // 1. Soft grounded drop shadow behind the glass slab
            if (root.dropShadow) {
                ctx.save();
                ctx.shadowColor = root.isDark ? "rgba(0, 0, 0, 0.56)" : "rgba(0, 0, 0, 0.32)";
                ctx.shadowBlur = Math.max(7, Math.round(root.pixelSize * 0.11));
                ctx.shadowOffsetY = Math.max(2, Math.round(root.pixelSize * 0.038));
                ctx.fillStyle = "rgba(0, 0, 0, 0.16)";
                ctx.fillText(root.text, cx, cy);
                ctx.restore();
            }

            // 2. 3D glass thickness / bottom-right depth bevel
            ctx.save();
            ctx.lineWidth = Math.max(1.8, root.pixelSize * 0.020);
            ctx.lineJoin = "round";
            ctx.strokeStyle = root.isDark ? "rgba(10, 14, 22, 0.34)" : "rgba(20, 28, 42, 0.24)";
            ctx.strokeText(root.text, cx + 1.4, cy + 2.0);
            ctx.restore();

            // 3. Translucent frosted glass core
            const gFill = ctx.createLinearGradient(0, cy - halfSpan, 0, cy + halfSpan);
            if (root.isDark) {
                gFill.addColorStop(0.0, "rgba(255, 255, 255, 0.60)");
                gFill.addColorStop(0.45, "rgba(255, 255, 255, 0.24)");
                gFill.addColorStop(0.82, "rgba(255, 255, 255, 0.32)");
                gFill.addColorStop(1.0, "rgba(255, 255, 255, 0.48)");
            } else {
                gFill.addColorStop(0.0, "rgba(255, 255, 255, 0.72)");
                gFill.addColorStop(0.45, "rgba(240, 245, 255, 0.34)");
                gFill.addColorStop(1.0, "rgba(255, 255, 255, 0.56)");
            }
            ctx.fillStyle = gFill;
            ctx.fillText(root.text, cx, cy);

            // 4. Inner specular refraction bevel & diagonal gloss clipped inside glyphs
            ctx.save();
            ctx.globalCompositeOperation = "source-atop";
            const gSheen = ctx.createLinearGradient(cx - root.pixelSize * 0.9, cy - halfSpan,
                                                    cx + root.pixelSize * 0.9, cy + halfSpan);
            gSheen.addColorStop(0.0, "rgba(255, 255, 255, 0.26)");
            gSheen.addColorStop(0.42, "rgba(255, 255, 255, 0.0)");
            gSheen.addColorStop(0.58, "rgba(255, 255, 255, 0.04)");
            gSheen.addColorStop(1.0, "rgba(255, 255, 255, 0.16)");
            ctx.fillStyle = gSheen;
            ctx.fillRect(0, 0, w, h);

            ctx.lineWidth = Math.max(2.4, root.pixelSize * 0.025);
            ctx.lineJoin = "round";
            const gInner = ctx.createLinearGradient(0, cy - halfSpan, 0, cy + halfSpan);
            gInner.addColorStop(0.0, "rgba(255, 255, 255, 0.85)");
            gInner.addColorStop(0.45, "rgba(255, 255, 255, 0.14)");
            gInner.addColorStop(1.0, "rgba(255, 255, 255, 0.42)");
            ctx.strokeStyle = gInner;
            ctx.strokeText(root.text, cx, cy + 1.2);
            ctx.restore();

            // 5. Crisp outer specular glass rim
            const gRim = ctx.createLinearGradient(0, cy - halfSpan, 0, cy + halfSpan);
            if (root.isDark) {
                gRim.addColorStop(0.0, "rgba(255, 255, 255, 0.94)");
                gRim.addColorStop(0.38, "rgba(255, 255, 255, 0.34)");
                gRim.addColorStop(0.76, "rgba(255, 255, 255, 0.22)");
                gRim.addColorStop(1.0, "rgba(255, 255, 255, 0.66)");
            } else {
                gRim.addColorStop(0.0, "rgba(255, 255, 255, 0.96)");
                gRim.addColorStop(0.42, "rgba(255, 255, 255, 0.48)");
                gRim.addColorStop(1.0, "rgba(0, 0, 0, 0.22)");
            }
            ctx.lineWidth = Math.max(1.4, root.pixelSize * 0.014);
            ctx.lineJoin = "round";
            ctx.strokeStyle = gRim;
            ctx.strokeText(root.text, cx, cy);
        }
    }
}
