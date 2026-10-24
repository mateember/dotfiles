import QtQuick
import qs
import qs.components
import qs.services

// Opens the quick settings panel (same as SUPER comma).
BarButton {
    id: root

    active: QuickSettingsState.open
    onClicked: QuickSettingsState.toggle()

    Icon { icon: "tune" }
}
