import QtQuick
import qs
import qs.components
import qs.services

// Caffeine: keeps the screen awake (Wayland idle inhibitor, see Bar.qml). Amber when on.
BarButton {
    id: root

    active: Idle.caffeine
    onClicked: Idle.toggle()

    Icon {
        icon: "coffee"
        filled: Idle.caffeine
        color: Idle.caffeine ? Theme.accent : Theme.text
    }
}
