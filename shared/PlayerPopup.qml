/*
 * Glasdock — cover-art media player card with discrete audio output, dynamic
 * cover-colored waves along the progress bar, and centered playback controls.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PC3
import org.kde.plasma.private.mpris as Mpris
import org.kde.plasma.private.volume as Volume

Item {
    id: popup

    property var player: null
    property bool seeking: false
    // last track seen by onTrackChanged (plain value: a binding would already
    // hold the new key when the handler runs)
    property string _trackKey: ""
    property color accent: Kirigami.Theme.highlightColor
    property bool isDark: true
    property real cardRadius: 22

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string art: hasPlayer ? (player.artUrl || "").toString() : ""
    readonly property bool hasCover: coverImg.status === Image.Ready
    readonly property bool windowShown: popup.visible && (Window.window ? Window.window.visible : true)

    property real _basePos: 0
    property double _baseTimeMs: 0
    property real _cachedLength: 0
    property real livePosition: 0
    readonly property real effectiveLength: hasPlayer
        ? (player.length > 0 ? player.length : _cachedLength) : 0
    readonly property real progress: effectiveLength > 0
        ? Math.max(0, Math.min(1, livePosition / effectiveLength)) : 0
    readonly property color fgColor: (hasCover || isDark) ? "#ffffff" : "#1d1d1f"
    readonly property color mutedFg: (hasCover || isDark) ? Qt.rgba(1, 1, 1, 0.78) : Qt.rgba(0.11, 0.11, 0.12, 0.72)

    function _currentInterpolated() {
        if (!hasPlayer || !playing || _baseTimeMs <= 0)
            return _basePos;
        const elapsedUs = Math.max(0, Date.now() - _baseTimeMs) * 1000;
        const next = _basePos + elapsedUs;
        return effectiveLength > 0 ? Math.min(effectiveLength, next) : next;
    }

    function syncClock(forcePos) {
        if (hasPlayer && player.length > 0)
            _cachedLength = player.length;
        if (forcePos !== undefined) {
            const p = Math.max(0, forcePos);
            _basePos = p;
            _baseTimeMs = Date.now();
            livePosition = p;
            return;
        }
        const curLive = _currentInterpolated();
        const rawPos = hasPlayer ? Math.max(0, player.position || 0) : 0;
        // Browsers (e.g. Firefox native MPRIS) often emit position=0 and omit length
        // while playing; ignore bogus 0 resets so the local clock doesn't snap back.
        if (rawPos === 0 && (!hasPlayer || (player.length || 0) <= 0) && curLive > 1500000) {
            _basePos = curLive;
            _baseTimeMs = Date.now();
            livePosition = curLive;
            return;
        }
        if (rawPos > 0 && playing && Math.abs(rawPos - curLive) < 1500000)
            return;
        _basePos = rawPos;
        _baseTimeMs = Date.now();
        livePosition = rawPos;
    }

    function refreshLivePosition() {
        livePosition = _currentInterpolated();
    }

    onPlayerChanged: {
        _cachedLength = (hasPlayer && player.length > 0) ? player.length : 0;
        syncClock(hasPlayer ? Math.max(0, player.position || 0) : 0);
        if (player && player.updatePosition)
            player.updatePosition();
    }
    onWindowShownChanged: {
        seekContainer.animateFill = false;
        syncClock();
        if (windowShown) {
            if (player && player.updatePosition)
                player.updatePosition();
            smoothEnableTimer.restart();
        }
    }
    Component.onCompleted: {
        if (hasPlayer && player.length > 0)
            _cachedLength = player.length;
        syncClock();
        if (player && player.updatePosition)
            player.updatePosition();
    }

    Connections {
        target: popup.player
        function onLengthChanged() {
            if (popup.hasPlayer && popup.player.length > 0)
                popup._cachedLength = popup.player.length;
        }
        function onPositionChanged() { if (!popup.seeking) popup.syncClock(); }
        function onPlaybackStatusChanged() {
            const cur = popup._currentInterpolated();
            popup._basePos = cur;
            popup._baseTimeMs = Date.now();
            popup.livePosition = cur;
            popup.syncClock();
            if (popup.player && popup.player.updatePosition)
                popup.player.updatePosition();
        }
        function onTrackChanged() {
            // the proxy's title also changes when a Spotify id resolves to the
            // real name: only a different underlying track resets the progress
            const key = popup.player ? (popup.player.trackKey !== undefined ? popup.player.trackKey : popup.player.track) : "";
            if (key === popup._trackKey)
                return;
            popup._trackKey = key;
            popup._cachedLength = (popup.hasPlayer && popup.player.length > 0) ? popup.player.length : 0;
            popup.syncClock(0);
            if (popup.player && popup.player.updatePosition)
                popup.player.updatePosition();
        }
    }

    readonly property var defaultSink: Volume.PreferredDevice.sink
    readonly property string audioOutputName: {
        if (!defaultSink)
            return "";
        if (defaultSink.formFactor === "internal" && defaultSink.ports
            && defaultSink.activePortIndex >= 0
            && defaultSink.activePortIndex < defaultSink.ports.length) {
            const portDesc = defaultSink.ports[defaultSink.activePortIndex].description || "";
            if (portDesc)
                return portDesc;
        }
        return (defaultSink.description || "").replace(/\s*(Analog|Digital)\s+Stereo$/i, "").trim();
    }

    signal closeRequested()

    implicitWidth: Kirigami.Units.gridUnit * 25
    implicitHeight: Math.max(Kirigami.Units.gridUnit * 10.8, contentCol.implicitHeight + Kirigami.Units.largeSpacing * 2.4)

    function fmt(us) {
        const s = Math.max(0, Math.floor(us / 1000000));
        const m = Math.floor(s / 60);
        return String(m).padStart(2, "0") + ":" + String(s % 60).padStart(2, "0");
    }

    function boostSwatch(c, minSat, minVal) {
        if (!c)
            return popup.accent;
        const hasHue = c.hsvHue >= 0 && c.hsvSaturation > 0.08;
        const h = hasHue ? c.hsvHue : (popup.accent.hsvHue >= 0 ? popup.accent.hsvHue : 0.08);
        const s = hasHue ? Math.max(minSat, Math.min(1.0, c.hsvSaturation * 1.35)) : 0.15;
        const v = Math.max(minVal, Math.min(1.0, c.hsvValue * 1.18));
        return Qt.hsva(h, s, v, 1.0);
    }

    property color wavePrimary: popup.accent
    property color waveSecondary: Qt.lighter(popup.accent, 1.35)
    property color waveTertiary: Qt.lighter(popup.accent, 1.6)

    function updateWavePalette() {
        if (!hasCover) {
            wavePrimary = popup.accent;
            waveSecondary = Qt.lighter(popup.accent, 1.32);
            waveTertiary = Qt.lighter(popup.accent, 1.55);
            return;
        }
        const candidates = [];
        const pal = imgColors.palette;
        for (let i = 0; i < pal.length; i++) {
            const c = pal[i].color;
            const sat = c.hsvHue >= 0 ? c.hsvSaturation : 0;
            const val = c.hsvValue;
            // Favor rich, saturated mid/bright colors from the album art
            const score = sat * (0.45 + 0.55 * (pal[i].ratio || 0)) * (val > 0.15 ? 1.0 : 0.4);
            candidates.push({ color: c, score: score });
        }
        if (imgColors.highlight)
            candidates.push({ color: imgColors.highlight, score: (imgColors.highlight.hsvSaturation || 0) * 0.85 });
        if (imgColors.dominant)
            candidates.push({ color: imgColors.dominant, score: (imgColors.dominant.hsvSaturation || 0) * 0.75 });
        candidates.sort((a, b) => b.score - a.score);

        const c1Raw = candidates.length > 0 ? candidates[0].color : popup.accent;
        let c2Raw = null;
        for (let i = 1; i < candidates.length; i++) {
            const dHue = Math.abs((candidates[i].color.hsvHue || 0) - (c1Raw.hsvHue || 0));
            if (dHue > 0.05 || Math.abs(candidates[i].color.hsvValue - c1Raw.hsvValue) > 0.18) {
                c2Raw = candidates[i].color;
                break;
            }
        }
        const p1 = boostSwatch(c1Raw, 0.72, 0.88);
        const p2 = c2Raw ? boostSwatch(c2Raw, 0.55, 0.94) : Qt.lighter(p1, 1.36);
        const p3 = Qt.rgba(Math.min(1, p2.r * 0.65 + 0.35), Math.min(1, p2.g * 0.65 + 0.35), Math.min(1, p2.b * 0.65 + 0.35), 1.0);
        wavePrimary = p1;
        waveSecondary = p2;
        waveTertiary = p3;
    }

    onHasCoverChanged: updateWavePalette()
    onAccentChanged: if (!hasCover) updateWavePalette()

    // Periodic MPRIS D-Bus sync while open (smooth interpolation runs locally at 30fps)
    Timer {
        interval: 2000
        repeat: true
        running: popup.windowShown && popup.playing
        onTriggered: if (popup.player && popup.player.updatePosition) popup.player.updatePosition()
    }

    readonly property real effectiveRadius: Math.min(popup.cardRadius, Math.min(width, height) / 2)

    Image {
        id: coverImg
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.smooth: true
        source: popup.art
        sourceSize: Qt.size(512, 512)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        onStatusChanged: if (status === Image.Ready) imgColors.update()
    }

    Kirigami.ImageColors {
        id: imgColors
        source: coverImg
        onPaletteChanged: popup.updateWavePalette()
    }

    // SDF-antialiased rounded cover art matching GlassSurface's exact corner curve
    Kirigami.ShadowedTexture {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, popup.effectiveRadius - 1)
        color: "transparent"
        source: coverImg
        opacity: popup.hasCover ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }

    // Dedicated rounded dark scrim always rendered cleanly over cover art (including on track changes)
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        visible: popup.hasCover || (popup.art.length > 0 && coverImg.status === Image.Loading)
        radius: Math.max(0, popup.effectiveRadius - 1)
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.05, 0.05, 0.07, 0.50) }
            GradientStop { position: 0.45; color: Qt.rgba(0.05, 0.05, 0.07, 0.54) }
            GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.03, 0.05, 0.78) }
        }
    }

    // Refined outer glass rim + subtle top specular highlight
    Rectangle {
        anchors.fill: parent
        visible: popup.hasCover || (popup.art.length > 0 && coverImg.status === Image.Loading)
        radius: popup.effectiveRadius
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.18)
    }
    Rectangle {
        visible: (popup.hasCover || coverImg.status === Image.Loading) && width > 0
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(0, parent.width - popup.effectiveRadius * 1.4)
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.25; color: Qt.rgba(1, 1, 1, 0.20) }
            GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.46) }
            GradientStop { position: 0.75; color: Qt.rgba(1, 1, 1, 0.20) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.gridUnit * 1.25
        anchors.rightMargin: Kirigami.Units.gridUnit * 1.25
        anchors.topMargin: Kirigami.Units.gridUnit * 0.95
        anchors.bottomMargin: Kirigami.Units.gridUnit * 1.05
        spacing: Kirigami.Units.smallSpacing * 1.6

        // --------------------------------------------------- top bar (output + raise)
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                visible: text.length > 0
                Layout.maximumWidth: Math.round(contentCol.width * 0.65)
                text: popup.audioOutputName
                color: popup.fgColor
                opacity: 0.88
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true }

            Item {
                id: raiseBtn
                visible: popup.hasPlayer && popup.player.canRaise
                implicitWidth: 26
                implicitHeight: 26
                activeFocusOnTab: visible
                Accessible.role: Accessible.Button
                Accessible.name: popup.hasPlayer ? i18n("Open %1", popup.player.identity) : ""
                Keys.onReturnPressed: { popup.player.raise(); popup.closeRequested(); }
                Keys.onSpacePressed: { popup.player.raise(); popup.closeRequested(); }

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: raiseMouse.containsPress ? Qt.rgba(1, 1, 1, 0.24)
                         : raiseMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                }

                Kirigami.Icon {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    source: popup.hasPlayer && popup.player.iconName ? popup.player.iconName : "media-playback-start"
                    opacity: raiseMouse.containsMouse ? 1.0 : 0.85
                }

                MouseArea {
                    id: raiseMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        popup.player.raise();
                        popup.closeRequested();
                    }
                }

                PC3.ToolTip.visible: raiseMouse.containsMouse
                PC3.ToolTip.text: popup.hasPlayer ? i18n("Open %1", popup.player.identity) : ""
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        // --------------------------------------------------- track title • artist
        Item {
            Layout.fillWidth: true
            implicitHeight: titleRow.implicitHeight

            RowLayout {
                id: titleRow
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width)
                spacing: Kirigami.Units.smallSpacing * 1.2

                Kirigami.Icon {
                    visible: source !== ""
                    Layout.preferredWidth: 16
                    Layout.preferredHeight: 16
                    Layout.alignment: Qt.AlignVCenter
                    source: popup.hasPlayer && popup.player.iconName ? popup.player.iconName : ""
                }

                PC3.Label {
                    Layout.fillWidth: true
                    text: {
                        if (!popup.hasPlayer)
                            return i18n("Media player");
                        const t = popup.player.track || popup.player.identity || i18n("Media player");
                        const a = popup.player.artist || "";
                        return a ? (t + "  •  " + a) : t;
                    }
                    color: popup.fgColor
                    font.pixelSize: Math.round(Kirigami.Theme.defaultFont.pixelSize * 1.12)
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    style: popup.hasCover ? Text.Raised : Text.Normal
                    styleColor: Qt.rgba(0, 0, 0, 0.45)
                }
            }
        }

        // --------------------------------------------------- dynamic waves + progress
        ColumnLayout {
            Layout.fillWidth: true
            visible: popup.hasPlayer
            spacing: 2

            Item {
                id: seekContainer
                Layout.fillWidth: true
                implicitHeight: 34

                readonly property real barY: 22
                property bool animateFill: false
                property real fillW: Math.max(0, Math.min(width, width * popup.progress))
                Behavior on fillW {
                    enabled: seekContainer.animateFill && popup.windowShown && popup.playing && !popup.seeking
                    NumberAnimation { duration: 220; easing.type: Easing.Linear }
                }
                property real waveAmp: popup.playing ? 1.0 : 0.25
                Behavior on waveAmp { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }

                Timer {
                    id: smoothEnableTimer
                    interval: 60
                    onTriggered: seekContainer.animateFill = true
                }

                Timer {
                    interval: 200
                    repeat: true
                    running: popup.windowShown && popup.playing && !popup.seeking
                    onTriggered: popup.refreshLivePosition()
                }

                // Pre-rendered wave layers painted only when the cover palette
                // changes, then scaled and animated purely on the GPU scene graph.
                Item {
                    x: 0
                    y: 0
                    width: seekContainer.width
                    height: seekContainer.barY + 2
                    visible: seekContainer.fillW > 3

                    WaveLayer {
                        waveColor: popup.waveTertiary
                        maxH: seekContainer.barY * 0.78
                        freq: 6.2
                        phaseOffset: 0.8
                        alpha: 0.48
                        breathMin: 0.68
                        breathDuration: 1350
                    }
                    WaveLayer {
                        waveColor: popup.waveSecondary
                        maxH: seekContainer.barY * 0.90
                        freq: 9.4
                        phaseOffset: 2.3
                        alpha: 0.70
                        breathMin: 0.62
                        breathDuration: 980
                    }
                    WaveLayer {
                        waveColor: popup.wavePrimary
                        maxH: seekContainer.barY * 0.70
                        freq: 12.6
                        phaseOffset: 4.1
                        alpha: 0.88
                        breathMin: 0.65
                        breathDuration: 760
                    }
                }

                // Track background (unplayed right)
                Rectangle {
                    id: track
                    x: 0
                    y: seekContainer.barY - height / 2
                    width: parent.width
                    height: seekArea.containsMouse || seekArea.pressed ? 6 : 5
                    radius: height / 2
                    color: (popup.hasCover || popup.isDark) ? Qt.rgba(1, 1, 1, 0.34) : Qt.rgba(0, 0, 0, 0.18)
                    Behavior on height { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }

                    // Played left bar in dominant cover color
                    Rectangle {
                        id: fillBar
                        width: seekContainer.fillW
                        height: parent.height
                        radius: parent.radius
                        color: popup.wavePrimary
                        Behavior on color { ColorAnimation { duration: 320 } }
                    }

                    // Circular thumb matching the reference (dominant fill + crisp white ring)
                    Rectangle {
                        width: seekArea.pressed ? 18 : 16
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, fillBar.width - width / 2))
                        color: popup.wavePrimary
                        Behavior on color { ColorAnimation { duration: 320 } }
                        border.width: 2.5
                        border.color: "#ffffff"
                        Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                    }
                }

                MouseArea {
                    id: seekArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    enabled: popup.hasPlayer && popup.player.canSeek && popup.effectiveLength > 0
                    // while dragging only the thumb/time move locally; the player
                    // gets a single seek on release (not one D-Bus call per pixel)
                    property real dragPos: -1
                    function posAt(mx) {
                        return Math.max(0, Math.min(1, mx / width)) * popup.effectiveLength;
                    }
                    function preview(mx) {
                        if (!popup.hasPlayer || popup.effectiveLength <= 0)
                            return;
                        dragPos = posAt(mx);
                        popup.syncClock(dragPos);
                    }
                    function commit() {
                        const pos = dragPos;
                        dragPos = -1;
                        popup.seeking = false;
                        if (pos < 0 || !popup.hasPlayer)
                            return;
                        popup.syncClock(pos);
                        if (popup.player.seekTo)
                            popup.player.seekTo(pos);
                        else
                            popup.player.position = pos;
                    }
                    onPressed: mouse => { popup.seeking = true; preview(mouse.x); }
                    onPositionChanged: mouse => { if (pressed) preview(mouse.x); }
                    onReleased: commit()
                    onCanceled: { dragPos = -1; popup.seeking = false; popup.syncClock(); }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PC3.Label {
                    text: popup.hasPlayer ? popup.fmt(popup.livePosition) : ""
                    color: popup.mutedFg
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                }
                Item { Layout.fillWidth: true }
                PC3.Label {
                    text: popup.hasPlayer ? (popup.effectiveLength > 0 ? popup.fmt(popup.effectiveLength) : "--:--") : ""
                    color: popup.mutedFg
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    font.features: { "tnum": 1 }
                }
            }
        }

        // --------------------------------------------------- playback controls
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            spacing: Kirigami.Units.largeSpacing * 1.1

            CircleControlButton {
                size: 46
                iconPx: 22
                iconName: "media-skip-backward"
                accessibleName: i18n("Previous track")
                fgColor: popup.fgColor
                enabled: popup.hasPlayer && popup.player.canGoPrevious
                onClicked: popup.player.previous()
            }

            CircleControlButton {
                size: 50
                iconPx: 26
                prominent: true
                iconName: popup.playing ? "media-playback-pause" : "media-playback-start"
                accessibleName: popup.playing ? i18n("Pause") : i18n("Play")
                fgColor: popup.fgColor
                enabled: popup.hasPlayer
                onClicked: popup.player.playPause()
            }

            CircleControlButton {
                size: 46
                iconPx: 22
                iconName: "media-skip-forward"
                accessibleName: i18n("Next track")
                fgColor: popup.fgColor
                enabled: popup.hasPlayer && popup.player.canGoNext
                onClicked: popup.player.next()
            }
        }
    }

    component CircleControlButton: Item {
        id: cbtn
        property int size: 46
        property int iconPx: 22
        property string iconName: ""
        property string accessibleName: ""
        property color fgColor: "#ffffff"
        property bool prominent: false
        signal clicked()

        activeFocusOnTab: enabled
        Accessible.role: Accessible.Button
        Accessible.name: accessibleName
        Keys.onReturnPressed: if (enabled) clicked()
        Keys.onSpacePressed: if (enabled) clicked()

        implicitWidth: size
        implicitHeight: size

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: {
                const base = cbtn.prominent ? 0.24 : 0.16;
                const a = !cbtn.enabled ? 0.10
                        : mouse.containsPress ? base + 0.16
                        : mouse.containsMouse ? base + 0.08 : base;
                return cbtn.fgColor === "#ffffff" ? Qt.rgba(1, 1, 1, a) : Qt.rgba(0, 0, 0, a);
            }
            border.width: 1
            border.color: cbtn.fgColor === "#ffffff"
                ? Qt.rgba(1, 1, 1, cbtn.prominent ? 0.22 : (cbtn.enabled ? 0.14 : 0.07))
                : Qt.rgba(0, 0, 0, cbtn.prominent ? 0.16 : (cbtn.enabled ? 0.09 : 0.05))
            scale: (cbtn.enabled && mouse.containsPress) ? 0.93 : 1.0
            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        }

        Kirigami.Icon {
            anchors.centerIn: parent
            width: cbtn.iconPx
            height: cbtn.iconPx
            source: cbtn.iconName
            isMask: true
            color: cbtn.fgColor
            opacity: cbtn.enabled ? 1.0 : 0.38
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: cbtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: cbtn.clicked()
        }
    }

    component WaveLayer: Canvas {
        id: wlayer
        property color waveColor: popup.accent
        property real maxH: 18
        property real freq: 8.0
        property real phaseOffset: 0.0
        property real alpha: 0.7
        property real breathMin: 0.65
        property int breathDuration: 1000
        property real breath: 1.0

        width: 256
        height: 24
        x: 0
        y: 0
        onWaveColorChanged: requestPaint()
        Component.onCompleted: requestPaint()

        SequentialAnimation on breath {
            running: popup.windowShown && popup.playing
            loops: Animation.Infinite
            NumberAnimation { to: wlayer.breathMin; duration: wlayer.breathDuration; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: wlayer.breathDuration; easing.type: Easing.InOutSine }
        }

        transform: Scale {
            origin.x: 0
            origin.y: seekContainer.barY
            xScale: Math.max(0, seekContainer.fillW / 256)
            yScale: seekContainer.waveAmp * wlayer.breath
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const spanW = width;
            const baseY = seekContainer.barY;
            const steps = 64;
            ctx.beginPath();
            ctx.moveTo(0, baseY);
            for (let i = 0; i <= steps; i++) {
                const u = i / steps;
                const env = Math.pow(Math.sin(Math.PI * u), 0.78);
                const mod = 0.52 + 0.48 * Math.sin(u * wlayer.freq + wlayer.phaseOffset);
                const h = wlayer.maxH * env * mod;
                ctx.lineTo(u * spanW, baseY - h);
            }
            ctx.lineTo(spanW, baseY);
            ctx.closePath();
            const col = wlayer.waveColor;
            const grad = ctx.createLinearGradient(0, baseY - wlayer.maxH, 0, baseY);
            grad.addColorStop(0.0, Qt.rgba(col.r, col.g, col.b, wlayer.alpha));
            grad.addColorStop(1.0, Qt.rgba(col.r, col.g, col.b, wlayer.alpha * 0.55));
            ctx.fillStyle = grad;
            ctx.fill();
        }
    }
}
