/*
 * Glasdock — cover-art media player card with discrete audio output, dynamic
 * cover-colored waves along the progress bar, and centered playback controls.
 */
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
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
    property bool showWaves: true

    readonly property bool hasPlayer: player !== null && player !== undefined
    readonly property bool hasTrackedClock: hasPlayer && player.currentPosition !== undefined
    readonly property bool playing: hasPlayer && player.playbackStatus === Mpris.PlaybackStatus.Playing
    readonly property string art: hasPlayer ? (player.artUrl || "").toString() : ""
    readonly property bool hasCover: coverImg.status === Image.Ready
    readonly property bool windowShown: popup.visible && (Window.window ? Window.window.visible : true)

    property real _basePos: 0
    property double _baseTimeMs: 0
    property real _cachedLength: 0
    property real livePosition: 0
    readonly property real effectiveLength: !hasPlayer ? 0
        : hasTrackedClock ? player.trackedLength
        : (player.length > 0 ? player.length : _cachedLength)
    readonly property real progress: effectiveLength > 0
        ? Math.max(0, Math.min(1, livePosition / effectiveLength)) : 0
    readonly property color fgColor: (hasCover || isDark) ? "#ffffff" : "#1d1d1f"
    readonly property color mutedFg: (hasCover || isDark) ? Qt.rgba(1, 1, 1, 0.78) : Qt.rgba(0.11, 0.11, 0.12, 0.72)

    function _currentInterpolated() {
        if (hasTrackedClock)
            return player.currentPosition();
        if (!hasPlayer || !playing || _baseTimeMs <= 0)
            return _basePos;
        const elapsedUs = Math.max(0, Date.now() - _baseTimeMs) * 1000;
        const next = _basePos + elapsedUs;
        return effectiveLength > 0 ? Math.min(effectiveLength, next) : next;
    }

    function syncClock(forcePos) {
        if (hasTrackedClock) {
            if (forcePos !== undefined) {
                const p = Math.max(0, forcePos);
                if (player.previewSeek)
                    player.previewSeek(p);
                livePosition = p;
            } else {
                livePosition = player.currentPosition();
            }
            return;
        }
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
        if (rawPos === 0 && playing && (!hasPlayer || (player.length || 0) <= 0) && curLive > 0) {
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
        if (hasTrackedClock)
            livePosition = player.currentPosition();
        else
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
        applyCachedOrUpdateColors();
        if (player && player.updatePosition)
            player.updatePosition();
    }

    Connections {
        target: popup.player
        function onClockRevisionChanged() {
            if (!popup.seeking && popup.hasTrackedClock)
                popup.livePosition = popup.player.currentPosition();
        }
        function onLengthChanged() {
            if (!popup.hasTrackedClock && popup.hasPlayer && popup.player.length > 0)
                popup._cachedLength = popup.player.length;
        }
        function onPositionChanged() { if (!popup.seeking && !popup.hasTrackedClock) popup.syncClock(); }
        function onPlaybackStatusChanged() {
            if (popup.hasTrackedClock) {
                popup.livePosition = popup.player.currentPosition();
                return;
            }
            const cur = popup._currentInterpolated();
            popup._basePos = cur;
            popup._baseTimeMs = Date.now();
            popup.livePosition = cur;
            popup.syncClock();
            if (popup.player && popup.player.updatePosition)
                popup.player.updatePosition();
        }
        function onTrackChanged() {
            Qt.callLater(() => popup.applyCachedOrUpdateColors());
            if (popup.hasTrackedClock) {
                popup.livePosition = popup.player.currentPosition();
                return;
            }
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

    implicitWidth: Math.round(Kirigami.Units.gridUnit * 22)
    implicitHeight: Math.round(Math.max(Kirigami.Units.gridUnit * 15,
        contentCol.implicitHeight + Kirigami.Units.largeSpacing * 2.0))

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

    function resetWavePalette() {
        wavePrimary = popup.accent;
        waveSecondary = Qt.lighter(popup.accent, 1.32);
        waveTertiary = Qt.lighter(popup.accent, 1.55);
    }

    function applyCachedOrUpdateColors() {
        if (!popup.art) {
            resetWavePalette();
            return;
        }
        const cached = hasPlayer && player.cachedPalette ? player.cachedPalette(popup.art) : null;
        if (cached) {
            wavePrimary = cached.p1;
            waveSecondary = cached.p2;
            waveTertiary = cached.p3;
            return;
        }
        colorProbe.sampleUrl(popup.art);
    }

    function extractDeterministicPalette(data) {
        const BUCKETS = 18;
        const sumW = new Array(BUCKETS).fill(0);
        const sumR = new Array(BUCKETS).fill(0);
        const sumG = new Array(BUCKETS).fill(0);
        const sumB = new Array(BUCKETS).fill(0);

        for (let i = 0; i < data.length; i += 4) {
            if (data[i + 3] < 128)
                continue;
            const r = data[i] / 255;
            const g = data[i + 1] / 255;
            const b = data[i + 2] / 255;
            const mx = Math.max(r, g, b);
            const mn = Math.min(r, g, b);
            const d = mx - mn;
            const v = mx;
            const s = mx > 0 ? d / mx : 0;
            if (v < 0.14 || s < 0.16)
                continue;
            let h = 0;
            if (d > 0) {
                if (mx === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6;
                else if (mx === g) h = ((b - r) / d + 2) / 6;
                else h = ((r - g) / d + 4) / 6;
            }
            const idx = Math.floor(h * BUCKETS) % BUCKETS;
            const w = (0.35 + 0.65 * s) * (0.40 + 0.60 * v);
            sumW[idx] += w;
            sumR[idx] += r * w;
            sumG[idx] += g * w;
            sumB[idx] += b * w;
        }

        // Smooth bucket ranking across adjacent hue bins so colors near a bin edge don't split
        const scores = new Array(BUCKETS);
        let best1 = -1, bestScore1 = 0;
        for (let i = 0; i < BUCKETS; i++) {
            const prev = (i + BUCKETS - 1) % BUCKETS;
            const next = (i + 1) % BUCKETS;
            scores[i] = sumW[i] + 0.25 * (sumW[prev] + sumW[next]);
            if (sumW[i] > 0 && scores[i] > bestScore1) {
                bestScore1 = scores[i];
                best1 = i;
            }
        }
        if (best1 < 0) {
            resetWavePalette();
            return;
        }

        let best2 = -1, bestScore2 = 0;
        for (let i = 0; i < BUCKETS; i++) {
            const dist = Math.min(Math.abs(i - best1), BUCKETS - Math.abs(i - best1));
            if (dist >= 2 && sumW[i] > 0 && scores[i] > bestScore2 && sumW[i] >= sumW[best1] * 0.15) {
                bestScore2 = scores[i];
                best2 = i;
            }
        }

        const c1Raw = Qt.rgba(sumR[best1] / sumW[best1], sumG[best1] / sumW[best1], sumB[best1] / sumW[best1], 1.0);
        const c2Raw = best2 >= 0
            ? Qt.rgba(sumR[best2] / sumW[best2], sumG[best2] / sumW[best2], sumB[best2] / sumW[best2], 1.0)
            : null;
        const p1 = boostSwatch(c1Raw, 0.72, 0.88);
        const p2 = c2Raw ? boostSwatch(c2Raw, 0.55, 0.94) : Qt.lighter(p1, 1.36);
        const p3 = Qt.rgba(Math.min(1, p2.r * 0.65 + 0.35), Math.min(1, p2.g * 0.65 + 0.35), Math.min(1, p2.b * 0.65 + 0.35), 1.0);
        wavePrimary = p1;
        waveSecondary = p2;
        waveTertiary = p3;
        if (hasPlayer && player.storePalette && popup.art)
            player.storePalette(popup.art, p1, p2, p3);
    }

    onHasCoverChanged: applyCachedOrUpdateColors()
    onArtChanged: applyCachedOrUpdateColors()
    onAccentChanged: if (!hasCover) resetWavePalette()

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
        onStatusChanged: if (status === Image.Ready) popup.applyCachedOrUpdateColors()
    }

    // Tiny 24x24 canvas for 100% deterministic hue-histogram sampling via Canvas.loadImage
    // (unloaded immediately after sampling so zero image memory is retained).
    Canvas {
        id: colorProbe
        width: 24
        height: 24
        opacity: 0
        enabled: false
        property string targetUrl: ""

        function sampleUrl(u) {
            if (!u)
                return;
            if (targetUrl && targetUrl !== u && isImageLoaded(targetUrl))
                unloadImage(targetUrl);
            targetUrl = u;
            if (isImageLoaded(u))
                requestPaint();
            else
                loadImage(u);
        }

        onImageLoaded: {
            if (targetUrl && isImageLoaded(targetUrl))
                requestPaint();
        }
        onPaint: {
            const u = targetUrl;
            if (!u || !isImageLoaded(u))
                return;
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.drawImage(u, 0, 0, width, height);
            const pixels = ctx.getImageData(0, 0, width, height).data;
            unloadImage(u);
            if (u === popup.art)
                popup.extractDeterministicPalette(pixels);
        }
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
            GradientStop { position: 0.0; color: Qt.rgba(0.04, 0.04, 0.06, 0.38) }
            GradientStop { position: 0.42; color: Qt.rgba(0.04, 0.04, 0.06, 0.46) }
            GradientStop { position: 1.0; color: Qt.rgba(0.03, 0.03, 0.05, 0.82) }
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
        anchors.topMargin: Kirigami.Units.gridUnit * 0.9
        anchors.bottomMargin: Kirigami.Units.gridUnit * 1.0
        spacing: Kirigami.Units.smallSpacing * 1.5

        // --------------------------------------------------- top bar (output + raise)
        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PC3.Label {
                visible: text.length > 0
                Layout.maximumWidth: Math.round(contentCol.width * 0.65)
                text: popup.audioOutputName
                color: popup.fgColor
                opacity: 0.90
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                style: popup.hasCover ? Text.Raised : Text.Normal
                styleColor: Qt.rgba(0, 0, 0, 0.45)
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
            }
        }

        // Let the upper portion of album covers & video thumbnails breathe
        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.smallSpacing
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
                implicitHeight: popup.showWaves ? 34 : 22

                readonly property real barY: popup.showWaves ? 22 : 11
                property bool animateFill: false
                property real fillW: Math.max(0, Math.min(width, width * popup.progress))
                Behavior on fillW {
                    enabled: seekContainer.animateFill && popup.windowShown && popup.playing && !popup.seeking
                    NumberAnimation { duration: 220; easing.type: Easing.Linear }
                }
                property real waveAmp: popup.playing ? 1.0 : 0.25
                Behavior on waveAmp { NumberAnimation { duration: 350; easing.type: Easing.OutCubic } }
                // Scales wave height smoothly when the played bar is still short
                readonly property real sizeAmp: Math.max(0, Math.min(1, Math.pow(Math.max(0, fillW - 4) / 72, 0.72)))
                readonly property real edgeFadeStop: Math.min(0.46, Math.max(0.18, 46 / Math.max(1, fillW)))

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

                // Pre-rendered periodic silk wave ribbons painted only when the cover
                // palette changes, then scrolled & masked purely on the GPU at
                // fixed FBO size so wavelength and height adapt naturally to fillW.
                Item {
                    id: waveStrip
                    x: 0
                    y: 0
                    width: Math.max(1, seekContainer.width)
                    height: seekContainer.barY + 2
                    clip: true
                    visible: false
                    layer.enabled: popup.showWaves
                    layer.smooth: true

                    WaveLayer {
                        shapeKind: 0
                        waveColor: popup.waveTertiary
                        maxH: 13.5
                        periodPx: 256
                        phaseOffset: 0.4
                        alpha: 0.42
                        scrollDuration: 6400
                        reverse: false
                        breathMin: 0.76
                        breathDuration: 1900
                    }
                    WaveLayer {
                        shapeKind: 1
                        waveColor: popup.waveSecondary
                        maxH: 12.5
                        periodPx: 196
                        phaseOffset: 2.3
                        alpha: 0.62
                        scrollDuration: 4600
                        reverse: true
                        breathMin: 0.72
                        breathDuration: 1450
                    }
                    WaveLayer {
                        shapeKind: 2
                        waveColor: popup.wavePrimary
                        maxH: 10.5
                        periodPx: 152
                        phaseOffset: 4.2
                        alpha: 0.88
                        scrollDuration: 3500
                        reverse: false
                        breathMin: 0.70
                        breathDuration: 1150
                    }
                }

                Item {
                    id: waveMask
                    x: 0
                    y: 0
                    width: waveStrip.width
                    height: waveStrip.height
                    visible: false
                    layer.enabled: popup.showWaves

                    Rectangle {
                        x: 0
                        y: 0
                        width: Math.max(0, seekContainer.fillW - 2)
                        height: parent.height
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: seekContainer.edgeFadeStop; color: "#ffffff" }
                            GradientStop { position: 1.0 - seekContainer.edgeFadeStop; color: "#ffffff" }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                }

                Item {
                    x: 0
                    y: 0
                    width: Math.max(0, seekContainer.fillW)
                    height: waveStrip.height
                    clip: true
                    visible: popup.showWaves
                    opacity: seekContainer.fillW > 3 ? 1 : 0

                    MultiEffect {
                        x: 0
                        y: 0
                        width: waveStrip.width
                        height: waveStrip.height
                        source: waveStrip
                        maskEnabled: true
                        maskSource: waveMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1.0
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

                    // Circular thumb matching the reference (dominant fill + crisp white ring + soft glow)
                    Kirigami.ShadowedRectangle {
                        width: seekArea.pressed ? 18 : 16
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        x: Math.max(0, Math.min(parent.width - width, fillBar.width - width / 2))
                        color: popup.wavePrimary
                        Behavior on color { ColorAnimation { duration: 320 } }
                        border.width: 2.5
                        border.color: "#ffffff"
                        shadow.size: popup.showWaves ? 14 : 6
                        shadow.color: Qt.rgba(popup.wavePrimary.r, popup.wavePrimary.g, popup.wavePrimary.b, popup.showWaves ? 0.68 : 0.35)
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
                    onPressed: mouse => {
                        popup.seeking = true;
                        if (popup.hasPlayer && popup.player.setSeeking)
                            popup.player.setSeeking(true);
                        preview(mouse.x);
                    }
                    onPositionChanged: mouse => { if (pressed) preview(mouse.x); }
                    onReleased: {
                        if (popup.hasPlayer && popup.player.setSeeking)
                            popup.player.setSeeking(false);
                        commit();
                    }
                    onCanceled: {
                        dragPos = -1;
                        popup.seeking = false;
                        if (popup.hasPlayer && popup.player.setSeeking)
                            popup.player.setSeeking(false);
                        popup.syncClock();
                    }
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
        property int shapeKind: 0
        property color waveColor: popup.accent
        property real maxH: 18
        property int periodPx: 96
        property real phaseOffset: 0.0
        property real alpha: 0.7
        property int scrollDuration: 3000
        property bool reverse: false
        property real breathMin: 0.65
        property int breathDuration: 1000
        property real breath: 1.0
        property real scrollX: reverse ? -periodPx : 0

        readonly property int cycles: Math.max(4, Math.ceil((seekContainer.width + periodPx) / periodPx) + 1)
        width: periodPx * cycles
        height: 24
        x: scrollX
        y: 0
        onWaveColorChanged: if (popup.showWaves) requestPaint()
        onWidthChanged: if (popup.showWaves) requestPaint()
        Component.onCompleted: if (popup.showWaves) requestPaint()

        Connections {
            target: popup
            function onShowWavesChanged() {
                if (popup.showWaves)
                    wlayer.requestPaint();
            }
        }

        NumberAnimation on scrollX {
            running: popup.showWaves && popup.windowShown && popup.playing
            loops: Animation.Infinite
            from: wlayer.reverse ? -wlayer.periodPx : 0
            to: wlayer.reverse ? 0 : -wlayer.periodPx
            duration: wlayer.scrollDuration
        }

        SequentialAnimation on breath {
            running: popup.showWaves && popup.windowShown && popup.playing
            loops: Animation.Infinite
            NumberAnimation { to: wlayer.breathMin; duration: wlayer.breathDuration; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: wlayer.breathDuration; easing.type: Easing.InOutSine }
        }

        transform: Scale {
            origin.x: 0
            origin.y: seekContainer.barY
            yScale: seekContainer.waveAmp * seekContainer.sizeAmp * wlayer.breath
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const spanW = width;
            const baseY = seekContainer.barY;
            const steps = Math.max(72, wlayer.cycles * 36);
            ctx.beginPath();
            ctx.moveTo(0, baseY);
            for (let i = 0; i <= steps; i++) {
                const px = (i / steps) * spanW;
                const a = (px / wlayer.periodPx) * Math.PI * 2 + wlayer.phaseOffset;
                let mod;
                if (wlayer.shapeKind === 0) {
                    // Longest, lowest translucent silk arch touching the bar cleanly between swells
                    mod = Math.pow(0.5 + 0.5 * Math.sin(a), 1.45);
                } else if (wlayer.shapeKind === 1) {
                    // Broad asymmetric dual-lobe silk ribbon
                    const b1 = Math.pow(0.5 + 0.5 * Math.sin(a), 1.65);
                    const b2 = Math.pow(0.5 + 0.5 * Math.sin(a + 2.2), 2.5) * 0.48;
                    mod = Math.min(1.0, b1 + b2);
                } else {
                    // Sleek luminous front highlight ribbon hugging the played bar
                    const s = 0.5 + 0.5 * Math.sin(a);
                    mod = Math.pow(s, 1.9) * (0.78 + 0.22 * Math.sin(a * 2 + 0.9));
                }
                const h = wlayer.maxH * Math.max(0.0, Math.min(1.0, mod));
                ctx.lineTo(px, baseY - h);
            }
            ctx.lineTo(spanW, baseY);
            ctx.closePath();
            const col = wlayer.waveColor;
            const grad = ctx.createLinearGradient(0, baseY - wlayer.maxH, 0, baseY);
            if (wlayer.shapeKind === 2) {
                grad.addColorStop(0.0, Qt.rgba(col.r, col.g, col.b, wlayer.alpha * 0.72));
                grad.addColorStop(1.0, Qt.rgba(col.r, col.g, col.b, wlayer.alpha));
            } else {
                grad.addColorStop(0.0, Qt.rgba(col.r, col.g, col.b, wlayer.alpha * 0.95));
                grad.addColorStop(1.0, Qt.rgba(col.r, col.g, col.b, wlayer.alpha * 0.50));
            }
            ctx.fillStyle = grad;
            ctx.fill();
        }
    }
}
