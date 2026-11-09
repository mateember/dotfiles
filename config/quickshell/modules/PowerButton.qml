import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services

// Session menu. Log out / reboot / shut down need a second click (or Enter) to confirm.
// Grabs the keyboard when open (SUPER+L): ↑/↓ or j/k to move, Enter/Space/l to run, Esc/q/h to close.
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
        grabKeyboard: true

        property string confirm: ""
        property int selected: 0
        onOpenChanged: { confirm = ""; selected = 0; }

        readonly property var actions: [
            { id: "lock", icon: "lock", text: "Lock", command: ["loginctl", "lock-session"], confirm: false },
            { id: "suspend", icon: "bedtime", text: "Suspend", command: ["systemctl", "suspend"], confirm: false },
            { id: "logout", icon: "logout", text: "Log out", command: [], confirm: true },
            { id: "reboot", icon: "restart_alt", text: "Restart", command: ["systemctl", "reboot"], confirm: true },
            { id: "poweroff", icon: "power_settings_new", text: "Shut down", command: ["systemctl", "poweroff"], confirm: true }
        ]

        function run(action) {
            if (action.confirm && pop.confirm !== action.id) {
                pop.confirm = action.id;
                return;
            }
            pop.close();
            if (action.id === "logout") Hypr.exit();
            else Quickshell.execDetached(action.command);
        }

        function moveSelection(delta) {
            const n = pop.actions.length;
            pop.selected = (pop.selected + delta + n) % n;
            pop.confirm = "";
        }

        // ↑/↓, k/j (also Tab / Shift+Tab) move; Enter / Space / l / → activate (twice to confirm).
        keyHandler: e => {
            switch (e.key) {
            case Qt.Key_Up: case Qt.Key_K: case Qt.Key_Backtab:
                pop.moveSelection(-1); e.accepted = true; break;
            case Qt.Key_Down: case Qt.Key_J: case Qt.Key_Tab:
                pop.moveSelection(1); e.accepted = true; break;
            case Qt.Key_Home: case Qt.Key_G:
                if (e.key === Qt.Key_G && (e.modifiers & Qt.ShiftModifier)) pop.selected = pop.actions.length - 1;
                else pop.selected = 0;
                pop.confirm = ""; e.accepted = true; break;
            case Qt.Key_End:
                pop.selected = pop.actions.length - 1; pop.confirm = ""; e.accepted = true; break;
            case Qt.Key_Return: case Qt.Key_Enter: case Qt.Key_Space: case Qt.Key_L: case Qt.Key_Right:
                pop.run(pop.actions[pop.selected]); e.accepted = true; break;
            case Qt.Key_Q: case Qt.Key_H: case Qt.Key_Left:
                pop.close(); e.accepted = true; break;
            }
        }

        Repeater {
            model: pop.actions
            delegate: ListItem {
                required property var modelData
                required property int index
                icon: modelData.icon
                text: pop.confirm === modelData.id ? `Press again to ${modelData.text.toLowerCase()}` : modelData.text
                highlighted: pop.confirm === modelData.id
                selected: pop.selected === index
                onHovered: pop.selected = index
                onClicked: pop.run(modelData)
            }
        }
    }
}
