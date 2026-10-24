import QtQuick

// Turns wheel events into discrete steps. A mouse notch (120 units) = one step; touchpad
// scrolling sends many small events, which are summed up until they reach the same distance.
// `cooldown` (ms) limits how often a step can fire (for workspace switching).
//   ScrollStepper { id: s; onStepped: dir => ... }      // dir: +1 = scroll up, -1 = down
//   ... onWheel: e => s.feed(e)
QtObject {
    id: root

    property real threshold: 120
    property int cooldown: 0
    property real _acc: 0
    property double _last: 0

    signal stepped(int direction)

    function feed(e) {
        // angleDelta is in 1/8 degree; touchpads report small values per event.
        const d = e.angleDelta.y !== 0 ? e.angleDelta.y : e.pixelDelta.y * 2;
        if ((d > 0) !== (root._acc > 0)) root._acc = 0;   // direction change resets
        root._acc += d;
        if (Math.abs(root._acc) < root.threshold) return;
        const now = Date.now();
        const dir = root._acc > 0 ? 1 : -1;
        root._acc = 0;
        if (root.cooldown > 0 && now - root._last < root.cooldown) return;
        root._last = now;
        root.stepped(dir);
    }
}
