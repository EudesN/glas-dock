/*
 * Glasdock — the media player to show.
 *
 * Plasma's Mpris2Model has a "multiplexer" row that always follows the active
 * player, but it is inserted after the real players; Mpris2Model.currentPlayer
 * can stay on whichever row was first. So the multiplexer row is looked up
 * explicitly, falling back to a playing player, then to any player.
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
        }
        onObjectAdded: source.pick()
        onObjectRemoved: source.pick()
    }

    function pick() {
        let multiplexer = null, playing = null, any = null;
        for (let i = 0; i < rows.count; i++) {
            const r = rows.objectAt(i);
            if (!r || !r.container)
                continue;
            if (r.isMultiplexer)
                multiplexer = r.container;
            else {
                if (!any)
                    any = r.container;
                if (!playing && r.container.playbackStatus === Mpris.PlaybackStatus.Playing)
                    playing = r.container;
            }
        }
        player = multiplexer || playing || any;
    }
}
