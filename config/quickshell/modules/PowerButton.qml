import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Session menu. Log out / reboot / shut down need a second click to confirm.
// Lock goes through loginctl so hypridle's lock_cmd decides what locks (shell lock, else hyprlock).
BarButton {
    id: root

    active: pop.open
    onClicked: pop.toggle()

    Icon { icon: "power_settings_new" }

    Popup {
        id: pop
        name: "power"
        anchorItem: root
        contentWidth: 240

        property string confirm: ""
        onOpenChanged: confirm = ""

        function run(action) {
            if (action.confirm && pop.confirm !== action.id) {
                pop.confirm = action.id;
                return;
            }
            pop.close();
            if (action.id === "logout") Hypr.exit();
            else Quickshell.execDetached(action.command);
        }

        Repeater {
            model: [
                { id: "lock", icon: "lock", text: "Lock", command: ["loginctl", "lock-session"], confirm: false },
                { id: "suspend", icon: "bedtime", text: "Suspend", command: ["systemctl", "suspend"], confirm: false },
                { id: "logout", icon: "logout", text: "Log out", command: [], confirm: true },
                { id: "reboot", icon: "restart_alt", text: "Restart", command: ["systemctl", "reboot"], confirm: true },
                { id: "poweroff", icon: "power_settings_new", text: "Shut down", command: ["systemctl", "poweroff"], confirm: true }
            ]
            delegate: ListItem {
                required property var modelData
                icon: modelData.icon
                text: pop.confirm === modelData.id ? `Click again to ${modelData.text.toLowerCase()}` : modelData.text
                highlighted: pop.confirm === modelData.id
                onClicked: pop.run(modelData)
            }
        }
    }
}
