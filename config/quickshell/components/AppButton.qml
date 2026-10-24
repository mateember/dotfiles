import QtQuick
import Quickshell
import qs
import qs.services

// Header button that opens an external app (e.g. a cosmic-settings page) and closes the popups.
//   AppButton { command: ["cosmic-settings", "bluetooth"] }
IconButton {
    id: root

    property var command: []
    icon: "settings"

    onClicked: {
        Popups.close();
        Quickshell.execDetached(root.command);
    }
}
