/*
 * Glasdock — the media player to show.
 *
 * Plasma's Mpris2Model has a "multiplexer" row that follows the active player,
 * but it is inserted after the real players and its data can arrive later
 * than the row itself; Mpris2Model.currentPlayer can also stay on whichever
 * row came first. So the choice is redone whenever any row is added, removed
 * or changes: the multiplexer when it points at a real player, otherwise a
 * playing player, otherwise any player.
 */
import QtQuick
import org.kde.plasma.private.mpris as Mpris

Item {
    id: source

    property var rawPlayer: null
    readonly property var player: rawPlayer ? playerProxy : null

    // Spotify Desktop on Linux leaves xesam:title, xesam:artist and mpris:artUrl
    // empty when playing on a remote Spotify Connect device (e.g. a phone), and
    // only exposes xesam:url = https://open.spotify.com/track/<22-char base62 id>,
    // which Plasma's Mpris2Model turns into track = "<id>". Resolve the real
    // title, artist and cover from Spotify's public embed/oEmbed metadata.
    readonly property string rawTrack: rawPlayer ? (rawPlayer.track || "") : ""
    readonly property string rawArtist: rawPlayer ? (rawPlayer.artist || "") : ""
    readonly property string rawArtUrl: rawPlayer ? (rawPlayer.artUrl || "").toString() : ""
    readonly property bool isSpotifyTrackId: rawTrack.length === 22
        && rawArtist === "" && rawArtUrl === ""
        && /^[0-9A-Za-z]{22}$/.test(rawTrack)

    property string resolvedForId: ""
    property string resolvedTrack: ""
    property string resolvedArtist: ""
    property string resolvedArtUrl: ""
    property var _cache: ({})
    property var _xhrOEmbed: null
    property var _xhrEmbed: null

    // Pre-fetch and keep the active track's cover in Qt's pixmap cache at the
    // exact size used by Cover.qml, so opening PlayerPopup shows it instantly.
    Image {
        visible: false
        source: playerProxy.artUrl
        sourceSize: Qt.size(256, 256)
        asynchronous: true
        cache: true
    }

    onRawTrackChanged: resolveSpotifyTrack()
    onIsSpotifyTrackIdChanged: resolveSpotifyTrack()

    function _abortXhrs() {
        if (_xhrOEmbed) {
            _xhrOEmbed.onreadystatechange = null;
            _xhrOEmbed.abort();
            _xhrOEmbed = null;
        }
        if (_xhrEmbed) {
            _xhrEmbed.onreadystatechange = null;
            _xhrEmbed.abort();
            _xhrEmbed = null;
        }
    }

    function resolveSpotifyTrack() {
        _abortXhrs();
        if (!isSpotifyTrackId) {
            resolvedForId = "";
            resolvedTrack = "";
            resolvedArtist = "";
            resolvedArtUrl = "";
            return;
        }
        const id = rawTrack;
        if (_cache[id] && _cache[id].artist) {
            resolvedForId = id;
            resolvedTrack = _cache[id].track;
            resolvedArtist = _cache[id].artist;
            resolvedArtUrl = _cache[id].artUrl;
            return;
        }
        if (resolvedForId !== id) {
            resolvedForId = id;
            resolvedTrack = _cache[id] ? _cache[id].track : "";
            resolvedArtist = _cache[id] ? _cache[id].artist : "";
            resolvedArtUrl = _cache[id] ? _cache[id].artUrl : "";
        }
        // 1) Fast lightweight JSON (~500 bytes) for immediate title + cover art
        const xhrFast = new XMLHttpRequest();
        _xhrOEmbed = xhrFast;
        xhrFast.timeout = 6000;
        xhrFast.onreadystatechange = () => {
            if (xhrFast.readyState !== XMLHttpRequest.DONE)
                return;
            if (_xhrOEmbed === xhrFast)
                _xhrOEmbed = null;
            if (xhrFast.status !== 200)
                return;
            try {
                const json = JSON.parse(xhrFast.responseText);
                const title = json.title || "";
                const art = json.thumbnail_url || "";
                if (title && source.rawTrack === id) {
                    if (!source.resolvedTrack)
                        source.resolvedTrack = title;
                    if (!source.resolvedArtUrl && art)
                        source.resolvedArtUrl = art;
                    if (!_cache[id])
                        _cache[id] = { track: title, artist: "", artUrl: art };
                }
            } catch (e) {}
        };
        xhrFast.open("GET", "https://open.spotify.com/oembed?url=https://open.spotify.com/track/" + encodeURIComponent(id));
        xhrFast.send();

        // 2) Full embed metadata to also populate the artist name and high-res cover
        const xhrFull = new XMLHttpRequest();
        _xhrEmbed = xhrFull;
        xhrFull.timeout = 8000;
        xhrFull.onreadystatechange = () => {
            if (xhrFull.readyState !== XMLHttpRequest.DONE)
                return;
            if (_xhrEmbed === xhrFull)
                _xhrEmbed = null;
            if (xhrFull.status !== 200)
                return;
            try {
                const m = xhrFull.responseText.match(/<script id="__NEXT_DATA__"[^>]*>([\s\S]*?)<\/script>/);
                if (m) {
                    const entity = JSON.parse(m[1]).props.pageProps.state.data.entity;
                    const title = entity.title || "";
                    const artist = entity.subtitle
                        || (entity.artists ? entity.artists.map(a => a.name).join(", ") : "");
                    const imgs = (entity.visualIdentity && entity.visualIdentity.image) || [];
                    const art = imgs.length > 0 ? (imgs[imgs.length - 1].url || "") : "";
                    if (title) {
                        _cache[id] = { track: title, artist: artist, artUrl: art || (source.resolvedArtUrl || "") };
                        if (source.rawTrack === id) {
                            source.resolvedTrack = title;
                            source.resolvedArtist = artist;
                            if (art)
                                source.resolvedArtUrl = art;
                        }
                    }
                }
            } catch (e) {}
        };
        xhrFull.open("GET", "https://open.spotify.com/embed/track/" + encodeURIComponent(id));
        xhrFull.send();
    }

    QtObject {
        id: playerProxy
        readonly property string track: source.isSpotifyTrackId
            ? (source.resolvedTrack || (source.rawPlayer ? source.rawPlayer.identity : ""))
            : source.rawTrack
        readonly property string artist: source.isSpotifyTrackId ? source.resolvedArtist : source.rawArtist
        readonly property string album: source.rawPlayer ? (source.rawPlayer.album || "") : ""
        readonly property string artUrl: source.isSpotifyTrackId ? source.resolvedArtUrl : source.rawArtUrl
        readonly property string identity: source.rawPlayer ? (source.rawPlayer.identity || "") : ""
        readonly property string iconName: source.rawPlayer ? (source.rawPlayer.iconName || "") : ""
        readonly property int playbackStatus: source.rawPlayer ? source.rawPlayer.playbackStatus : 0
        readonly property real position: source.rawPlayer ? source.rawPlayer.position : 0
        readonly property real length: source.rawPlayer ? source.rawPlayer.length : 0
        readonly property bool canSeek: source.rawPlayer ? source.rawPlayer.canSeek : false
        readonly property bool canGoPrevious: source.rawPlayer ? source.rawPlayer.canGoPrevious : false
        readonly property bool canGoNext: source.rawPlayer ? source.rawPlayer.canGoNext : false
        readonly property bool canPlay: source.rawPlayer ? source.rawPlayer.canPlay : false
        readonly property bool canPause: source.rawPlayer ? source.rawPlayer.canPause : false
        readonly property bool canRaise: source.rawPlayer ? source.rawPlayer.canRaise : false

        function seekTo(pos) { if (source.rawPlayer) source.rawPlayer.position = pos; }
        function playPause() { if (source.rawPlayer) source.rawPlayer.PlayPause(); }
        function previous() { if (source.rawPlayer) source.rawPlayer.Previous(); }
        function next() { if (source.rawPlayer) source.rawPlayer.Next(); }
        function raise() { if (source.rawPlayer) source.rawPlayer.Raise(); }
        function updatePosition() { if (source.rawPlayer) source.rawPlayer.updatePosition(); }
    }

    Mpris.Mpris2Model { id: mprisModel }

    Instantiator {
        id: rows
        model: mprisModel
        delegate: QtObject {
            required property var container
            required property bool isMultiplexer
            onContainerChanged: pickTimer.restart()
            onIsMultiplexerChanged: pickTimer.restart()
            // a player that starts/stops playing can change the fallback choice
            readonly property int status: container ? container.playbackStatus : 0
            onStatusChanged: pickTimer.restart()
            readonly property string identity: container ? (container.identity || "") : ""
            onIdentityChanged: pickTimer.restart()
        }
        onObjectAdded: pickTimer.restart()
        onObjectRemoved: pickTimer.restart()
    }

    Connections {
        target: mprisModel
        function onRowsInserted() { pickTimer.restart(); }
        function onRowsRemoved() { pickTimer.restart(); }
        function onModelReset() { pickTimer.restart(); }
        function onDataChanged() { pickTimer.restart(); }
    }

    // coalesce bursts of model changes into one choice
    Timer {
        id: pickTimer
        interval: 50
        onTriggered: source.pick()
    }
    Component.onCompleted: pickTimer.start()

    function pick() {
        let multiplexer = null, playing = null, any = null;
        for (let i = 0; i < rows.count; i++) {
            const r = rows.objectAt(i);
            if (!r || !r.container)
                continue;
            if (r.isMultiplexer) {
                // only when it actually points at a player
                if (r.container.identity)
                    multiplexer = r.container;
            } else {
                if (!any)
                    any = r.container;
                if (!playing && r.container.playbackStatus === Mpris.PlaybackStatus.Playing)
                    playing = r.container;
            }
        }
        const next = multiplexer || playing || any;
        if (rawPlayer !== next)
            rawPlayer = next;
    }
}
