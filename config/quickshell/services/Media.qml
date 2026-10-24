pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// MPRIS players. `active` = the one the user picked, else the playing one, else the first.
Singleton {
    id: root

    // playerctld mirrors other players; hide it to avoid duplicates.
    readonly property var players: Mpris.players.values.filter(p => !p.dbusName.includes("playerctld"))
    property MprisPlayer selected: null
    readonly property MprisPlayer active: (selected && players.includes(selected)) ? selected
                                        : (players.find(p => p.isPlaying) ?? players[0] ?? null)
    readonly property bool playing: active?.isPlaying ?? false

    function togglePlaying() { if (root.active?.canTogglePlaying) root.active.togglePlaying(); }
    function next() { if (root.active?.canGoNext) root.active.next(); }
    function previous() { if (root.active?.canGoPrevious) root.active.previous(); }

    function formatTime(s: real): string {
        if (!s || s < 0) s = 0;
        const m = Math.floor(s / 60), sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }
}
