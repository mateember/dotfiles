pragma Singleton

import QtQuick
import Quickshell
import qs

// Shared clock so every bar uses one timer.
Singleton {
    id: root

    readonly property date date: clock?.date ?? new Date()
    readonly property var locale: Config.locale === "" ? Qt.locale() : Qt.locale(Config.locale)

    function format(fmt: string): string {
        return root.locale.toString(root.date, fmt);
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }
}
