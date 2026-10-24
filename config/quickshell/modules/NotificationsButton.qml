import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications
import qs
import qs.components
import qs.services

// Notification center: history, do-not-disturb, clear all.
// Middle click on the bar icon toggles do-not-disturb.
BarButton {
    id: root

    active: pop.open
    onClicked: button => button === Qt.MiddleButton ? Notifs.toggleDnd() : pop.toggle()

    Icon {
        icon: Notifs.dnd ? "notifications_off" : (Notifs.history.length > 0 ? "notifications_unread" : "notifications")
        color: Notifs.dnd ? Theme.textDim : Theme.text
    }

    Popup {
        id: pop
        name: "notifications"
        anchorItem: root
        contentWidth: 380

        // Toasts would duplicate what the center shows.
        onOpenChanged: if (open) Notifs.toasts = []

        PopupHeader {
            title: "Notifications"
            IconButton {
                icon: "clear_all"
                enabled: Notifs.history.length > 0
                onClicked: Notifs.clearAll()
            }
        }

        ListItem {
            icon: "do_not_disturb_on"
            text: "Do not disturb"
            highlighted: Notifs.dnd
            onClicked: Notifs.toggleDnd()
            Toggle { checked: Notifs.dnd; onToggled: Notifs.toggleDnd() }
        }

        StyledText {
            visible: !Notifs.running
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.warning
            text: "The notification server is off (started with --no-notify)."
        }

        MediaCard {}

        Separator {}

        StyledText {
            visible: Notifs.history.length === 0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "No notifications"
            color: Theme.textDim
            Layout.topMargin: Theme.spaceXs
            Layout.bottomMargin: Theme.spaceXs
        }

        ListView {
            visible: count > 0
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 520)
            clip: true
            spacing: Theme.spaceXxs
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.history

            delegate: NotificationCard {
                required property Notification modelData
                notification: modelData
                width: ListView.view.width
            }
        }
    }
}
