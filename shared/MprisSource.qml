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

    property var player: null

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
        if (player !== next)
            player = next;
    }
}
