/*
 * Wheel → previous/next track, throttled. Touchpads send many small deltas
 * per gesture (and mice can send several notches at once), so deltas are
 * accumulated to one wheel notch (120) and then a short cooldown swallows
 * the rest of the gesture: one gesture = one skip.
 */
import QtQuick

QtObject {
    id: skipper

    property var player: null
    property int cooldownMs: 300

    property real _acc: 0
    property double _lastSkipMs: 0

    function handle(angleDeltaY) {
        if (!player)
            return;
        const now = Date.now();
        if (now - _lastSkipMs < cooldownMs) {
            _acc = 0;
            return;
        }
        // a change of direction starts a new count
        if (_acc !== 0 && Math.sign(_acc) !== Math.sign(angleDeltaY))
            _acc = 0;
        _acc += angleDeltaY;
        if (Math.abs(_acc) < 120)
            return;
        const forward = _acc < 0;
        _acc = 0;
        _lastSkipMs = now;
        if (forward && player.canGoNext)
            player.next();
        else if (!forward && player.canGoPrevious)
            player.previous();
    }
}
