/*
 * Glasdeskclock — static-cached translucent glass numeral renderer.
 * Paints only when the displayed text, size or theme changes (once per minute),
 * keeping idle CPU/GPU usage near zero while giving the digits a translucent
 * Liquid Glass fill, subtle diagonal sheen, specular bevel rim and soft shadow.
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
    property color shadowColor: Qt.rgba(0, 0, 0, 0.45)

    readonly property string fontFamily: Kirigami.Theme.defaultFont.family || "sans-serif"
    readonly property int pad: Math.max(8, Math.round(pixelSize * 0.10))
    property real measuredWidth: fallback.implicitWidth

    implicitWidth: glassEffect
        ? Math.ceil(Math.max(fallback.implicitWidth, measuredWidth)) + pad * 2
        : fallback.implicitWidth
    implicitHeight: glassEffect
        ? Math.ceil(Math.max(fallback.implicitHeight, pixelSize * 1.12)) + pad * 2
        : fallback.implicitHeight

    PC3.Label {
        id: fallback
        anchors.centerIn: parent
        visible: !root.glassEffect
        text: root.text
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

            // 1. Soft drop shadow for contrast without making the glass opaque
            if (root.dropShadow) {
                ctx.save();
                ctx.shadowColor = root.isDark ? "rgba(0, 0, 0, 0.46)" : "rgba(0, 0, 0, 0.22)";
                ctx.shadowBlur = Math.max(5, Math.round(root.pixelSize * 0.08));
                ctx.shadowOffsetY = Math.max(2, Math.round(root.pixelSize * 0.025));
                ctx.fillStyle = "rgba(0, 0, 0, 0.08)";
                ctx.fillText(root.text, cx, cy);
                ctx.restore();
            }

            // 2. Translucent frosted glass core
            const gFill = ctx.createLinearGradient(0, cy - halfSpan, 0, cy + halfSpan);
            if (root.isDark) {
                gFill.addColorStop(0.0, "rgba(255, 255, 255, 0.44)");
                gFill.addColorStop(0.45, "rgba(255, 255, 255, 0.16)");
                gFill.addColorStop(0.85, "rgba(255, 255, 255, 0.24)");
                gFill.addColorStop(1.0, "rgba(255, 255, 255, 0.36)");
            } else {
                gFill.addColorStop(0.0, "rgba(255, 255, 255, 0.68)");
                gFill.addColorStop(0.48, "rgba(235, 240, 248, 0.28)");
                gFill.addColorStop(1.0, "rgba(255, 255, 255, 0.52)");
            }
            ctx.fillStyle = gFill;
            ctx.fillText(root.text, cx, cy);

            // 3. Subtle diagonal optical sheen clipped to the glyphs
            ctx.save();
            ctx.globalCompositeOperation = "source-atop";
            const gSheen = ctx.createLinearGradient(cx - root.pixelSize * 0.85, cy - halfSpan,
                                                    cx + root.pixelSize * 0.85, cy + halfSpan);
            gSheen.addColorStop(0.0, "rgba(255, 255, 255, 0.22)");
            gSheen.addColorStop(0.45, "rgba(255, 255, 255, 0.0)");
            gSheen.addColorStop(1.0, "rgba(255, 255, 255, 0.12)");
            ctx.fillStyle = gSheen;
            ctx.fillRect(0, 0, w, h);
            ctx.restore();

            // 4. Specular glass rim around glyph edges
            const gRim = ctx.createLinearGradient(0, cy - halfSpan, 0, cy + halfSpan);
            if (root.isDark) {
                gRim.addColorStop(0.0, "rgba(255, 255, 255, 0.82)");
                gRim.addColorStop(0.42, "rgba(255, 255, 255, 0.28)");
                gRim.addColorStop(0.78, "rgba(255, 255, 255, 0.20)");
                gRim.addColorStop(1.0, "rgba(255, 255, 255, 0.56)");
            } else {
                gRim.addColorStop(0.0, "rgba(255, 255, 255, 0.92)");
                gRim.addColorStop(0.45, "rgba(255, 255, 255, 0.42)");
                gRim.addColorStop(1.0, "rgba(0, 0, 0, 0.18)");
            }
            ctx.lineWidth = Math.max(1.3, root.pixelSize * 0.014);
            ctx.lineJoin = "round";
            ctx.strokeStyle = gRim;
            ctx.strokeText(root.text, cx, cy);
        }
    }
}
