import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets
import qs
import qs.services

// One notification: icon, app + time, summary, body, action buttons, close button.
// Used both for toasts and in the notification center.
Rectangle {
    id: root

    required property Notification notification
    property bool toast: false
    readonly property bool hovered: hover.hovered
    readonly property bool critical: notification.urgency === NotificationUrgency.Critical

    implicitHeight: layout.implicitHeight + 2 * Theme.spaceXs
    radius: Theme.radiusS
    color: root.toast ? Theme.notificationsBg : (hover.hovered ? Theme.componentHover : Theme.component)
    border.width: root.toast ? 1 : 0
    border.color: root.critical ? Theme.destructive : Theme.popupBorder

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: e => e.button === Qt.MiddleButton ? Notifs.dismiss(root.notification) : Notifs.activate(root.notification)
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spaceXs
        spacing: Theme.spaceXs

        Item {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 40
            implicitHeight: 40
            ClippingRectangle {
                anchors.fill: parent
                radius: Theme.radiusS
                color: "transparent"
                visible: img.status === Image.Ready
                Image {
                    id: img
                    anchors.fill: parent
                    source: Notifs.iconSource(root.notification)
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    sourceSize.width: 80
                    sourceSize.height: 80
                }
            }
            Icon {
                anchors.centerIn: parent
                visible: img.status !== Image.Ready
                icon: root.critical ? "warning" : "notifications"
                size: 26
                color: root.critical ? Theme.destructive : Theme.accent
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                StyledText {
                    Layout.fillWidth: true
                    text: root.notification.appName || "Notification"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                    elide: Text.ElideRight
                }
                StyledText {
                    text: Notifs.timeText(root.notification)
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.textDim
                }
                IconButton {
                    icon: "close"
                    iconSize: 16
                    implicitWidth: 22
                    implicitHeight: 22
                    onClicked: Notifs.dismiss(root.notification)
                }
            }

            StyledText {
                Layout.fillWidth: true
                text: root.notification.summary
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.notification.body
                color: Theme.textDim
                wrapMode: Text.Wrap
                maximumLineCount: root.toast ? 4 : 8
                elide: Text.ElideRight
                textFormat: Text.StyledText
                linkColor: Theme.accent
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Flow {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spaceXxxs
                spacing: Theme.spaceXxxs
                visible: actions.count > 0

                Repeater {
                    id: actions
                    model: root.notification.actions.filter(a => a.identifier !== "default")
                    delegate: Rectangle {
                        required property NotificationAction modelData
                        implicitWidth: label.implicitWidth + 2 * Theme.spaceXs
                        implicitHeight: 28
                        radius: height / 2
                        color: actionMouse.containsMouse ? Theme.buttonHover : Theme.button
                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            text: parent.modelData.text
                            font.pixelSize: Theme.fontSizeSmall
                        }
                        MouseArea {
                            id: actionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Notifs.invokeAction(root.notification, parent.modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
