/*
 * Glasdeskclock — minimalist analog dial face drawn crisply at any desktop size.
 */
import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
    id: dial

    property date now: new Date()
    property bool isDark: true
    property color accentColor: Kirigami.Theme.highlightColor
    property bool showSeconds: true
    property bool accentSeconds: true
    property color textColor: Kirigami.Theme.textColor

    onNowChanged: requestPaint()
    onIsDarkChanged: requestPaint()
    onAccentColorChanged: requestPaint()
    onShowSecondsChanged: requestPaint()
    onAccentSecondsChanged: requestPaint()
    onTextColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const w = width;
        const h = height;
        ctx.reset();
        if (w <= 4 || h <= 4)
            return;

        const cx = w / 2;
        const cy = h / 2;
        const r = Math.min(w, h) / 2 - 4;
        if (r <= 4)
            return;

        const fg = dial.textColor;
        const acc = dial.accentColor;

        // subtle glass ring + face fill
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, Math.PI * 2);
        ctx.fillStyle = dial.isDark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(1, 1, 1, 0.25);
        ctx.fill();
        ctx.lineWidth = Math.max(1.2, r * 0.022);
        ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, dial.isDark ? 0.22 : 0.28);
        ctx.stroke();

        // 12 hour markers
        for (let i = 0; i < 12; i++) {
            const ang = (i * Math.PI) / 6 - Math.PI / 2;
            const major = i % 3 === 0;
            const inner = r * (major ? 0.80 : 0.86);
            const outer = r * 0.93;
            ctx.beginPath();
            ctx.moveTo(cx + Math.cos(ang) * inner, cy + Math.sin(ang) * inner);
            ctx.lineTo(cx + Math.cos(ang) * outer, cy + Math.sin(ang) * outer);
            ctx.lineCap = "round";
            ctx.lineWidth = Math.max(1.2, r * (major ? 0.036 : 0.018));
            ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, major ? 0.75 : 0.35);
            ctx.stroke();
        }

        const secs = dial.now.getSeconds();
        const mins = dial.now.getMinutes() + secs / 60;
        const hrs = (dial.now.getHours() % 12) + mins / 60;

        // hour hand
        const hAng = (hrs * Math.PI) / 6 - Math.PI / 2;
        ctx.beginPath();
        ctx.moveTo(cx - Math.cos(hAng) * r * 0.12, cy - Math.sin(hAng) * r * 0.12);
        ctx.lineTo(cx + Math.cos(hAng) * r * 0.50, cy + Math.sin(hAng) * r * 0.50);
        ctx.lineCap = "round";
        ctx.lineWidth = Math.max(2.5, r * 0.055);
        ctx.strokeStyle = fg;
        ctx.stroke();

        // minute hand
        const mAng = (mins * Math.PI) / 30 - Math.PI / 2;
        ctx.beginPath();
        ctx.moveTo(cx - Math.cos(mAng) * r * 0.14, cy - Math.sin(mAng) * r * 0.14);
        ctx.lineTo(cx + Math.cos(mAng) * r * 0.74, cy + Math.sin(mAng) * r * 0.74);
        ctx.lineCap = "round";
        ctx.lineWidth = Math.max(2.0, r * 0.038);
        ctx.strokeStyle = Qt.rgba(fg.r, fg.g, fg.b, 0.92);
        ctx.stroke();

        // second hand
        if (dial.showSeconds) {
            const sAng = (secs * Math.PI) / 30 - Math.PI / 2;
            ctx.beginPath();
            ctx.moveTo(cx - Math.cos(sAng) * r * 0.18, cy - Math.sin(sAng) * r * 0.18);
            ctx.lineTo(cx + Math.cos(sAng) * r * 0.82, cy + Math.sin(sAng) * r * 0.82);
            ctx.lineCap = "round";
            ctx.lineWidth = Math.max(1.2, r * 0.018);
            ctx.strokeStyle = dial.accentSeconds ? acc : Qt.rgba(fg.r, fg.g, fg.b, 0.65);
            ctx.stroke();
        }

        // center pivot
        ctx.beginPath();
        ctx.arc(cx, cy, Math.max(2.5, r * 0.042), 0, Math.PI * 2);
        ctx.fillStyle = (dial.showSeconds && dial.accentSeconds) ? acc : fg;
        ctx.fill();
    }
}
